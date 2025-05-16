using RenderLib;
using InputLib;
using System.Diagnostics;
using GameLogicLib;

Game.OnStart += () =>
{
    Console.WriteLine("Game has started...");
    Render.Init(Console.WindowWidth, Console.WindowHeight);
};
Game.OnStop += () => Console.WriteLine("Game has stopped...");
Game.OnRender += () => Console.WriteLine($"[Render] fps: {Game.Fps}");
Game.OnUpdate += (double delta) => Console.WriteLine($"[Update] delta: {delta}ms");

Game.Start();
Thread.Sleep(3000);
Game.Stop();





























return;

// Set up envirement
Render.Init(Console.WindowWidth, Console.WindowHeight);

char[] human =
{
    ' ', 'o', ' ',
    '/', '|', '\\',
    '/', ' ', '\\',
};

Frame humanF = new Frame(3, 3);
for (int i = 0; i < human.Length; i++)
{
    humanF.PutPixel(i % 3, i / 3, new(human[i], (255, 100, 200), null));
}
humanF.RaplacePixels((int x, int y, Pixel? p) => p?.character == ' ', null, true);
int x = 0, y = 0;

Frame hello = Draw.TextToFrame("Hello World!", (100, 150, 200));
hello.RaplacePixels((int x, int y, Pixel? p) => p?.character == ' ', null, true);
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