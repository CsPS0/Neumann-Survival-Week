namespace GameObjectsLib
{
    public static class Maps
    {
        public static string GetMapTileRender(char[][] map, int tileI, int tileJ)
        {
            if (tileJ < 0 || tileJ >= map.Length || tileI < 0 || tileI >= map[tileJ].Length)
            {
                if (map == frontNeu) return Sprites.Mountain;
                return Sprites.Open;
            }
            return map[tileJ][tileI] switch
            {
                'w' => Sprites.Water,
                'W' => Sprites.Wall_0000,
                'b' => Sprites.Barbie, // Barbie (moved above 'B')
                'B' => Sprites.Barrels1,
                't' => Sprites.Tree,
                ' ' or 'X' => Sprites.Open,
                'i' => Sprites.Inn,
                's' => Sprites.Store,
                'f' => Sprites.Fence,
                'c' => Sprites.Chest,
                'e' => Sprites.EmptyChest,
                '1' => tileJ < map.Length / 2 ? Sprites.ArrowUp : Sprites.ArrowDown,
                'm' => Sprites.Mountain,
                '0' => Sprites.Town,
                'g' => Sprites.Guard,
                '2' => Sprites.Castle,
                'p' => Sprites.Mountain2,
                'T' => Sprites.Tree2,
                'k' => Sprites.King,
                'h' => Sprites.Wall_0000,
                'd' => Sprites.Gate, // Door
                'y' => Sprites.Branyo, // Branyó
                'r' => Sprites.Rizzler, // Rizzler
                'l' => Sprites.Leibi, // Leibi
                _ => Sprites.Error,
            };
        }

        public static bool IsValidCharacterMapTile(char[][] map, int tileI, int tileJ)
        {
            if (tileJ < 0 || tileJ >= map.Length || tileI < 0 || tileI >= map[tileJ].Length)
            {
                return false;
            }
            return map[tileJ][tileI] switch
            {
                ' ' => true,
                'i' => true,
                's' => true,
                'c' => true,
                'e' => true,
                '1' => true,
                '0' => true,
                'g' => true,
                '2' => true,
                'X' => true,
                'k' => true,
                'h' => true,
                'd' => true, // Door is walkable
                _ => false,
            };
        }

        // Front
        public static readonly char[][] frontNeu =
        [
            "mmmmmmmmmmmm".ToCharArray(),
            "m t   1   tm".ToCharArray(),
            "m   WWWWW  m".ToCharArray(),
            "m  WW   WW m".ToCharArray(),
            "m WW  0  WWm".ToCharArray(),
            "mWW   d   Wm".ToCharArray(),
            "mW    d    m".ToCharArray(),
            "mt   WWW  tm".ToCharArray(),
            "m  WW   WW m".ToCharArray(),
            "m WW  g  WWm".ToCharArray(),
            "mt 1     1tm".ToCharArray(),
            "mmmmmmmmmmmm".ToCharArray(),
        ];

        // Classroom 5
        public static readonly char[][] classRoom5 =
        [
            "WWWWWWWWWWWW".ToCharArray(),
            "W    B    gW".ToCharArray(),
            "W  B B B   W".ToCharArray(),
            "d     y    W".ToCharArray(), // 'y' for Branyó
            "W  B B B   W".ToCharArray(),
            "W          W".ToCharArray(),
            "W  B B B   W".ToCharArray(),
            "W          W".ToCharArray(),
            "W  B B B  cW".ToCharArray(),
            "W         eW".ToCharArray(),
            "W    k     W".ToCharArray(),
            "WWWWWWWWWWWW".ToCharArray(),
        ];

        // Aula
        public static readonly char[][] Aula =
        [
            "WWWWWWWWWWWW".ToCharArray(),
            "W    r b l W".ToCharArray(), // 'r' = Rizzler, 'b' = Barbie, 'l' = Leibi
            "d B B B B  W".ToCharArray(),
            "W B B B B  W".ToCharArray(),
            "W B B B B  W".ToCharArray(),
            "W B B B B  W".ToCharArray(),
            "W B B B B  W".ToCharArray(),
            "W B B B B  W".ToCharArray(),
            "W          W".ToCharArray(),
            "W    k     W".ToCharArray(),
            "W  g  1  g W".ToCharArray(),
            "WWWWWWWWWWWW".ToCharArray(),
        ];
    };
}