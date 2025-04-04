namespace RPG_GAME
{
    public class Character
    {
        public string Name { get; set; }
        public int Health { get; set; }
        public int Strength { get; set; }
        public int Intelligence { get; set; }
        public Inventory Inventory { get; set; }

        public Character(string name)
        {
            Name = name;
            Health = 100;
            Strength = 10;
            Intelligence = 10;
            Inventory = new Inventory();
        }

        public void Attack(Character target)
        {
            int damage = Strength / 2;
            target.TakeDamage(damage);
            Console.WriteLine($"{Name} megtámadta {target.Name}-t {damage} sebzéssel!");
        }

        public void TakeDamage(int damage)
        {
            Health -= damage;
            if (Health <= 0)
            {
                Console.WriteLine($"{Name} meghalt!");
            }
        }
    }

    public class Inventory
    {
        public List<Item> Items { get; set; } = new List<Item>();

        public void AddItem(Item item)
        {
            Items.Add(item);
        }
    }

    public class Item
    {
        public string Name { get; set; }
        public string Description { get; set; }
    }
}