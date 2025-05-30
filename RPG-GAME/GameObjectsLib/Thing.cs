using System.Diagnostics;
using RenderLib;
using GameLogicLib;

namespace GameObjectsLib
{
    public class Thing
    {
        public double double_x;
        public double double_y;

        public bool hide = false;

        public int x
        {
            get => (int)Math.Round(double_x);
            set => double_x = value;
        }
        public int y
        {
            get => (int)(Math.Round(double_y));
            set => double_y = value;
        }

        public List<Thing> CheckCollisions = new();

        public int width { get => Output == null ? 0 : Output.width; }
        public int height { get => Output == null ? 0 : Output.height; }

        public Thing(double x, double y, bool IgnoreLayer = false, 
            Rect? Hitbox = null)
        {
            double_x = x;
            double_y = y;
            Game.OnRender += () =>
            {
                if (Output != null && !hide)
                    Render.PutFrame(this.x, this.y, Output, IgnoreLayer);
            };
            if (Hitbox != null) _Hitbox = Hitbox;
        }

        public int animation_fps = 24;
        public Dictionary<string, Frame[]> animations = new();

        private string? _animation_name;
        public string? animation_name 
        { 
            get => _animation_name;
            set
            {
                if (animations.ContainsKey(value))
                {
                    if (_animation_name != value)
                    {
                        _animation_name = value;
                        animation_index = 0;
                    }
                } else throw new Exception($"{value} animation not found. " +
                    $"Available animtions are: [{string.Join(", ", animations.Keys)}]");
            }
        }
        private Stopwatch timer = new();
        private int animation_index = 0;

        public Frame? Output;
        public Rect _Hitbox = new();
        public Rect Hitbox
        {
            get => new(
                    _Hitbox.x ?? x, _Hitbox.y ?? y, _Hitbox.width ?? width,
                    _Hitbox.height ?? height
                    );
            set => _Hitbox = value;
        }

        public void PlayAnimation()
        {
            if (animation_name != null)
            {
                double frame_time = 1000f / animation_fps;
                if (!timer.IsRunning) timer.Start();

                if (timer.ElapsedMilliseconds >= frame_time)
                {
                    int frames_passed = (int)(timer.ElapsedMilliseconds / frame_time);
                    animation_index = (animation_index + frames_passed) % animations[animation_name].Length;
                    timer.Restart();
                }

                Output = animations[animation_name][animation_index];
            }
        }

        public bool Move(double x, double y)
        {
            double new_x = double_x + x;
            double new_y = double_y + y;

            foreach (Thing thing in CheckCollisions)
            {
                Rect hitbox = thing.Hitbox;
                bool newXOverlap = new_x < hitbox.x + hitbox.width && new_x + width > hitbox.x;
                bool newYOverlap = new_y < hitbox.y + hitbox.height && new_y + height > hitbox.y;
                bool oldXOverlap = double_x < hitbox.x + hitbox.width && double_x + width > hitbox.x;
                bool oldYOverlap = double_y < hitbox.y + hitbox.height && double_y + height > hitbox.y;

                if (newXOverlap && newYOverlap)
                {
                    if (!oldXOverlap) x = 0;
                    if (!oldYOverlap) y = 0;
                }
            }

            if (x == 0 && y == 0) return false;
            double_x += x;
            double_y += y;
            return true;
        }

    }
}
