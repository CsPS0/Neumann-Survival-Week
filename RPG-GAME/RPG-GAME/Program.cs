using RenderLib;
using InputLib;

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
    char c = human[i];
    humanF.PutPixel(i % 3, i / 3, c == ' ' ? null : new(human[i], (255, 100, 200)));
}
int x = 0, y = 0;

// Main Loop
while (!Input.IsPressed(ConsoleKey.Escape))
{
    int C_W = Console.WindowWidth, C_H = Console.WindowHeight;
    if (C_W != Render.width || C_H != Render.height)
    { Render.Init(C_W, C_H); }

    Frame hello = Render.TextToFrame("Hello World!", (100, 150, 200));
    Render.PutFrame(Render.width / 2 - hello.width / 2, Render.height / 2, hello);

    Render.PutFrame(x, y, humanF);

    if (Input.IsDown(ConsoleKey.W)) y--;
    if (Input.IsDown(ConsoleKey.S)) y++;
    if (Input.IsDown(ConsoleKey.A)) x -= 2;
    if (Input.IsDown(ConsoleKey.D)) x += 2;

    Render.UpdateScreen();
    Thread.Sleep(20);
}