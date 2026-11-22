# Hands, phone, backpack, entity and school look: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** visible animated hands with the phone (its flashlight is the only light; no torch), a GTA-style phone, a per-player hand/pockets/backpack inventory,
a gory entity that wears the possessed teacher's mark, and the Godot school look, in the Roblox port.

**Architecture:** pure rules in `src/shared` (Lune-tested), server services own inventories and bags, client modules
draw viewmodels, phone and panels. The story (`src/server/Campaign`) switches from the team item list to per-player
inventories.

**Tech stack:** Luau, Rojo 7.7.1, Lune 0.11.1 tests, Roblox Studio MCP for play tests.

**Spec:** `docs/2026-11-20-hands-bag-entity-design.md` (read the "Calls made after the builder check" section).

## Global constraints

- Shared modules: `--!strict`, no Roblox globals, no `require` (Lune loads them).
- A statement starting with `(` after a call line is a compile error: use a local or a leading `;`.
- Gore within the Moderate (13+) label: no pools of blood, no gushing.
- Nothing uploaded to Roblox; built-in materials, parts, `SurfaceGui` text and the default particle texture only.
- 60 FPS in Studio on the user's PC; school parts target 3,000 (lamp grilles go first).
- Rebuild `build/TheEmptySchool.rbxlx` after every change (user rule); no commits unless asked; no AI attribution.
- Keys: F flashlight, T camera flash, P phone, H one/two hands, Tab carrying panel, B drop/put on bag, U use battery, arrows/Space/Backspace on the
  one-hand phone. Taken already: E, G, M, R (altar deal), C/Ctrl, Shift, Space (jump), 1-9 (votes, quiz).

## Review focus

1. Arrow keys and Space while the one-hand phone is up must not move or jump the character (bind above default).
2. A player going out or leaving with the only fuse/vial/bell: the item must end up in a reachable bag or on the floor.
3. Two players with the same bag open moving the same item: the server must never duplicate or lose it.
4. A clue picked up with full pockets and no bag room still counts for the team.
5. The viewmodel must not show while hidden in a locker, spectating, or for the Hide and Seek player seeker.

---

### Task 1: Inventory rules

**Files:** Create `src/shared/Inventory.luau`, `tests/inventory.spec.luau`; register the spec in `tests/run.luau`.

**Interfaces (produces):**
- `export type Slot = "hand" | "pocketL" | "pocketR" | "bag"`; `export type Item = { id: string, texts: { string }? }`
- `export type Inv = { hand: Item?, pocketL: Item?, pocketR: Item?, bag: { Item }, bagWorn: boolean }`
- `Inventory.ITEMS: { [string]: { name: string, small: boolean, kg: number } }` with key 0.1 small, vial 1.0 small,
  salt 1.2 big, fuse 0.8 big, bell 1.5 big, papers 0.1 small, battery 0.2 small. `BAG_SLOTS = 8`.
- `Inventory.new(): Inv`
- `Inventory.add(inv, item: Item): Slot?` (hand, then pocket if small, then bag if worn and not full; `papers` merges
  into an existing papers item anywhere first, returning its slot)
- `Inventory.reachable(inv, id): Slot?` (hand or pockets only); `Inventory.take(inv, id): Item?`
- `Inventory.move(from: Inv, fromSlot: Slot, fromIndex: number?, to: Inv, toSlot: Slot, toIndex: number?): boolean`
  (moves or swaps; refuses a big item into a pocket; papers onto papers merge; bag index 1..8)
- `Inventory.speed(inv): number` (1 when the bag is off; else `math.max(0.7, 1 - 0.03 * (3 + bag kg))`)
- `Inventory.all(inv): { Item }` (for the out spill)

- [ ] Write the tests: add order (hand, pocket, bag), big item skips pockets, bag full returns nil, worn=false keeps
  the bag closed to `add`, reachable ignores the bag, take removes, move/swap and the pocket refusal, papers merge
  (texts concatenated, one slot), speed values (empty bag 0.91, cap 0.7, off = 1).
- [ ] `lune run tests/run` fails; implement; passes.

### Task 2: Inventory server and bags

**Files:** Create `src/server/Inventories.luau`; modify `src/shared/Remotes.luau` (add `Inventory`, `BagAction`,
`BagView`), `src/server/Main.server.luau` (init), `src/client/MovementController.luau` (multiply the non-locked
target speed by the `CarrySpeed` player attribute, default 1).

**Interfaces (produces):**
- `Inventories.init(remotes)`, `Inventories.enable(folder: Instance)` / `Inventories.disable()` (story start/stop)
- `Inventories.of(player): Inventory.Inv`, `Inventories.give(player, item): boolean` (banner "No room..." on false),
  `Inventories.reachable(player, id)`, `Inventories.take(player, id): Item?`
- `Inventories.spill(player)` (out or leaving: hand and pockets into the bag, the rest as pickups, worn bag dropped)
- `Inventories.dropItem(item, at: Vector3)` (a pickup part with "Take" that calls `give`)
- `BagAction` ops: `drop`, `wear` (bagOwnerId), `open` (bagOwnerId), `close`, `move` {bagOwnerId?, from, fromIndex,
  to, toIndex}, `floor` {slot, index}, `use` {slot}. Server checks: alive, within 12 studs of the bag model, the bag on
  the ground for `open`/`move`, owner rule for `wear`.
- `Inventory` remote to the owner: `{ inv = Inv, bagDropped = boolean }`; `BagView` to every viewer of a bag:
  `{ owner, ownerName, bag = { Item } }` or nil when closed.
- Dropped bag model in the story folder, prompts E "Open bag" (`For` living) and B "Put on" (KeyboardKeyCode B).
- `CarrySpeed` player attribute from `Inventory.speed`.

- [ ] Implement; compile-check; Studio: drop, open, move, put on, speed change (Task 9 runs the full checks).

### Task 3: Hotbar, bag panel, carrying panel

**Files:** Create `src/client/BagUi.luau`; modify `src/client/Main.client.luau`.

- Hotbar (story only, bottom centre above the meters): Hand, L, R, BAG (worn/dropped, kg), item name pop.
- Bag panel on `BagView`: bag grid 8 + your hand/pockets, click-to-move, Read (papers text list), Use (battery),
  Drop on the floor, Close; mouse freed with `StoryUi.freeMouseWhile`.
- Tab: carrying panel (own hand/pockets, worn bag greyed), Read for reachable papers.
- B: `BagAction drop` when worn (the "Put on" prompt handles wearing). U: `use` battery from hand/pocket.

- [ ] Implement; compile-check.

### Task 4: Story uses inventories

**Files:** modify `src/server/Campaign/Quest.luau`, `CampaignMode.luau`, `Clues.luau`, `Pickups.luau`.

- `CampaignMode.start`: `Inventories.enable(folder)`; `stop`: `disable`. `markOut` and `playerLeft`:
  `Inventories.spill(player)` before despawn.
- Quest: porter `give` key; red door `reachable("key")`; salt/fuse pickups `give` (the part stays on no room); fuse
  box `take("fuse")`; cabinet `give(vial)` (no room = message, retry); notes: `give(papers {texts = {code text}})`, no
  room = stays, banner only "<name> found a note"; safe `give(bell)`; keypad still needs a player at the safe;
  altar `take` salt/vial/bell from the presser. Remove `self.items`, `itemList`; altar progress stays team-wide.
- Clues: on read, the text always joins the team list; `give(papers)` and remove the paper only if it fit, else the
  paper stays ("No room for the paper; the clue is on your phone").
- Batteries: 3 per run in free clue rooms (`Pickups`), `give(battery)`; `use` adds 35 to `Battery` (cap max).
- Snapshot: drop `items`; add `altar = {salt, vial, bell}` for the Tasks app.

- [ ] Implement; compile-check; Studio rerun of the Easy night chain via the existing MCP script, adapted.

### Task 5: Hands and phone flashlight viewmodel

**Files:** Create `src/client/Viewmodel.luau`; modify `src/client/Main.client.luau`.

**Interfaces (produces):** `Viewmodel.init(remotes)`, `Viewmodel.setPhone(state: "down" | "one" | "two")`,
`Viewmodel.phonePart(): BasePart` (the screen face for the phone `SurfaceGui`), `Viewmodel.setHeld(id: string?)`.

- Camera-local model, bound with `BindToRenderStep` at `Camera.Value + 2`: the phone in the left hand (lowered:
  back forward, lens on), the held item in the right hand; sway spring (shared `Spring`), bob from
  `MovementController.speed`, sprint/crouch offsets, thumb click on `TorchOn` change, camera-flash lift on T (listen
  to the `FlashReadyAt` attribute jump), raise/lower for the phone states, wall pull-back ray, visibility rules (spec
  section 1 and review focus 5).
- Server `Torch.luau`: parent the `SpotLight` to the character's `LeftHand` (fallback head). Rename player-facing
  text: the meter "Phone battery", the menu/README "flashlight".
- Held item: a small coloured part in the right hand from the `Inventory` remote's hand item, hidden in two-hand mode.

- [ ] Implement; Studio screenshot of the hands (lobby, flashlight on, phone raised).

### Task 6: Phone

**Files:** Create `src/client/Phone.luau`; modify `src/client/StoryHud.luau` (remove the phone panel and the P
binding, keep the objective and the Easy marker), `src/client/Main.client.luau`.

- One UI tree (home grid, Map, Tasks, Timetable, Clues, Team) reparented between a `SurfaceGui` (Adornee =
  `Viewmodel.phonePart()`) and a full-screen `ScreenGui`.
- P raise/lower, H one/two hands; one hand: arrows/Space/Backspace bound with
  `ContextActionService:BindActionAtPriority(..., Enum.ContextActionPriority.High.Value, ...)`, Sink; two hands:
  `Modal`, mouse; the flashlight keeps its state; status bar with clock and phone battery.
- Map: rooms from `FloorData` per floor as frames coloured by `Rooms` type, Left/Right floor, own marker outside the
  story or on Easy. Outside the story: Map only.
- Data from `CampaignState` (Tasks, Timetable, Clues, Team).

- [ ] Implement; Studio: arrows do not move the character, Space does not jump, Backspace returns home.

### Task 7: Entity look, marks, drips and glimpses

**Files:** modify `src/server/EntityModel.luau`, `src/shared/CampaignData.luau` (add `LOOKS` jacket/trouser colours,
moved from `Teachers.luau`, and `ENTITY_MARKS`), `src/server/Campaign/Teachers.luau` (use `LOOKS`),
`src/server/Campaign/CampaignMode.luau`; create `src/server/Campaign/Glimpses.luau`; test in
`tests/campaign.spec.luau` (LOOKS and ENTITY_MARKS cover all 8 suspects).

**Interfaces:** `EntityModel.build(look: { jacket: Color3, trousers: Color3, mark: string }?): Model`,
`EntityModel.attachTo(character, look?)`, `EntityModel.setTrail(model, on: boolean)` (drips + floor spots, story
only), `Glimpses.new(run): { destroy }` with `run = { folder, alive, look, minutesNow: () -> number, timeScale }`.

- Gore per spec section 4; marks per culprit; drips/trail only when `setTrail(true)` (the story night).
- Glimpses at two random game times in 14:00-17:30; server frozen model; sting; gone after 2.5 s or within 8 m.

- [ ] Tests first (data coverage), implement, Studio screenshot of the entity close up.

### Task 8: School look

**Files:** modify `src/server/SchoolBuilder.luau` (`STYLE`, walls lower facing + trim, ceilings, doors handle and
sign, boards in `normal` rooms, lamp tubes and grille), `src/server/Doors.luau` (handle and sign parts on the panel).

- [ ] Implement; `lune run tools/school-dryrun` still passes its door checks (no new blocked doors); part count
  printed by the server stays near 3,000; Studio screenshots of a corridor and a classroom; FPS check.

### Task 9: Verify, document, rebuild

- [ ] `lune run tools/compile-check`, `lune run tests/run`, `luau-lsp analyze --platform=standard src/shared`.
- [ ] Studio MCP runs: Easy night chain with items in hand/pockets and a dropped bag; out spill; phone keys; glimpse;
  ending reached; no errors in the output; FPS from the MicroProfiler header.
- [ ] README: keys table, Story section (bag, phone), checklist items for bag sharing; ledger entry; memory note.
- [ ] Fresh code review of the whole change; fix findings; `rojo build default.project.json -o
  build/TheEmptySchool.rbxlx`.
