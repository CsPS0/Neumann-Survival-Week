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

A school project from the Neumann János school. The repository holds two separate games and the project website. The games share a theme and a school setting. They share no code and no assets.

| Part | Folder | Stack | Status | Documentation |
|---|---|---|---|---|
| The Empty School, a first-person 3D horror game | [`HORROR-GAME/`](HORROR-GAME) | Godot 4.7, GDScript | Playable demo, the main focus | [HORROR-GAME/README.md](HORROR-GAME/README.md) |
| IKT: Survival Week, a console RPG | [`RPG-GAME/`](RPG-GAME) | C# on .NET 10 | Unfinished prototype, Windows only | [RPG-GAME/README.md](RPG-GAME/README.md) |
| Project website | [`docs/`](docs) | Static HTML, CSS, JS | English and Hungarian text | This file, section Website |

## How the project works

- Both games came from one idea: you are a student at the Neumann school and you must survive a week. The team first built the console RPG. The horror game replaced it as the main work.
- The horror game builds the whole school at runtime from floor plan data. It needs no model files and no recorded audio. Textures, furniture, characters and sound are made in code, apart from a few photo textures.
- The horror game plays alone or in co-op. Co-op runs through the game itself (a player hosts), through a headless dedicated server, or through a virtual machine that hosts several rooms on a school PC.
- The two games live in separate folders with their own build tools. A change in one folder never needs a change in the other.

## Where to start

- To play the horror game: read [HORROR-GAME/README.md](HORROR-GAME/README.md), section How to run. Open `HORROR-GAME/project.godot` in Godot 4.7 and press F5.
- To host a classroom session on a school PC: read the co-op chapter in [HORROR-GAME/README.md](HORROR-GAME/README.md) and the step by step guide in [HORROR-GAME/server/vm/GUIDE.md](HORROR-GAME/server/vm/GUIDE.md).
- To build an executable, APK or Quest build: read [HORROR-GAME/docs/BUILD-GUIDE.md](HORROR-GAME/docs/BUILD-GUIDE.md).
- To run the console RPG: read [RPG-GAME/README.md](RPG-GAME/README.md). It needs Windows and the .NET 10 SDK.

## Repository layout

| Path | Content |
|---|---|
| `HORROR-GAME/` | The Godot project: `scenes/`, `scripts/`, `textures/`, `tools/` (build scripts), `server/` (dedicated server and VM), `docs/` (build guide, multiplayer design note). |
| `RPG-GAME/` | The C# solution `RPG-GAME.sln` with the game and its libraries. |
| `docs/` | The static website. |
| `.github/` | The release workflow and the CI export presets for the horror game. |
| `LICENSE` | The licence. |

## Website

The site in `docs/` is a static page with English and Hungarian text. Open `docs/index.html` in a browser. No build step is needed.

- `docs/index.html`: the page, with a section for each game.
- `docs/JS/script.js`: the mobile menu toggle.
- `docs/JS/translations.js`: the English and Hungarian texts.
- `docs/CSS/`: the styles.

## Rules for contributors

- Keep the two games apart. A change for one game must not touch the other.
- The roster of real staff names is local only. `HORROR-GAME/scripts/staff.gd` stays gitignored and the repository holds a placeholder roster with invented names.
- Real student names and photos stay local too. The repository holds invented names and generated faces.
- Work on a branch and open a pull request. Merge with squash and delete the branch after the merge.

## Team

- Fehér Marcell
- Polyák Dávid
- Solti Csongor Péter

## Documents

- [License](LICENSE)
