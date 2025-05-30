namespace GameObjectsLib
{
    public enum SceneType
    {
        Outside,
        Aula
    }
    public class Scene
    {
        public SceneType Type;
        public List<Thing> Things;
        public event Action<double> OnUpdate = null!;
        public event Action OnRender = null!;

        public Scene(SceneType type, List<Thing> things)
        {
            Type = type;
            Things = things;
        }

        public static Scene Current = null!;
    }
}
