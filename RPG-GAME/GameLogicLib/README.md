# Game logic documentation

# Game in Game.cs

A class that manages the main game logic.
`Render` and `Update` is in 2 separate threads so the fps can be stabil and the collision 
detections and movements more precice.

attributes:
-`int? TargetFps`: A variable that hold the target fps for the rendering.
-`int? _Fps`: An fps that tracks the fps of the rendering.
-`int? Fps`: Manages `TargetFps` and `_Fps`.
-`bool RUN`: A state that keeps `Render` and `Update` running.
-`Thread TRender`: Thread of `Render`.
-`Thread TUpdate`: Thread of `Update`.
-`Action OnRender`: Render event, being fired before the actual rendering.
-`Action<double> OnUpdate`: Update event, only thing in `Update` aside of delta measurment.
-`Action OnStart`: Start event, being fired after `RenderLib.Render.init()` but before 
`TRender` and `TUpdate`
-`Action OnStop`: Stop event, being fired after `RenderLib.Render.ResetStyle()`. The program 
doesn't wait for `TRender` or `TUpdate` to finish.

methods:
-`void Start(int w, int h)`: Starts `TRender` and `TUpdate`, initializes `RenderLib.Render` 
and invokes the `OnStart` event.
-`void Stop()`: Stops `Render` and `Update`, resets the colors and styling and invokes the
`OnStop` event.
-`void Render()`: Manages the rendering through `RenderLib.Render`, keeps the fps at the
target and invokes `OnRender` event.
-`void Update()`: Keeps track of the delta time and invokes the `OnUpdate` event with passing
`delta` to the listeners.