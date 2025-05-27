using GameLogicLib;
using GameObjectsLib;
using InputLib;
using RenderLib;
using System.Diagnostics;

Textures t = new();

// Std out (max lines: 10)
string[] StdOutLines = new string[10];
Thing StdOut = new(0, 0);

// player
Thing player = new(0, 0);
player.animations.Add("idle", t.Load(["player_idle"]));
player.animations.Add("walk", t.Load(["player_walk1", "player_walk2"]));
player.animations.Add("wave", t.Load(["player_wave1", "player_wave2", "player_wave3", "player_wave2"]));
player.animation_name = "idle";
double player_speed = 0.05;

// --- Menu State ---
Menus.Menu? currentMenu = Menus.GetMainMenu();
bool inMenu = true;
bool colorsOn = true;

// --- Map State ---
char[][] currentMap = Maps.Aula;
string currentMapName = "Aula";
int mapWidth = currentMap[0].Length;
int mapHeight = currentMap.Length;

// --- Player State ---
player.x = 5;
player.y = 5;

// --- Conversation State ---
Discussion? currentDiscussion = null;
bool inConversation = false;

// --- Helper: Get NPC Discussion by map tile ---
Discussion? GetNpcDiscussion(char npc, string day)
{
    return npc switch
    {
        'y' => day == "Kedd" ? Conversations.BranyoTuesday : Conversations.BranyoMonday,
        'r' => day == "Kedd" ? Conversations.RizzlerTuesday : Conversations.RizzlerMonday,
        'b' => day == "Kedd" ? Conversations.BarbieTuesday : Conversations.BarbieMonday,
        'l' => day == "Kedd" ? Conversations.LeibiTuesday : Conversations.LeibiMonday,
        _ => null
    };
}

// --- Menu Navigation ---
void HandleMenuInput()
{
    // WS for up/down
    if (Input.IsPressed(ConsoleKey.W))
        currentMenu.SelectedIndex = (currentMenu.SelectedIndex - 1 + currentMenu.Options.Count) % currentMenu.Options.Count;
    if (Input.IsPressed(ConsoleKey.S))
        currentMenu.SelectedIndex = (currentMenu.SelectedIndex + 1) % currentMenu.Options.Count;
    // AD for toggle (Settings ON/OFF)
    if (currentMenu.Type == Menus.MenuType.Settings && (Input.IsPressed(ConsoleKey.A) || Input.IsPressed(ConsoleKey.D)))
    {
        colorsOn = !colorsOn;
        currentMenu = Menus.GetSettingsMenu(colorsOn);
    }
    if (Input.IsPressed(ConsoleKey.Enter))
    {
        if (currentMenu.Type == Menus.MenuType.Main)
        {
            if (currentMenu.SelectedIndex == 0) // Start
            {
                currentMenu = Menus.GetStartMenu(colorsOn);
            }
            else if (currentMenu.SelectedIndex == 1) // Settings
            {
                currentMenu = Menus.GetSettingsMenu(colorsOn);
            }
            else if (currentMenu.SelectedIndex == 2) // Exit
            {
                Game.Stop();
            }
        }
        else if (currentMenu.Type == Menus.MenuType.Start)
        {
            // Pick day and go to map
            string day = currentMenu.Options[currentMenu.SelectedIndex];
            if (day == "Hétfő")
            {
                currentMap = Maps.Aula;
                currentMapName = "Aula";
                player.x = 5; player.y = 5;
            }
            else if (day == "Kedd")
            {
                currentMap = Maps.classRoom5;
                currentMapName = "classRoom5";
                player.x = 5; player.y = 5;
            }
            inMenu = false;
            // Update map dimensions
            mapWidth = currentMap[0].Length;
            mapHeight = currentMap.Length;
        }
        else if (currentMenu.Type == Menus.MenuType.Settings)
        {
            // Enter does nothing in settings
        }
    }
    if (Input.IsPressed(ConsoleKey.Escape))
    {
        if (currentMenu.Type == Menus.MenuType.Main)
            Game.Stop();
        else
            currentMenu = Menus.GetMainMenu(colorsOn);
    }
}

// --- Map Roaming ---
void HandleMapInput()
{
    // Interact with NPC
    char tile = currentMap[ny][nx];
    if ((tile == 'y' || tile == 'r' || tile == 'b' || tile == 'l') && Input.IsPressed(ConsoleKey.E))
    {
        string day = currentMapName == "classRoom5" ? "Kedd" : "Hétfő";
        currentDiscussion = GetNpcDiscussion(tile, day);
        if (currentDiscussion != null)
        {
            inConversation = true;
        }
    }
    if (Input.IsPressed(ConsoleKey.Escape))
    {
        inMenu = true;
        currentMenu = Menus.GetMainMenu(colorsOn);
    }
}

// --- Conversation Input ---
void HandleConversationInput()
{
    var choices = currentDiscussion?.GetChoices();
    if (choices == null || choices.Count == 0)
    {
        if (Input.IsPressed(ConsoleKey.Escape) || Input.IsPressed(ConsoleKey.Enter))
        {
            inConversation = false;
            currentDiscussion = null;
        }
        return;
    }
    char[] keys = choices.Keys.ToArray();
    foreach (char k in keys)
    {
        if (Input.IsPressed((ConsoleKey)char.ToUpper(k)))
        {
            currentDiscussion?.SelectChoice(k);
            // For demo: just close after selection
            inConversation = false;
            currentDiscussion = null;
        }
    }
    if (Input.IsPressed(ConsoleKey.Escape))
    {
        inConversation = false;
        currentDiscussion = null;
    }
}

// fps counter
Stopwatch second_watcher = Stopwatch.StartNew();

// --- Main Update Loop ---
Game.OnUpdate += (delta) =>
{
    // Handle input based on current state
    if (inMenu)
    {
        HandleMenuInput();
    }
    else if (inConversation && currentDiscussion != null)
    {
        HandleConversationInput();
    }
    else
    {
        HandleMapInput();
        
        // Handle smooth movement and animations when not in menu/conversation
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

        if (moveX != 0 || moveY != 0) 
            player.animation_name = "walk";
        else if (player.animation_name == "walk") 
            player.animation_name = "idle";
        
        if (Input.IsPressed(ConsoleKey.E)) 
            player.animation_name = "wave";

        if (player.animation_name == "walk") 
            player.animation_fps = 10;
        else if (player.animation_name == "wave") 
            player.animation_fps = 10;

        player.x += moveX * player_speed * delta;
        player.y += moveY * player_speed / 2 * delta;
    }
    
    // Global escape handling
    if (Input.IsPressed(ConsoleKey.Escape) && !inMenu && !inConversation) 
        Game.Stop();
    
    // FPS counter update
    if (second_watcher.ElapsedMilliseconds >= 1000)
    {
        string fps_string = $"Render: {(Game.Fps ?? 0)} Fps";
        string delta_string = $"Update: {delta}ms";
        StdOutLines[0] = fps_string;
        StdOutLines[1] = delta_string;
        second_watcher.Restart();
    }
};

// --- Main Render Loop ---
Game.OnRender += () =>
{
    Render.Fill(new(' '));
    
    if (inMenu)
    {
        // Draw menu
        var menu = currentMenu;
        int w = 20, h = menu.Options.Count + 4;
        Frame menuFrame = Draw.RectToFrame(w, h, colorsOn ? ((byte)100, (byte)200, (byte)255) : ((byte)100, (byte)100, (byte)100));
        for (int i = 0; i < menu.Options.Count; i++)
        {
            string opt = menu.Options[i];
            Frame optFrame = Draw.TextToFrame((menu.SelectedIndex == i ? "> " : "  ") + opt, colorsOn && menu.SelectedIndex == i ? ((byte)255, (byte)255, (byte)0) : ((byte)255, (byte)255, (byte)255));
            menuFrame.PutFrame(2, 2 + i, optFrame);
        }
        Render.PutFrame(Render.width / 2 - w / 2, Render.height / 2 - h / 2, menuFrame);
    }
    else if (inConversation && currentDiscussion != null)
    {
        // Draw NPC face and dialogue
        int w = 60, h = 20;
        Frame box = Draw.RectToFrame(w, h, ((byte)200, (byte)200, (byte)200));
        Frame face = Draw.TextToFrame(currentDiscussion.AsciiFace, ((byte)100, (byte)100, (byte)255));
        box.PutFrame(2, 2, face);
        Frame name = Draw.TextToFrame(currentDiscussion.NpcName, ((byte)255, (byte)255, (byte)0));
        box.PutFrame(2, 1, name);
        Frame dialogue = Draw.TextToFrame(currentDiscussion.Dialogue, ((byte)0, (byte)0, (byte)0));
        box.PutFrame(20, 2, dialogue);
        int y = 8;
        foreach (var kv in currentDiscussion.GetChoices())
        {
            Frame choice = Draw.TextToFrame($"{kv.Key}. {kv.Value}", ((byte)0, (byte)0, (byte)0));
            box.PutFrame(20, y++, choice);
        }
        Render.PutFrame(Render.width / 2 - w / 2, Render.height / 2 - h / 2, box);
    }
    else
    {
        // Draw map and player
        for (int j = 0; j < mapHeight; j++)
        {
            for (int i = 0; i < mapWidth; i++)
            {
                string tileSprite = Maps.GetMapTileRender(currentMap, i, j);
                Frame tileFrame = Draw.TextToFrame(tileSprite, ((byte)150, (byte)150, (byte)150));
                Render.PutFrame(i * 8, j * 4, tileFrame);
            }
        }
        player.PlayAnimation();
        if (player.Output != null)
            Render.PutFrame(player.int_x * 8, player.int_y * 4, player.Output);
    }
    
    //// Only show additional UI elements when not in menu
    //if (!inMenu)
    //{
    //    // hello world box
    //    string text = " Hello world!!! ";
    //    Frame hello_frame = Draw.RectToFrame(text.Length + 2, 3, ((byte)100, (byte)150, (byte)200));
    //    hello_frame.PutFrame(1, 1, Draw.TextToFrame(text, ((byte)100, (byte)150, (byte)200)));
    //    Render.PutFrame(Render.width / 2 - hello_frame.width / 2, Render.height / 2, hello_frame);
        
    //    // StdOut render
    //    int l = StdOutLines.Count(l => l != null);
    //    if (l > 0)
    //    {
    //        Frame text_frame = new(Render.width - 2, l);
    //        for (int i = 0; i < l; i++)
    //        {
    //            string line = StdOutLines[i];
    //            if (line != null) text_frame.PutFrame(0, i, Draw.TextToFrame(line));
    //        }
    //        Frame box_frame = Draw.RectToFrame(text_frame.width + 4, text_frame.height + 2, Filled: true);
    //        box_frame.PutFrame(2, 1, text_frame);

    //        Frame name_tag = Draw.TextToFrame("Std output");

    //        int x = Render.width / 2 - box_frame.width / 2;
    //        int y = Render.height - box_frame.height + 1;
    //        Render.PutFrame(x, y, box_frame, true);
    //        Render.PutFrame(Render.width / 2 - name_tag.width / 2, y, name_tag, true);
    //    }
    //}
};

// resolution counter
Game.OnResized += (w, h) =>
{
    string resolution_string = $"resolution: {w}x{h}";
    StdOutLines[2] = resolution_string;
};

// Main initialization and startup
Game.Fps = 100;
Game.OnStart += () => 
{
    Render.Init(Console.WindowWidth, Console.WindowHeight);
    Render.Fill(new(' '));
};
Game.OnResized += (w, h) => Render.Fill(new(' '));
Game.OnStop += () =>
{
    Console.Clear();
    Render.ResetStyle();
};

Game.Start(Console.WindowWidth, Console.WindowHeight);