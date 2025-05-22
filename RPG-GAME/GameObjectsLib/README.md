# Game assets documentation

# Objetc in Objects.c

A class that implements a game object that holds the position and the state of animtion 
of the object

attributes:
- `double x`: precise x position of the object
- `double y`: precise y position of the object
- `int int_x`: rounded integer version of `x`
- `int int_y`: rounded integer version of `y`
- `int animation_fps`: determines how fast the animtation frame should be iterated
- `Dictionary<string, Frame[]> animations`: dictionary for storing the animations with
identifier names
- `string animation_name`: the name of the animation that should be played
- `Stopwatch timer`: timer for the animation frame iteration
- `int animation_index`: keep track of the animation frame index

methods:
- `void PlayAnimation()`: automaticly iterates over the animation frames and renders it
to the console with `Render.PutFrame()`

# Comment: not sure how Maps.cs and Sprites.cs will work out