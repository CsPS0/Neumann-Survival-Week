using GameLogicLib;
using GameObjectsLib;
using InputLib;
using RenderLib;

Textures TextureLoader = new();
(byte r, byte g, byte b) Gray_color = (100, 100, 100),
                         Blue_color = (102, 153, 225);
bool COLOR_ON = true;
bool HINTS_ON = false;
Menu? CurrentMenu = null;
string? CurrentScene = null;


// -- Player --
Thing player = new("Player", 5, 5);
player.animations.Add("idle", TextureLoader.Load(["player_idle"]));
player.animations.Add("walk", TextureLoader.Load(["player_walk1", "player_walk2"]));
player.animations.Add("wave", TextureLoader.Load([
    "player_wave1", "player_wave2", "player_wave3", "player_wave2"
    ]));
player.animations.Add("falling", TextureLoader.Load(["player_falling"]));
player.animation_name = "idle";
player.animation_fps = 10;
double player_speed = 0.05;
double old_x = player.double_x, old_y = player.double_y;
void PlayerUpdate(double delta)
{
    if (!player.Hide)
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

        player.Move(
            moveX * player_speed * delta,
            moveY * player_speed / 2 * delta
            );

        double r_player_x = Math.Round(player.double_x, 5);
        double r_player_y = Math.Round(player.double_y, 5);

        if (old_x != r_player_x || old_y != r_player_y)
        {
            player.animation_name = "walk";
            old_x = r_player_x;
            old_y = r_player_y;
        }
        else if (player.animation_name == "walk") player.animation_name = "idle";
        if (Input.IsPressed(ConsoleKey.E)) player.animation_name = "wave";
    }
}


// -- Game border barriers
Thing LeftBarrier = new("LeftBarrier", -1, -1, Hitbox: new());
Thing TopBarrier = new("TopBarrier", -1, -1, Hitbox: new());
Thing RightBarrier = new("RightBarrier", 0, 0, Hitbox: new());
Thing BottomBarrier = new("BottomBarrier", 0, 0, Hitbox: new());
player.CheckCollisions.AddRange([
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
player.OnCollision += (thing, resolve) =>
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
player.CheckCollisions.Add(SchoolDoor);
void SchoolUpdate()
{
    if (!School.Hide && CurrentScene == "Outside")
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
string[] Scenens = ["Outside"];


// -- Menus --
Menu Main_menu = new(MenuType.Main, [ "Start", "Settings", "Exit" ]);
Menu Start_menu = new(MenuType.Start, [ "Hétfő", "Kedd" ]);
Menu Settings_menu = new(MenuType.Settings, [ "Colors ON" ]);
void MenuUpdate()
{
    int i = CurrentMenu.SelectedIndex;
    string selected = CurrentMenu.Options[i];
    int l = CurrentMenu.Options.Count;

    // if the current menu is not settings
    if (CurrentMenu.Type == MenuType.Settings)
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
    if (Input.IsPressed(ConsoleKey.W)) CurrentMenu.SelectedIndex = (i - 1 + l) % l;
    if (Input.IsPressed(ConsoleKey.S)) CurrentMenu.SelectedIndex = (i + 1) % l;

    if (Input.IsPressed(ConsoleKey.Enter))
    {
        switch (CurrentMenu.Type)
        {
            case MenuType.Main:
                switch (selected)
                {
                    case "Start": CurrentMenu = Start_menu; break;
                    case "Settings":CurrentMenu = Settings_menu; break;
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
        if (CurrentMenu.Type == MenuType.Main) CurrentMenu = null;
        else CurrentMenu = Main_menu;
    }
}
void MenuDraw()
{
    Frame title = Draw.Text(CurrentMenu.Type.ToString(), COLOR_ON ? Blue_color : Gray_color);
    Render.PutFrame(Render.width / 2 - title.width / 2, (int)(Render.height * 0.1), title);

    string[] options = CurrentMenu.Options.ToArray();
    int longest = options.Max(item => item.Length) + 2;
    int index = CurrentMenu.SelectedIndex;
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
    if (CurrentMenu == null && Input.IsPressed(ConsoleKey.Escape))
    {
        CurrentMenu = Main_menu;
        CurrentMenu.SelectedIndex = 0;
    }
    if (CurrentMenu != null) MenuUpdate();
    else PlayerUpdate(delta);
};


// -- Game render --
Game.OnRender += () =>
{
    if (CurrentMenu != null) MenuDraw();
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
        player.PlayAnimation();
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