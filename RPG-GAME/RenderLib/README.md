# Rendering documentation

## Pixel in Pixel.cs

A class for representing a pixel.

attributes:
- (byte r, byte g, byte b) `fg`, `bg` : Rgb foreground and background colors
- char `character` : character to be displayed
- int `layer` : the layer of the pixel (for overlapping drawings)

## Frame in Frame.cs

A class for representing a frame (matrix of pixels).

attributes:
- Pixel[,]? `pixels` : matrix of pixels (it can contain null values)
- int `width`, `height` : dimensions of the frame

methods:
- `Frame(int width, int height)` : sets the dimensions of the frame
- `bool InFrameBounds(int x, int y)` : checks if the position (x, y) is inside 
the frame
- `bool PutPixel(int x, int y, Pixel pixel)` : set a pixel at position (x, y)
and returns true if the operation was successful
- `bool PutFrame(int x, int y, Frame frame)` : inserts a frame at position (x, y)
and returns true if the operation was successful

## Render in Render.cs

A class for "drawing" things to a hidden frame and when a function is called
it renders the changes to the screen.

attributes:
- Frame `frame` : the hidden buffer
- List<(int x, int y)> `changes` : keeps track of the changes made to the frame

methods:
- `Render(int width, int height)` : creates a hidden frame with the given dimensions
- `bool InConsoleBounds(int x, int y)` : checks if the position (x, y) is inside 
the console
- `void PutPixel(int x, int y, Pixel pixel)` : set a pixel at position (x, y) 
and adds the changes to the `changes` list
- `void PutFrame(int x, int y, Frame frame)` : inserts a frame at position (x, y)
and adds the changes to the `changes` list
- `void Render()` : renders the changes made to the frame to the screen
- `void ClearFrame()` : clears the frame
- `void ClearScreen()` : clears the screen
- `void Resize(int width, int height)` : creates a new frame with the 
given dimensions and inserts the previous frame into it
- `void SetRgbColor(byte r, byte g, byte b, bool fg = true)` : sets the color of 
the console with ansi escape codes, if fg is false it sets the background color
- `void SetRgbColor((byte r, byte g, byte b) color, bool fg = true)` : function 
overload --> the same function but you can pass different arguments
- `void ResetColors()` : resets the colors of the console