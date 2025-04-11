namespace AssetsLib
{
    public class Assets
    {
        public static readonly string Path =
            Directory.GetParent(Directory.GetCurrentDirectory())
            .Parent.Parent.Parent.FullName + "\\Assets";

        public static Dictionary<string, object?>? GetFileTree(string path)
        {
            if (!Directory.Exists(path)) return null;

            Dictionary<string, object?>? tree = new();

            foreach (string file in Directory.GetFiles(path))
            {
                tree.Add(file, null);
            }

            foreach (string dir in Directory.GetDirectories(path))
            {
                tree.Add(dir, GetFileTree(dir));
            }

            return tree;
        }
    }
}
