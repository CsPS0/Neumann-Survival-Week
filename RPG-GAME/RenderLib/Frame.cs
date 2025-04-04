using System.Threading.Tasks.Dataflow;

namespace RenderLib
{
    public class Frame
    {
        public Pixel?[,] pixels;
        public int width => pixels!.GetLength(1);
        public int height => pixels!.GetLength(0);

        public Frame(int width, int height)
        {
            pixels = new Pixel[height, width];
        }

        public bool InFrameBounds(int x, int y) => 
            x >= 0 && x < width && y >= 0 && y < height;

        public bool PutPixel(int x, int y, Pixel? pixel, bool IgnoreLayer = false)
        {
            if (InFrameBounds(x, y) && !Pixel.Equals(pixel, pixels[y, x]) &&
                (IgnoreLayer || pixels[y, x] == null ||
                pixel?.layer >= pixels[y, x]?.layer))
            {
                pixels![y, x] = pixel!;
                return true;
            }

            return false;
        }

        public bool PutFrame(int x, int y, Frame frame)
        {
            if (InFrameBounds(x, y) ||
                InFrameBounds(x + frame.width, y + frame.height))
            {
                for (int _x = 0; _x < frame.width; _x++)
                {
                    for (int _y = 0; _y < frame.height; _y++)
                    {
                        PutPixel(x + _x, y + _y, frame.pixels![_y, _x], true);
                    }
                }
                return true;
            }

            return false;
        }

        public void Fill(Pixel pixel)
        {
            for (int x = 0; x < width; x++)
            {
                for (int y = 0; y < height; y++)
                {
                    PutPixel(x, y, pixel, true);
                }
            }
        }
    }
}