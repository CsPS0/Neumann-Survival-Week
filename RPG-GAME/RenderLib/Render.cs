// ansi escape codes: https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797

namespace RenderLib
{
    public class Render
    {
        // 2 buffers(matrixes) for better performance
        static private Frame Current;
        static private Frame Next;

        // draw the next frame to the console and swap the buffers
        static public void UpdateScreen()
        {
            if (Current != null)
            {
                for (int y = 0; y < Current.Height; y++)
                {
                    for (int x = 0; x < Current.Width; x++)
                    {
                        // if the pixel is not null and is in bounds
                        if (Next.Pixels[x, y] != null && InBounds(x, y))
                        {
                            // if the pixel is different from the current
                            if (Current.Pixels[x, y] == null
                                || !Next.Pixels[x, y].Equals(Current.Pixels[x, y]))
                            {
                                // set the cursor position
                                Console.SetCursorPosition(x, y);
                                // set the colors
                                SetRGBColor(Next.Pixels[x, y].Fg);
                                SetRGBColor(Next.Pixels[x, y].Bg, false);
                                // write the character
                                Console.Write(Next.Pixels[x, y].Char);
                            }
                        }
                        else if (Current.Pixels[x, y] != null)
                        {
                            // set the cursor position
                            Console.SetCursorPosition(x, y);
                            // reset the color
                            ResetColors();
                            // write a space
                            Console.Write(' ');
                        }
                    }
                }
                // swap the buffers
                var temp = Current;
                Current = Next;
                Next = temp;
            }
        }

        // initialize the console
        static public void Init()
        {
            Clear();
            Console.CursorVisible = false;

            // sets the buffer size to the window size
            // (will be elsewhere later)
            Console.SetBufferSize(Console.WindowWidth, Console.WindowHeight);

            // set the Current and Next buffers
            Current = new Frame(Console.BufferWidth, Console.BufferHeight);
            Next = new Frame(Console.BufferWidth, Console.BufferHeight);
        }

        // checks if position is within the console bounds
        static public bool InBounds(int x, int y) 
            => x >= 0 && x < Console.BufferWidth 
            && y >= 0 && y < Console.BufferHeight;

        // uses ansi escape codes to set rgb colors
        static public void SetRGBColor(byte r, byte g, byte b, bool fg = true)
            => Console.Write($"\x1b[{(fg ? "38;2" : "48;2")};{r};{g};{b}m");
        static public void SetRGBColor((byte r, byte g, byte b) color, bool fg = true)
            => Console.Write($"\x1b[{(fg ? "38;2" : "48;2")};{color.r};{color.b};{color.b}m");

        // resets the colors to default
        static public void ResetColors()
            => Console.Write("\x1b[0m");

        // clears the screen
        static public void Clear()
            => Console.Write("\x1b[2J");
    }
}
