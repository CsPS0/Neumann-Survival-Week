using System.Diagnostics;

namespace RenderLib
{
    public class Render
    {
        public static Frame current;
        public static Frame next;
        private static (byte r, byte g, byte b)? _fg, _bg;
        public static int width => current.width;
        public static int height => current.height;

        public static void Init(int w, int h)
        {
            current = new Frame(w, h);
            next = new Frame(w, h);
            Console.Clear();
        }

        public static bool InConsoleBounds(int x, int y) => 
            x >= 0 && x < Console.BufferWidth && y >= 0 && y < Console.BufferHeight;

        public static bool PutPixel(int x, int y, Pixel? pixel, bool IgnoreLayer = false)
        {
            if (next.InFrameBounds(x, y) &&
                    (IgnoreLayer || next.pixels[y, x] == null ||
                    pixel?.layer >= next.pixels[y, x]?.layer))
            {
                next.pixels[y, x] = pixel;
                return true;
            }

            return false;
        }
    
        public static bool PutFrame(int x, int y, Frame frame)
        {
            if (next.InFrameBounds(x, y) || 
                next.InFrameBounds(x + frame.width, y + frame.height))
            {
                for (int _x = 0; _x < frame.width; _x++)
                {
                    for (int _y = 0; _y < frame.height; _y++)
                    {
                        PutPixel(x + _x, y + _y, frame.pixels[_y, _x]);
                    }
                }

                return true;
            }
            return false;
        }

        public static void Fill(Pixel pixel)
        {
            for (int x = 0; x < next.width; x++)
            {
                for (int y = 0; y < next.height; y++)
                {
                    PutPixel(x, y, pixel, true);
                }
            }
        }
    
        public static void Clear() => next = new Frame(current.width, current.height);

        public static void UpdateScreen()
        {
            for (int x = 0; x < next.width; x++)
            {
                for (int y = 0; y < next.height; y++)
                {
                    if (InConsoleBounds(x, y) && next.pixels[y, x] != null)
                    {
                        Pixel pixel = next.pixels[y, x];
                        Console.SetCursorPosition(x, y);
                        SetRgbColor(pixel.fg);
                        SetRgbColor(pixel.bg, false);
                        Console.Write(pixel.character);
                    }
                }
            }
        }
    
        public static void Resize(int width, int height)
        {
            if (width != current.width || height != current.height)
            {
                Frame temp = current;
                current = new Frame(width, height);
                next = new Frame(width, height);
                PutFrame(0, 0, temp);
            }
        }
    
        public static void SetRgbColor(byte r, byte g, byte b, bool fg = true)
        {
            if (fg && _fg != (r, g, b))
            {
                Console.Write($"\x1b[38;2;{r};{g};{b}m");
                _fg = (r, g, b);
            } else if (!fg && _bg != (r, g, b))
            {
                Console.Write($"\x1b[48;2;{r};{g};{b}m");
                _bg = (r, g, b);
            }
        }

        public static void SetRgbColor((byte r, byte g, byte b) color, bool fg = true)
        {
            if (fg && _fg != color)
            {
                Console.Write($"\x1b[38;2;{color.r};{color.g};{color.b}m");
                _fg = color;
            }
            else if (!fg && _bg != color)
            {
                Console.Write($"\x1b[48;2;{color.r};{color.g};{color.b}m");
                _bg = color;
            }
        }

        public static void ResetStyles() => Console.Write("\x1b[0m");
    }
}
