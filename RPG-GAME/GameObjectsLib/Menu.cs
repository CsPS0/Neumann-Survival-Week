namespace GameObjectsLib
{
    public class Menu
    {
        public string Name;
        public List<string> Options;
        public int SelectedIndex;

        public Menu(string Name, List<string> options)
        {
            this.Name = Name;
            Options = options;
            SelectedIndex = 0;
        }

        public static Menu? Current = null;
    }
}