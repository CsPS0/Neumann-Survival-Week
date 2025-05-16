using RenderLib;
using InputLib;
using System.Diagnostics;
using GameLogicLib;

Frame hello_frame = Draw.TextToFrame("Hello World");
Game.OnRender += () =>
{
    int x = Render.width / 2 - hello_frame.width / 2;
    int y = Render.height / 2;

    Render.PutFrame(x, y, hello_frame);
};

Game.Fps = 60;
Game.Start(Console.WindowWidth, Console.WindowHeight);








return;

// Set up envirement
Render.Init(Console.WindowWidth, Console.WindowHeight);

char[,] human =
{
    { ' ', 'o', ' ' },
    { '/', '|', '\\' },
    { '/', ' ', '\\' },
};

Frame humanF = new Frame(3, 3);
humanF.RaplacePixels((int x, int y, Pixel? p) =>
{
    return human[y, x] != ' ' ? new(human[y, x], (255, 100, 200)) : null; 
}, true);

int x = 0, y = 0;

Frame hello = Draw.TextToFrame("Hello World!", (100, 150, 200));
hello.RaplacePixels((int x, int y, Pixel? p) => p?.character == ' ' ? null : p, true);
Frame rect = Draw.RectToFrame(hello.width + 2, 3, (100, 150, 200));

Stopwatch timer = Stopwatch.StartNew();
Stopwatch timer2 = Stopwatch.StartNew();
double delta = 0;
Frame fps = new(0, 0);
Frame rect2 = new(0, 0);

// Main Loop
while (!Input.IsPressed(ConsoleKey.Escape))
{
    Render.Resize(Console.WindowWidth, Console.WindowHeight);

    if (delta > 0 && timer2.ElapsedMilliseconds > 200)
    {
        fps = Draw.TextToFrame($"Fps: {(int)(1000 / delta)}", layer: 1);
        rect2 = Draw.RectToFrame(fps.width + 2, fps.height + 2, layer: 1);
        timer2.Restart();
    }
    Render.PutFrame(1, 1, rect2);
    Render.PutFrame(2, 2, fps);

    Render.PutFrame(Render.width / 2 - hello.width / 2, Render.height / 2, hello);
    Render.PutFrame(Render.width / 2 - hello.width / 2 - 1, Render.height / 2 - 1, 
        rect);

    Frame resolution = 
        Draw.TextToFrame($"Resoltuion: {Console.WindowWidth}x{Console.WindowHeight}");
    Frame rect3 = Draw.RectToFrame(resolution.width + 2, resolution.height + 2);

    Render.PutFrame(1, rect2.height + 1, rect3);
    Render.PutFrame(2, rect2.height + 2, resolution);

    Render.PutFrame(x, y, humanF);

    if (Input.IsDown(ConsoleKey.W)) y--;
    if (Input.IsDown(ConsoleKey.S)) y++;
    if (Input.IsDown(ConsoleKey.A)) x -= 2;
    if (Input.IsDown(ConsoleKey.D)) x += 2;

    Render.UpdateScreen();
    Thread.Sleep(16);

    delta = timer.ElapsedMilliseconds;
    timer.Restart();
}

Console.Clear();
Render.ResetStyle();