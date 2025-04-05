using System.Runtime.InteropServices;

namespace InputLib
{
    public class Mouse
    {
        public enum Button
        {
            Left = 0x01,
            Right = 0x02,
            Middle = 0x04,
            X1 = 0x05,
            X2 = 0x06
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct POINT
        {
            public int X;
            public int Y;
        }

        [DllImport("user32.dll")]
        private static extern bool GetCursorPos(out POINT lpPoint);

        public static POINT? GetPos()
        {
            if (GetCursorPos(out POINT point)) return point;
            return null;
        }

        [DllImport("user32.dll")]
        static extern int GetSystemMetrics(int nIndex);

        public static POINT GetMaxPos() =>
            new POINT() { X = GetSystemMetrics(0), Y = GetSystemMetrics(1) };


        [DllImport("user32.dll")]
        private static extern bool SetCursorPos(int X, int Y);

        public static void MoveTo(int x, int y) => SetCursorPos(x, y);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern IntPtr LoadCursorFromFile(string lpFileName);

        [DllImport("user32.dll")]
        private static extern IntPtr SetSystemCursor(IntPtr hcur, uint id);
        
        public static void SetCustomCursor(string cursorFilePath)
        {
            IntPtr hCursor = LoadCursorFromFile(cursorFilePath);
            if (hCursor != IntPtr.Zero)
            {
                SetSystemCursor(hCursor, 32512);
            }
        }

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);

        public static void RestoreDefaultCursors()
            => SystemParametersInfo(0x0057, 0, IntPtr.Zero, 0x02);
    }
}
