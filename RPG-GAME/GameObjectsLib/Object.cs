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

        public Object(double x, double y)
        {
            this.x = x;
            this.y = y;
        }

        public int animation_fps = 24;
        public Dictionary<string, Frame[]> animations = new();

        public string animation_name;
        private Stopwatch timer = new();
        private int animation_index = 0;

        public void PlayAnimation()
        {
            if (animation_name == null) return;

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

            Render.PutFrame(int_x, int_y, animations[animation_name][animation_index]);
        }
    }
}
