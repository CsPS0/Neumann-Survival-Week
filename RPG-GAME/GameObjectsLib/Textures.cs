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

            // idle
            options.Add("player_idle", () =>
            {
                Pixel head = new('O', skin_color, layer: player_layer);
                Pixel arm = new('|', skin_color, layer: player_layer);
                Pixel shirt = new('H', shirt_color, layer: player_layer);
                Pixel leg = new('║', pants_color, layer: player_layer);

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
                Pixel head = new('O', skin_color, layer: player_layer);
                Pixel l_arm = new('/', skin_color, layer: player_layer);
                Pixel r_arm = new('\\', skin_color, layer: player_layer);
                Pixel shirt = new('H', shirt_color, layer: player_layer);
                Pixel l_leg = new('/', pants_color, layer: player_layer);
                Pixel r_leg = new('\\', pants_color, layer: player_layer);

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
                Pixel head = new('O', skin_color, layer: player_layer);
                Pixel arm = new('|', skin_color, layer: player_layer);
                Pixel leg = new('|', pants_color, layer: player_layer);

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
                Pixel head = new('O', skin_color, layer: player_layer);
                Pixel l_arm = new('|', skin_color, layer: player_layer);
                Pixel shirt = new('H', shirt_color, layer: player_layer);
                Pixel r_arm = new('_', skin_color, layer: player_layer);
                Pixel leg = new('║', pants_color, layer: player_layer);

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
                Pixel head = new('O', skin_color, layer: player_layer);
                Pixel l_arm = new('|', skin_color, layer: player_layer);
                Pixel shirt = new('H', shirt_color, layer: player_layer);
                Pixel r_arm = new('/', skin_color, layer: player_layer);
                Pixel leg = new('║', pants_color, layer: player_layer);

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
                Pixel head = new('O', skin_color, layer: player_layer);
                Pixel arm = new('|', skin_color, layer: player_layer);
                Pixel shirt = new('H', shirt_color, layer: player_layer);
                Pixel leg = new('║', pants_color, layer: player_layer);

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
        }
    }
}
