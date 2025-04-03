# Input documentation

dependencies:
- System.Runtime.InteropServices

## Window in Window.cs

A class that gets information about the current window

attributes:
- `IntPtr FindWindow(string lpClassName, string lpWindowName)` : finds a window by the title 
of the class of it
- `public struct RECT` : a struct that contains the position and size of a window
- `bool GetWindowRect(IntPtr hWnd, out RECT lpRect)` : writes the position and size of the 
window to the `lpRect` variable and returns true if successful
- `RECT? GetWindowRect(string windowName)` : combines `FindWindow` and `GetWindowRect` to get the
rect of a window by its name

## Mouse in Mouse.cs

A class that stores properties of the mouse

attributes:
- `enum Button` : an enum that contains the buttons of the mouse like ConsoleKey
- `POINT? Pos` : the coordinates of the mouse
- `struct POINT` : a struct that contains the x and y coordinates of the mouse

methods:
- `bool GetCursorPos(out POINT lpPoint)` : writes the current position of the mouse to the 
`lpPoint` variable and returns true if successful

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