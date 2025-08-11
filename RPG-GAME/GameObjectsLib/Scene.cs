namespace GameObjectsLib
{
    public class Scene
    {
        static Scene? _Current = null;
        static List<Thing> AllThings = new();
        public static void HideAllThings() 
        { foreach (var thing in AllThings) thing.Hide = true; }
        public static Scene? Current
        {
            get => _Current;
            set
            {
                if (_Current != value)
                {
                    HideAllThings();
                    if (value != null) 
                        foreach (var thing in value._Things) thing.Hide = false;
                    OnChange?.Invoke(_Current, value);
                    _Current = value;
                }
            }
        }


        public static Action<Scene?, Scene?> OnChange = null!;

        public string Name;
        
        List<Thing> _Things = new();
        public void AddThings(params Thing[] things)
        {
            foreach (var thing in things)
            {
                if (!AllThings.Contains(thing)) AllThings.Add(thing);
                _Things.Add(thing);
            }
        }

        

        public Scene(string Name)
        {
            this.Name = Name;
        }
    }
}
