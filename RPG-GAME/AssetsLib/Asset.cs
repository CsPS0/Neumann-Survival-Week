namespace AssetsLib
{
    public class Assets
    {
        public static string Path = "./";

        public static string[] ReadFileLines(string relative_path)
        {
            string full_path = $"{Path}/{relative_path}";
            if (!File.Exists(full_path))
                throw new FileNotFoundException("File not found.");
            return File.ReadAllLines(full_path);
        }

        public static void WriteFileLines(string relative_path, string[] lines)
        {
            if (!Directory.Exists(Path))
                throw new FileNotFoundException("File not found.");
            File.WriteAllLines($"{Path}/{relative_path}", lines);
        }
    }
}
