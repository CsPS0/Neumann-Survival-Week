namespace RenderLib
{
    public class Draw
    {
        public static Frame TextToFrame(string text, 
            (byte r, byte g, byte b)? fg = null, 
            (byte r, byte g, byte b)? bg = null, 
            int layer = 0)
        {
            Frame result = new Frame(text.Length, 1);
            for (int i = 0; i < text.Length; i++)
                result.PutPixel(i, 0, new(text[i], fg, bg, layer));
            return result;
        }

        public static Frame RectToFrame(int w, int h, 
            (byte r, byte g, byte b)? fg = null, 
            (byte r, byte g, byte b)? bg = null,
            int layer = 0,
            bool Rounded = false,
            bool Filled = false)
        {
            Pixel tl = new(Rounded ? '╭' : '┌', fg, bg, layer);
            Pixel tr = new(Rounded ? '╮' :'┐', fg, bg, layer);
            Pixel bl = new(Rounded ? '╰' : '└', fg, bg, layer);
            Pixel br = new(Rounded ? '╯' : '┘', fg, bg, layer);
            Pixel hr = new('│', fg, bg, layer);
            Pixel vr = new('─', fg, bg, layer);

            Frame result = new(w, h);
            for (int x = 0; x < w; x++)
            {
                for (int y = 0; y <  h; y++)
                {
                    if (x == 0 && y == 0) result.PutPixel(x, y, tl);
                    else if (x == w - 1 && y == 0) result.PutPixel(x, y, tr);
                    else if (x == 0 && y == h - 1) result.PutPixel(x, y, bl);
                    else if (x == w - 1 && y == h - 1) result.PutPixel(x, y, br);
                    else if (x > 0 && x < w - 1 && (y == 0 || y == h - 1)) result.PutPixel(x, y, vr);
                    else if (y > 0 && y < h - 1 && (x == 0 || x == w - 1)) result.PutPixel(x, y, hr);
                    else if (Filled) result.PutPixel(x, y, new(' ', bg: bg, layer: layer));
                }
            }

            return result;
        }
    }
}
