using RenderLib;
using InputLib;
using System.Diagnostics;
using GameLogicLib;
using GameObjectsLib;

// Player
char[,] player_chars =
{
    { ' ', 'o', ' ' },
    { '/', '|', '\\' },
    { '/', ' ', '\\' },
};
Frame player_frame = new Frame(3, 3);
player_frame.RaplacePixels((int x, int y, Pixel? p) =>
{
    return player_chars[y, x] != ' ' ? new(player_chars[y, x], (255, 100, 200), layer: 1) : null;
}, true);

double x = 0, y = 0;
double speed = 0.075;
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
    x += moveX * speed * delta;
    y += moveY * speed / 2 * delta;
};
Game.OnRender += () => Render.PutFrame((int)Math.Round(x), (int)Math.Round(y), player_frame);

// hello world box
string text = "Hello world!!!";
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
        string fps_string = $"Redner: {(Game.Fps ?? 0)} Fps";
        string delta_string = $"Update: {delta}ms";
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
    string resolution_string = $"{w}x{h}";
    resolution_frame = Draw.RectToFrame(resolution_string.Length + 2, 3);
    resolution_frame.PutFrame(1, 1, Draw.TextToFrame(resolution_string));
};
Game.OnRender += () => Render.PutFrame(0, fps_frame.height, resolution_frame);


// test------------------------


// THIS SETUP IS SOOO LONG
string[] walk1 =
{
    " O ",
    "/|\\",
    "/ \\"
};
Frame walk1_frame = new(3, 3);
walk1_frame.RaplacePixels((int x, int y, Pixel? p) =>
{
    char current = walk1[y][x];
    return current != ' ' ? new(current, (255, 100, 200)) : null;
}, true);

string[] walk2 =
{
    " O ",
    " | ",
    " | "
};
Frame walk2_frame = new(3, 3);
walk2_frame.RaplacePixels((int x, int y, Pixel? p) =>
{
    char current = walk2[y][x];
    return current != ' ' ? new(current, (255, 100, 200)) : null;
}, true);
// THIS SETUP IS SOOO LONG

// this is soo good and easy though
GameObjectsLib.Object test = new(20, 20);
test.animation_fps = 5;
test.animations.Add("walk", [ walk1_frame, walk2_frame ]);
Game.OnRender += () => test.PlayAnimation();
// this is soo good and easy though


// test------------------------



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