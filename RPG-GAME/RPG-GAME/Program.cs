using DataTypesLib;
using GameLogicLib;
using GameObjectsLib;
using InputLib;
using RenderLib;
using System.Diagnostics;
using static System.Net.Mime.MediaTypeNames;

Environment.CurrentDirectory = AppDomain.CurrentDomain.BaseDirectory;

Textures TextureLoader = new();
(byte r, byte g, byte b) Gray_color = (100, 100, 100),
                         Blue_color = (102, 153, 225),
                         Black_color = (0, 0, 0);
bool COLOR_ON = true;
bool HINTS_ON = true;
Stopwatch scenechange_cooldown = Stopwatch.StartNew();
long sc_cooldown = 200;
bool INVENTORY_OPEN = false;
bool STATISTICS_OPEN = false;
bool FULLSCREEN_ON = false;
int old_w = Console.WindowWidth, old_h = Console.WindowHeight;


// -- Hints --
Dictionary<string, string> Hints_Content = new()
{
    { "Hints", "" }
};
void DrawHints()
{
    (byte r, byte g, byte b) color = COLOR_ON ? Blue_color : Gray_color;
    Frame Hints =
        Draw.TextBox(Hints_Content.Select(item => $"{item.Key}: {item.Value}").ToArray(), (1, 0),
        color, Black_color, color, Filled: true);
    Render.PutFrame(0, 0, Hints, true);
}


// -- Scenes --
Scene Intro_scene = new("Intro Dialog");
Scene Outside_scene = new("Outside");
Scene Aula_scene = new("Aula");
Scene Classroom_scene = new("Classroom");


// -- Menus --
Menu Main_menu = new("Main menu", ["Start", "Settings", "Statistics", "Exit"]);
Menu Start_menu = new("Start menu", ["Hétfő", "Kedd", "Szerda", "Csütörtök", "Péntek"]);
Menu Settings_menu = new("Settings", ["UI Colors ON", "Hints ON", "Fullscreen ON"]);


// -- Player --
Thing Player = new("Player", 0, 0);
Player.animations.Add("idle", TextureLoader.Load("player_idle"));
Player.animations.Add("walk", TextureLoader.Load("player_walk1", "player_walk2"));
Player.animations.Add("wave", TextureLoader.Load("player_wave1", "player_wave2", "player_wave3", "player_wave2"));
Player.animations.Add("falling", TextureLoader.Load("player_falling"));
Player.animation_name = "idle";
Player.animation_fps = 10;
Player.Inventory.AddItem(new Item("Rusty Key", "An old rusty key. I wonder what it opens?"));
double player_speed = 0.05;
double old_x = Player.double_x, old_y = Player.double_y;
void PlayerUpdate(double delta)
{
    if (!Player.Hide)
    {
        double r_player_x = Math.Round(Player.double_x, 5);
        double r_player_y = Math.Round(Player.double_y, 5);
        
        bool x_change = r_player_x != old_x;
        bool y_change = r_player_y != old_y;
        if (x_change || y_change)
        {
            if (y_change && Scene.Current == Outside_scene)
                Player.animation_name = "falling";
            else Player.animation_name = "walk";
        }
        else if (Player.animation_name != "wave") Player.animation_name = "idle";
        if (Input.IsPressed(ConsoleKey.E)) Player.animation_name = "wave";
        old_x = r_player_x;
        old_y = r_player_y;
        Player.PlayAnimation();

        double moveX = 0, moveY = 0;
        if (Scene.Current != Outside_scene)
        {
            if (Input.IsDown(ConsoleKey.W)) moveY -= 1;
            if (Input.IsDown(ConsoleKey.S)) moveY += 1;
        } else moveY += 1;
        if (Input.IsDown(ConsoleKey.A)) moveX -= 1;
        if (Input.IsDown(ConsoleKey.D)) moveX += 1;

        double length = Math.Sqrt(moveX * moveX + moveY * moveY);
        if (length > 1)
        {
            moveX /= length;
            moveY /= length;
        }

        Player.Move(
            moveX * player_speed * delta,
            moveY * player_speed / 2 * delta
            );

        foreach (Thing thing in Scene.Current?.Things ?? new List<Thing>())
        {
            if (thing == Player || !thing.IsSolid || thing.Hide) continue;
            (double x, double y)? dist = Player.IsCollidingWith(thing);
            if (dist != null)
            {
                Player.double_x += dist.Value.x;
                Player.double_y += dist.Value.y;
            }
        }
    }
}


// -- School --
Thing School = new("School", 0, 0, Hitbox: new(37, 9, 21, 5)) 
{ 
    IsSolid = false,
    InteractHint = "Go Inside[Enter]",
    OnInteract = () => { Scene.Current = Aula_scene; }
};
School.Output = TextureLoader.Load("school_front")[0];
Thing stair1 = new(null, 0, 0); stair1.Output = new(23, 1);
Thing stair2 = new(null, 0, 0); stair2.Output = new(27, 1);
Thing stair3 = new(null, 0, 0); stair3.Output = new(31, 1);
void SchoolUpdate()
{
    if (!School.Hide)
    {
        School.double_x = Render.width / 2 - School.width / 2;
        School.double_y = Render.height - School.height;
        
        stair1.x = School.x + 36;
        stair1.y = School.y + School.height - 3;

        stair2.x = School.x + 34;
        stair2.y = School.y + School.height - 2;

        stair3.x = School.x + 32;
        stair3.y = School.y + School.height - 1;

        foreach (Thing stair in new Thing[] { stair1, stair2, stair3 })
        {
            (double x, double y)? dist = Player.IsCollidingWith(stair);
            if (dist != null) Player.double_y += dist.Value.y;
        }
    }   
}


// -- Aula --
Thing Aula = new("Aula", 0, 0, Hitbox: new(62, 30, 11, 1))
{
    IsSolid = true,
    InteractHint = "Go Outside[Enter]",
    OnInteract = () => { Scene.Current = Outside_scene; }
};
Aula.Output = TextureLoader.Load("aula")[0];

Thing AulaTopWall = new(null, 0, 0, Hitbox: new(26, 0, 85, 5)) { IsSolid = true };
Thing AulaLeftDesks = new(null, 0, 0, Hitbox: new(0, 5, 40, 26)) { IsSolid = true };
Thing AulaRightDesks = new(null, 0, 0, Hitbox: new(80, 5, 45, 26)) { IsSolid = true };
Thing AulaBottomLeftWall = new(null, 0, 0, Hitbox: new(0, 31, 61, 1)) { IsSolid = true };
Thing AulaBottomRightWall = new(null, 0, 0, Hitbox: new(73, 31, 60, 1)) { IsSolid = true };

Discussion? CurrentDiscussion = null;

Thing BranyoNPC = new("Branyo", 0, 0, Hitbox: new(0, 0, 5, 4));
BranyoNPC.Output = Draw.Text(Sprites.NpcA.Split('\n'), (200, 200, 200), (0, 0, 0));
BranyoNPC.IsSolid = true;
BranyoNPC.OnInteract = () => { CurrentDiscussion = Conversations.BranyoMonday; };
BranyoNPC.InteractHint = "Talk to Branyó [Enter]";

Thing BarbieNPC = new("Barbie", 0, 0, Hitbox: new(0, 0, 5, 4));
BarbieNPC.Output = Draw.Text(Sprites.NpcB.Split('\n'), (200, 200, 200), (0, 0, 0));
BarbieNPC.IsSolid = true;
BarbieNPC.OnInteract = () => { CurrentDiscussion = Conversations.BarbieMonday; };
BarbieNPC.InteractHint = "Talk to Barbie [Enter]";

Thing CsPSNPC = new("CsPS", 0, 0, Hitbox: new(0, 0, 5, 4));
CsPSNPC.Output = Draw.Text(Sprites.NpcC.Split('\n'), (200, 200, 200), (0, 0, 0));
CsPSNPC.IsSolid = true;
CsPSNPC.OnInteract = () => { CurrentDiscussion = Conversations.CsPSMonday; };
CsPSNPC.InteractHint = "Talk to CsPS [Enter]";

Thing LockedDoor = new("LockedDoor", 0, 0, Hitbox: new(10, 10, 3, 1)) 
{ 
    IsSolid = true, 
    InteractHint = "Unlock Door[Enter]"
};
LockedDoor.Output = Draw.Box(3, 1, (200, 100, 0), (0, 0, 0));
LockedDoor.OnInteract = () => {
    if (Player.Inventory.Items.Any(i => i.Name == "Rusty Key")) {
        LockedDoor.InteractHint = "Enter Classroom[Enter]";
        LockedDoor.OnInteract = () => { Scene.Current = Classroom_scene; };
        Hints_Content["System"] = "Unlocked the door!";
    } else {
        Hints_Content["System"] = "You need a Rusty Key!";
    }
};

void AulaUpdate()
{
    if (!Aula.Hide)
    {
        Aula.x = Render.width / 2 - Aula.width / 2;
        Aula.y = Render.height - Aula.height;
        LockedDoor.x = Aula.x + 60;
        LockedDoor.y = Aula.y + 5;

        AulaTopWall.x = Aula.x; AulaTopWall.y = Aula.y;
        AulaLeftDesks.x = Aula.x; AulaLeftDesks.y = Aula.y;
        AulaRightDesks.x = Aula.x; AulaRightDesks.y = Aula.y;
        AulaBottomLeftWall.x = Aula.x; AulaBottomLeftWall.y = Aula.y;
        AulaBottomRightWall.x = Aula.x; AulaBottomRightWall.y = Aula.y;

        BranyoNPC.x = Aula.x + 30; BranyoNPC.y = Aula.y + 15;
        BarbieNPC.x = Aula.x + 80; BarbieNPC.y = Aula.y + 10;
        CsPSNPC.x = Aula.x + 50; CsPSNPC.y = Aula.y + 22;
    }
}

// -- Classroom --
Thing Classroom = new("Classroom", 0, 0, Hitbox: new(80, 25, 1, 1));
Classroom.Output = Draw.Box(80, 25, (100, 100, 100), (0, 0, 0), Filled: true);
Thing ClassroomDoor = new("ClassroomDoor", 0, 0, Hitbox: new(10, 24, 6, 1))
{
    IsSolid = true,
    InteractHint = "Go to Aula[Enter]",
    OnInteract = () => { Scene.Current = Aula_scene; }
};
ClassroomDoor.Output = Draw.Box(6, 1, (200, 100, 0), (0, 0, 0));

Thing ClassroomTopWall = new(null, 0, 0, Hitbox: new(0, 0, 80, 1)) { IsSolid = true };
Thing ClassroomBottomWall = new(null, 0, 0, Hitbox: new(0, 24, 80, 1)) { IsSolid = true };
Thing ClassroomLeftDesks = new("Classroom Desks Left", 0, 0, Hitbox: new(0, 10, 20, 20));
ClassroomLeftDesks.IsSolid = true;
Thing ClassroomRightDesks = new("Classroom Desks Right", 0, 0, Hitbox: new(80, 10, 20, 20));
ClassroomRightDesks.IsSolid = true;

// -- NPCs --
Thing LeibiNPC = new("Leibi", 0, 0, Hitbox: new(0, 0, 5, 4));
LeibiNPC.Output = Draw.Text(Sprites.NpcA.Split('\n'), (200, 200, 200), (0, 0, 0));
LeibiNPC.IsSolid = true;
LeibiNPC.OnInteract = () => { CurrentDiscussion = Conversations.LeibiMonday; };
LeibiNPC.InteractHint = "Talk to Leibi [Enter]";

Thing RizzlerNPC = new("Rizzler", 0, 0, Hitbox: new(0, 0, 5, 4));
RizzlerNPC.Output = Draw.Text(Sprites.NpcB.Split('\n'), (200, 200, 200), (0, 0, 0));
RizzlerNPC.IsSolid = true;
RizzlerNPC.OnInteract = () => { CurrentDiscussion = Conversations.RizzlerMonday; };
RizzlerNPC.InteractHint = "Talk to Rizzler [Enter]";

void ClassroomUpdate()
{
    if (!Classroom.Hide)
    {
        Classroom.x = Render.width / 2 - Classroom.width / 2;
        Classroom.y = Render.height / 2 - Classroom.height / 2;
        
        ClassroomDoor.x = Classroom.x + 10;
        ClassroomDoor.y = Classroom.y + 24;

        ClassroomTopWall.x = Classroom.x; ClassroomTopWall.y = Classroom.y;
        ClassroomBottomWall.x = Classroom.x; ClassroomBottomWall.y = Classroom.y;
        ClassroomLeftDesks.x = Classroom.x; ClassroomLeftDesks.y = Classroom.y;
        ClassroomRightDesks.x = Classroom.x; ClassroomRightDesks.y = Classroom.y;

        LeibiNPC.x = Classroom.x + 25; LeibiNPC.y = Classroom.y + 5;
        RizzlerNPC.x = Classroom.x + 60; RizzlerNPC.y = Classroom.y + 5;
    }
}

// -- Game border barriers
Thing LeftBarrier = new("LeftBarrier", -1, -1) { IsSolid = true };
Thing TopBarrier = new("TopBarrier", -1, -1) { IsSolid = true };
Thing RightBarrier = new("RightBarrier", 0, 0) { IsSolid = true };
Thing BottomBarrier = new("BottomBarrier", 0, 0) { IsSolid = true };
Game.OnResized += (w, h) =>
{
    Render.Fill(new(' '));
    if (Scene.Current != Aula_scene)
    {
        Frame horizontal = new(w, 1);
        Frame vertical = new(1, h);

        LeftBarrier.Output = vertical;
        TopBarrier.Output = horizontal;
        RightBarrier.Output = vertical;
        BottomBarrier.Output = horizontal;

        RightBarrier.x = w;
        BottomBarrier.y = h;
    }
    SchoolUpdate();
    AulaUpdate();
};



// -- Dialoges --
Thing Dialog_SideArt = new("Dialog SideArt", 0, 0);
Thing Dialog_TextBox = new("Dialog TextBox", 0, 0);
Dialog Intro_dialog = Dialog.LoadDialog("Assets/dialogs/intro.json");
void DialogUpdate()
{
    Dialog current = Dialog.Current!;
    if (current.CurrentLine != null && Input.IsPressed(ConsoleKey.Enter))
    {
        if(!current.NextLine())
        {
            Dialog.Current = null;
            Scene.Current = Outside_scene;
        }
    }
}
void DialogDraw()
{
    Dialog dialog = Dialog.Current!;
    
    (byte r, byte g, byte b) color = COLOR_ON ? Blue_color : Gray_color;
    string[] line = dialog.CurrentLine!.Value.Split("\n");
    Dialog_TextBox.Output = Draw.TextBox(line, (2, 1), color,
            Black_color, color);
    Dialog_TextBox.y = Render.height / 2 - Dialog_TextBox.height / 2;
    Dialog_TextBox.x = (int)(Render.width * 0.75 - Dialog_TextBox.width / 2);
}

// -- Discussions --

void DiscussionUpdate()
{
    if (CurrentDiscussion == null) return;

    if (Input.IsPressed(ConsoleKey.Escape))
    {
        CurrentDiscussion = null;
        return;
    }

    if (CurrentDiscussion.Choices.Count == 0)
    {
        if (Input.IsPressed(ConsoleKey.Enter))
            CurrentDiscussion = null;
    }
    else
    {
        if (Input.IsPressed(ConsoleKey.A) && CurrentDiscussion.Choices.ContainsKey('a'))
        {
            CurrentDiscussion.SelectChoice('a');
            CurrentDiscussion = null;
        }
        else if (Input.IsPressed(ConsoleKey.B) && CurrentDiscussion.Choices.ContainsKey('b'))
        {
            CurrentDiscussion.SelectChoice('b');
            CurrentDiscussion = null;
        }
        else if (Input.IsPressed(ConsoleKey.C) && CurrentDiscussion.Choices.ContainsKey('c'))
        {
            CurrentDiscussion.SelectChoice('c');
            CurrentDiscussion = null;
        }
    }
}

void DiscussionDraw()
{
    if (CurrentDiscussion == null) return;
    (byte r, byte g, byte b) color = COLOR_ON ? Blue_color : Gray_color;

    // Draw Face
    Dialog_SideArt.Output = Draw.Text(CurrentDiscussion.AsciiFace.Split('\n'), color, Black_color);
    Dialog_SideArt.y = Render.height / 2 - Dialog_SideArt.height / 2;
    Dialog_SideArt.x = (int)(Render.width * 0.25 - Dialog_SideArt.width / 2);
    
    // Draw Text
    List<string> lines = new List<string>();
    lines.Add($"[{CurrentDiscussion.NpcName}]");
    lines.Add("");
    lines.AddRange(CurrentDiscussion.Dialogue.Split('\n'));
    lines.Add("");
    
    if (CurrentDiscussion.Choices.Count > 0)
    {
        foreach (var choice in CurrentDiscussion.Choices)
            lines.Add($"[{char.ToUpper(choice.Key)}] {choice.Value}");
    }
    else
    {
        lines.Add("Press [Enter] to continue...");
    }

    Dialog_TextBox.Output = Draw.TextBox(lines.ToArray(), (2, 1), color, Black_color, color);
    Dialog_TextBox.y = Render.height / 2 - Dialog_TextBox.height / 2;
    Dialog_TextBox.x = (int)(Render.width * 0.75 - Dialog_TextBox.width / 2);

    Render.PutFrame(Dialog_SideArt.x, Dialog_SideArt.y, Dialog_SideArt.Output, true);
    Render.PutFrame(Dialog_TextBox.x, Dialog_TextBox.y, Dialog_TextBox.Output, true);
}

// -- Scenes --
Intro_scene.AddThings(Dialog_SideArt, Dialog_TextBox);
Outside_scene.AddThings(Player, School, LeftBarrier, TopBarrier, RightBarrier, BottomBarrier);
Aula_scene.AddThings(Player, Aula, LockedDoor, AulaTopWall, AulaLeftDesks, AulaRightDesks, AulaBottomLeftWall, AulaBottomRightWall, BranyoNPC, BarbieNPC, CsPSNPC);
Classroom_scene.AddThings(Player, Classroom, ClassroomDoor, ClassroomTopWall, ClassroomBottomWall, ClassroomLeftDesks, ClassroomRightDesks, LeibiNPC, RizzlerNPC);

Scene.OnChange += (from, to) =>
{
    if (to == Outside_scene)
    {
        Hints_Content["Movement"] = "Left[A] Right[D]";
        if (from == Intro_scene)
        {
            Player.x = 10;
            Player.y = Render.height - Player.height - 2;
        } else
        {
            Player.x = Render.width / 2 - Player.width / 2;
            Player.y = Render.height - Player.height - 3;
        }
    } else Hints_Content.Remove("School interaction");
    
    if (to == Aula_scene)
    {
        Player.x = Render.width / 2 - Player.width / 2;
        Player.y = Render.height - Player.height;
        Hints_Content["Movement"] = "Up[W] Left[A] Down[S] Right[D]";
    } else Hints_Content.Remove("Aula interaction");

    if (to == Intro_scene)
    {
        Dialog.Current = Intro_dialog;
        Hints_Content["Dialog interaction"] = "Next dialog[Enter]";
    } else Hints_Content.Remove("Dialog interaction");

    scenechange_cooldown.Restart();
};
void SceneUpdate(double delta)
{
    Scene? current = Scene.Current;
    long cooldown = scenechange_cooldown.ElapsedMilliseconds;

    if (current != null && current.Name.Contains("Dialog")) 
    {
        DialogUpdate();
    }
    else
    {
        Hints_Content.Remove("Interaction");
        Rect originalHitbox = Player._Hitbox;
        Player._Hitbox = new Rect(originalHitbox.x - 2, originalHitbox.y - 2, 
            (originalHitbox.width ?? Player.width) + 4, 
            (originalHitbox.height ?? Player.height) + 4);

        foreach (Thing thing in Scene.Current?.Things ?? new List<Thing>())
        {
            if (thing == Player || thing.Hide || thing.OnInteract == null) continue;
            
            if (Player.IsCollidingWith(thing) != null)
            {
                Hints_Content["Interaction"] = thing.InteractHint ?? "Interact[Enter]";
                if (cooldown >= sc_cooldown && Input.IsDown(ConsoleKey.Enter))
                {
                    scenechange_cooldown.Restart();
                    thing.OnInteract();
                    break;
                }
            }
        }
        Player._Hitbox = originalHitbox;
        
        if (current == Outside_scene) SchoolUpdate();
        else if (current == Aula_scene) AulaUpdate();
        else if (current == Classroom_scene) ClassroomUpdate();
    }
    
    PlayerUpdate(delta);
}
void SceneDraw()
{
}


// -- Menus --
void MenuUpdate()
{
    int i = Menu.Current!.SelectedIndex;
    string selected = Menu.Current.Options[i];
    int l = Menu.Current.Options.Count;

    // WS for up/down
    if (Input.IsPressed(ConsoleKey.W)) Menu.Current.SelectedIndex = (i - 1 + l) % l;
    if (Input.IsPressed(ConsoleKey.S)) Menu.Current.SelectedIndex = (i + 1) % l;

    // if the current menu is not settings
    if (Menu.Current == Settings_menu)
    {
        // AD for toggle (Settings ON/OFF)
        if (Input.IsPressed(ConsoleKey.A) || Input.IsPressed(ConsoleKey.D))
        {
            switch (i)
            {
                case 0:
                    COLOR_ON = !COLOR_ON;
                    Settings_menu.Options[i] = $"UI Colors {(COLOR_ON ? "ON" : "OFF")}";
                    break;
                case 1:
                    HINTS_ON = !HINTS_ON;
                    Settings_menu.Options[i] = $"Hints {(HINTS_ON ? "ON" : "OFF")}";
                    break;
                case 2:
                    FULLSCREEN_ON = !FULLSCREEN_ON;
                    Settings_menu.Options[i] = $"Fullscreen {(FULLSCREEN_ON ? "ON" : "OFF")}";
                    if (OperatingSystem.IsWindows())
                    {
                        if (FULLSCREEN_ON)
                        {
                            old_w = Console.WindowWidth;
                            old_h = Console.WindowHeight;
                            Console.SetWindowSize(Console.LargestWindowWidth, Console.LargestWindowHeight);
                        }
                        else
                        {
                            Console.SetWindowSize(old_w, old_h);
                        }
                    }
                    break;
            }
        }
    }

    if (Input.IsPressed(ConsoleKey.Enter))
    {
        if (Menu.Current == Main_menu)
        {
            switch (selected)
            {
                case "Start": 
                    if (Intro_dialog.CurrentLine != null)
                    {
                        Scene.Current = Intro_scene;
                        Menu.Current = null;
                    }
                    else Menu.Current = Start_menu;
                    break;
                case "Settings": Menu.Current = Settings_menu; break;
                case "Statistics": STATISTICS_OPEN = true; break;
                case "Exit": Game.Stop(); break;
            }
        }
        else if (Menu.Current == Start_menu)
        {
            Menu.Current = null!;
            Scene.Current = Outside_scene;
        }
    }

    if (Input.IsPressed(ConsoleKey.Escape))
    {
        if (Menu.Current == Main_menu && Scene.Current != null) Menu.Current = null!;
        else Menu.Current = Main_menu;
    }
}
void MenuDraw()
{
    Frame title;
    if (Menu.Current!.Name == "Main menu")
    {
        string[] logo = new string[] {
            " _   _                                              ",
            "| \\ | | ___ _   _ _ __ ___   __ _ _ __  _ __        ",
            "|  \\| |/ _ \\ | | | '_ ` _ \\ / _` | '_ \\| '_ \\       ",
            "| |\\  |  __/ |_| | | | | | | (_| | | | | | | |      ",
            "|_| \\_|\\___|\\__,_|_| |_| |_|\\__,_|_| |_|_| |_|      ",
            "                                                    ",
            " ____                  _            _               ",
            "/ ___| _   _ _ ____   _(_)_   ____ _| |             ",
            "\\___ \\| | | | '__\\ \\ / / \\ \\ / / _` | |             ",
            " ___) | |_| | |   \\ V /| |\\ V / (_| | |             ",
            "|____/ \\__,_|_|    \\_/ |_| \\_/ \\__,_|_|             ",
            "                                                    ",
            "__AF__        _   __AF__        _   _               ",
            "\\ \\      / /___| | __\\ \\      / /___| | __          ",
            " \\ \\ /\\ / // _ \\ |/ / \\ \\ /\\ / // _ \\ |/ /          ",
            "  \\ V  V /|  __/   <   \\ V  V /|  __/   <           ",
            "   \\_/\\_/  \\___|_|\\_\\   \\_/\\_/  \\___|_|\\_\\          "
        };
        for (int i = 0; i < logo.Length; i++) logo[i] = logo[i].Replace("__AF__", " ");
        title = Draw.Text(logo, COLOR_ON ? Blue_color : Gray_color, Black_color);
    }
    else
    {
        title = Draw.Text(Menu.Current!.Name, COLOR_ON ? Blue_color : Gray_color, Black_color);
    }
    Render.PutFrame(Render.width / 2 - title.width / 2, (int)(Render.height * 0.1), title, IgnoreLayer: true);

    string[] options = Menu.Current.Options.ToArray();
    int longest = options.Max(item => item.Length) + 2;
    int index = Menu.Current.SelectedIndex;
    (int horizontal, int vertical) padding = (1, 1);

    // Draw menu
    padding.horizontal += 2;
    padding.vertical += 1;
    int w = longest + padding.horizontal * 2;
    int h = options.Length + padding.vertical * 2;
    Frame MenuFrame = Draw.Box(w, h, COLOR_ON ? Blue_color : Gray_color, Black_color, Filled: true);
    for (int i = 0, l = options.Length; i < l; i++)
    {
        string opt = options[i];
        (byte r, byte g, byte b) color = COLOR_ON && index == i ? Blue_color : Gray_color;
        Frame OptFrame = Draw.Text((index == i ? "> " : "  ") + opt, color, Black_color);
        MenuFrame.PutFrame(padding.horizontal, padding.vertical + i, OptFrame, true);
    }
    Render.PutFrame(Render.width / 2 - w / 2, Render.height / 2 - h / 2, MenuFrame, true);
}

void UpdateInventory()
{
    if (Input.IsPressed(ConsoleKey.Tab) || Input.IsPressed(ConsoleKey.Escape))
    {
        INVENTORY_OPEN = false;
    }
}

void DrawInventory()
{
    Frame inventoryFrame = Draw.Box(40, 20, (100, 100, 100), (0, 0, 0), Filled: true);
    Render.PutFrame(Render.width / 2 - 20, Render.height / 2 - 10, inventoryFrame);

    Frame title = Draw.Text("Inventory", (102, 153, 225), (0, 0, 0));
    Render.PutFrame(Render.width / 2 - title.width / 2, Render.height / 2 - 9, title);

    if (Player.Inventory.Items.Count == 0)
    {
        Frame emptyText = Draw.Text("Your inventory is empty.", (100, 100, 100), (0, 0, 0));
        Render.PutFrame(Render.width / 2 - emptyText.width / 2, Render.height / 2 - 5, emptyText);
    }
    else
    {
        for (int i = 0; i < Player.Inventory.Items.Count; i++)
        {
            Item item = Player.Inventory.Items[i];
            Frame itemFrame = Draw.Text(item.Name, (102, 153, 225), (0, 0, 0));
            Render.PutFrame(Render.width / 2 - 18, Render.height / 2 - 7 + i, itemFrame);
        }
    }
}

void UpdateStatistics()
{
    if (Input.IsPressed(ConsoleKey.Escape))
    {
        STATISTICS_OPEN = false;
    }
}

void DrawStatistics()
{
    Frame statisticsFrame = Draw.Box(40, 20, (100, 100, 100), (0, 0, 0), Filled: true);
    Render.PutFrame(Render.width / 2 - 20, Render.height / 2 - 10, statisticsFrame);

    Frame title = Draw.Text("Statistics", (102, 153, 225), (0, 0, 0));
    Render.PutFrame(Render.width / 2 - title.width / 2, Render.height / 2 - 9, title);

    Frame questsCompleted = Draw.Text($"Quests Completed: {Player.Statistics.QuestsCompleted}", (102, 153, 225), (0, 0, 0));
    Render.PutFrame(Render.width / 2 - 18, Render.height / 2 - 7, questsCompleted);

    Frame enemiesDefeated = Draw.Text($"Enemies Defeated: {Player.Statistics.EnemiesDefeated}", (102, 153, 225), (0, 0, 0));
    Render.PutFrame(Render.width / 2 - 18, Render.height / 2 - 6, enemiesDefeated);
}


// Game update
Game.OnUpdate += (delta) =>
{
    if (Input.IsPressed(ConsoleKey.Tab))
    {
        INVENTORY_OPEN = !INVENTORY_OPEN;
    }

    if (INVENTORY_OPEN)
    {
        UpdateInventory();
        return;
    }

    if (STATISTICS_OPEN)
    {
        UpdateStatistics();
        return;
    }

    if (CurrentDiscussion != null)
    {
        DiscussionUpdate();
        return;
    }

    if (Menu.Current == null && Input.IsPressed(ConsoleKey.Escape))
    {
        Menu.Current = Main_menu;
        Menu.Current.SelectedIndex = 0;
    }
    if (Menu.Current != null) MenuUpdate();
    else SceneUpdate(delta);
};


// -- Game render --
Game.OnRender += () =>
{
    if (INVENTORY_OPEN)
    {
        DrawInventory();
    }
    else if (STATISTICS_OPEN)
    {
        DrawStatistics();
    }
    else
    {
        SceneDraw();
        
        if (HINTS_ON) DrawHints();
        if (STATISTICS_OPEN) DrawStatistics();
        if (Dialog.Current != null) DialogDraw();
        if (CurrentDiscussion != null) DiscussionDraw();
        if (Menu.Current != null) MenuDraw();
    }
};


// Main initialization and startup
Game.Fps = 100;
Game.OnResized += (w, h) => Render.Fill(new(' '));
Game.OnStart += () =>
{
    Scene.HideAllThings();
    Menu.Current = Main_menu;
};
Game.OnStop += () =>
{
    Render.ResetStyle();
    Console.Clear();
};

Game.Start(Console.WindowWidth, Console.WindowHeight);