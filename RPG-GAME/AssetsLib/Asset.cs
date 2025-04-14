namespace AssetsLib
{
    public class Assets
    {
        public static string Path = "./";

        public string[] ReadFileLines(string relative_path)
        {
            string full_path = $"{Path}/{relative_path}";
            if (!File.Exists(full_path))
                throw new FileNotFoundException("File not found.");
            return File.ReadAllLines(full_path);
        }

        public void WriteFileLines(string relative_path, string[] lines)
        {
            string full_path = $"{Path}/{relative_path}";
            if (!File.Exists(full_path))
                throw new FileNotFoundException("File not found.");
            File.WriteAllLines(full_path, lines);
        }
    }
}
