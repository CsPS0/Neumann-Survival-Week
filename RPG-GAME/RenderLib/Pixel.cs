namespace RenderLib
{
    public class Pixel
    {
        public (byte r, byte g, byte b) Bg, Fg;
        public char Char;
        public int Layer;

        public Pixel(char c, 
            (byte r, byte g, byte b)? fg = null,
            (byte r, byte g, byte b)? bg = null,
            int Layer = 0)
        {
            Char = c;
            Fg = fg ?? (255, 255, 255);
            Bg = bg ?? (0, 0, 0);
            this.Layer = Layer;
        }
    }
}
