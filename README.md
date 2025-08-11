```
                    ┌─────────────────────────────────────────────────────┐
                    │ ┌─────┐ ┌─────┐ ┌─────┬─────┬─────┐ ┌─────┐ ┌─────┐ │
                    │ │     │ │     │ │     │     │     │ │     │ │     │ │
                    │ └─────┘ └─────┘ └─────┴─────┴─────┘ └─────┘ └─────┘ │
┌───────────────────┤ ┌─────┐ ┌─────┐ ┌─────┬─────┬─────┐ ┌─────┐ ┌─────┐ ├───────────────────┐
│                   │ │     │ │     │ │     │     │     │ │     │ │     │ │                   │
│ ┌─────┐ ┌─────┐   │ └─────┘ └─────┘ └─────┴─────┴─────┘ └─────┘ └─────┘ │  ┌─────┐ ┌─────┐  │
│ │     │ │     │   │  ┌───────────────────────────────────────────────┐  │  │     │ │     │  │
│ │     │ │     │   │  │NEUMANN JÁNOS SZÁMITÁSTECHNIKAI SZAKKÖZÉPISKOLA│  │  │     │ │     │  │
│ │     │ │     │   │  └─────────────┬───╥───╥───╥───╥───┬─────────────┘  │  │     │ │     │  │
│ │     │ │     │   │┌─────┐ ┌─────┐ │   ║   ║   ║   ║   │ ┌─────┐ ┌─────┐│  │     │ │     │  │
│ │     │ │     │   ││     │ │     │ │ --║---║---║---║-- │ │     │ │     ││  │     │ │     │  │
│ └─────┘ └─────┘   │└─────┘ └─────┘ │   ║   ║   ║   ║   │ └─────┘ └─────┘│  └─────┘ └─────┘  │
│                   │              _/┴───╨───╨───╨───╨───┴\_              │                   │
│                   │            _/─────────────────────────\_            │                   │
│                   │           /─────────────────────────────\           │                   │
```
# 🎮 NJSZKI IKT RPG Game - IKT: Survival Week

## 📖 Story
- Új diák vagy a Neumannban, és 2 napot kell túlélned.
- ~~📅 A hétfő a legkönnyebb, míg a péntek a legnehezebb nap.~~
- 🤝 A játék során találkozol különböző [NPC](#npc-k)-kkel, akikkel interaktálhatsz, és különböző küldetéseket (questeket) kaphatsz tőlük.

## 🕹️ A játékról
- ✅ A játék különböző küldetésekre épül, ahol a játékos választhat a lehetőségek között.
- ~~🎲 Véletlenszerű események (*random eventek*) teszik izgalmassá a játékmenetet.~~
- 🕵️ Bizonyos lépésekre reagáló *easter egg*-ek is lesznek elrejtve.
- ~~🏆 Minden nap végén egy *boss fight* vár a játékosra.~~
- 🔊 Animációk ~~és hangeffektek~~ fokozzák az élményt.
- 🎛️ Részletes főmenü és almenük a könnyebb navigációhoz.
- 💾 **A játékos válaszai eltárolásra kerülnek a játék bezárásáig**:
  - 📝 Név
  - 🎂 Kor
  - ✅ Jó válaszok száma
  - ❌ Rossz válaszok száma

## 🗺️ Irányítás
- **W, A, S, D**: Mozgás a pályán, menüben választás (W/S: fel/le, A/D: váltás)
- **ENTER**: Menüben választás
- **ESC**: Vissza a menübe vagy kilépés
- **E**: Interakció NPC-kkel
- **TAB**: Inventory (későbbi verzió)
- **ENTER**: Statisztikák (későbbi verzió)

## 🧑‍💻 Kód dokumentáció
This project is divided into several libraries, each with a specific responsibility.

### `RPG-GAME`
This is the main executable project for the game.

*   **`Program.cs`**: This file is the main entry point of the application. It initializes the game, creates the scenes, menus, and the player object. It also contains the main game logic for handling scene transitions, player updates, and menu navigation.

### `docs`
This folder contains the documentation for the project.

*   **`index.html`**: The main page of the documentation.
*   **`CSS/style.css`**: The stylesheet for the documentation.
*   **`JS/script.js`**: The script for the documentation.
*   **`JS/translations.js`**: The translations for the documentation.

### `AssetHandleLib`
This library is responsible for handling game assets.

*   **`AssetHandler.cs`**: This class is used to manage game assets. It contains the path to the assets.

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

## 🏗️ Csapattagok
A fejlesztésért felelős csapat:

- **👨‍💻 Fehér Marcell**
- **👨‍💻 Polyák Dávid**
- **👨‍💻 Solti Csongor Péter**

## 🔗 Dokumentumok
* [Licensz](LICENSE)
* [Dokumentáció](DOCS/Dokumentacio.pdf)

---

<div align="center">
    <a href="#top" style="color: white; text-decoration: none;">🔝 Vissza a tetejére 🔝</a>
</div>
