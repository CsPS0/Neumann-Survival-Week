namespace RPG_GAME
{
    public static class Sprites
    {
        public static void DrawLogo()
        {
            Console.WriteLine(@"
 _   _     _  ____   ____  _  ______  _____   _____  _____   _____ 
| \ | |   | |/ ___| |_   _|| |/ /_   \|_   _| |  __ \|  __ \ / ____|
|  \| |   | |\___ \   | |  | ' /  | |) || |   | |__) | |__) | |  __ 
| . ` |_  | | ___) |  | |  | . \  |  _/ | |   |  _  /|  ___/| | |_ |
|_|\__(_) |_||____/   |_|  |_|\_\_| |_  |_|   |_| \_\|_|    |_____|
        ");
        }

        public static void DrawCharacter(int x, int y)
        {
            Console.SetCursorPosition(x, y);
            Console.Write("@");
        }

        public static void DrawEnemy(int x, int y)
        {
            Console.SetCursorPosition(x, y);
            Console.Write("E");
        }
    }
}
