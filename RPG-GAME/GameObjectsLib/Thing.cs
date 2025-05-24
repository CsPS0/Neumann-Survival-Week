using System.Diagnostics;
using RenderLib;

namespace GameObjectsLib
{
    public class Thing
    {
        public double x;
        public double y;

        public int int_x
        {
            get => (int)Math.Round(x);
            set => x = value;
        }
        public int int_y
        {
            get => (int)(Math.Round(y));
            set => y = value;
        }

        public int width { get => Output == null ? 0 : Output.width; }
        public int height { get => Output == null ? 0 : Output.height; }

        public Thing(double x, double y)
        {
            this.x = x;
            this.y = y;
        }

        public int animation_fps = 24;
        public Dictionary<string, Frame[]> animations = new();

        private string? _animation_name;
        public string? animation_name 
        { 
            get => _animation_name;
            set
            {
                if (_animation_name != value)
                {
                    _animation_name = value;
                    animation_index = 0;
                }
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

                if (animations.ContainsKey(animation_name))
                {
                    if (!timer.IsRunning) timer.Start();

                    if (timer.ElapsedMilliseconds >= frame_time)
                    {
                        int frames_passed = (int)(timer.ElapsedMilliseconds / frame_time);
                        animation_index = (animation_index + frames_passed) % animations[animation_name].Length;
                        timer.Restart();
                    }
                }
                else throw new Exception($"{animation_name} animation not found.");

                Output = animations[animation_name][animation_index];
            }
        }

        public bool IsColliding(Thing obj)
        {
            return !(this.int_x + this.width < obj.int_x ||
            this.int_x > obj.int_x + obj.width ||
            this.int_y + this.height < obj.int_y ||
            this.int_y > obj.int_y + obj.height);
        }

        public bool IsColliding(int x, int y, int w, int h)
        {
            return !(this.int_x + this.width - 1 < x ||
            this.int_x > x + w - 1 ||
            this.int_y + this.height - 1 < y ||
            this.int_y > y + h - 1);
        }
    }
}
