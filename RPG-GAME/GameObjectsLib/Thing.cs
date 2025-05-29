using System.Diagnostics;
using RenderLib;
using GameObjectsLib;
using GameLogicLib;
using System.Numerics;

namespace GameObjectsLib
{
    public class Thing
    {
        public double double_x;
        public double double_y;

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

        public List<Thing> Collisions = new();

        public int width { get => Output == null ? 0 : Output.width; }
        public int height { get => Output == null ? 0 : Output.height; }

        public Thing(double x, double y)
        {
            double_x = x;
            double_y = y;
            Game.OnRender += () =>
            {
                if (Output != null) Render.PutFrame(this.x, this.y, Output);
            };
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

        public void Move(double x, double y)
        {
            double new_x = x + double_x;
            double new_y = y + double_y;
            for (int i = 0, l = Collisions.Count; i < l; i++)
            {
                Thing thing = Collisions[i];
                if (
                    new_x < thing.x + thing.width && new_x + width > thing.x &&
                    new_y < thing.y + thing.height && new_y + height > thing.y
                    ) return;
            }
            double_x += x;
            double_y += y;
        }
    }
}
