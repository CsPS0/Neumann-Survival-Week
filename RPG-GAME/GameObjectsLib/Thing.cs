using GameLogicLib;
using RenderLib;
using System;
using System.Diagnostics;

namespace GameObjectsLib
{
    public class Thing
    {
        public string? name = null;

        public double double_x;
        public double double_y;

        public bool Hide = false;
        public bool IgnoreLayer = false;

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

        public int width { get => Output == null ? 0 : Output.width; }
        public int height { get => Output == null ? 0 : Output.height; }

        public Thing(string? name, double x, double y, bool IgnoreLayer = false,
            Rect? Hitbox = null)
        {
            this.name = name;
            double_x = x;
            double_y = y;
            this.IgnoreLayer = IgnoreLayer;
            Game.OnRender += () =>
            {
                if (Output != null && !Hide)
                    Render.PutFrame(this.x, this.y, Output, this.IgnoreLayer);
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
                if (animations.ContainsKey(value!))
                {
                    if (_animation_name != value)
                    {
                        _animation_name = value;
                        animation_index = 0;
                    }
                }
                else throw new Exception($"{value} animation not found. " +
                    $"Available animtions are: [{string.Join(", ", animations.Keys)}]");
            }
        }
        private Stopwatch timer = new();
        private int animation_index = 0;

        public Frame? Output;
        public Rect _Hitbox = new();
        public Rect Hitbox
        {
            get => 
                new(_Hitbox.x + x, _Hitbox.y + y, _Hitbox.width, _Hitbox.height);
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

        public void Move(double x, double y)
        {
            double_x += x;
            double_y += y;
        }

        public Action? IsCollidingWith(Thing thing)
        {
            Rect hitbox = thing.Hitbox;

            double l1 = double_x, r1 = l1 + width;
            double l2 = (int)hitbox.x!, r2 = l2 + (int)hitbox.width!;
            double t1 = double_y, b1 = t1 + height;
            double t2 = (int)hitbox.y!, b2 = t2 + (int)hitbox.height!;

            double distLeft = l1 - r2;
            double distRight = l2 - r1;
            double distTop = t1 - b2;
            double distBottom = t2 - b1;

            bool left = Math.Abs(distLeft) >= Math.Abs(distRight);
            double signedXDist = left ? distRight : distLeft;

            bool top = Math.Abs(distTop) >= Math.Abs(distBottom);
            double signedYDist = top ? distBottom : distTop;

            double? xAdjust = null, yAdjust = null;

            if (signedXDist < 0 && signedYDist < 0)
            {
                if (Math.Abs(signedXDist) < Math.Abs(signedYDist))
                {
                    xAdjust = left ? signedXDist : -signedXDist;
                }
                else if (Math.Abs(signedYDist) < Math.Abs(signedXDist))
                {
                    yAdjust = top ? signedYDist : -signedYDist;
                }
                else
                {
                    xAdjust = left ? signedXDist : -signedXDist;
                    yAdjust = top ? signedYDist : -signedYDist;
                }

                void ResolveCollision()
                {
                    if (xAdjust.HasValue) double_x += xAdjust.Value;
                    if (yAdjust.HasValue) double_y += yAdjust.Value;
                }

                return ResolveCollision;
            }
            return null;
        }

        public event Action<Thing, Action> OnCollision = null!;
    }
}
