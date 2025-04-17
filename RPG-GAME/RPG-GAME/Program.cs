using RenderLib;
using InputLib;
using AssetsLib;
using System.Security.Cryptography;


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

Frame hello = Draw.StringToFrame("Hello World!", (100, 150, 200));
hello.RaplacePixels((int x, int y, Pixel? p) => p?.character == ' ', null, true);

// Main Loop
while (!Input.IsPressed(ConsoleKey.Escape))
{
    Render.Resize(Console.WindowWidth, Console.WindowHeight);

    Render.PutFrame(Render.width / 2 - hello.width / 2, Render.height / 2, hello);
    Render.PutFrame(Render.width / 2 - hello.width / 2 - 1, Render.height / 2 - 1, 
        Draw.RectToFrame(hello.width + 2, 3, (100, 150, 200)));

    Render.PutFrame(x, y, humanF);

    if (Input.IsDown(ConsoleKey.W)) y--;
    if (Input.IsDown(ConsoleKey.S)) y++;
    if (Input.IsDown(ConsoleKey.A)) x -= 2;
    if (Input.IsDown(ConsoleKey.D)) x += 2;

    Render.UpdateScreen();
    Thread.Sleep(20);
}