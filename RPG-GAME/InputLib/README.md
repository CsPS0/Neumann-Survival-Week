# Input documentation

dependencies:
- System.Runtime.InteropServices

## Input in Input.cs

A class that captures input from the user.

attributes:

methods:
- `short GetAsyncKeyState(int vKey)` : gets the state of a key, returns a 16-bit number and
the `most left` bit indicates if the `key is down` and the `most right` bit indicates if the `key 
was pressed`
- `bool IsPressed(ConsoleKey key)` : checks if a key is pressed
- `bool IsPressed(Mouse.Button button)` : checks if a mouse button is pressed
- `bool IsDown(ConsoleKey key)` : checks if a key is being held down
- `bool IsDown(Mouse.Button button)` : checks if a mouse button is being held down
