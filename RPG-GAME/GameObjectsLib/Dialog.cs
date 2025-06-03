using DataTypesLib;
using RenderLib;

namespace GameObjectsLib
{
    public class Dialog
    {
        public static Dialog? Current = null;

        public string Name;
        public TreeNode<string> RootLine;
        public TreeNode<string>? CurrentLine;

        public void ReStartDialog() => CurrentLine = RootLine;
        public bool NextLine(int branch = 0)
        {
            if (CurrentLine?.Children.Count > branch)
                CurrentLine = CurrentLine.Children[branch];
            else CurrentLine = null;

            return CurrentLine != null;
        }

        public string[]? ReadLines()
        {
            if (CurrentLine == RootLine) return [ RootLine.Value ];

            if (CurrentLine?.Children.Count > 0)
                return CurrentLine.Children.Select(c => c.Value).ToArray();

            return null;
        }

        public void AddDialogBranch(TreeNode<string> Entry, TreeNode<string> BranchRoot)
        {
            if (Entry != null) Entry.Children.Add(BranchRoot);
            else RootLine = BranchRoot;
        }

        public Dialog(string name)
        {
            Name = name;
        }
    }
}
