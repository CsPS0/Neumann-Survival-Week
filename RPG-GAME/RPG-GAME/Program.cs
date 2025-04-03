using RPG_GAME;
using RenderLib;

class Program
{
    static void Main(string[] args)
    {

        Render.Init(10, 10);

        Render.Fill(new(' ', null, (144, 144, 144)));

        Render.UpdateScreen();
















        Render.ResetStyles();
        Console.Write("\nEnd...");
        Console.ReadLine();
        return;


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
    }
}