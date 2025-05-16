using RenderLib;

namespace GameObjectsLib
{
    public class Object
    {
        public double x;
        public double y;

        public int int_x
        {
            get => (int)Math.Round(x);
            set => x = value;
        }
        public int int_y
        {
            get => (int)(Math.Round(y));
            set => y = value;
        }

        public Frame[] textures;

        public Object(double x, double y)
        {
            this.x = x;
            this.y = y;
        }
    }
}
