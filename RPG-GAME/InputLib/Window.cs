using System.Runtime.InteropServices;

namespace InputLib
{
    public class Window
    {
        [DllImport("user32.dll", SetLastError = true)]
        private static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

        [DllImport("user32.dll")]
        private static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

        [StructLayout(LayoutKind.Sequential)]
        public struct RECT
        {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }

        public static RECT? GetWindowRect(string windowName)
        {
            IntPtr hWnd = FindWindow(null, windowName);
            if (!GetWindowRect(hWnd, out RECT rect)) return null;
            return rect;
        }
    }
}
