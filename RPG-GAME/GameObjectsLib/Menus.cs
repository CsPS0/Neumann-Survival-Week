namespace GameObjectsLib
{
    public class Menus
    {
        public enum MenuType
        {
            Main,
            Start,
            Settings
        }

        public class Menu
        {
            public MenuType Type { get; set; }
            public List<string> Options { get; set; }
            public int SelectedIndex { get; set; }
            public bool ColorsOn { get; set; } // For settings

            public Menu(MenuType type, List<string> options, bool colorsOn = true)
            {
                Type = type;
                Options = options;
                SelectedIndex = 0;
                ColorsOn = colorsOn;
            }
        }

        public static Menu GetMainMenu(bool colorsOn = true)
        {
            return new Menu(MenuType.Main, new List<string> { "Start", "Settings", "Exit" }, colorsOn);
        }

        public static Menu GetStartMenu(bool colorsOn = true)
        {
            return new Menu(MenuType.Start, new List<string> { "Hétfő", "Kedd" }, colorsOn);
        }

        public static Menu GetSettingsMenu(bool colorsOn)
        {
            string colorOption = $"Colors: {(colorsOn ? "ON" : "OFF")}";
            return new Menu(MenuType.Settings, new List<string> { colorOption }, colorsOn);
        }
    }
}