using DataTypesLib;
using Newtonsoft.Json;
using System.IO;
using System.Linq;

namespace GameObjectsLib
{
    public class Dialog
    {
        public static Dialog? Current = null;

        public string Name;
        public TreeNode<string>? RootLine;
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
            if (CurrentLine == RootLine) return new string[] { RootLine?.Value! };

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

        public static Dialog LoadDialog(string path)
        {
            string json = File.ReadAllText(path);
            DialogData data = JsonConvert.DeserializeObject<DialogData>(json)!;

            Dialog dialog = new Dialog(data.Name!);
            dialog.RootLine = CreateTreeNode(data.Root)!;
            dialog.ReStartDialog();
            return dialog;
        }

        private static TreeNode<string>? CreateTreeNode(DialogNodeData? data)
        {
            if (data == null) return null;

            TreeNode<string> node = new TreeNode<string>(data.Text!);
            foreach (var childData in data.Children)
            {
                TreeNode<string>? childNode = CreateTreeNode(childData);
                if (childNode != null)
                {
                    node.Children.Add(childNode);
                }
            }
            return node;
        }
    }
}