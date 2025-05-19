using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

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
                'b' => Sprites.Building,
                't' => Sprites.Tree,
                ' ' or 'X' => Sprites.Open,
                'i' => Sprites.Inn,
                's' => Sprites.Store,
                'f' => Sprites.Fence,
                'c' => Sprites.Chest,
                'e' => Sprites.EmptyChest,
                'B' => Sprites.Barrels1,
                '1' => tileJ < map.Length / 2 ? Sprites.ArrowUp : Sprites.ArrowDown,
                'm' => Sprites.Mountain,
                '0' => Sprites.Town,
                'g' => Sprites.Guard,
                '2' => Sprites.Castle,
                'p' => Sprites.Mountain2,
                'T' => Sprites.Tree2,
                'k' => Sprites.King,
                'h' => Sprites.Wall_0000,
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
                _ => false,
            };
        }

        public static readonly char[][] frontNeu =
        [
        
        ];

        public static readonly char[][] classRoom5 =
        [

        ];

        public static readonly char[][] Aula =
        [

        ];
    }
}
