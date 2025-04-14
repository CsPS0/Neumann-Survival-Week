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
        public static Pixel? FromString(string pixel)
        {
            string[] parts = pixel.Split(',');
            if (parts.Length == 8 &&
                char.TryParse(parts[0], out char ch) &&
                byte.TryParse(parts[1], out byte r1) &&
	            byte.TryParse(parts[2], out byte g1) &&
	            byte.TryParse(parts[3], out byte b1) &&
	            byte.TryParse(parts[4], out byte r2) &&
	            byte.TryParse(parts[5], out byte g2) &&
	            byte.TryParse(parts[6], out byte b2) &&
	            int.TryParse(parts[7], out int layer))
            {
                var fg = (r1, g1, b1);
                var bg = (r2, g2, b2);
                return new(ch, fg, bg, layer);
            }

            return null;
        }

        public override string ToString()
            => $"{character},{fg.r},{fg.g},{fg.b},{bg.r},{bg.g},{bg.b},{layer}";
    }
}