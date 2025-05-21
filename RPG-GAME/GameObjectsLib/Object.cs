using System.Diagnostics;
using RenderLib;

namespace GameObjectsLib
{
    public class Object
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

        public int w = 0;
        public int h = 0;

        public Object(double x, double y)
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

                Frame frame = animations[animation_name][animation_index];
                w = frame.width;
                h = frame.height;
                Render.PutFrame(int_x, int_y, frame);
            } else
            {
                w = 0;
                h = 0;
            }
        }

        public bool IsColliding(GameObjectsLib.Object obj)
        {
            return !(this.int_x + this.w < obj.int_x ||
            this.int_x > obj.int_x + obj.w ||
            this.int_y + this.h < obj.int_y ||
            this.int_y > obj.int_y + obj.h);
        }

        public bool IsColliding(int x, int y, int w, int h)
        {
            return !(this.int_x + this.w - 1 < x ||
                     this.int_x > x + w - 1 ||
                     this.int_y + this.h - 1 < y ||
                     this.int_y > y + h - 1);
        }

    }
}
