# Rendering documentation

## Pixel in Pixel.cs

A class for representing a pixel.

attributes:
- char `character` : character to be displayed
- (byte r, byte g, byte b) `fg`, `bg` : Rgb foreground and background colors
- int `layer` : the layer of the pixel (for overlapping drawings)

methods:
- `bool Equals(Pixel? a, Pixel? b)` : checks if two pixels are have the same properties
except for the layer
- `Pixel? FromString(string pixel)` : Tries to create a pixel from a string, 
example string: 
```
"a,255,255,255,0,100,30,0"
```

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
- `bool PutFrame(int x, int y, Frame frame, bool IgnoreLayer = false)` : inserts a frame and 
returns true if the operation was successful
- `Frame? SubFrame(int x1, int y1, int countx, int county)` : returns a subframe 
of the frame
- `void RaplacePixels(Pixel? Old, Pixel? New, bool IgnoreLayer = false)` :
replaces the 'old' pixels with the 'new' pixels in the frame
- `void Fill(Pixel pixel)` : fills the frame with the given pixel
- `Frame? FromStrings(string[] frame)` : Tries to create a frame from an array of 
strings that containes the dimensions and the lines of the frame,
example string:
```
{
	"3x1",
	"A,0,0,0,255,255,255,0;B,0,0,0,255,255,255,0;C,0,0,0,255,255,255,0;"
}
```

## Render in Render.cs

A class for "drawing" things on the console. It uses 2 buffers(Pixel matrixies): 
	- Current buffer: stores the current content of the console
	- Next buffer: stores the next frame to be rendered
The render function only draws the pixels that have changed since the last frame.

attributes:
- Frame `current` : the current frame
- Frame `next` : the next frame to be rendered
- (byte r, byte g, byte b)? `_fg`, `_bg` : keeps track of the colors of the 
console while rendering and if the colors are already set, skip the step.
- int `width`, `height` : dimensions of the buffers

methods:
- `void Init()` : initializes the buffers and the console
- `bool PutPixel(int x, int y, Pixel pixel, bool IgnoreLayer)` : `Frame.PutPixel()` for 
the `next` frame
- `bool PutFrame(int x, int y, Frame frame, bool IgnoreLayer = false)` : 
`Frame.PutFrame()` for the `next` frame
- `public static Frame TextToFrame(string text, 
            (byte r, byte g, byte b)? fg = null,
            (byte r, byte g, byte b)? bg = null, int layer = 0)` : converts a string 
to a `Frame`
- `void Fill(Pixel pixel)` : `Frame.Fill()` for the `next` frame
- `void UpdateScreen()` : renders the pixels from `next` to the console that differ
from `current` and clears `next` and sets `current` to `next`
- `void Clear()` : clears the `next` frame
- `void Resize(int width, int height)` : `Render.Init()` if the width or height is not
the same as the current one
- `void ResetStyle()` : reset the colors
