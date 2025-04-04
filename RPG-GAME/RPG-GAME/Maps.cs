namespace RPG_GAME
{
    public class GameMap
    {
        private char[,] map;
        public int Width { get; private set; }
        public int Height { get; private set; }

        public GameMap(int width, int height)
        {
            Width = width;
            Height = height;
            map = new char[height, width];
            GenerateMap();
        }

        private void GenerateMap()
        {
            for (int y = 0; y < Height; y++)
            {
                for (int x = 0; x < Width; x++)
                {
                    if (x == 0 || x == Width - 1 || y == 0 || y == Height - 1)
                        map[y, x] = '#';
                    else
                        map[y, x] = '.';
                }
            }
        }

        public void DrawMap()
        {
            for (int y = 0; y < Height; y++)
            {
                for (int x = 0; x < Width; x++)
                {
                    Console.Write(map[y, x]);
                }
                Console.WriteLine();
            }
        }

        public bool IsWalkable(int x, int y)
        {
            return map[y, x] == '.';
        }
    }
}
