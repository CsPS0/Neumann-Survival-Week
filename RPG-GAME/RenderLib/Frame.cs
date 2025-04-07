namespace RenderLib
{
    public class Frame
    {
        public Pixel?[,] pixels;
        public int width => pixels.GetLength(1);
        public int height => pixels.GetLength(0);

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
                pixels[y, x] = pixel;
                return true;
            }

            return false;
        }

        public bool PutFrame(int x, int y, Frame frame, bool IgnoreLayer = false)
        {
            if (InFrameBounds(x, y) ||
                InFrameBounds(x + frame.width, y + frame.height))
            {
                for (int _x = 0; _x < frame.width; _x++)
                {
                    for (int _y = 0; _y < frame.height; _y++)
                    {
                        PutPixel(x + _x, y + _y, frame.pixels[_y, _x], IgnoreLayer);
                    }
                }
                return true;
            }

            return false;
        }

        public Frame? SubFrame(int x1, int y1, int countx, int county)
        {
            if (x1 >= 0 && x1 < countx && y1 >= 0 && y1 < county &&
                countx <= width && county <= height)
            {
                Frame sub = new(countx - x1, county - y1);
                for (int x = x1; x < countx; x++)
                {
                    for (int y = y1; y < county; y++)
                    {
                        sub.PutPixel(x - x1, y - y1, pixels[y, x]);
                    }
                }
                return sub;
            }

            return null;
        }

        public void RaplacePixels(Pixel? Old, Pixel? New, bool IgnoreLayer = false)
        {
            for (int x = 0; x < width; x++)
            {
                for (int y = 0; y < height; y++)
                {
                    if (Pixel.Equals(pixels[y, x], Old))
                    {
                        PutPixel(x, y, New, IgnoreLayer);
                    }
                }
            }
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