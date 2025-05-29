namespace GameObjectsLib
{
    public enum MenuType
    {
        Main,
        Start,
        Settings
    }
    public class Menu
    {
        public MenuType Type;
        public List<string> Options;
        public int SelectedIndex;

        public Menu(MenuType type, List<string> options)
        {
            Type = type;
            Options = options;
            SelectedIndex = 0;
        }
    }
}