using System.Linq.Expressions;
using System.Xml;
using RenderLib;

namespace GameObjectsLib
{
    public class Textures
    {
        public Dictionary<string, Func<Frame>> options = new();
        public Frame Load(string texture_name)
        {
            if (options.ContainsKey(texture_name)) return options[texture_name]();
            else throw new Exception($"{texture_name} not found in options");
        }

        public Frame[] Load(string[] texture_names)
        {
            List<Frame> frames = new();
            foreach (string name in texture_names)
            {
                if (options.ContainsKey(name))
                {
                    frames.Add(options[name]());
                }
                else throw new Exception($"{name} not found in options");
            }
            return frames.ToArray();
        }

        public Textures()
        {
            // --- Player ---
            int player_layer = 1;
            (byte r, byte g, byte b) skin_color = (255, 181, 145);
            (byte r, byte g, byte b) pants_color = (19, 119, 214);
            (byte r, byte g, byte b) shirt_color = pants_color;

            Pixel template = new(' ', layer: player_layer);

            Pixel head = template.Clone('O', skin_color);
            Pixel shirt = template.Clone('#', shirt_color);

            // idle
            options.Add("player_idle", () =>
            {
                Pixel arm = template.Clone('|', skin_color);
                Pixel leg = template.Clone('║', pants_color);

                return new Frame(0, 0)
                {
                    pixels = new Pixel[,]
                    {
                        { null, head, null },
                        { arm, shirt, arm },
                        { null, leg, null },
                    }
                };
            });

            // walk1
            options.Add("player_walk1", () =>
            {
                Pixel l_arm = template.Clone('/', skin_color);
                Pixel r_arm = template.Clone('\\', skin_color);
                Pixel l_leg = template.Clone('/', pants_color);
                Pixel r_leg = template.Clone('\\', pants_color);

                return new Frame(0, 0)
                {
                    pixels = new Pixel[,]
                    {
                        { null, head, null },
                        { l_arm, shirt, r_arm },
                        { l_leg, null, r_leg },
                    }
                };
            });

            // walk2
            options.Add("player_walk2", () =>
            {
                Pixel arm = template.Clone('|', skin_color);
                Pixel leg = template.Clone('|', pants_color);

                return new Frame(0, 0)
                {
                    pixels = new Pixel[,]
                    {
                        { null, head, null },
                        { null, arm, null },
                        { null, leg, null },
                    }
                };
            });

            // wave1
            options.Add("player_wave1", () =>
            {
                Pixel l_arm = template.Clone('|', skin_color);
                Pixel r_arm = template.Clone('_', skin_color);
                Pixel leg = template.Clone('║', pants_color);

                return new Frame(0, 0)
                {
                    pixels = new Pixel[,]
                    {
                        { null, head, null, r_arm, r_arm },
                        { l_arm, shirt, null, null, null },
                        { null, leg, null, null, null },
                    }
                };
            });

            // wave2
            options.Add("player_wave2", () =>
            {
                Pixel l_arm = template.Clone('|', skin_color);
                Pixel r_arm = template.Clone('/', skin_color);
                Pixel leg = template.Clone('║', pants_color);

                return new Frame(0, 0)
                {
                    pixels = new Pixel[,]
                    {
                        { null, head, null, r_arm },
                        { l_arm, shirt, null, null },
                        { null, leg, null, null },
                    }
                };
            });

            // wave3
            options.Add("player_wave3", () =>
            {
                Pixel arm = template.Clone('|', skin_color);
                Pixel leg = template.Clone('║', pants_color);

                return new Frame(0, 0)
                {
                    pixels = new Pixel[,]
                    {
                        { null, head, arm },
                        { arm, shirt, null },
                        { null, leg, null },
                    }
                };
            });
            // --- Player ---

            //# ┌
            //# ┐
            //# └
            //# ┘
            //# │ ║
            //# ─ ═
            //# ┴ ╨
            //# ┤
            //# ┬ ╥
            //# ├
            //# ╲
            Pixel hr = new('│');
            Pixel vr = new('─');
            Pixel tl = new('┌');
            Pixel tr = new('┐');
            Pixel bl = new('└');
            Pixel br = new('┘');

            // --- School ---
            options.Add("school_front", () =>
            {
                (byte r, byte g, byte b) window_color = (0, 0, 0);
                (byte r, byte g, byte b) wall_color = (0, 0, 0);
                (byte r, byte g, byte b) door_color = (0, 0, 0);

                Pixel[] window_top_frame = new Pixel[] { tl, vr, vr, vr, vr, vr, tr };
                Frame window_middle_frame = new Frame(0, 0)
                {
                    pixels = new Pixel[,]
                    {
                        { hr, null, null, null, null, null, hr }
                    }
                };
                Frame window_bottom_frame = new Frame(0, 0)
                {
                    pixels = new Pixel[,]
                    {
                        { bl, vr, vr, vr, vr, vr, br }
                    }
                };

                return new Frame(0, 0);
            });
            // --- School ---

            // --- Start Button ---
            // active
            options.Add("start_button_active", () => 
            Draw.TextBoxToFrame("Start Game", (1, 0), modifiers: new(underline: true)));
            // inactive
            options.Add("start_button_inactive", () => 
            Draw.TextBoxToFrame("Start Game", (1, 0)));
            // --- Start Button ---
        }
    }
}
