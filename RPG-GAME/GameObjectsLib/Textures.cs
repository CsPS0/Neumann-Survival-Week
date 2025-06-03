using System.Linq.Expressions;
using System.Xml;
using RenderLib;

namespace GameObjectsLib
{
    public class Textures
    {
        public Dictionary<string, Func<Frame>> options = new();

        public Frame[] Load(params string[] texture_names)
        {
            List<Frame> frames = new();
            foreach (string name in texture_names)
            {
                if (options.ContainsKey(name)) frames.Add(options[name]());
                else throw new Exception($"{name} option not found. " +
                    $"Available options are: [{string.Join(", ", options.Keys)}]");
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
                    pixels = new Pixel?[,]
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
                    pixels = new Pixel?[,]
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
                    pixels = new Pixel?[,]
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
                    pixels = new Pixel?[,]
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
                    pixels = new Pixel?[,]
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
                    pixels = new Pixel?[,]
                    {
                        { null, head, arm },
                        { arm, shirt, null },
                        { null, leg, null },
                    }
                };
            });

            // falling
            options.Add("player_falling", () =>
            {
                Pixel shoulder = template.Clone('_', shirt_color);
                Pixel l_arm = template.Clone('/', skin_color);
                Pixel r_arm = template.Clone('\\', skin_color);
                Pixel leg = template.Clone('>', pants_color);
                Pixel feet = template.Clone(',', pants_color);

                return new Frame(0, 0)
                {
                    pixels = new Pixel?[,]
                    {
                        { null, shoulder, head, shoulder, null },
                        { l_arm, null, shirt, null, r_arm },
                        { feet, leg, feet, leg, null },
                    }
                };
            });
            // --- Player ---

            // --- School ---
            options.Add("school_front", () =>
            {
                string[] school = [
"                    ┌─────────────────────────────────────────────────────┐",
"                    │ ┌─────┐ ┌─────┐ ┌─────┬─────┬─────┐ ┌─────┐ ┌─────┐ │",
"                    │ │     │ │     │ │     │     │     │ │     │ │     │ │",
"                    │ └─────┘ └─────┘ └─────┴─────┴─────┘ └─────┘ └─────┘ │",
"┌───────────────────┤ ┌─────┐ ┌─────┐ ┌─────┬─────┬─────┐ ┌─────┐ ┌─────┐ ├───────────────────┐",
"│                   │ │     │ │     │ │     │     │     │ │     │ │     │ │                   │",
"│ ┌─────┐ ┌─────┐   │ └─────┘ └─────┘ └─────┴─────┴─────┘ └─────┘ └─────┘ │  ┌─────┐ ┌─────┐  │",
"│ │     │ │     │   │  ┌───────────────────────────────────────────────┐  │  │     │ │     │  │",
"│ │     │ │     │   │  │NEUMANN JÁNOS SZÁMITÁSTECHNIKAI SZAKKÖZÉPISKOLA│  │  │     │ │     │  │",
"│ │     │ │     │   │  └─────────────┬───╥───╥───╥───╥───┬─────────────┘  │  │     │ │     │  │",
"│ │     │ │     │   │┌─────┐ ┌─────┐ │   ║   ║   ║   ║   │ ┌─────┐ ┌─────┐│  │     │ │     │  │",
"│ │     │ │     │   ││     │ │     │ │ --║---║---║---║-- │ │     │ │     ││  │     │ │     │  │",
"│ └─────┘ └─────┘   │└─────┘ └─────┘ │   ║   ║   ║   ║   │ └─────┘ └─────┘│  └─────┘ └─────┘  │",
"│                   │              _/┴───╨───╨───╨───╨───┴\\_              │                   │",
"│                   │            _/─────────────────────────\\_            │                   │",
"│                   │           /─────────────────────────────\\           │                   │"
                ];
                return Frame.FromStrings(school);
            });
            // --- School ---

            // -- Aula
            options.Add("aula", () =>
            {
                string[] aula =
                {

"                          ___________________________________________________________________________________",
"                          │          ║          ║          ║               ║          ║          ║          │",
"                          │          ║          ║          ║               ║          ║          ║          │",
"                          │          ║          ║          ║               ║          ║          ║          │",
"                          └──────────╨──────────╨──────────╨───────────────╨──────────╨──────────╨──────────┘",
"   ______                                 ______                                      ______                                 ______",
"  │\\_____\\                               │\\_____\\                                    │\\_____\\                               │\\_____\\",
"  │ │     │                              │ │     │                                   │ │     │                              │ │     │",
"  │ │     │                              │ │     │                                   │ │     │                              │ │     │",
"  │ │     │                              │ │     │                                   │ │     │                              │ │     │",
"  │ │     │                              │ │     │                                   │ │     │                              │ │     │",
"  │ │     │                              │ │     │                                   │ │     │                              │ │     │",
"   \\│     │                               \\│     │                                    \\│     │                               \\│     │",
"    └─────┘                                └─────┘                                     └─────┘                                └─────┘",
"                                                                                                                                     ",
" ______________________________                                                     ______________________________                   ",
"│       \\────────────────────┐ \\                                                   │       \\────────────────────┐ \\                  ",
"│        \\───────────────────┴┐ \\                                                  │        \\───────────────────┴┐ \\                 ",
"│         \\───────────────────┴┐ \\                                                 │         \\───────────────────┴┐ \\                ",
"│  ______  \\───────────────────┴┐ \\       ______                                   │  ______  \\───────────────────┴┐ \\       ______  ",
"│ │\\_____\\  \\───────────────────┴┐ \\     │\\_____\\                                  │ │\\_____\\  \\───────────────────┴┐ \\     │\\_____\\ ",
"│ │ │     │  \\───────────────────┴┐ \\    │ │     │                                 │ │ │     │  \\───────────────────┴┐ \\    │ │     │",
"│ │ │     │  │────────────────────┴┐│    │ │     │                                 │ │ │     │  │────────────────────┴┐│    │ │     │",
"│ │ │     │  │─────────────────────┴┤    │ │     │                                 │ │ │     │  │─────────────────────┴┤    │ │     │",
"└─│ │     │──┴──────────────────────┘    │ │     │                                 └─│ │     │──┴──────────────────────┘    │ │     │",
"  │ │     │                              │ │     │                                   │ │     │                              │ │     │",
"   \\│     │                               \\│     │                                    \\│     │                               \\│     │",
"    └─────┘                                └─────┘                                     └─────┘                                └─────┘",
"                                                                                                                                     ",
"                                                                                                                                     ",
"─────────────────────────────────────────────────────────────┐           ┌─────────────────────────────────────────────────────────────"
                };
                return Frame.FromStrings(aula);
            });
            // -- Aula

            // -- Leibi --
            options.Add("leibi_face", () =>
            {
                string[] face = [
"%#--+*----::::-======-:--++++=-::+=+-::::--=-----#",
"%%%#:::--==*######***++*++##+=-=++**+=::--:=-::-+=",
"###*--#%#%%%%%%#%*+=+======+#%%#+*###%=::-++----==",
"#----=%#%%%%%%%%%*++++++++#+#%@%%#####*-:::++##+--",
"=--=+#%%%%%%###**+*#**#####%##%%%#*=**#-::::-*#*##",
"--=+##%%@@@@%%##*+++*#%##%%%####**+==**#+:::----+*",
"=-=+#%%@@@@%%%####********++=====-====##*+-----:-*",
"--=*%%%@@%###******+++====-------=====+#**=----::-",
"--=#%%%%#********+++====----========--=##*+=-==+**",
"==##%%%#********+++=================-==+#**===+*##",
"-=#%%###*******+++++++=================+##*+==+*##",
"###%%##*****++++=======================+*#%*-#**##",
"###%%#****+++=============-==--========+*%%#+#**##",
"##%%@***++++++++++++===================++%%%##**##",
"#+#%@****###%#####******++*****++*++===++#%%##*###",
"#**%@***######%%%%%##******##%%%%%%###*++*%#--+###",
"##+%#***##%%%%@@%%%%##***###%%%@%%%####*++%++#*###",
"#*#%*+*****#######%###*++##%%%#%%##%###*++%**#*###",
"####+++******########+===+##########**++==##*=*###",
"**##+*+**************+===+****#*****+====+*#*=*###",
"+*******************+==-==+******+++======#+==*###",
"-=******+++*******+===---=++**+++=======++%=+=*###",
"====************##+++++=====+***+++++==++******##*",
"==++*************#####**####********+++++*##*+*##*",
"++*##*********#**##%#######*++**********+*##@@%%#*",
"**##%***************######***++*********+######@@@",
"###%@#********##%##%%############********######**%",
"#%%@@@*************#####*+++++**********#####***##",
"#%@@@%*#************######***++*******#*%#####%%%#",
"%@@@@#***##****************++++**###%%%#####%@%###",
"@@@@@#****####***********++=+++*#####%%##%%%%#%%%%",
"@@@@@#*****#######*#***********#%#**#%@##%@@%@%%%#",
"@@@@@%******####%###########%%@@%%%**%@%#%%@@@#%@%",
"@@@@@@#*******########%%%######%%****%@%#%%@@@@@@@"
                ];
                return Frame.FromStrings(face);
            });
            // -- Leibi --
        }
    }
}
