using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace GameObjectsLib
{
    public class Rect
    {
        public int? x, y, width, height;

        public Rect(int? x = null, int? y = null, int? width = null, 
            int? height = null)
        {
            this.x = x;
            this.y = y;
            this.width = width;
            this.height = height;
        }
    }
}
