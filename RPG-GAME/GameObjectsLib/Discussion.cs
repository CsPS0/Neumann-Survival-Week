namespace GameObjectsLib
{
    public class Discussion
    {
        public string NpcName { get; set; }
        public string AsciiFace { get; set; }
        public string Dialogue { get; set; }
        public Dictionary<char, string> Choices { get; set; } // e.g. 'a' => "Yes", 'b' => "No", 'c' => "Maybe"
        public char? SelectedChoice { get; private set; }

        public Discussion(string npcName, string asciiFace, string dialogue, Dictionary<char, string> choices)
        {
            NpcName = npcName;
            AsciiFace = asciiFace;
            Dialogue = dialogue;
            Choices = choices;
            SelectedChoice = null;
        }

        public void SelectChoice(char choice)
        {
            if (Choices.ContainsKey(choice))
                SelectedChoice = choice;
        }

        public string GetCurrentDialogue()
        {
            return Dialogue;
        }

        public Dictionary<char, string> GetChoices()
        {
            return Choices;
        }
    }
}