using System.Diagnostics;

namespace GameLogicLib
{
    public class Game
    {
        static int? TargetFps = null;
        static int? _Fps = null;
        public static int? Fps
        {
            get => _Fps;
            set => TargetFps = value;
        }

        static bool RUN = false;
        static Thread TRender = new(Render);
        static Thread TUpdate = new(Update);

        public static void Start(int w, int h)
        {
            RenderLib.Render.Init(w, h);
            RUN = true;
            OnStart?.Invoke();
            OnResized?.Invoke(w, h);
            TUpdate.Start();
            TRender.Start();
        }
        public static void Stop()
        {
            RUN = false;
            OnStop?.Invoke();
        }

        static void Render()
        {
            Stopwatch time = Stopwatch.StartNew();

            while (RUN)
            {
                OnRender?.Invoke();
                RenderLib.Render.UpdateScreen();

                int w = Console.WindowWidth;
                int h = Console.WindowHeight;
                if (RenderLib.Render.width != w ||
                    RenderLib.Render.height != h)
                {
                    RenderLib.Render.Init(w, h);
                    OnResized?.Invoke(w, h);
                }


                int fps;
                if (TargetFps == null || TargetFps.Value == 0) fps = 1000;
                else fps = TargetFps.Value;

                while (time.ElapsedMilliseconds < 1000 / fps) { }
                _Fps = (int)(1000 / time.ElapsedMilliseconds);

                time.Restart();
            }
        }
        static void Update()
        {
            Stopwatch time = Stopwatch.StartNew();

            while (RUN)
            {
                while (time.ElapsedMilliseconds < 1) { }
                OnUpdate?.Invoke(time.ElapsedTicks * 1000d / Stopwatch.Frequency);
                time.Restart();
            }
        }

        public static event Action OnRender = delegate { };
        public static event Action<double> OnUpdate = delegate { };
        public static event Action OnStart = delegate { };
        public static event Action OnStop = delegate { };
        public static event Action<int, int> OnResized = delegate { };
    }
}
