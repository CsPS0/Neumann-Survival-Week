# IKT: Survival Week (RPG-GAME)

> **Status: unfinished prototype.** Development stopped at an early stage. The game starts and a few scenes are playable, but the planned quests, scoring and day system were never built.

The original plan: you are a new student at the Neumann school and you have to survive the week. You meet NPCs, get quests and make choices that change the outcome. The game draws everything with ASCII art in the console.

## What works

- Main menu (Start, Settings, Statistics, Exit) with an ASCII logo.
- Settings: UI colours, hints, fullscreen.
- Intro dialog loaded from `Assets/dialogs/intro.json`.
- Three scenes: Outside, Aula and Classroom.
- Five NPC conversations with A, B, C choices, in Hungarian and German.
- A locked classroom door that opens with the key the player starts with.
- Inventory screen (TAB) and Statistics screen.

## What is not finished

- **Windows only.** Input uses `user32.dll`, so the game crashes on Linux and macOS.
- The day picker (Monday to Friday) ignores the choice. Every day starts in the same scene.
- Dialog choices are stored but nothing reads them. There are no quests, no scoring and no consequences.
- The statistics counters never change. Name, age and right or wrong answer counts were planned but never added.
- Planned random events, boss fights and sound effects were never added.
- The classroom layout is off-screen in part and does not re-centre when the window resizes.

## Run it

Requires Windows and the [.NET 10 SDK](https://dotnet.microsoft.com/download).

```
cd RPG-GAME/RPG-GAME
dotnet run
```

Or start `RPG-GAME/run.bat`.

## Controls

- **W, A, S, D**: move, menu selection (W/S: up/down, A/D: switch)
- **ENTER**: select in a menu
- **ESC**: back to the menu or exit
- **E**: talk to an NPC
- **TAB**: inventory

## Code documentation

This project is divided into several libraries, each with a specific responsibility.

### `RPG-GAME`
This is the main executable project for the game.

*   **`Program.cs`**: This file is the main entry point of the application. It initializes the game, creates the scenes, menus, and the player object. It also contains the main game logic for handling scene transitions, player updates, and menu navigation.

### `AssetHandleLib`
An empty stub. No other project references it.

### `AssetsLib`
This library provides utilities for reading and writing asset files.

*   **`Asset.cs`**: This class provides static methods for reading and writing text files from the assets folder.

### `DataTypesLib`
This library contains custom data structures used in the game.

*   **`TreeNode.cs`**: A generic tree data structure used to represent conversation trees for dialogs.

### `GameLogicLib`
This library forms the core of the game engine.

*   **`Game.cs`**: This class manages the main game loop. It runs the rendering and update logic in two separate threads to ensure a stable frame rate and responsive input. It uses events (`OnStart`, `OnStop`, `OnUpdate`, `OnRender`, `OnResized`) to allow the main application to hook into the game's lifecycle.

### `GameObjectsLib`
This library defines the various objects that make up the game world.

*   **`Thing.cs`**: This is the base class for all game objects (e.g., player, NPCs, items). It manages the object's position, size, current animation frame (`Output`), and hitbox. It also includes logic for animation playback and collision detection.
*   **`Scene.cs`**: This class manages a collection of `Thing` objects that are currently active in the game. It handles showing and hiding objects when the scene changes.
*   **`Menu.cs`**: This class represents a menu with a list of options.
*   **`Dialog.cs`**: This class manages the flow of conversations. It uses a `TreeNode<string>` to represent the dialog tree.

### `InputLib`
This library is responsible for handling user input.

*   **`Input.cs`**: This class is a static utility class that provides methods to check the state of keyboard keys (`IsPressed`, `IsDown`). It uses P/Invoke to call the Windows `GetAsyncKeyState` function, so it is specific to the Windows platform.

### `RenderLib`
This is a sophisticated console rendering engine.

*   **`Pixel.cs`**: Represents a single character on the screen, with foreground and background colors, a character, and a layer for depth.
*   **`Frame.cs`**: Represents a 2D grid of `Pixel`s. It's used to store sprites, UI elements, and the entire screen buffer.
*   **`Render.cs`**: The core rendering class. It uses a double-buffering technique (`current` and `next` frames) to render only the changed pixels to the console, which prevents flickering and improves performance. It uses ANSI escape codes to set colors and text styles.
*   **`Draw.cs`**: A helper class with static methods for creating common UI elements like text, boxes, and text boxes as `Frame` objects.

## Assets

- `Assets/dialogs/intro.json`: the intro dialog, loaded at runtime.
- `Assets/stickman/`: Python files (`walk.py`, `run.py`) that hold the stickman ASCII art frames.
- `Assets/asciiart.py`: ASCII art character notes.

## Build

Open `RPG-GAME.sln` in Visual Studio or Rider, or run `dotnet build RPG-GAME.sln` from this folder.
