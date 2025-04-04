using System.Runtime.InteropServices;

namespace InputLib
{
    public class Mouse
    {
        [StructLayout(LayoutKind.Sequential)]
        public struct POINT
        {
            public int X;
            public int Y;
        }

        [DllImport("user32.dll")]
        private static extern bool GetCursorPos(out POINT lpPoint);

        public static POINT? GetGlobalPos()
        {
            if (GetCursorPos(out POINT point)) return point;
            return null;
        }

        public enum Button
        {
            Left = 0x01,
            Right = 0x02,
            Middle = 0x04,
            X1 = 0x05,
            X2 = 0x06
        }
    }
}
