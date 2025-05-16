using System.Diagnostics;

namespace GameLogicLib
{
    public class Game
    {
        static int? TargetFPS = null;
        static int? _Fps = null;
        public static int? Fps
        {
            get => _Fps;
            set => TargetFPS = value;
        }

        static bool RUN = false;
        static Thread TRender = new(Render);
        static Thread TUpdate = new(Update);

        public static void Start(int w, int h)
        {
            RenderLib.Render.Init(w, h);
            RUN = true;
            OnStart?.Invoke();
            TUpdate.Start();
            TRender.Start();
        }
        public static void Stop()
        {
            RUN = false;
            TUpdate.Join();
            TRender.Join();
            OnStop?.Invoke();
        }


        static void Render()
        {
            Stopwatch stopwatch = new Stopwatch();
            stopwatch.Start();

            long lastTicks = stopwatch.ElapsedTicks;
            double deltaTime;

            while (RUN)
            {
                long currentTicks = stopwatch.ElapsedTicks;
                long tickDelta = currentTicks - lastTicks;

                int targetFrameTime = 1000 / (TargetFPS ?? 1000);

                deltaTime = (tickDelta * 1000f) / Stopwatch.Frequency;
                _Fps = deltaTime == 0 ? 1000 : (int)(1000 / deltaTime);

                if (deltaTime >= targetFrameTime)
                {
                    lastTicks = currentTicks;
                    OnRender?.Invoke();
                    RenderLib.Render.UpdateScreen();
                }
                else Thread.Sleep((int)(targetFrameTime - deltaTime));
            }
        }
        static void Update()
        {
            Stopwatch stopwatch = new Stopwatch();
            stopwatch.Start();

            long lastTicks = stopwatch.ElapsedTicks;
            double deltaTime;

            while (RUN)
            {
                long currentTicks = stopwatch.ElapsedTicks;
                long tickDelta = currentTicks - lastTicks;
                lastTicks = currentTicks;

                deltaTime = (tickDelta * 1000f) / Stopwatch.Frequency;

                OnUpdate?.Invoke(deltaTime);
            }
        }

        public static event Action OnRender = null;
        public static event Action<double> OnUpdate = null;
        public static event Action OnStart = null;
        public static event Action OnStop = null;
    }
}
