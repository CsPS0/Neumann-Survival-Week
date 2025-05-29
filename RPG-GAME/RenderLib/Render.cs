namespace RenderLib
{
    public class Render
    {
        private static Frame current;
        private static Frame next;
        private static (byte r, byte g, byte b)? _fg, _bg;
        private static Modifiers _modifiers = new();
        public static int width => current.width;
        public static int height => current.height;

        public static void Init(int w, int h)
        {
            Console.CursorVisible = false;
            try { Console.SetBufferSize(w, h); } catch { }
            current = new Frame(w, h);
            next = new Frame(w, h);
        }

        static void CheckBuffers()
        {
            if (next == null || current == null) 
                throw new Exception("You need ti Render.Init() first.");
        }
        public static void PutPixel(int x, int y, Pixel? pixel, bool IgnoreLayer = false) {
            CheckBuffers();
            next.PutPixel(x, y, pixel, IgnoreLayer);
        }

        public static void PutFrame(int x, int y, Frame frame, bool IgnoreLayer = false)
        {
            CheckBuffers();
            next.PutFrame(x, y, frame, IgnoreLayer);
        }

        public static void Fill(Pixel pixel)
        {
            CheckBuffers();
            next.Fill(pixel);
        }

        public static void Clear()
        {
            CheckBuffers();
            next = new Frame(current.width, current.height);
        }

        public static void UpdateScreen()
        {
            CheckBuffers();
            int WindowWidth = Console.WindowWidth;
            int WindowHeight = Console.WindowHeight;

            for (int x = 0, endx = Math.Min(next.width, WindowWidth); x < endx; x++)
            {
                for (int y = 0, endy = Math.Min(next.height, WindowHeight); y < endy; y++)
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

                        Modifiers modifiers = pixel.modifiers;
                        if (modifiers.italic != _modifiers.italic)
                        {
                            if (modifiers.italic) output += "\x1b[3m";
                            else output += "\x1b[23m";
                        }
                        if (modifiers.bold != _modifiers.bold)
                        {
                            if (modifiers.bold) output += "\x1b[1m"; 
                            else output += "\x1b[22m";
                        }
                        if (modifiers.underline != _modifiers.underline)
                        {
                            if (modifiers.underline) output += "\x1b[4m";
                            else output += "\x1b[24m";
                        }
                        if (modifiers.strikethrough != _modifiers.strikethrough)
                        {
                            if (modifiers.strikethrough) output += "\x1b[9m";
                            else output += "\x1b[29m";
                        }
                        if (modifiers.blink != _modifiers.blink)
                        {
                            if (modifiers.blink) output += "\x1b[5m";
                            else output += "\x1b[25m";
                        }
                        _modifiers = modifiers.Clone();

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
