using System.Diagnostics;

namespace GameLogicLib;

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

    public static readonly object StateLock = new();

    static void Render()
    {
        Stopwatch time = Stopwatch.StartNew();

        while (RUN)
        {
            lock (StateLock)
            {
                OnRender?.Invoke();
                RenderLib.Render.UpdateScreen();
            }

            int w = Console.WindowWidth;
            int h = Console.WindowHeight;
            if (RenderLib.Render.width != w ||
                RenderLib.Render.height != h)
            {
                lock (StateLock)
                {
                    RenderLib.Render.Init(w, h);
                    OnResized?.Invoke(w, h);
                }
            }

            int fps = (TargetFps == null || TargetFps.Value == 0) ? 1000 : TargetFps.Value;
            int targetMs = 1000 / fps;

            while (time.ElapsedMilliseconds < targetMs) 
            { 
                Thread.Sleep(1); 
            }
            
            long elapsed = time.ElapsedMilliseconds;
            _Fps = elapsed > 0 ? (int)(1000 / elapsed) : fps;
            time.Restart();
        }
    }
    
    static void Update()
    {
        Stopwatch time = Stopwatch.StartNew();

        while (RUN)
        {
            while (time.ElapsedMilliseconds < 1) 
            { 
                Thread.Sleep(1); 
            }
            
            lock (StateLock)
            {
                OnUpdate?.Invoke(time.ElapsedTicks * 1000d / Stopwatch.Frequency);
            }
            time.Restart();
        }
    }

    public static event Action OnRender = delegate { };
    public static event Action<double> OnUpdate = delegate { };
    public static event Action OnStart = delegate { };
    public static event Action OnStop = delegate { };
    public static event Action<int, int> OnResized = delegate { };
}
