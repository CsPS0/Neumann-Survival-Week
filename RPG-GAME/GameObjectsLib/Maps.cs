namespace GameObjectsLib
{
    public static class Maps
    {
        public static string GetMapTileRender(char[][] map, int tileI, int tileJ)
        {
            //if (tileJ < 0 || tileJ >= map.Length || tileI < 0 || tileI >= map[tileJ].Length)
            //{
            //    if (map == frontNeu) return;
            //    return Sprites.Open;
            //}
            return map[tileJ][tileI] switch
            {
                'b' => Sprites.Barbie, // Barbie (moved above 'B')
                't' => Sprites.Tree,
                ' ' or 'X' => Sprites.Open,
                'f' => Sprites.Fence,
                'c' => Sprites.Chest,
                'e' => Sprites.EmptyChest,
                '1' => tileJ < map.Length / 2 ? Sprites.ArrowUp : Sprites.ArrowDown,
                'T' => Sprites.Tree2,
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

        public string[] frontNeu = {
            ""
        }

        //        // Front
        //        public static readonly char[][] frontNeu =
        //        [
        //            "                    ┌─────────────────────────────────────────────────────┐
        //                    │ ┌─────┐ ┌─────┐ ┌─────┬─────┬─────┐ ┌─────┐ ┌─────┐ │
        //                    │ │     │ │     │ │     │     │     │ │     │ │     │ │
        //                    │ └─────┘ └─────┘ └─────┴─────┴─────┘ └─────┘ └─────┘ │
        //┌───────────────────┤ ┌─────┐ ┌─────┐ ┌─────┬─────┬─────┐ ┌─────┐ ┌─────┐ ├───────────────────┐
        //│                   │ │     │ │     │ │     │     │     │ │     │ │     │ │                   │
        //│ ┌─────┐ ┌─────┐   │ └─────┘ └─────┘ └─────┴─────┴─────┘ └─────┘ └─────┘ │  ┌─────┐ ┌─────┐  │
        //│ │     │ │     │   │  ┌───────────────────────────────────────────────┐  │  │     │ │     │  │
        //│ │     │ │     │   │  │NEUMANN JÁNOS SZÁMITÁSTECHNIKAI SZAKKÖZÉPISKOLA│  │  │     │ │     │  │
        //│ │     │ │     │   │  └─────────────┬───╥───╥───╥───╥───┬─────────────┘  │  │     │ │     │  │
        //│ │     │ │     │   │┌─────┐ ┌─────┐ │   ║   ║   ║   ║   │ ┌─────┐ ┌─────┐│  │     │ │     │  │
        //│ │     │ │     │   ││     │ │     │ │ --║---║---║---║-- │ │     │ │     ││  │     │ │     │  │
        //│ └─────┘ └─────┘   │└─────┘ └─────┘ │   ║   ║   ║   ║   │ └─────┘ └─────┘│  └─────┘ └─────┘  │
        //│                   │              _/┴───╨───╨───╨───╨───┴\_              │                   │
        //│                   │            _/─────────────────────────\_            │                   │
        //│                   │           /─────────────────────────────\           │                   │".ToCharArray(),
        //        ];

        //        // Classroom 5
        //        public static readonly char[][] classRoom5 =
        //        [

        //        ];

        //        // Aula
        //        public static readonly char[][] Aula =
        //        [
        //            ""
        //        ];
    };
}