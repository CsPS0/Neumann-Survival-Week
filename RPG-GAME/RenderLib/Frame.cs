namespace RenderLib
{
    public class Frame
    {
        public Pixel[,]? pixels;
        public int width => pixels.GetLength(1);
        public int height => pixels.GetLength(0);

        public Frame(int width, int height)
        {
            pixels = new Pixel[height, width];
        }

        public bool InFrameBounds(int x, int y) => 
            x >= 0 && x < width && y >= 0 && y < height;
    }
}