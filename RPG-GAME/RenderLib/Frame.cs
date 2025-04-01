namespace RenderLib
{
    public class Frame
    {
        public Pixel?[,] Pixels;
        public Frame(int width, int height)
        {
            Pixels = new Pixel[width, height];
        }

        public int Width => Pixels.GetLength(0);
        public int Height => Pixels.GetLength(1);

        // check if a position is within the frame
        public bool InBound(int x, int y)
        {
            return x >= 0 && x < Width && y >= 0 && y < Height;
        }

        // put a pixel on the frame
        public void PutPixel(int x, int y, Pixel p, bool IgnoreLayer = false)
        {
            // if p is on a higher or equal layer replace
            // the current pixel
            if (IgnoreLayer || Pixels[x, y] == null 
                || Pixels[x, y].Layer <= p.Layer)
            {
                Pixels[x, y] = p;
            }
        }
    }
}
