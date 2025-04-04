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

        public override string ToString() => $"{character};{fg};{bg}";
    }
}