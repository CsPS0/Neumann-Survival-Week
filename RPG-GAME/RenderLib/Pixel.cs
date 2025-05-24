using System.ComponentModel;

namespace RenderLib
{
    public class Modifiers
    {
        public bool italic = false;
        public bool bold = false;
        public bool underline = false;
        public bool strikethrough = false;
        public bool blink = false;

        public Modifiers(
            bool italic = false,
            bool bold = false,
            bool underline = false,
            bool strikethrough = false,
            bool blink = false
            )
        {
            if (italic) this.italic = italic;
            if (bold) this.bold = bold;
            if (underline) this.underline = underline;
            if (strikethrough) this.strikethrough = strikethrough;
            if (blink) this.blink = blink;
        }

        public void Reset ()
        {
            italic = false;
            bold = false;
            underline = false;
            strikethrough = false;
            blink = false;
        }

        public Modifiers Clone()
        {
            return new Modifiers(italic, bold, underline, strikethrough, blink);
        }
    }

    public class Pixel
    {
        public static (byte r, byte g, byte b) DefaultFg = (255, 255, 255);
        public static (byte r, byte g, byte b) DefaultBg = (0, 0, 0);

        public (byte r, byte g, byte b) fg, bg;
        public char character;
        public int layer;
        public Modifiers modifiers;

        public Pixel(char c, (byte r, byte g, byte b)? fg = null,
            (byte r, byte g, byte b)? bg = null, int layer = 0, 
            Modifiers? modifiers = null)
        {
            character = c;
            this.fg = fg ?? DefaultFg;
            this.bg = bg ?? DefaultBg;
            this.layer = layer;
            this.modifiers = modifiers ?? new();
        }

        public static bool Equals(Pixel? a, Pixel? b)
        {
            if (a == null && b == null) return true;
            if (a == null || b == null) return false;
            return a.character == b.character && a.fg.Equals(b.fg) && a.bg.Equals(b.bg);
        }
        public static Pixel? Parse(string pixel)
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
    
        public Pixel Clone(char? c = null, (byte r, byte g, byte b)? fg = null,
            (byte r, byte g, byte b)? bg = null, int? layer = null)
            => new(
                c ?? character, 
                fg ?? this.fg, 
                bg ?? this.bg, 
                layer ?? this.layer
                );
    }
}