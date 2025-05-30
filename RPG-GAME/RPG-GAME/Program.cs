using GameLogicLib;
using GameObjectsLib;
using InputLib;
using RenderLib;

Textures TextureLoader = new();
(byte r, byte g, byte b) Gray_color = (100, 100, 100),
                         Blue_color = (102, 153, 225);
bool COLOR_ON = true;
bool HINTS_ON = false;
Scene? CurrentScene = null;


// -- Player --
Thing Player = new("Player", 5, 5);
Player.animations.Add("idle", TextureLoader.Load(["player_idle"]));
Player.animations.Add("walk", TextureLoader.Load(["player_walk1", "player_walk2"]));
Player.animations.Add("wave", TextureLoader.Load([
    "player_wave1", "player_wave2", "player_wave3", "player_wave2"
    ]));
Player.animations.Add("falling", TextureLoader.Load(["player_falling"]));
Player.animation_name = "idle";
Player.animation_fps = 10;
double player_speed = 0.05;
double old_x = Player.double_x, old_y = Player.double_y;
void PlayerUpdate(double delta)
{
    if (!Player.Hide)
    {
        double moveX = 0, moveY = 0;
        if (Input.IsDown(ConsoleKey.W)) moveY -= 1;
        if (Input.IsDown(ConsoleKey.S)) moveY += 1;
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

        double r_player_x = Math.Round(Player.double_x, 5);
        double r_player_y = Math.Round(Player.double_y, 5);

        if (old_x != r_player_x || old_y != r_player_y)
        {
            Player.animation_name = "walk";
            old_x = r_player_x;
            old_y = r_player_y;
        }
        else if (Player.animation_name == "walk") Player.animation_name = "idle";
        if (Input.IsPressed(ConsoleKey.E)) Player.animation_name = "wave";
    }
}


// -- Game border barriers
Thing LeftBarrier = new("LeftBarrier", -1, -1, Hitbox: new());
Thing TopBarrier = new("TopBarrier", -1, -1, Hitbox: new());
Thing RightBarrier = new("RightBarrier", 0, 0, Hitbox: new());
Thing BottomBarrier = new("BottomBarrier", 0, 0, Hitbox: new());
Player.CheckCollisions.AddRange([
    LeftBarrier, TopBarrier, RightBarrier, BottomBarrier
]);
Game.OnResized += (w, h) =>
{
    Frame horizontal = new(w, 1);
    horizontal.Fill(new('#'));

    Frame vertical = new(1, h);
    vertical.Fill(new('#'));

    RightBarrier.x = w;
    BottomBarrier.y = h;

    LeftBarrier.Output = vertical;
    TopBarrier.Output = horizontal;
    RightBarrier.Output = vertical;
    BottomBarrier.Output = horizontal;
};
Player.OnCollision += (thing, resolve) =>
{
    if (new Thing[] { LeftBarrier, TopBarrier, RightBarrier, BottomBarrier }.Contains(thing))
        resolve();
};


// -- School --
Thing School = new("School", 0, 0);
School.Hide = true;
School.Output = TextureLoader.Load("school_front");
Thing SchoolDoor = new("Doors", 0, 0);
SchoolDoor.Output = new Frame(21, 1);
SchoolDoor.Hide = true;
SchoolDoor.Output.Fill(new('#', (255, 0, 0)));
Player.CheckCollisions.Add(SchoolDoor);
void SchoolUpdate()
{
    if (!School.Hide && Scene.Current.Type == SceneType.Outside)
    {
        School.double_x = Render.width / 2 - School.width / 2;
        School.double_y = Render.height - School.height;
        SchoolDoor.x = School.x + 37;
        SchoolDoor.y = School.y + School.height - 3;
    }
}


// -- Corridor --
Thing Corridor = new("Corridor", 0, 0);


// -- Leibi --
Thing Leibi = new("Leibi", 0, 0);
Leibi.Output = TextureLoader.Load("leibi_face");
Leibi.Hide = true;


// -- Scenes --
Scene Outside_scene = new(SceneType.Outside, [ Player, School, SchoolDoor ]);
Scene Aula_scene = new(SceneType.Aula, [ Player ]);

// -- Menus --
Menu Main_menu = new(MenuType.Main, [ "Start", "Settings", "Exit" ]);
Menu Start_menu = new(MenuType.Start, [ "Hétfő", "Kedd" ]);
Menu Settings_menu = new(MenuType.Settings, [ "Colors ON" ]);
void MenuUpdate()
{
    int i = Menu.Current.SelectedIndex;
    string selected = Menu.Current.Options[i];
    int l = Menu.Current.Options.Count;

    // if the current menu is not settings
    if (Menu.Current.Type == MenuType.Settings)
    {
        // AD for toggle (Settings ON/OFF)
        if (Input.IsPressed(ConsoleKey.A) || Input.IsPressed(ConsoleKey.D))
        {
            switch (i)
            {
                case 0:
                    COLOR_ON = !COLOR_ON;
                    Settings_menu.Options[i] = $"Colors {(COLOR_ON ? "ON" : "OFF")}";
                    break;
            }
        }
    }

    // WS for up/down
    if (Input.IsPressed(ConsoleKey.W)) Menu.Current.SelectedIndex = (i - 1 + l) % l;
    if (Input.IsPressed(ConsoleKey.S)) Menu.Current.SelectedIndex = (i + 1) % l;

    if (Input.IsPressed(ConsoleKey.Enter))
    {
        switch (Menu.Current.Type)
        {
            case MenuType.Main:
                switch (selected)
                {
                    case "Start": Menu.Current = Start_menu; break;
                    case "Settings":Menu.Current = Settings_menu; break;
                    case "Exit": Game.Stop(); break;
                }
                break;

            case MenuType.Start:
                switch (selected)
                {
                    //case "Hétfő":
                    //    currentMap = Maps.Aula;
                    //    currentMapName = "Aula";
                    //    player.x = 5; player.y = 5;
                    //    break;
                    //case "Kedd":
                    //    currentMap = Maps.classRoom5;
                    //    currentMapName = "classRoom5";
                    //    player.x = 5; player.y = 5;
                    //    break;
                }
                break;
        }
    }

    if (Input.IsPressed(ConsoleKey.Escape))
    {
        if (Menu.Current.Type == MenuType.Main) Menu.Current = null!;
        else Menu.Current = Main_menu;
    }
}
void MenuDraw()
{
    Frame title = Draw.Text(Menu.Current.Type.ToString(), COLOR_ON ? Blue_color : Gray_color);
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
    Frame MenuFrame = Draw.Box(w, h, COLOR_ON ? Blue_color : Gray_color, Filled: true);
    for (int i = 0, l = options.Length; i < l; i++)
    {
        string opt = options[i];
        (byte r, byte g, byte b) color = COLOR_ON && index == i ? Blue_color : Gray_color;
        Frame OptFrame = Draw.Text((index == i ? "> " : "  ") + opt, color);
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
    else PlayerUpdate(delta);
};


// -- Game render --
Game.OnRender += () =>
{
    if (Menu.Current != null) MenuDraw();
    else if (false)
    {
        //// Draw NPC face and dialogue
        //int w = 60, h = 20;
        //Frame box = Draw.RectToFrame(w, h, ((byte)200, (byte)200, (byte)200));
        //Frame face = Draw.TextToFrame(currentDiscussion.AsciiFace, ((byte)100, (byte)100, (byte)255));
        //box.PutFrame(2, 2, face);
        //Frame name = Draw.TextToFrame(currentDiscussion.NpcName, ((byte)255, (byte)255, (byte)0));
        //box.PutFrame(2, 1, name);
        //Frame dialogue = Draw.TextToFrame(currentDiscussion.Dialogue, ((byte)0, (byte)0, (byte)0));
        //box.PutFrame(20, 2, dialogue);
        //int y = 8;
        //foreach (var kv in currentDiscussion.GetChoices())
        //{
        //    Frame choice = Draw.TextToFrame($"{kv.Key}. {kv.Value}", ((byte)0, (byte)0, (byte)0));
        //    box.PutFrame(20, y++, choice);
        //}
        //Render.PutFrame(Render.width / 2 - w / 2, Render.height / 2 - h / 2, box);
    }
    else
    {
        Player.PlayAnimation();
        SchoolUpdate();
    }
};


// Main initialization and startup
Game.Fps = 100;
Game.OnResized += (w, h) => Render.Fill(new(' '));
Game.OnStop += () =>
{
    Render.ResetStyle();
    Console.Clear();
};

Game.Start(Console.WindowWidth, Console.WindowHeight);