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
# Neumann Survival Week

## Magyar

A Neumann János Számítástechnikai Szakközépiskola iskolai projektje két változatban:

| Változat | Mappa | Motor | Állapot |
|---|---|---|---|
| **The Empty School (Az Üres Iskola)**, 3D horrorjáték | [`HORROR-GAME/`](HORROR-GAME/README.hu.md) | Godot 4.7 | Játszható demó |
| **IKT: Survival Week**, konzolos RPG | [`RPG-GAME/`](RPG-GAME) | C# / .NET 10 | Befejezetlen prototípus |

A projekt weboldala a [`docs/`](docs/index.html) mappában van, angol és magyar nyelven.

### The Empty School (Godot 3D horrorjáték)

Öt nap a Neumannban. Valami nincs rendben az épületben. Járj be az órákra, figyeld a tanárokat, és derítsd ki, ki az, mielőtt ő talál meg téged.

- Háromszintes iskola, kódból felépítve az alaprajzok alapján.
- Ötnapos kampány: három tanítási nap csengetéssel, órákkal és dolgozatokkal, utána két vadászat nap.
- Nyomozás: a nyomok nyolc kitalált tanár egyikére mutatnak. Nevezd meg a jót.
- Ördögűzés az aula oltáránál, négy egymásra épülő feladat után.
- Kóborló démon, amely éjjel ébred, meghallja a futást, és ha meglát, üldöz. A szekrények elrejtenek.
- Napi rutint követő tanárok, gondnok, a kutyája, a portás és egy diáksereg.
- Nyolc befejezés, eredmények és mentett beállítások.

Indítás: nyisd meg a `HORROR-GAME/project.godot` fájlt a Godot 4.7-ben, és nyomd meg az F5-öt. A teljes dokumentáció, az irányítás és a befejezések: [HORROR-GAME/README.hu.md](HORROR-GAME/README.hu.md).

### IKT: Survival Week (C# konzolos játék)

> **Állapot: befejezetlen prototípus.** A fejlesztés korai állapotban leállt. A játék elindul, és néhány jelenet játszható, de a tervezett küldetések, a pontozás és a napok rendszere sosem készült el.

#### 📖 Történet
- Új diák vagy a Neumannban, és 2 napot kell túlélned.
- ~~📅 A hétfő a legkönnyebb, míg a péntek a legnehezebb nap.~~
- 🤝 A játék során találkozol különböző NPC-kkel, akikkel interaktálhatsz, és különböző küldetéseket (questeket) kaphatsz tőlük.

#### 🕹️ A játékról
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

Az áthúzott pontok nem készültek el. A dialógusválaszok tárolva vannak, de semmi nem olvassa őket, a statisztikák számlálói pedig sosem változnak, így a név, a kor és a jó vagy rossz válaszok száma sem érhető el.

#### Ami működik

- Főmenü (Start, Settings, Statistics, Exit) ASCII logóval, beállítások (színek, tippek, teljes képernyő).
- Bevezető párbeszéd az `Assets/dialogs/intro.json` fájlból.
- Három jelenet: Kint, Aula és Tanterem.
- Öt NPC beszélgetés A, B, C válaszokkal, magyarul és németül.
- Kulccsal nyitható zárt tanterem ajtó.
- Leltár (TAB) és statisztika képernyő.

#### Ami nem működik

- Csak Windowson fut: a bemenetkezelés a `user32.dll`-t hívja, ezért Linuxon és macOS-en összeomlik.
- A napválasztó (Hétfő és Péntek között) figyelmen kívül hagyja a választást.
- A dialógusválaszoknak nincs hatásuk: nincsenek küldetések és nincs pontozás.
- Az osztályterem elrendezése részben a képernyőn kívülre esik, és átméretezéskor nem igazodik.

#### Indítás

Windows és a [.NET 10 SDK](https://dotnet.microsoft.com/download) szükséges.

```
cd RPG-GAME/RPG-GAME
dotnet run
```

Vagy indítsd el a `RPG-GAME/run.bat` fájlt.

#### 🗺️ Irányítás
- **W, A, S, D**: Mozgás a pályán, menüben választás (W/S: fel/le, A/D: váltás)
- **ENTER**: Menüben választás
- **ESC**: Vissza a menübe vagy kilépés
- **E**: Interakció NPC-kkel
- **TAB**: Leltár

#### Kód dokumentáció

A kód dokumentációja angolul az [English](#english) részben található.

## English

### The Empty School (Godot 3D horror game)

Five days at the Neumann school. Something in the building is not what it seems. Attend your lessons, watch the teachers, and find out who it is before it finds you.

- A three-floor model of the school, built in code from floor plan data.
- A five-day campaign: three school days with bells, lessons and quizzes, then two hunt days.
- Deduction: clues point to one of eight invented teachers. Name the right one.
- An exorcism quest at the Aula altar in four chained steps.
- A roaming demon that wakes at night, hears sprinting and chases on sight. Lockers hide you.
- Teachers with routines, a caretaker, his dog, the porter and a student crowd.
- Eight endings, achievements and saved settings.

Run it: open `HORROR-GAME/project.godot` in Godot 4.7 and press F5. Full documentation, controls and endings: [HORROR-GAME/README.md](HORROR-GAME/README.md).

### IKT: Survival Week (C# console game)

> **Status: unfinished prototype.** Development stopped at an early stage. The game starts and a few scenes are playable, but the planned quests, scoring and day system were never built.

The original plan: you are a new student at the Neumann school and you have to survive the week. You meet NPCs, get quests and make choices that change the outcome. The game draws everything with ASCII art in the console.

#### What works

- Main menu (Start, Settings, Statistics, Exit) with an ASCII logo.
- Settings: UI colours, hints, fullscreen.
- Intro dialog loaded from `Assets/dialogs/intro.json`.
- Three scenes: Outside, Aula and Classroom.
- Five NPC conversations with A, B, C choices, in Hungarian and German.
- A locked classroom door that opens with the key the player starts with.
- Inventory screen (TAB) and Statistics screen.

#### What is not finished

- **Windows only.** Input uses `user32.dll`, so the game crashes on Linux and macOS.
- The day picker (Monday to Friday) ignores the choice. Every day starts in the same scene.
- Dialog choices are stored but nothing reads them. There are no quests, no scoring and no consequences.
- The statistics counters never change. Name, age and right or wrong answer counts were planned but never added.
- Planned random events, boss fights and sound effects were never added.
- The classroom layout is off-screen in part and does not re-centre when the window resizes.

#### Run it

Requires Windows and the [.NET 10 SDK](https://dotnet.microsoft.com/download).

```
cd RPG-GAME/RPG-GAME
dotnet run
```

Or start `RPG-GAME/run.bat`.

#### Controls

- **W, A, S, D**: move, menu selection (W/S: up/down, A/D: switch)
- **ENTER**: select in a menu
- **ESC**: back to the menu or exit
- **E**: talk to an NPC
- **TAB**: inventory

#### Code documentation
This project is divided into several libraries, each with a specific responsibility.

##### `RPG-GAME`
This is the main executable project for the game.

*   **`Program.cs`**: This file is the main entry point of the application. It initializes the game, creates the scenes, menus, and the player object. It also contains the main game logic for handling scene transitions, player updates, and menu navigation.

##### `AssetHandleLib`
An empty stub. No other project references it.

##### `AssetsLib`
This library provides utilities for reading and writing asset files.

*   **`Asset.cs`**: This class provides static methods for reading and writing text files from the assets folder.

##### `DataTypesLib`
This library contains custom data structures used in the game.

*   **`TreeNode.cs`**: A generic tree data structure used to represent conversation trees for dialogs.

##### `GameLogicLib`
This library forms the core of the game engine.

*   **`Game.cs`**: This class manages the main game loop. It runs the rendering and update logic in two separate threads to ensure a stable frame rate and responsive input. It uses events (`OnStart`, `OnStop`, `OnUpdate`, `OnRender`, `OnResized`) to allow the main application to hook into the game's lifecycle.

##### `GameObjectsLib`
This library defines the various objects that make up the game world.

*   **`Thing.cs`**: This is the base class for all game objects (e.g., player, NPCs, items). It manages the object's position, size, current animation frame (`Output`), and hitbox. It also includes logic for animation playback and collision detection.
*   **`Scene.cs`**: This class manages a collection of `Thing` objects that are currently active in the game. It handles showing and hiding objects when the scene changes.
*   **`Menu.cs`**: This class represents a menu with a list of options.
*   **`Dialog.cs`**: This class manages the flow of conversations. It uses a `TreeNode<string>` to represent the dialog tree.

##### `InputLib`
This library is responsible for handling user input.

*   **`Input.cs`**: This class is a static utility class that provides methods to check the state of keyboard keys (`IsPressed`, `IsDown`). It uses P/Invoke to call the Windows `GetAsyncKeyState` function, so it is specific to the Windows platform.

##### `RenderLib`
This is a sophisticated console rendering engine.

*   **`Pixel.cs`**: Represents a single character on the screen, with foreground and background colors, a character, and a layer for depth.
*   **`Frame.cs`**: Represents a 2D grid of `Pixel`s. It's used to store sprites, UI elements, and the entire screen buffer.
*   **`Render.cs`**: The core rendering class. It uses a double-buffering technique (`current` and `next` frames) to render only the changed pixels to the console, which prevents flickering and improves performance. It uses ANSI escape codes to set colors and text styles.
*   **`Draw.cs`**: A helper class with static methods for creating common UI elements like text, boxes, and text boxes as `Frame` objects.

### Website (`docs`)

A static page with English and Hungarian text. Open `docs/index.html` in a browser.

*   **`index.html`**: The page, with sections for both games.
*   **`JS/script.js`**: The mobile menu toggle.
*   **`JS/translations.js`**: The English and Hungarian texts.

## 🏗️ Csapattagok / Team

A fejlesztésért felelős csapat / The development team:

- **👨‍💻 Fehér Marcell**
- **👨‍💻 Polyák Dávid**
- **👨‍💻 Solti Csongor Péter**

## 🔗 Dokumentumok / Documents

* [Licensz / License](LICENSE)
