namespace GameObjectsLib
{
    public class Rect
    {
        public int x, y;
        public int? width, height;

        public Rect(int x = 0, int y = 0, int? width = null, int? height = null)
        {
            this.x = x;
            this.y = y;
            this.width = width;
            this.height = height;
        }
    }
}
