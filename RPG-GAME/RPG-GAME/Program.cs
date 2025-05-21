using RenderLib;
using InputLib;
using System.Diagnostics;
using GameLogicLib;
using GameObjectsLib;

Textures t = new();

Thing player = new(0, 0);
player.animations.Add("idle", t.Load([ "player_idle" ]));
player.animations.Add("walk", t.Load([ "player_walk1", "player_walk2" ]));
player.animations.Add("wave", t.Load([ "player_wave1", "player_wave2", "player_wave3", "player_wave2" ]));
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

    if (player.animation_name == "walk") player.animation_fps = 7;
    else if (player.animation_name == "wave") player.animation_fps = 10;

        player.x += moveX * player_speed * delta;
    player.y += moveY * player_speed / 2 * delta;
};
Game.OnRender += () => player.PlayAnimation();

// hello world box
string text = " Hello world!!! ";
Frame hello_frame = Draw.RectToFrame(text.Length + 2, 3, (100, 150, 200));
hello_frame.PutFrame(1, 1, Draw.TextToFrame(text, (100, 150, 200)));
Game.OnRender += () => 
    Render.PutFrame(Render.width / 2 - hello_frame.width / 2, Render.height / 2, hello_frame);

// fps counter
Frame fps_frame = new(0, 0);
Stopwatch second_watcher = Stopwatch.StartNew();
Game.OnUpdate += (delta) =>
{
    if (second_watcher.ElapsedMilliseconds >= 1000)
    {
        string fps_string = $" Retler: {(Game.Fps ?? 0)} Fps ";
        string delta_string = $" Update: {delta}mf ";
        int max_length = Math.Max(fps_string.Length, delta_string.Length);
        fps_frame = Draw.RectToFrame(max_length + 2, 4);
        fps_frame.PutFrame(1, 1, Draw.TextToFrame(fps_string));
        fps_frame.PutFrame(1, 2, Draw.TextToFrame(delta_string));
        second_watcher.Restart();
    }
};
Game.OnRender += () => Render.PutFrame(0, 0, fps_frame);

// resolution counter
Frame resolution_frame = new(0, 0);
Game.OnResized += (w, h) =>
{
    string resolution_string = $" {w}x{h} ";
    resolution_frame = Draw.RectToFrame(resolution_string.Length + 2, 3);
    resolution_frame.PutFrame(1, 1, Draw.TextToFrame(resolution_string));
};
Game.OnRender += () => Render.PutFrame(0, fps_frame.height, resolution_frame);



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