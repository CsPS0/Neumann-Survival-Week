namespace GameObjectsLib;

public interface IInteractable
{
    string InteractHint { get; }
    void OnInteract();
}
