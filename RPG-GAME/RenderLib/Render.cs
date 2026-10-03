namespace RenderLib;

public class Render
{
    private static Frame? current;
    private static Frame? next;
    private static (byte r, byte g, byte b)? _fg, _bg;
    private static Modifiers _modifiers = new();
    public static int width => current!.width;
    public static int height => current!.height;

    public static void Init(int w, int h)
    {
        Console.CursorVisible = false;
        try 
        { 
            if (OperatingSystem.IsWindows())
            {
                Console.SetBufferSize(w, h); 
            }
        } 
        catch { }
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
        next!.PutPixel(x, y, pixel, IgnoreLayer);
    }

    public static void PutFrame(int x, int y, Frame frame, bool IgnoreLayer = false)
    {
        CheckBuffers();
        next!.PutFrame(x, y, frame, IgnoreLayer);
    }

    public static void Fill(Pixel pixel)
    {
        CheckBuffers();
        next!.Fill(pixel);
    }

    public static void Clear()
    {
        CheckBuffers();
        next = new Frame(current!.width, current!.height);
    }

    public static void UpdateScreen()
    {
        CheckBuffers();
        int WindowWidth = Console.WindowWidth;
        int WindowHeight = Console.WindowHeight;

        System.Text.StringBuilder sb = new System.Text.StringBuilder();

        for (int y = 0, endy = Math.Min(next!.height, WindowHeight); y < endy; y++)
        {
            for (int x = 0, endx = Math.Min(next!.width, WindowWidth); x < endx; x++)
            {
                if (!Pixel.Equals(next!.pixels[y, x], current!.pixels[y, x]))
                {
                    Pixel pixel = next!.pixels[y, x] ?? new(' ');

                    sb.Append($"\x1b[{y + 1};{x + 1}H");

                    if (pixel.fg != _fg && pixel.character != ' ')
                    {
                        sb.Append($"\x1b[38;2;{pixel.fg.r};{pixel.fg.g};{pixel.fg.b}m");
                        _fg = pixel.fg;
                    }
                    if (pixel.bg != _bg)
                    {
                        sb.Append($"\x1b[48;2;{pixel.bg.r};{pixel.bg.g};{pixel.bg.b}m");
                        _bg = pixel.bg;
                    }

                    Modifiers modifiers = pixel.modifiers;
                    if (modifiers.italic != _modifiers.italic)
                        sb.Append(modifiers.italic ? "\x1b[3m" : "\x1b[23m");
                    if (modifiers.bold != _modifiers.bold)
                        sb.Append(modifiers.bold ? "\x1b[1m" : "\x1b[22m");
                    if (modifiers.underline != _modifiers.underline)
                        sb.Append(modifiers.underline ? "\x1b[4m" : "\x1b[24m");
                    if (modifiers.strikethrough != _modifiers.strikethrough)
                        sb.Append(modifiers.strikethrough ? "\x1b[9m" : "\x1b[29m");
                    if (modifiers.blink != _modifiers.blink)
                        sb.Append(modifiers.blink ? "\x1b[5m" : "\x1b[25m");

                    _modifiers = modifiers.Clone();
                    sb.Append(pixel.character);
                }
            }
        }
        
        if (sb.Length > 0)
        {
            Console.Write(sb.ToString());
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
