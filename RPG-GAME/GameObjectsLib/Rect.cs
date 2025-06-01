using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace GameObjectsLib
{
    public class Rect
    {
        public int x, y, width, height;

        public Rect(int x = 0, int y = 0, int width = 0, int height = 0)
        {
            this.x = x;
            this.y = y;
            this.width = width;
            this.height = height;
        }
    }
}
