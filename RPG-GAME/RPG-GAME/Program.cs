using RenderLib;
using InputLib;
using System.Diagnostics;
using GameLogicLib;
using GameObjectsLib;

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
Game.OnUpdate += (delta) =>
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

    if (moveX != 0 || moveY != 0) player.animation_name = "walk";
    else if (player.animation_name == "walk") player.animation_name = "idle";
    if (Input.IsPressed(ConsoleKey.E)) player.animation_name = "wave";

    if (player.animation_name == "walk") player.animation_fps = 10;
    else if (player.animation_name == "wave") player.animation_fps = 10;

    player.x += moveX * player_speed * delta;
    player.y += moveY * player_speed / 2 * delta;
};
Game.OnRender += () =>
{
    player.PlayAnimation();
    if (player.Output != null)
        Render.PutFrame(player.int_x, player.int_y, player.Output);
};

// hello world box
string text = " Hello world!!! ";
Frame hello_frame = Draw.RectToFrame(text.Length + 2, 3, (100, 150, 200));
hello_frame.PutFrame(1, 1, Draw.TextToFrame(text, (100, 150, 200)));
Game.OnRender += () =>
    Render.PutFrame(Render.width / 2 - hello_frame.width / 2, Render.height / 2, hello_frame);

// fps counter
Stopwatch second_watcher = Stopwatch.StartNew();
Game.OnUpdate += (delta) =>
{
    if (second_watcher.ElapsedMilliseconds >= 1000)
    {
        string fps_string = $"Render: {(Game.Fps ?? 0)} Fps";
        string delta_string = $"Update: {delta}ms";
        StdOutLines[0] = fps_string;
        StdOutLines[1] = delta_string;
        second_watcher.Restart();
    }
};

// resolution counter
Game.OnResized += (w, h) =>
{
    string resolution_string = $"resolution: {w}x{h}";
    StdOutLines[2] = resolution_string;
};


// StdOut render
Game.OnRender += () =>
{
    int l = StdOutLines.Count(l => l != null);
    Frame text_frame = new(Render.width - 2, l);
    for (int i = 0; i < l; i++)
    {
        string line = StdOutLines[i];
        if (line != null) text_frame.PutFrame(0, i, Draw.TextToFrame(line));
    }
    Frame box_frame = Draw.RectToFrame(text_frame.width + 4, text_frame.height + 2, Filled: true);
    box_frame.PutFrame(2, 1, text_frame);

    Frame name_tag = Draw.TextToFrame("Std output");

    int x = Render.width / 2 - box_frame.width / 2;
    int y = Render.height - box_frame.height + 1;
    Render.PutFrame(x, y, box_frame, true);
    Render.PutFrame(Render.width / 2 - name_tag.width / 2, y, name_tag, true);
};


// Main
Game.Fps = 100;
Game.OnStart += () => Render.Fill(new(' '));
Game.OnResized += (w, h) => Render.Fill(new(' '));
Game.OnStop += () =>
{
    Console.Clear();
    Render.ResetStyle();
};
Game.OnUpdate += (delta) => { if (Input.IsPressed(ConsoleKey.Escape)) Game.Stop(); };
Game.Start(Console.WindowWidth, Console.WindowHeight);