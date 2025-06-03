namespace DataTypesLib
{
    public class TreeNode<T>
    {
        public T Value { get; set; }
        public List<TreeNode<T>> Children { get; set; } = new();
        public TreeNode(T value)
        {
            Value = value;
        }

        public static TreeNode<T>? CreateBranch(params T[] values)
        {
            if (values.Length > 0)
            {
                TreeNode<T> root = new TreeNode<T>(values[0]);
                for (int i = 1; i < values.Length; i++)
                    root.Children.Add(new(values[i]));
                return root;
            }
            return null;
        }
    }
}
