using DataTypesLib;
using System.Collections.Generic;

namespace GameObjectsLib
{
    public class DialogNodeData
    {
        public string Text { get; set; }
        public List<DialogNodeData> Children { get; set; } = new();
    }

    public class DialogData
    {
        public string Name { get; set; }
        public DialogNodeData Root { get; set; }
    }
}
