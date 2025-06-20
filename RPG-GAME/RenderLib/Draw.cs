﻿namespace RenderLib
{
    public class Draw
    {
        public static Frame Text(string[] text,
            (byte r, byte g, byte b)? fg = null,
            (byte r, byte g, byte b)? bg = null,
            int layer = 0,
            Modifiers? modifiers = null)
        {
            int longest = text.Length > 0 ? text.Max(item => item.Length) : 0;

            Frame result = new Frame(longest, text.Length);
            for (int i = 0, l = text.Length; i < l; i++)
            {
                for (int j = 0, _l = text[i].Length; j < _l; j++)
                {
                    char c = text[i][j];
                    Pixel pixel = new(c, fg, bg, layer, modifiers);
                    result.PutPixel(j, i, pixel);
                }
            }
            return result;
        }
        public static Frame Text(string text,
            (byte r, byte g, byte b)? fg = null,
            (byte r, byte g, byte b)? bg = null,
            int layer = 0,
            Modifiers? modifiers = null)
        {
            Frame result = new Frame(text.Length, 1);
            for (int i = 0, l = text.Length; i < l; i++)
            {
                char c = text[i];
                Pixel pixel = new(c, fg, bg, layer, modifiers);
                result.PutPixel(i, 0, pixel);
            }
            return result;
        }

        public static Frame Box(int w, int h,
            (byte r, byte g, byte b)? fg = null,
            (byte r, byte g, byte b)? bg = null,
            int layer = 0,
            bool Rounded = false,
            bool Filled = false)
        {
            Pixel tl = new(Rounded ? '╭' : '┌', fg, bg, layer);
            Pixel tr = new(Rounded ? '╮' : '┐', fg, bg, layer);
            Pixel bl = new(Rounded ? '╰' : '└', fg, bg, layer);
            Pixel br = new(Rounded ? '╯' : '┘', fg, bg, layer);
            Pixel hr = new('│', fg, bg, layer);
            Pixel vr = new('─', fg, bg, layer);

            Frame result = new(w, h);
            for (int x = 0; x < w; x++)
            {
                for (int y = 0; y < h; y++)
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

        public static Frame TextBox(
            string text,
            (int horizontal, int vertical)? padding = null,
            (byte r, byte g, byte b)? text_fg = null,
            (byte r, byte g, byte b)? bg = null,
            (byte r, byte g, byte b)? border_fg = null,
            int layer = 0,
            Modifiers? modifiers = null,
            bool Rounded = false,
            bool Filled = false)
        {
            padding = padding ?? (0, 0);

            Frame TextResult = Text(text, text_fg, bg, layer, modifiers);
            Frame Rect = Box(
                TextResult.width + padding.Value.horizontal * 2 + 2,
                TextResult.height + padding.Value.vertical * 2 + 2,
                border_fg, bg, layer, Rounded, Filled);
            Rect.PutFrame(padding.Value.horizontal + 1, padding.Value.vertical + 1,
                TextResult);

            return Rect;
        }
        public static Frame TextBox(
                string[] text,
                (int horizontal, int vertical)? padding = null,
                (byte r, byte g, byte b)? text_fg = null,
                (byte r, byte g, byte b)? bg = null,
                (byte r, byte g, byte b)? border_fg = null,
                int layer = 0,
                Modifiers? modifiers = null,
                bool Rounded = false,
                bool Filled = false)
        {
            padding = padding ?? (0, 0);

            Frame TextResult = Text(text, text_fg, bg, layer, modifiers);
            Frame BoxResult = Box(
                TextResult.width + padding.Value.horizontal * 2 + 2,
                TextResult.height + padding.Value.vertical * 2 + 2,
                border_fg, bg, layer, Rounded, Filled);
            BoxResult.PutFrame(padding.Value.horizontal + 1, padding.Value.vertical + 1,
                TextResult);

            return BoxResult;
        }
    }
}
