# School map editor

A temporary page for fixing the Roblox school's map: what each room is, what it is called in the real school, and the
shape of rooms and doors. It runs in your browser from this folder; nothing is uploaded anywhere.

## Open it

Double-click `index.html` (it opens in your default browser). The floor-plan photos come from
`HORROR-GAME/docs/floor-plans/`, so keep this repository's folders as they are.

## Use it

- **Floors:** the buttons at the top left (Ground floor, 1st floor, 2nd floor).
- **Select / move** (V): click a room to edit it on the right. Drag inside it to move it, drag the yellow squares to
  resize it. Arrow keys nudge it by 0.1 m (Shift: 1 m). Delete removes it, Ctrl+D copies it.
- **For each room:**
  - **Game code**: the short label on the door sign (14, GT2, WC).
  - **Real name**: what it is called in the real school ("Kémia labor").
  - **What it is**: classroom, IT room, lab, office, toilet, gym and so on. This decides the furniture and the people
    in it. "Closed" rooms stay locked in the game.
  - **Notes**: anything else (what furniture it has, who uses it).
  - **Doors**: N/S/W/E wall, door or opening (no door panel), position along the wall (empty = middle).
- **Draw room** (R): drag a rectangle.
- **Place door** (D): click on a wall. Click the same door again to make it an opening, a third time to remove it.
- **Draw courtyard / solid** (S): blocks with no door (courtyards, roof terraces).
- **Real floor plan underneath:** already lined up with the game's rooms. Where a room does not sit on the plan,
  the game is wrong there: drag the room onto the plan. "Line up again" resets it if you moved it; "See-through" or
  Plan "(none)" hides it.
- **Checks:** warnings about overlapping rooms, rooms without doors, doors off their wall, duplicate codes.
- Mouse wheel zooms, right or middle drag pans, F fits the view, Ctrl+Z / Ctrl+Y undo and redo.

Your changes stay in this browser until you save. Use only real room names, never people's names (Roblox rules).

## Give it back

Click **Save map file…**: it downloads `school-map.json`. Put that file in this folder and tell Claude; it becomes
`src/shared/FloorData.luau` and the room types in `Rooms.luau`, and the furniture and people follow the room types.
**Open map file…** loads a saved file again to keep working on it.

## Tidy it up first

Hand-drawn rooms rarely line up: two rooms 10 cm apart get two walls with a sliver of floor between them, a door
opens into that sliver, a room sits across a corridor. `lune run tools/map-editor/tidy-map` (from `ROBLOX-GAME/`)
fixes the map file itself and prints every change:

- neighbours closer than 0.4 m (or overlapping by up to 1 m) get one shared wall;
- edges within 0.3 m along a corridor become one straight wall;
- rooms within 0.4 m of the building's outline are pulled onto it;
- the upper floors' stairs are put exactly over the ground floor's (the game builds them from the ground floor);
- empty space nobody can reach (between rooms, along the outer walls) becomes a closed room;
- named rooms without a door get one, and every door is moved to open onto a corridor joined to the stairs (or,
  when no wall reaches one, into a neighbouring room, like the head's office through the secretary's).

The first run keeps the untouched map as `school-map.before-tidy.json`. Lines starting with CHECK are left for you.
After it, open the map file in the editor again to see the result.

To see where the built school is cut off (green: reachable, red: cut off), from `ROBLOX-GAME/`:
`lune run tools/school-dryrun -- --obstacles out/obstacles.json` then
`python tools/map-editor/reach.py out/obstacles.json out` (needs numpy and Pillow; draws `out/reach-<floor>.png`).

## Into the game

`lune run tools/map-editor/import-map` (from `ROBLOX-GAME/`) reads `school-map.json` here and rewrites the generated
blocks of `src/shared/FloorData.luau` and `src/shared/Rooms.luau`, then prints what it changed or could not fix:

- The same door rules as the tidy-up (`door-rules.luau`), for maps that were not tidied: a door that opens into a
  wall or a sealed pocket moves to the nearest spot on a corridor; doors between two rooms are lined up so both walls
  have the gap; a room with no wall on a corridor opens into a neighbouring room.
- The ground floor's stairs are used on every floor (a staircase has to line up).
- Patrol points inside rooms or on walls, lights in courtyards and old corridor end walls inside rooms are left out.
- Rooms with no door are listed (they stay sealed).

Then rebuild the place (`rojo build default.project.json -o build/TheEmptySchool.rbxlx`) and run
`lune run tools/school-dryrun` (0 blocked doors) and `lune run tests/run`.

## For developers

`map-data.js` is generated from the game's current map: run `lune run tools/map-editor/export-map` from `ROBLOX-GAME/`.
Plan units are metres; the game builds the school 1.25 times larger.
