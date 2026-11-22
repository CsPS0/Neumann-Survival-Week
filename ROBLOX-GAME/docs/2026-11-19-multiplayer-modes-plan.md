# The Empty School on Roblox: Multiplayer Modes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hide and Seek and Social Deduction from the Godot game, playable online on Roblox in the empty night school,
built from the same floor-plan data.

**Architecture:** A Rojo project in `ROBLOX-GAME/`. Pure Luau modules in `src/shared` (data and rules, no Roblox
APIs, no `require`) are unit-tested with Lune. The server builds the school from that data at start, owns every rule
(roles, phases, timers, catches, takedowns, votes) and talks to clients through RemoteEvents and replicated
attributes. Clients draw the HUD, lobby, meeting panel, torch input and spectator camera.

**Tech Stack:** Luau, Roblox (PathfindingService, ProximityPrompt, TextChatService, ContextActionService), Rojo,
Lune (tests), luau-lsp (static analysis), Rokit (installs the three).

**Spec:** `ROBLOX-GAME/docs/2026-11-19-multiplayer-modes-design.md`. Godot source for every ported value:
`HORROR-GAME/scripts/` (`floor_data.gd`, `rooms.gd`, `main.gd`, `match.gd`, `match_world.gd`, `horror_entity.gd`,
`player.gd`, `entity_model.gd`) and `HORROR-GAME/docs/multiplayer-modes.md`.

## Global Constraints

- Never touch `HORROR-GAME/`, `RPG-GAME/` or `docs/`; read them only. The one exception is Task 1's new row in the
  root `README.md`, `AGENTS.md` and `CLAUDE.md`.
- No commits, pushes or staging unless the author asks (repository rule). Each task ends with `git status --short`
  listing only that task's files.
- Never add an AI or tool as author or co-author anywhere (commit messages, README, file headers, project metadata).
- No real person's name anywhere in `ROBLOX-GAME/`. Social Deduction tags are "Student N" / "Teacher N".
- English UI text. Room labels keep the Godot spelling (Hungarian), with the floor added.
- Up to 10 players per server.
- `STUDS_PER_METRE = 3`; every Godot metre value goes through `Config.studs(m)`, never a bare stud literal.
- Modules in `src/shared` are `--!strict`, use no Roblox globals (`game`, `workspace`, `Instance`, `Vector3`
  constructors) and no `require`, so Lune can load them. Vector arguments are "vector-like": anything with numeric
  `X`, `Y`, `Z` fields (a Roblox `Vector3` or a plain table).
- Floor indices are `0` (ground), `1`, `2` everywhere, as in Godot.
- Server is authoritative: every RemoteEvent handler and prompt `Triggered` handler checks phase, role, state,
  distance and cooldown before acting.
- Downloading anything (Rokit, the Roblox type definitions, sounds) needs the author's OK at that moment.
- Sounds come from Creator Store asset ids; an empty id means the sound is skipped.

## Review Focus

1. **A player leaves mid-round** (the entity, a survivor inside a locker, a downed survivor, a voter in a meeting):
   the round resolves as the spec says, the locker frees up, the meeting ends when the remaining living players have
   voted, and the majority uses the new living count. Tests: `tallyVotes` with a reduced living count (Task 3),
   `hideSeekResult` with an emptied table (Task 3), and the leave-cases checklist in Task 11.
2. **A player joins mid-round or mid-meeting:** they spectate, are not in the vote list, and do not count for the
   majority or the win checks. Checklist item in Task 7 and Task 10.
3. **Start pressed with too few players, twice at once, or while a round runs:** rejected with a banner, no second
   round. Tests: `canStart` (Task 3); server guard in Task 7.
4. **Roblox reset button or a character dying** during a round: reset is disabled on clients, and a character that
   dies anyway counts as out. Steps in Task 5 (`Controls`) and Task 7 (`playerDied`).
5. **Phone players:** every action (sprint, torch, flash, breath, meeting, vote, prompts) reachable by touch.
   Checklist with the Studio device emulator in Task 11.

---

## File map

```
ROBLOX-GAME/
  AGENTS.md  README.md  rokit.toml  default.project.json  .gitignore
  src/shared/   Config.luau  FloorData.luau  Rooms.luau  Rules.luau  RoomLog.luau  Remotes.luau  Sounds.luau
  src/server/   Main.server.luau  SchoolBuilder.luau  Doors.luau  Lockers.luau  Characters.luau  Torch.luau
                RoundManager.luau  EntityModel.luau  EntityAI.luau  HideAndSeek.luau  SocialDeduction.luau
                ChatControl.luau
  src/client/   Main.client.luau  Hud.luau  LobbyUi.luau  Controls.luau  PromptFilter.luau  Spectator.luau
                MeetingUi.luau  Effects.luau
  tests/        run.luau  config.spec.luau  floordata.spec.luau  rooms.spec.luau  rules.spec.luau  roomlog.spec.luau
  docs/         design + this plan
```

Shared state contract (used by several tasks):

- `ReplicatedStorage` attributes, set by the server: `Mode` (`"none"|"hideseek"|"deduction"`), `Phase`
  (`"lobby"|"hiding"|"hunt"|"brief"|"night"|"meeting"|"result"`), `PhaseEndsAt` (`workspace:GetServerTimeNow()`
  based), `Cycle` (boolean, rounds repeat).
- `Player` attributes, set by the server, public: `State` (`"lobby"|"alive"|"downed"|"out"|"spectator"`), `Tag`
  (Social Deduction label, else `""`), `Hidden` (in a locker), `Battery` (0-100), `TorchOn`, `FlashReadyAt`,
  `Sprinting` (set by the server from the `Sprint` remote).
- The secret role never goes in an attribute; it goes to one client through the `Role` remote.
- `ProximityPrompt` attribute `For`: `"entity"|"survivor"|"crew"|"all"`. `PromptFilter` (client) disables prompts not
  meant for the local role; the server re-checks on `Triggered`.

---

### Task 1: Tooling, project skeleton and test runner

**Files:**
- Create: `ROBLOX-GAME/rokit.toml`, `ROBLOX-GAME/default.project.json`, `ROBLOX-GAME/.gitignore`,
  `ROBLOX-GAME/AGENTS.md`, `ROBLOX-GAME/README.md`, `ROBLOX-GAME/tests/run.luau`,
  `ROBLOX-GAME/tests/config.spec.luau`, `ROBLOX-GAME/src/shared/Config.luau`,
  `ROBLOX-GAME/src/server/Main.server.luau`, `ROBLOX-GAME/src/client/Main.client.luau`
- Modify: root `README.md` (parts table), root `AGENTS.md` (folder table), root `CLAUDE.md` (one line)

**Interfaces:**
- Produces: `Config` (table below); test contract: each `tests/*.spec.luau` returns `function(t)`, where
  `t.test(name: string, fn: () -> ())`, `t.eq(actual, expected, msg: string?)`, `t.near(actual: number,
  expected: number, tolerance: number, msg: string?)`, `t.truthy(value, msg: string?)`.

- [ ] **Step 1: Ask the author to install Rokit** (link and command in the README draft: the Rokit GitHub releases
  page, then `rokit self-install`). Do not download it yourself without their OK.
- [ ] **Step 2: Add the tools.** In `ROBLOX-GAME/`: `rokit init`, then `rokit add rojo-rbx/rojo`,
  `rokit add lune-org/lune`, `rokit add JohnnyMorganz/luau-lsp`. Expected: `rokit.toml` lists three pinned versions.
- [ ] **Step 3: Write `default.project.json`.** Name `TheEmptySchool`. Tree: `ReplicatedStorage.Shared` <-
  `src/shared`, `ServerScriptService.Server` <- `src/server`, `StarterPlayer.StarterPlayerScripts.Client` <-
  `src/client`, and `Players` with `$properties` `{"CharacterAutoLoads": false}`. Max players (10) is a publish
  setting, not a property; the README covers it (Task 11).
- [ ] **Step 4: `.gitignore`:** `build/`, `sourcemap.json`, `types/`, `*.rbxl`, `*.rbxlx`, `*.lock`.
- [ ] **Step 5: Write the failing test** `tests/config.spec.luau`:

```lua
local Config = require("../src/shared/Config")
return function(t)
	t.test("studs converts metres", function()
		t.eq(Config.studs(1), 3)
		t.near(Config.studs(2.2), 6.6, 1e-9)
		t.near(Config.studs(Config.FLOOR_HEIGHT), 12, 1e-9)
	end)
	t.test("stair rects follow WORLD_SCALE", function()
		t.near(Config.STAIRS[1].x0, -9.75, 1e-9)
		t.near(Config.STAIRS[1].z1, -2.8, 1e-9)
		t.eq(#Config.STAIRS, 4)
	end)
end
```

- [ ] **Step 6: Write `tests/run.luau`:** reads every `tests/*.spec.luau` with `@lune/fs`, requires it, runs its
  tests in `pcall`, prints `FAIL <file> <name>: <error>` per failure and `N passed, M failed` at the end, and exits
  with `@lune/process` `exit(1)` when M > 0.
- [ ] **Step 7: Run** `lune run tests/run`. Expected: FAIL (Config missing).
- [ ] **Step 8: Write `src/shared/Config.luau`** (`--!strict`, returns one table). Values, all metres unless noted:
  `STUDS_PER_METRE = 3`, `studs(m: number): number`, `WORLD_SCALE = 1.25`, `FLOOR_HEIGHT = 4.0`,
  `WALL_HEIGHT = 3.2`, `WALL_THICKNESS = 0.25`, `DOOR_WIDTH = 1.5`, `DOOR_HEIGHT = 2.2`, `WINDOW_SILL = 0.9`,
  `WINDOW_TOP = 2.4`, `WINDOW_WIDTH = 1.6`, `WINDOW_PITCH = 3.2`, `INNER_WINDOWS = {Porta = "E", ["Büfé"] = "W"}`,
  `INNER_WINDOW_WIDTH = 1.2`, `STAIR_STEPS = 22`, `STAIRS` = the four rects `{x0, z0, x1, z1}` from every pair of
  `STAIR_X = {{-7.8, -6.0}, {6.0, 7.8}}` and `STAIR_Z = {{-9.76, -2.24}, {4.0, 11.52}}` multiplied by `WORLD_SCALE`
  (order: x outer loop, z inner loop, as `main._stair_rects`), `SPAWN = {X = -3.0, Y = 0.1, Z = 16.75}`,
  `MAX_PLAYERS = 10`,
  `HideSeek = {hide = 25, hunt = 240, downed = 25, result = 12, reviveHold = 3}`,
  `Deduction = {brief = 8, night = 360, meeting = 45, meetingResult = 6, result = 12, takedownCooldown = 30,
  firstTakedown = 20, meetingLockout = 15, minPlayers = 3, logAge = 60, secondEntityAt = 8, flickerRange = 20,
  flickerTime = 1.6}`,
  `Player = {walk = 3.0, sprint = 5.5, seeker = 4.2, staminaMax = 100, staminaDrain = 20, staminaRegen = 12.5,
  staminaDelay = 1.0, staminaResume = 30}`,
  `Torch = {range = 9, coneDeg = 35, cooldown = 12, cost = 15, drainPerSec = 0.3, stun = 3, batteryMax = 100}`,
  `Entity = {patrolSpeed = 1.9, chaseSpeed = 4.2, sight = 15, proximity = 2.5, hearing = 12, loseSight = 4,
  attackRange = 1.4, attackDuration = 1.5, blindAfterStun = 3, hintInterval = 15, idleTime = 3, roamMin = 10,
  waypointBias = 0.35, lockerCheck = 2.5}`, `RESTART_DELAY = 12`.
- [ ] **Step 9: Run** `lune run tests/run`. Expected: `2 passed, 0 failed`.
- [ ] **Step 10: Stub entry scripts.** `Main.server.luau` prints `"[server] booted"`; `Main.client.luau` prints
  `"[client] booted"`. Run `rojo build default.project.json -o build/TheEmptySchool.rbxlx`. Expected: exit 0.
- [ ] **Step 11: Static analysis setup.** Ask the author's OK, then download the Roblox type definitions
  (`globalTypes.d.luau` from the luau-lsp repository's `scripts/` folder) to `types/`. Run
  `rojo sourcemap default.project.json -o sourcemap.json` and
  `luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --definitions=types/globalTypes.d.luau src`
  (check `luau-lsp analyze --help`; older builds spell it `--defs`). Expected: no errors. From here on,
  **"Verify build"** in a task means: `lune run tests/run` (0 failed), `rojo build ...` (exit 0) and this analyze
  command (no errors).
- [ ] **Step 12: Docs.** `ROBLOX-GAME/AGENTS.md`: what the folder is, the commands above, the Global Constraints of
  this plan, "the agent cannot run Roblox; the author play-tests in Studio". `README.md`: install Rokit, `rokit
  install`, Rojo Studio plugin (`rojo plugin install`), `rojo serve`, connect from Studio, play-test with Test >
  Clients and Servers, and a placeholder "Play-test checklist" heading. Add the `ROBLOX-GAME/` row (Roblox, Luau,
  "In development, multiplayer modes") to the root `README.md` table and the root `AGENTS.md` table, and one line to
  root `CLAUDE.md` pointing at `ROBLOX-GAME/AGENTS.md`.
- [ ] **Step 13: Verify build** and `git status --short` (only this task's files).

### Task 2: Floor data and room kinds

**Files:**
- Create: `src/shared/FloorData.luau`, `src/shared/Rooms.luau`, `tests/floordata.spec.luau`, `tests/rooms.spec.luau`

**Interfaces:**
- Produces:
  - `FloorData.FLOORS: {Floor}` (index 1..3 = floors 0..2), `Floor = {origin: {x, y}, scale: number, rect: {x0, y0,
    x1, y1}, rooms: {{label: string, x0, y0, x1, y1, doors: string}}, solids: {{x0, y0, x1, y1}}, endWalls: {...},
    lights: {{x, y}}, patrol: {{x, y}}}` in plan units, copied value for value from `floor_data.gd` (corridors and
    csoki are not needed).
  - `FloorData.LOCKERS: {{floor: number, x: number, y: number, yaw: number}}`: the 14 spots from
    `main._place_lockers` (plan units, yaw in radians, same sign convention as Godot; Task 4 converts).
  - `FloorData.FLOOR_NAMES = {"ground floor", "1st floor", "2nd floor"}`.
  - `FloorData.toWorld(floor: number, px: number, py: number): (number, number)` metres, `(p - origin) * scale`.
  - `FloorData.roomRect(floor: number, label: string): {x0: number, z0: number, x1: number, z1: number}?` metres,
    normalized so x0 < x1, z0 < z1.
  - `FloorData.roomLabelAt(floor: number, x: number, z: number): string` (unnamed rooms and no room = `"Corridor"`).
  - `FloorData.logLabel(floor: number, x: number, z: number): string` = `"<label> (<floor name>)"`.
  - `FloorData.floorAt(yMetres: number): number` = `round(y / 4)` clamped to 0..2.
  - `Rooms.typeOf(label: string): "normal"|"computer"|"wc"|"gym"|"entrance"|"other"`,
    `Rooms.isOpen(label: string): boolean`, lists copied from `rooms.gd`.

- [ ] **Step 1: Write the failing tests.**

```lua
-- floordata.spec.luau
local F = require("../src/shared/FloorData")
return function(t)
	t.test("room lookup matches Godot", function()
		t.eq(F.roomLabelAt(0, 1.0, 19.0), "Porta")
		t.eq(F.roomLabelAt(1, -16, -18), "109")
		t.eq(F.roomLabelAt(0, -32.6, -13.9), "Corridor")
		t.eq(F.roomLabelAt(0, -10.6, -18.9), "Corridor") -- unnamed store
	end)
	t.test("log label adds the floor", function()
		t.eq(F.logLabel(1, -16, -18), "109 (1st floor)")
		t.eq(F.logLabel(0, -32.6, -13.9), "Corridor (ground floor)")
	end)
	t.test("roomRect", function()
		local r = F.roomRect(0, "Porta")
		t.near(r.x0, -0.1, 1e-9); t.near(r.z0, 17.7, 1e-9); t.near(r.x1, 3.9, 1e-9); t.near(r.z1, 21.9, 1e-9)
		t.eq(F.roomRect(0, "nope"), nil)
	end)
	t.test("data sizes", function()
		t.eq(#F.FLOORS, 3); t.eq(#F.LOCKERS, 14); t.eq(#F.FLOORS[1].lights, 21); t.eq(#F.FLOORS[2].patrol, 6)
	end)
	t.test("floorAt", function()
		t.eq(F.floorAt(0.1), 0); t.eq(F.floorAt(4.2), 1); t.eq(F.floorAt(9), 2); t.eq(F.floorAt(-1), 0)
	end)
end
```

```lua
-- rooms.spec.luau
local R = require("../src/shared/Rooms")
return function(t)
	t.test("kinds", function()
		t.eq(R.typeOf("14"), "normal"); t.eq(R.typeOf("GT5"), "computer"); t.eq(R.typeOf("WC"), "wc")
		t.eq(R.typeOf("Tornaterem"), "gym"); t.eq(R.typeOf("Porta"), "entrance"); t.eq(R.typeOf("Konyha"), "other")
		t.eq(R.isOpen("Konyha"), false); t.eq(R.isOpen("229"), true)
	end)
end
```

- [ ] **Step 2: Run** `lune run tests/run`. Expected: FAIL (modules missing).
- [ ] **Step 3: Implement `FloorData.luau` and `Rooms.luau`** with the interfaces above. Label matching is exact
  string equality (UTF-8 labels such as `"Ebédlő"` copied byte for byte).
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass.
- [ ] **Step 5: Verify build**, `git status --short`.

### Task 3: Round rules and the room log

**Files:**
- Create: `src/shared/Rules.luau`, `src/shared/RoomLog.luau`, `tests/rules.spec.luau`, `tests/roomlog.spec.luau`

**Interfaces:**
- Consumes: `Config` (values are passed in by callers; `Rules` does not require it).
- Produces:
  - `Rules.canStart(mode: "hideseek"|"deduction", entity: "computer"|"player", players: number): (boolean, string?)`
  - `Rules.entityCount(players: number, secondAt: number): number`
  - `Rules.hideSeekResult(states: {[any]: string}, timeUp: boolean): ("survivors"|"entity")?`
  - `Rules.deductionResult(livingEntities: number, livingCrew: number, timeUp: boolean): ("crew"|"entity")?`
  - `Rules.tallyVotes(votes: {[string]: string}, living: number): (string?, {[string]: number})`. Voter tag ->
    target tag or `"skip"`.
  - `Rules.takedownReadyAt(nightStart: number, last: number?, first: number, cooldown: number): number`
  - `Rules.canCallMeeting(now: number, nightStart: number, used: boolean, lockout: number): boolean`
  - `Rules.newStamina(max: number): Stamina` with `Stamina = {value: number, exhausted: boolean, delay: number}`;
    `Rules.stepStamina(s: Stamina, held: boolean, moving: boolean, dt: number, p: typeof(Config.Player)): boolean`.
    It returns whether the player sprints this frame.
  - `Rules.flashHits(origin: Vec, look: Vec, target: Vec, maxDist: number, coneDeg: number): boolean`
  - `RoomLog.new(): RoomLog`, `log:record(key: string, label: string, t: number)`,
    `log:recent(key: string, now: number, age: number): {{label: string, t: number}}`, `log:clear()`.

Rules, from the spec and `match.gd`:
- `canStart`: deduction needs `players >= 3` (`"Social Deduction needs at least 3 players."`) and only the player
  entity; hideseek with `"player"` needs `>= 2` (`"A player entity needs at least 2 players."`); otherwise true.
- `entityCount` = 2 when `players >= secondAt`, else 1. It is called once at round start only.
- `hideSeekResult`: `"entity"` when no state is `"alive"` (an empty table too); else `"survivors"` when `timeUp`
  (some state is not `"out"`, which holds since one is alive); else nil.
- `deductionResult`: `"crew"` when `livingEntities == 0`; else `"entity"` when `livingEntities >= livingCrew`; else
  `"crew"` when `timeUp`; else nil.
- `tallyVotes`: counts per target including `"skip"`; ejects the non-skip target with `count > living / 2`; else nil.
- `stepStamina` (`player.gd`): sprinting = held and moving and not exhausted; while sprinting value -= drain*dt,
  at 0 it clamps and sets exhausted; held resets `delay` to `staminaDelay`, otherwise `delay -= dt` and once
  `delay <= 0` value += regen*dt (capped at max); exhausted clears when value >= resume.
- `flashHits`: distance <= maxDist and the angle between `look` and `target - origin` <= coneDeg.
- `RoomLog.record` appends only when the label differs from the key's last label. `recent` returns entries with
  `t >= now - age`, preceded by the last older entry (so the room at the start of the window is known), oldest first.

- [ ] **Step 1: Write the failing tests** (`rules.spec.luau`):

```lua
local Rules = require("../src/shared/Rules")
local P = {walk = 3, sprint = 5.5, seeker = 4.2, staminaMax = 100, staminaDrain = 20, staminaRegen = 12.5,
	staminaDelay = 1, staminaResume = 30}
return function(t)
	t.test("canStart", function()
		t.eq((Rules.canStart("deduction", "player", 2)), false)
		t.eq((Rules.canStart("deduction", "player", 3)), true)
		t.eq((Rules.canStart("hideseek", "player", 1)), false)
		t.eq((Rules.canStart("hideseek", "computer", 1)), true)
	end)
	t.test("entityCount", function()
		t.eq(Rules.entityCount(7, 8), 1); t.eq(Rules.entityCount(8, 8), 2)
	end)
	t.test("hideSeekResult", function()
		t.eq(Rules.hideSeekResult({a = "alive", b = "downed"}, false), nil)
		t.eq(Rules.hideSeekResult({a = "downed", b = "out"}, false), "entity")
		t.eq(Rules.hideSeekResult({}, false), "entity") -- everyone left
		t.eq(Rules.hideSeekResult({a = "alive", b = "out"}, true), "survivors")
	end)
	t.test("deductionResult", function()
		t.eq(Rules.deductionResult(0, 3, false), "crew")
		t.eq(Rules.deductionResult(1, 1, false), "entity")
		t.eq(Rules.deductionResult(2, 2, false), "entity")
		t.eq(Rules.deductionResult(1, 2, true), "crew")
		t.eq(Rules.deductionResult(1, 2, false), nil)
	end)
	t.test("tallyVotes", function()
		t.eq((Rules.tallyVotes({a = "c", b = "c", c = "a"}, 3)), "c")      -- 2 > 1.5
		t.eq((Rules.tallyVotes({a = "c", b = "a"}, 4)), nil)               -- tie, too few
		t.eq((Rules.tallyVotes({a = "skip", b = "skip", c = "a"}, 3)), nil) -- skip never ejects
		t.eq((Rules.tallyVotes({a = "c", b = "c"}, 3)), "c")               -- a voter left: living is 3
		local _, counts = Rules.tallyVotes({a = "skip", b = "c"}, 3)
		t.eq(counts.skip, 1); t.eq(counts.c, 1)
	end)
	t.test("takedown and meeting timing", function()
		t.eq(Rules.takedownReadyAt(100, nil, 20, 30), 120)
		t.eq(Rules.takedownReadyAt(100, 150, 20, 30), 180)
		t.eq(Rules.canCallMeeting(114, 100, false, 15), false)
		t.eq(Rules.canCallMeeting(115, 100, false, 15), true)
		t.eq(Rules.canCallMeeting(200, 100, true, 15), false)
	end)
	t.test("stamina", function()
		local s = Rules.newStamina(100)
		for _ = 1, 50 do Rules.stepStamina(s, true, true, 0.1, P) end
		t.near(s.value, 0, 0.01); t.eq(s.exhausted, true)
		t.eq(Rules.stepStamina(s, true, true, 0.1, P), false) -- exhausted: no sprint
		for _ = 1, 10 do Rules.stepStamina(s, false, true, 0.1, P) end
		t.truthy(s.value < 1.3, "delay holds regen")
		for _ = 1, 26 do Rules.stepStamina(s, false, true, 0.1, P) end
		t.eq(s.exhausted, false); t.truthy(s.value >= 30 and s.value < 34)
	end)
	t.test("flashHits", function()
		local o, look = {X = 0, Y = 0, Z = 0}, {X = 0, Y = 0, Z = -1}
		t.eq(Rules.flashHits(o, look, {X = 0, Y = 0, Z = -8}, 9, 35), true)
		t.eq(Rules.flashHits(o, look, {X = 0, Y = 0, Z = -10}, 9, 35), false)
		t.eq(Rules.flashHits(o, look, {X = 6, Y = 0, Z = -6}, 9, 35), false) -- 45 degrees off
		t.eq(Rules.flashHits(o, look, {X = 0, Y = 0, Z = 5}, 9, 35), false)  -- behind
	end)
end
```

  and `roomlog.spec.luau`:

```lua
local RoomLog = require("../src/shared/RoomLog")
return function(t)
	t.test("records changes only and keeps the window", function()
		local log = RoomLog.new()
		log:record("Student 1", "14 (ground floor)", 0)
		log:record("Student 1", "14 (ground floor)", 5)
		log:record("Student 1", "Corridor (ground floor)", 30)
		log:record("Student 1", "WC (1st floor)", 80)
		local r = log:recent("Student 1", 100, 60)
		t.eq(#r, 2); t.eq(r[1].label, "Corridor (ground floor)"); t.eq(r[2].label, "WC (1st floor)")
		t.eq(#log:recent("nobody", 100, 60), 0)
		log:clear(); t.eq(#log:recent("Student 1", 100, 60), 0)
	end)
end
```

- [ ] **Step 2: Run** `lune run tests/run`. Expected: FAIL (modules missing).
- [ ] **Step 3: Implement `Rules.luau` and `RoomLog.luau`.**
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass.
- [ ] **Step 5: Verify build**, `git status --short`.

### Task 4: The school

**Files:**
- Create: `src/server/SchoolBuilder.luau`, `src/server/Doors.luau`
- Modify: `src/server/Main.server.luau`

**Interfaces:**
- Consumes: `Config`, `FloorData`, `Rooms`.
- Produces:
  - `SchoolBuilder.build(parent: Instance): School`, where `School = {spawn: CFrame, farPoint: Vector3, patrol:
    {Vector3}, lockers: {Model}, lamps: {PointLight}}` (all in studs; `farPoint` = the patrol point farthest from
    spawn, as `_far_from_spawn`).
  - `Doors.create(parent: Instance, hinge: CFrame, width: number, height: number, locked: boolean): Model`. The door
    is tagged `"Door"`, has a `ProximityPrompt` (`For = "all"`, Open/Close) and a `PathfindingModifier` with
    `PassThrough = true` on the panel. `Doors.setOpen(door: Model, open: boolean)` tweens the hinge 90 degrees
    (swing side from `DOOR_SWING` in `main.gd`). Locked doors show "Not available in the demo." and never open.
  - Locker models tagged `"Locker"`, each with a `ProximityPrompt` named `HidePrompt` (`For = "all"`, "Hide") and an
    attribute `Occupant` (`UserId` or 0).

World mapping: Godot metres `(x, y, z)` -> studs `(studs(x), studs(y), studs(z))`; floor `i` sits at
`y = i * FLOOR_HEIGHT`. Godot yaw `a` around +Y maps to `CFrame.Angles(0, a, 0)` (both are right-handed, -Z
forward).

What to build, per floor, following `main.gd` (`_build_floor`, `_wall`, door cutting, `_build_stairs`,
`_build_flight`, `_place_lockers`): floor slab and ceiling slab over `rect`; walls along every room edge with door
gaps (tokens: side letter + optional position, default middle; lowercase = opening, no door) and a lintel above each
gap; outer walls with windows (`WINDOW_*`); `INNER_WINDOWS`; solids as full-height blocks; end walls; doors on
uppercase tokens, locked when `not Rooms.isOpen(label)`; doorless openings into closed rooms get a solid barrier;
two flights per stairwell (22 steps, plus an invisible ramp part for smooth walking, `CanCollide` on the ramp,
steps `CanCollide = false`), with holes cut in the upper slabs over the stairwells; a lamp part with a `PointLight`
(range `studs(8)`, warm, dim) at every light; lockers (a model about `0.9 x 2.0 x 0.6` m). Materials: floor
`SmoothPlastic` light grey, walls `Concrete`, doors `WoodPlanks`, stairs `Concrete`. Merge nothing; anchor
everything. Lighting at night: `ClockTime = 0`, `Brightness = 0`, `Ambient` and `OutdoorAmbient` near black,
`Technology = Future`.

- [ ] **Step 1: Implement `Doors.luau`.**
- [ ] **Step 2: Implement `SchoolBuilder.luau`.** Build into `parent` with one `Model` per floor (`Floor0`..`Floor2`).
- [ ] **Step 3: `Main.server.luau`:** build into `workspace.School`, print part count and build time.
- [ ] **Step 4: Verify build.**
- [ ] **Step 5: Author checkpoint (Studio).** Ask the author to run `rojo serve`, connect, press Play and check:
  the school appears in a few seconds, the output prints the part count, all three floors are reachable by the four
  stairwells, doors open with E, closed rooms say "Not available in the demo.", the 14 lockers stand in corridors,
  and the size feels right (if not, change only `STUDS_PER_METRE`). Note the reported numbers in the task log.
- [ ] **Step 6:** `git status --short`.

### Task 5: Remotes, characters, movement and the torch

**Files:**
- Create: `src/shared/Remotes.luau`, `src/server/Characters.luau`, `src/server/Torch.luau`,
  `src/client/Controls.luau`, `src/client/PromptFilter.luau`
- Modify: `src/server/Main.server.luau`, `src/client/Main.client.luau`

**Interfaces:**
- Produces:
  - `Remotes.NAMES = {"StartRound", "BackToLobby", "Sprint", "Torch", "Flash", "Breath", "CallMeeting", "Vote",
    "Role", "Banner", "MeetingStarted", "MeetingResult", "Flicker", "Stunned"}`. The server creates a
    `ReplicatedStorage.Remotes` folder of `RemoteEvent`s with these names at boot; clients `WaitForChild` them.
  - `Characters.spawn(player: Player, at: CFrame)`: `LoadCharacter`, then place; walk speed `studs(walk)`, jump off
    (`JumpPower = 0`, `UseJumpPower = true`), Roblox name display on.
  - `Characters.setSpeed(player: Player, metresPerSecond: number)`, `Characters.freeze(player: Player, on: boolean)`,
    `Characters.despawn(player: Player)`.
  - `Torch.init(remotes)`: adds a `SpotLight` (range `studs(9)`, angle 70) to each character's head, handles
    `Torch(on)` and `Flash()`; server-side battery (drain 0.3/s while lit, flash costs 15, cooldown 12) in attributes
    `Battery`, `TorchOn`, `FlashReadyAt`. `Torch.onFlash: (player: Player, origin: Vector3, look: Vector3) -> ()` is a
    hook the active mode sets to apply stuns (with `Rules.flashHits`). `Torch.reset(player)` refills the battery.
    `Torch.setAllowed(player: Player, allowed: boolean)` (the player entity has no torch).
  - `Controls` (client): Shift / touch "Sprint" runs `Rules.stepStamina` every frame and sets the local
    `Humanoid.WalkSpeed` to `studs(sprint)` or `studs(walk)` unless the server set attribute `SpeedLock` on the
    player (then it uses that value); it fires `Sprint(bool)` on changes. F = `Torch`, T = `Flash`, Space in a locker
    = `Breath(bool)` while held, G = `CallMeeting`. Touch buttons through `ContextActionService` with
    `createTouchButton = true`. Disables the Roblox reset button (`StarterGui:SetCore("ResetButtonCallback", false)`,
    retried until it succeeds).
  - `PromptFilter` (client): on every `ProximityPrompt` added, enables it only when its `For` matches the local
    role (`"all"` always; others from the latest `Role` remote and the local `State`).

- [ ] **Step 1: Implement the five modules and wire them in the entry scripts.** Until rounds exist, the server
  spawns everyone at `School.spawn` on join (`CharacterAutoLoads` is off).
- [ ] **Step 2: Verify build.**
- [ ] **Step 3: Author checkpoint (Studio, 2 clients):** both players spawn at the entrance; walking is slower than
  Roblox default; Shift sprints for about 5 s and then stops until stamina is back; F switches the torch for both
  players to see; T flashes and the battery drops by 15; the reset button is gone; touch buttons appear in the
  phone emulator.
- [ ] **Step 4:** `git status --short`.

### Task 6: Lockers

**Files:**
- Create: `src/server/Lockers.luau`
- Modify: `src/server/Main.server.luau`

**Interfaces:**
- Consumes: `School.lockers`, the `Breath` remote, `Characters`.
- Produces: `Lockers.init(school: School, remotes)`, `Lockers.isHidden(player: Player): boolean`,
  `Lockers.holdingBreath(player: Player): boolean`, `Lockers.occupied(): {[Model]: Player}`,
  `Lockers.release(player: Player)`, `Lockers.releaseAll()`, `Lockers.setEnabled(on: boolean)`.

Hiding: `HidePrompt` with no occupant moves the player inside (character anchored inside the locker, invisible to
others through `Transparency`, `Hidden = true`, prompt text "Leave"). The same prompt from the occupant brings them
out in front of the locker. Breath only counts while hidden. `PlayerRemoving` and character death call `release`.

- [ ] **Step 1: Implement `Lockers.luau`** and hook it in `Main.server.luau`.
- [ ] **Step 2: Verify build.**
- [ ] **Step 3: Author checkpoint:** hide and leave with E; the other client sees the player vanish; a second player
  cannot enter an occupied locker; leaving the game from a locker frees it.
- [ ] **Step 4:** `git status --short`.

### Task 7: Round manager, lobby, HUD and spectating

**Files:**
- Create: `src/server/RoundManager.luau`, `src/client/LobbyUi.luau`, `src/client/Hud.luau`,
  `src/client/Spectator.luau`
- Modify: `src/server/Main.server.luau`, `src/client/Main.client.luau`

**Interfaces:**
- Consumes: `Rules.canStart`, `Characters`, `Lockers`, `Torch`, `Remotes`.
- Produces:
  - `RoundManager.init(school: School, remotes, modes: {hideseek: Mode, deduction: Mode})`.
  - `type Mode = {start: (ctx: RoundContext) -> (), playerLeft: (player: Player) -> (), playerDied: (player:
    Player) -> (), stop: () -> ()}`.
  - `type RoundContext = {players: {Player}, options: {mode: string, entity: string}, school: School, remotes:
    any, setPhase: (phase: string, seconds: number) -> (), finish: (summary: string) -> (), isPlaying: (player:
    Player) -> boolean}`.
  - `finish(summary)` sets phase `"result"` for `RESTART_DELAY`, shows `summary` as a banner, calls `mode.stop()`,
    respawns everyone at the entrance, then starts the next round with the same options unless `Cycle` is false
    (then `"lobby"`). Late joiners get `State = "spectator"` and join at the next round.

Behaviour:
- `StartRound(mode, entity)` is accepted only in phase `"lobby"` and when `Rules.canStart` agrees. The first accepted
  request wins; a rejected one gets a `Banner` with the reason.
- `BackToLobby` sets `Cycle = false` (any player).
- `setPhase` writes `Phase` and `PhaseEndsAt`.
- `PlayerRemoving` calls `mode.playerLeft`; `Humanoid.Died` during a round calls `mode.playerDied`.
- `LobbyUi`: shown in phase `"lobby"`: buttons "Hide and Seek (computer)", "Hide and Seek (player entity)", "Social
  Deduction"; in a round, a small "Back to lobby" button.
- `Hud`: top line `"<Phase> mm:ss  |  <role>  |  <n> up"` from the attributes, and a banner line for `Banner`
  messages (5 s).
- `Spectator`: while the local `State` is `"out"` or `"spectator"`, the camera follows a living player; Left/Right
  (or on-screen arrows) switch players.

- [ ] **Step 1: Implement the four modules** with two stub modes that only call `setPhase("hunt", 10)` and then
  `finish("Stub round over.")`.
- [ ] **Step 2: Verify build.**
- [ ] **Step 3: Author checkpoint (3 clients):** the lobby buttons start a stub round for everybody; pressing a start
  button twice starts one round only; a stub round repeats after 12 s until "Back to lobby"; a fourth client
  joining mid-round spectates and plays from the next round; Social Deduction with 2 clients shows the "needs at
  least 3 players" banner.
- [ ] **Step 4:** `git status --short`.

### Task 8: The entity model and the computer entity

**Files:**
- Create: `src/server/EntityModel.luau`, `src/server/EntityAI.luau`

**Interfaces:**
- Produces:
  - `EntityModel.build(): Model`: a Humanoid rig of parts, close to `entity_model.gd` (tall, thin, dark), with a
    `HumanoidRootPart`; `EntityModel.attachTo(character: Model)` welds the same look onto a player's character and
    hides the avatar parts.
  - `EntityAI.new(model: Model, school: School, opts: {targets: () -> {Player}, isHidden: (Player) -> boolean,
    holdingBreath: (Player) -> boolean, lockers: () -> {[Model]: Player}, onCatch: (Player) -> ()}): EntityAI`;
    `ai:start()`, `ai:stop()`, `ai:stun(seconds: number)`, `ai:placeAt(position: Vector3)`.

States IDLE/PATROL/CHASE/ATTACK as `horror_entity.gd`, with `Config.Entity` values: patrol at `patrolSpeed` between
random patrol points and waypoints (`waypointBias`), chase at `chaseSpeed`. It sees a target within `sight` in front
or `proximity` around it, with a clear raycast, never a hidden one. It hears a target with the `Sprinting` attribute
within `hearing` on the same floor and walks there. Every `hintInterval` it walks towards its target's rough
position. It drops the chase after `loseSight` seconds unseen. Within `attackRange` of a visible target it calls
`onCatch`. When it passes within `lockerCheck` of an occupied locker whose occupant is not holding breath, it walks
to the locker and lingers `idleTime`. It never catches the occupant. A stun freezes it for the given seconds, then
it is blind for `blindAfterStun`. Paths come from `PathfindingService:CreatePath` (agent radius and height from the
model, `AgentCanJump = false`); repath every 0.15 s while chasing, and if it does not move for 1 s, pick a new
point. Doors it touches open (`Doors.setOpen`). It runs on the server only.

- [ ] **Step 1: Implement `EntityModel.luau` and `EntityAI.luau`.**
- [ ] **Step 2: Verify build.**
- [ ] **Step 3:** `git status --short`. Play-testing happens with Task 9.

### Task 9: Hide and Seek

**Files:**
- Create: `src/server/HideAndSeek.luau`, `src/client/Effects.luau`
- Modify: `src/server/Main.server.luau` (register the mode)

**Interfaces:**
- Consumes: `RoundContext`, `EntityAI`, `EntityModel`, `Lockers`, `Torch.onFlash`, `Rules.hideSeekResult`,
  `Rules.flashHits`, `Config.HideSeek`.
- Produces: `HideAndSeek: Mode`. `Effects` (client): the black curtain for the player entity during `"hiding"`, the
  stun white-out, light flicker on `Flicker(position, seconds)` (Task 10 uses it too), heartbeat and sting hooks
  (Task 11 fills the sounds).

Rules (spec, unchanged from Godot):
- Phases `hiding` 25 s, `hunt` 240 s, then `finish`.
- Computer entity: placed at `farPoint` during hiding, `ai:start()` at hunt; `onCatch` downs the survivor.
- Player entity (random player, `options.entity == "player"`): `EntityModel.attachTo`, `SpeedLock = studs(4.2)`,
  `Torch.setAllowed(false)`, black curtain through its `Role`, frozen at `farPoint` while hiding. It catches through
  a `Catch` prompt on every alive survivor (`For = "entity"`, `RequiresLineOfSight`, range `studs(2.5)`).
- `Role` remote to each player: `"survivor"` or `"entity"`.
- Downed: `State = "downed"`, frozen, a `Revive` prompt on them (`For = "survivor"`, `HoldDuration = 3`); not
  revived in 25 s -> `"out"`, despawn, spectate. Revive -> `"alive"`.
- Flash: `Torch.onFlash` stuns the computer entity (`ai:stun(3)`) or freezes the player entity for 3 s and sends it
  `Stunned`.
- Win check after every state change and at time-up with `Rules.hideSeekResult`; summary "Survivors win." /
  "The entity wins.".
- Leaving: entity leaves -> `finish("The entity left.")`; survivor leaves -> treated as out. A survivor who dies
  counts as out.
- `stop()`: stops the AI, destroys the entity model and prompts, `Lockers.releaseAll()`, clears `SpeedLock`, resets
  torches.

- [ ] **Step 1: Implement `HideAndSeek.luau` and `Effects.luau`; register the mode** in place of the stub.
- [ ] **Step 2: Verify build.**
- [ ] **Step 3: Author checkpoint (Studio, 3 clients, both entity options):** hiding lasts 25 s; the computer entity
  hunts, hears sprinting and catches; a survivor in a locker is never caught; the entity comes to an occupied locker
  unless Space is held; T stuns it for 3 s; a downed player is revived by a teammate holding E for 3 s or is out
  after 25 s and spectates; the player entity sees black while hiding, walks at 4.2 m/s and catches with E; both
  results appear; the next round starts after 12 s; the entity leaving ends the round.
- [ ] **Step 4:** `git status --short`.

### Task 10: Social Deduction

**Files:**
- Create: `src/server/SocialDeduction.luau`, `src/server/ChatControl.luau`, `src/client/MeetingUi.luau`
- Modify: `src/server/Main.server.luau` (register the mode)

**Interfaces:**
- Consumes: `RoundContext`, `Rules.entityCount`, `Rules.deductionResult`, `Rules.tallyVotes`,
  `Rules.takedownReadyAt`, `Rules.canCallMeeting`, `RoomLog`, `FloorData.logLabel`, `FloorData.floorAt`,
  `Lockers`, `Effects` (`Flicker`), `Config.Deduction`.
- Produces: `SocialDeduction: Mode`; `ChatControl.init()`, `ChatControl.setRound(active: boolean)`,
  `ChatControl.setMeeting(open: boolean)`, `ChatControl.setOut(player: Player, out: boolean)`;
  `MeetingStarted(info)` with `info = {caller: string, victim: string?, living: {string}, log: {[string]:
  {{label: string, t: number}}}, endsAt: number}` and `MeetingResult(ejected: string?, wasEntity: boolean?,
  counts: {[string]: number})`.

Rules (spec):
- Start: `Rules.entityCount(#players, 8)` random entities; everyone else crew. Tags: shuffle players, entities and
  crew alike get "Student N" or "Teacher N" (alternate). `Tag` attribute, a `BillboardGui` with the tag over each
  head, `Humanoid.DisplayDistanceType = None`. Everyone gets the same uniform: a `HumanoidDescription` with no
  accessories or clothing and fixed body colours; the original description is restored at `stop()`.
- `Role` remote: crew get `"crew"`; entities get `"entity"` plus the partner's tag when there are two.
- Phases: `brief` 8 s (frozen), `night` 360 s, `meeting` 45 s (+6 s result), then back to `night` with the
  remaining time.
- Takedown: a `Takedown` prompt on every living crew member (`For = "entity"`, line of sight, `studs(2.5)`). Each
  entity has its own `readyAt` from `Rules.takedownReadyAt` (relative to the night start). Entities are never
  targets. Victim: `"out"`, a body clone (anchored, lying down, with a `Report` prompt, `For = "crew"`, also usable by
  living entities to blend in), the original character despawned, spectating. `Flicker` to all clients for lamps
  within `studs(20)`, 1.6 s.
- Room log: once a second, the server records `FloorData.logLabel` for every living player by tag.
- Meeting: `Report` on a body or `CallMeeting` (`Rules.canCallMeeting`, once per player per round). Freeze all,
  remove bodies, `ChatControl.setMeeting(true)`, send `MeetingStarted` with the log of every living player and the
  victim. `Vote(tag or "skip")` once per living player; the meeting ends at 45 s or when all living have voted. Then
  `Rules.tallyVotes` with the current living count. An ejected player is out and their role is shown in
  `MeetingResult`. After 6 s, everyone living goes back to the entrance and the night resumes.
- Win check after every takedown, ejection, leave and at time-up with `Rules.deductionResult`; summaries "The crew
  wins." / "The entity wins." (or "The entities win.") with every entity's tag revealed.
- Leaving: an entity leaving counts as ejected (round ends when none are left); a crew member leaving counts as out.
- Chat (`ChatControl`, TextChatService): during a Social Deduction round, `RBXGeneral` delivers only in meetings;
  bubble chat is off; players who are out are added to a `"Out"` text channel the living cannot see. Everything is
  open again in the lobby and in Hide and Seek. Voice chat is an experience setting (README, Task 11).
- `MeetingUi`: the room log per tag (oldest first, with seconds ago), the vote list as buttons (1-9 keys too, plus
  "Skip"), live tally hidden until the result, then the result line.

- [ ] **Step 1: Implement `SocialDeduction.luau`, `ChatControl.luau`, `MeetingUi.luau`; register the mode.**
- [ ] **Step 2: Verify build.**
- [ ] **Step 3: Author checkpoint (Studio, 4 clients):** everyone looks the same and shows a tag; each client sees only
  its own role; the entity cannot take down before 20 s, then every 30 s; lights flicker near a takedown; a body can
  be reported; G calls a meeting once and not in the first 15 s; chat works only in the meeting; the log shows rooms
  with floors; votes eject with a majority and show the role; a tie ejects nobody; both win paths; an out player
  chats only with other out players; a client joining during a meeting is not in the vote list. With 8 clients (if
  the PC copes): two entities who see each other's tag.
- [ ] **Step 4:** `git status --short`.

### Task 11: Sounds, README and the full play-test

**Files:**
- Create: `src/shared/Sounds.luau`
- Modify: `src/client/Effects.luau`, `ROBLOX-GAME/README.md`, `ROBLOX-GAME/AGENTS.md`

**Interfaces:**
- Produces: `Sounds.IDS: {[string]: string}` with keys `entitySteps`, `heartbeat`, `sting`, `torchClick`, `locker`,
  `breath`, `door`, `bell`, all `""` until the author picks Creator Store sounds. `Effects.play(name: string,
  at: Vector3?)` skips empty ids.

- [ ] **Step 1: Implement `Sounds.luau` and the sound hooks in `Effects`:** entity steps (3D, on the entity), a
  heartbeat when the entity is within `studs(12)`, the sting at hunt start and on a takedown near you, torch click,
  locker, door, the bell at round start.
- [ ] **Step 2: README:** the full play-test checklist (Tasks 4 to 10 checkpoints plus the Review Focus items: leave
  cases in each mode, joins mid-meeting, double start, phone emulator for every action) and a "Publish" section:
  publish from Studio, max players 10, the content maturity questionnaire, turn voice chat off in the experience's
  communication settings, and give friends access through a private server link (check the current private
  server options in the Creator Hub).
- [ ] **Step 3: Verify build.**
- [ ] **Step 4: Author play-test** of the README checklist in Studio, then a first private server with friends.
- [ ] **Step 5:** `git status --short`, then report to the author what is ready to commit.
