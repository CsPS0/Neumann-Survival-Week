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
            current = new Frame(w, h);
            next = new Frame(w, h);
            Console.Clear();
            Fill(new(' '));
        }

        public static bool PutPixel(int x, int y, Pixel? pixel, bool IgnoreLayer = false)
            => next.PutPixel(x, y, pixel, IgnoreLayer);

        public static bool PutFrame(int x, int y, Frame frame, bool IgnoreLayer = false)
            => next.PutFrame(x, y, frame, IgnoreLayer);

        public static Frame ReplacePixel(Pixel? Old, Pixel? New)
            => next.ReplacePixel(Old, New);

        public static Frame TextToFrame(string text,
            (byte r, byte g, byte b)? fg = null,
            (byte r, byte g, byte b)? bg = null, int layer = 0)
        {
            Frame result = new Frame(text.Length, 1);
            for (int i = 0; i < text.Length; i++)
                result.PutPixel(i, 0, new(text[i], fg, bg, layer));
            return result;
        }

        public static void Fill(Pixel pixel)
            => next.Fill(pixel);

        public static void Clear() => next = new Frame(current.width, current.height);

        public static void UpdateScreen()
        {
            int WindowWidth = Console.WindowWidth;
            int WindowHeight = Console.WindowHeight;

            for (int x = 0; x < next.width; x++)
            {
                for (int y = 0; y < next.height; y++)
                {
                    if (x >= 0 && x < WindowWidth && y >= 0 && y < WindowHeight &&
                        !Pixel.Equals(next.pixels[y, x], current.pixels[y, x]))
                    {
                        Pixel pixel = next.pixels[y, x] ?? new(' ');
                        string output = "";

                        if (pixel.fg != _fg || pixel.bg != _bg)
                        {
                            if (pixel.character != ' ')
                            {
                                output += $"\x1b[38;2;{pixel.fg.r};{pixel.fg.g};{pixel.fg.b}m";
                                _fg = pixel.fg;
                            }
                            output += $"\x1b[48;2;{pixel.bg.r};{pixel.bg.g};{pixel.bg.b}m";
                            _bg = pixel.bg;
                        }

                        try { Console.SetCursorPosition(x, y); }
                        catch { continue; }
                        Console.Write(output += pixel.character);
                    }
                }
            }
            current = next;
            Clear();
        }

        public static void Resize(int width, int height)
        {
            if (width != current.width || height != current.height) 
                Init(width, height); 
        }
    }
}
