using System.Collections.Generic;

namespace GameObjectsLib
{
    public class Inventory
    {
        public List<Item> Items { get; } = new List<Item>();

        public void AddItem(Item item)
        {
            Items.Add(item);
        }

        public void RemoveItem(Item item)
        {            Items.Remove(item);
        }
    }
}
