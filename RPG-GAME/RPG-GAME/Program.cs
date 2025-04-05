using RPG_GAME;
using RenderLib;
using InputLib;
using System.Text;

Render.Init(Console.WindowWidth, Console.WindowHeight);

Render.Fill(new(' '));
Render.UpdateScreen();

int frameCount = 0;
DateTime startTime = DateTime.Now;
int FPS = 0;

char[] human = {
    ' ', 'o', ' ',
    '/', '|', '\\',
    '/', ' ', '\\',
};

Frame Fhuman = new Frame(3, 3);

for (int x = 0; x < 3; x++)
{
    for (int y = 0; y < 3; y++)
    {
        Fhuman.PutPixel(x, y, new(human[y * 3 + x]));
    }
}


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

    Render.PutFrame(5, 5, Fhuman);

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