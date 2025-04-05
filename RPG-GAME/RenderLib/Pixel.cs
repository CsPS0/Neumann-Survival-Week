namespace RenderLib
{
    public class Pixel
    {
        public (byte r, byte g, byte b) fg, bg;
        public char character;
        public int layer;

        public Pixel(char c, (byte r, byte g, byte b)? fg = null,
            (byte r, byte g, byte b)? bg = null, int layer = 0)
        {
            character = c;
            this.fg = fg ?? (255, 255, 255);
            this.bg = bg ?? (0, 0, 0);
            this.layer = layer;
        }

        public static bool Equals(Pixel? a, Pixel? b)
        {
            if (a == null && b == null) return true;
            if (a == null || b == null) return false;
            return a.character == b.character && a.fg.Equals(b.fg) && a.bg.Equals(b.bg);
        }
    }
}