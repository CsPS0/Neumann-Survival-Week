namespace GameObjectsLib
{
    public class Conversations
    {
        public static readonly Discussion LeibiMonday = new Discussion(
            "Leibi",
            Sprites.Leibi,
            "Üdv! Leibinger Bence vagyok a webprogramozás tanár!",
            new Dictionary<char, string> {
                {'a', "Jó napot!"},
                {'b', "Szakmailag szia tanár úr!"},
                {'c', "Mosolgás"}
            }
        );

        public static readonly Discussion RizzlerMonday = new Discussion(
            "Rizzler",
            Sprites.Rizzler,
            "Hallo, ich weiß, das ist etwas zurückhaltend, aber ich schwöre, ich bin kein Schüler, ich bin Lehrer...",
            new Dictionary<char, string>()
        );

        public static readonly Discussion BarbieMonday = new Discussion(
            "Barbie",
            Sprites.Barbie,
            "Hi, I'm the English teacher, and many people call me 'Skibidi Barbie' or 'Little Mole'.",
            new Dictionary<char, string> {
                {'a', "I don't speak English."},
                {'b', "Well, that's funny."},
                {'c', "And that doesn't bother you?"}
            }
        );

        public static readonly Discussion BranyoMonday = new Discussion(
            "Branyó",
            Sprites.Branyo,
            "Jajj ne már, a szüleim nem engedtek el gamblingezni, és most elvették az összes pénzem!\nOh, helló, téged még nem ismerlek.",
            new Dictionary<char, string> {
                {'a', "uhm, még új vagyok"},
                {'b', "eskü pedig idejárok már egy ideje"},
                {'c', "{player.name} vagyok."}
            }
        );

        public static readonly Discussion CsPSFrontOfNeu = new Discussion(
            "CsPS",
            Sprites.CsPS,
            "Mi a neved:",
            new Dictionary<char, string>()
        );
    }
}