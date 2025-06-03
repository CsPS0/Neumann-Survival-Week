using DataTypesLib;
using GameLogicLib;
using GameObjectsLib;
using InputLib;
using RenderLib;
using System.Diagnostics;
using static System.Net.Mime.MediaTypeNames;

Textures TextureLoader = new();
(byte r, byte g, byte b) Gray_color = (100, 100, 100),
                         Blue_color = (102, 153, 225),
                         Black_color = (0, 0, 0);
bool COLOR_ON = true;
bool HINTS_ON = true;
Stopwatch scenechange_cooldown = Stopwatch.StartNew();
long sc_cooldown = 200;


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


// -- Menus --
Menu Main_menu = new("Main menu", ["Start", "Settings", "Exit"]);
Menu Start_menu = new("Start menu", ["Hétfő", "Kedd"]);
Menu Settings_menu = new("Settings", ["UI Colors ON", "Hints ON"]);


// -- Player --
Thing Player = new("Player", 0, 0);
Player.animations.Add("idle", TextureLoader.Load("player_idle"));
Player.animations.Add("walk", TextureLoader.Load("player_walk1", "player_walk2"));
Player.animations.Add("wave", TextureLoader.Load("player_wave1", "player_wave2", "player_wave3", "player_wave2"));
Player.animations.Add("falling", TextureLoader.Load("player_falling"));
Player.animation_name = "idle";
Player.animation_fps = 10;
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
    }
}


// -- School --
Thing School = new("School", 0, 0, Hitbox: new(37, 9, 21, 5));
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
Thing Aula = new("Aula", 0, 0, Hitbox: new(62, 30, 11, 1));
Aula.Output = TextureLoader.Load("aula")[0];
void AulaUpdate()
{
    if (!Aula.Hide)
    {
        Aula.x = Render.width / 2 - Aula.width / 2;
        Aula.y = Render.height - Aula.height;
    }
}


// -- Game border barriers
Thing LeftBarrier = new("LeftBarrier", -1, -1);
Thing TopBarrier = new("TopBarrier", -1, -1);
Thing RightBarrier = new("RightBarrier", 0, 0);
Thing BottomBarrier = new("BottomBarrier", 0, 0);
Game.OnResized += (w, h) =>
{
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
};
void BarriersUpdate()
{
    foreach (Thing barrier in
        new Thing[] { LeftBarrier, TopBarrier, RightBarrier, BottomBarrier })
    {
        (double x, double y)? dist = Player.IsCollidingWith(barrier);
        if (dist != null)
        {
            Player.double_x += dist.Value.x;
            Player.double_y += dist.Value.y;
        }
    }
}


// -- Dialoges --
Thing Dialog_SideArt = new("Dialog SideArt", 0, 0);
Thing Dialog_TextBox = new("Dialog TextBox", 0, 0);
Dialog Intro_dialog = new("Intro");
Intro_dialog.AddDialogBranch(Intro_dialog.RootLine, TreeNode<string>.CreateBranch(
    "Welcome to the Neuman!" +
    "\nYou were kicked out of your previous school." +
    "\nAnd now you have to survive here a whole week.",
    "Good luck kid!"
)!);
Intro_dialog.ReStartDialog();
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
    Dialog_TextBox.x =
        (int)(Render.width * 0.75 - Dialog_TextBox.width / 2);
}

// -- Scenes --
Intro_scene.AddThings(Dialog_SideArt, Dialog_TextBox);
Outside_scene.AddThings(Player, School);
Aula_scene.AddThings(Player, Aula);
Scene.OnChange += (from, to) =>
{
    if (to == Outside_scene)
    {
        Hints_Content["Movement"] = "Left[A] Right[D]";
        if (from == Intro_scene)
        {
            Player.x = 10;
            Player.y = 0;
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

    if (current == Outside_scene)
    {
        if (Player.IsCollidingWith(School) != null)
        {
            if (cooldown >= sc_cooldown)
            {
                Hints_Content["School interaction"] = "Go Inside[Enter]";
                if (Input.IsDown(ConsoleKey.Enter)) Scene.Current = Aula_scene;
            }
        } else Hints_Content.Remove("School interaction");
        
        SchoolUpdate();
    }
    else if (current == Aula_scene)
    {
        if (Player.IsCollidingWith(Aula) != null)
        {
            if (cooldown >= sc_cooldown)
            {
                Hints_Content["Aula interaction"] = "Go Outside[Enter]";
                if (Input.IsDown(ConsoleKey.Enter)) Scene.Current = Outside_scene;
            }
        } else Hints_Content.Remove("Aula interaction");

        AulaUpdate();
    }
    else if (current != null && current.Name.Contains("Dialog")) DialogUpdate();
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
    Frame title = Draw.Text(Menu.Current.Name, COLOR_ON ? Blue_color : Gray_color, Black_color);
    Render.PutFrame(Render.width / 2 - title.width / 2, (int)(Render.height * 0.1), title);

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


// Game update
Game.OnUpdate += (delta) =>
{
    if (Menu.Current == null && Input.IsPressed(ConsoleKey.Escape))
    {
        Menu.Current = Main_menu;
        Menu.Current.SelectedIndex = 0;
    }
    if (Menu.Current != null) MenuUpdate();
    else SceneUpdate(delta);
    BarriersUpdate();
};


// -- Game render --
Game.OnRender += () =>
{
    if (HINTS_ON) DrawHints();
    if (Menu.Current != null) MenuDraw();
    if (Dialog.Current != null) DialogDraw();
    else SceneDraw();
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