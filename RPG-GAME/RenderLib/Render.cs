using System.Diagnostics;

namespace RenderLib
{
    public class Render
    {
        private static Frame current;
        private static Frame next;
        private static (byte r, byte g, byte b)? _fg, _bg;
        public static int width => current.width;
        public static int height => current.height;

        public static void Init(int w, int h)
        {
            Console.CursorVisible = false;
            try { Console.SetBufferSize(w, h); } catch { }
            current = new Frame(w, h);
            next = new Frame(w, h);
        }

        public static void PutPixel(int x, int y, Pixel? pixel, bool IgnoreLayer = false)
            => next.PutPixel(x, y, pixel, IgnoreLayer);

        public static void PutFrame(int x, int y, Frame frame, bool IgnoreLayer = false)
            => next.PutFrame(x, y, frame, IgnoreLayer);

        public static void Fill(Pixel pixel)
            => next.Fill(pixel);

        public static void Clear() => next = new Frame(current.width, current.height);

        public static void UpdateScreen()
        {
            int WindowWidth = Console.WindowWidth;
            int WindowHeight = Console.WindowHeight;

            for (int x = 0; x < Math.Min(next.width, WindowWidth); x++)
            {
                for (int y = 0; y < Math.Min(next.height, WindowHeight); y++)
                {
                    if (!Pixel.Equals(next.pixels[y, x], current.pixels[y, x]))
                    {
                        Pixel pixel = next.pixels[y, x] ?? new(' ');
                        string output = "";

                        if (pixel.fg != _fg && pixel.character != ' ')
                        {
                            output += $"\x1b[38;2;{pixel.fg.r};{pixel.fg.g};{pixel.fg.b}m";
                            _fg = pixel.fg;
                        }
                        if (pixel.bg != _bg)
                        {
                            output += $"\x1b[48;2;{pixel.bg.r};{pixel.bg.g};{pixel.bg.b}m";
                            _bg = pixel.bg;
                        }

                        try { Console.SetCursorPosition(x, y); }
                        catch { continue; }
                        Console.Write(output + pixel.character);
                    }
                }
            }
            current = next;
            Clear();
        }
    
        public static void ResetStyle()
        {
            _fg = null;
            _bg = null;
            Console.Write("\x1b[0m");
        }
    }
}
