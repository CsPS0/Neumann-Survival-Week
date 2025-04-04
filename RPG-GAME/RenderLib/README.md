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
- `bool InFrameBounds(int x, int y)` : checks if the position (x, y) is 
inside the frame
- `bool PutPixel(int x, int y, Pixel pixel, bool IgnoreLayer)` : puts a pixel and 
returns true if the operation was successful
- `bool PutFrame(int x, int y, Frame frame)` : inserts a frame and 
returns true if the operation was successful
- `void Fill(Pixel pixel)` : fills the frame with the given pixel

## Render in Render.cs

A class for "drawing" things on the console. It uses 2 buffers(Pixel matrixies): 
	- Current buffer: stores the current content of the console
	- Next buffer: stores the next frame to be rendered
The render function only draws the pixels that have changed since the last frame.

attributes:
- Frame `current` : the current frame
- Frame `next` : the next frame to be rendered
- int `width`, `height` : dimensions of the buffers
- (byte r, byte g, byte b) `_fg`, `_bg` : keeps track of the colors of the 
console while rendering if the colors are already set, don't call `SetRgbColor()`.

methods:
- `void Init()` : initializes the buffers and the console
- `bool InConsoleBounds(int x, int y)` : checks if the position (x, y) is 
inside the console
- `bool PutPixel(int x, int y, Pixel pixel, bool IgnoreLayer)` : `Frame.PutPixel()` for 
the `next` frame
- `bool PutFrame(int x, int y, Frame frame)` : `Frame.PutFrame()` for
the `next` frame
- `void Fill(Pixel pixel)` : `Frame.Fill()` for the `next` frame
- `void UpdateScreen()` : renders the pixels from `next` to the console that differ
from `current` and clears `next` and sets `current` to `next`
- `void Clear()` : clears the `next` frame
- `void Resize(int width, int height)` : creates new frames with the 
given dimensions and inserts the previous `next` frame into the new one
- `void SetRgbColor(byte r, byte g, byte b, bool fg = true)` : sets the 
color of the console with ansi escape codes, if fg is false it sets the 
background color
- `void SetRgbColor((byte r, byte g, byte b) color, bool fg = true)` :
function overload --> the same function but you can pass different arguments
- `void ResetStyles()` : resets the styles of the console