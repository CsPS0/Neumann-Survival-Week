using RPG_GAME;
using RenderLib;
using InputLib;

int frameCount = 0;
DateTime startTime = DateTime.Now;
int FPS = 0;

Render.Init(Console.WindowWidth, Console.WindowHeight);

char[] human = {
    ' ', 'o', ' ',
    '/', '|', '\\',
    '/', ' ', '\\',
};

Frame Fhuman = new Frame(3, 3);

for (int _x = 0; _x < 3; _x++)
{
    for (int _y = 0; _y < 3; _y++)
    {
        char c = human[_y * 3 + _x];
        Fhuman.PutPixel(_x, _y, c == ' ' ? null : new(c, (100, 50, 255)));
    }
}

int x = 0, y = 0;

while (true)
{
    frameCount++;

    if ((DateTime.Now - startTime).TotalSeconds >= 1)
    {
        FPS = frameCount;

        frameCount = 0;
        startTime = DateTime.Now;
    }

    Frame text = Render.TextToFrame($"FPS: {FPS}");

    Render.PutFrame(0, 0, text);
    Render.PutFrame(x, y, Fhuman);

    Thread.Sleep(20);
    if (Input.IsDown(ConsoleKey.W)) y = Math.Max(0, y - 1);
    if (Input.IsDown(ConsoleKey.S)) y = Math.Min(Render.height - Fhuman.width, y + 1);
    if (Input.IsDown(ConsoleKey.A)) x = Math.Max(0, x - 2);
    if (Input.IsDown(ConsoleKey.D)) x = Math.Min(Render.width - Fhuman.width, x + 2);

    Render.UpdateScreen();
}













Console.WriteLine("Üdvözöllek a NJSZKI IKT RPG játékban!");

Character player = new Character("Játékos");
GameMap map = new GameMap(20, 10);

while (true)
{
    Console.Clear();
    map.DrawMap();
    Console.WriteLine($"\nNév: {player.Name} | Élet: {player.Health} | Erő: {player.Strength}");
    Console.WriteLine("Irányítás: W-fel, S-le, A-bal, D-jobb, Q-kilépés");

    var key = Console.ReadKey(true).Key;
    switch (key)
    {
        case ConsoleKey.W:
            // Mozgás felfelé
            break;
        case ConsoleKey.S:
            // Mozgás lefelé
            break;
        case ConsoleKey.A:
            // Mozgás balra
            break;
        case ConsoleKey.D:
            // Mozgás jobbra
            break;
        case ConsoleKey.Q:
            return;
    }
}