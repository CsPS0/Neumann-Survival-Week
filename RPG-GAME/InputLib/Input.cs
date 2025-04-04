using System.Runtime.InteropServices;

namespace InputLib
{
    public class Input
    {
        [DllImport("user32.dll")]
        private static extern short GetAsyncKeyState(int vKey);

        public static bool IsPressed(ConsoleKey key)
            => (GetAsyncKeyState((int)key) & 0x0001) != 0;

        public static bool IsPressed(Mouse.Button button)
            => (GetAsyncKeyState((int)button) & 0x0001) != 0;

        public static bool IsDown(ConsoleKey key)
            => (GetAsyncKeyState((int)key) & 0x8000) != 0;

        public static bool IsDown(Mouse.Button button)
            => (GetAsyncKeyState((int)button) & 0x8000) != 0;
    }
}
