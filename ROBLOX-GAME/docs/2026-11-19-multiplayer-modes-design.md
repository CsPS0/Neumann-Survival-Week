# The Empty School on Roblox: multiplayer modes (design)

Date: 2026-11-19. Status: draft, waiting for approval.

## Why

The Godot game (`HORROR-GAME/`) has two multiplayer modes, but players on different networks can only join through a
forwarded port or a self-hosted server, and there is no relay. Roblox hosts servers for free and handles joining, so
friends can play from anywhere with a link. The Godot game and the console RPG are final and will not be developed
further; new work happens here.

The first version is a private test for the author's school and friends, for fun.

## Goals

- The two Godot modes, **Hide and Seek** and **Social Deduction**, playable online on Roblox in the empty night school.
- The school layout built from the same floor-plan data as the Godot game, so it is the same building.
- Works with the default Roblox controls on PC and on phones.
- Server-authoritative rules (roles, phases, timers, catches, takedowns, votes).
- Code in git as plain Luau files, synced into Roblox Studio with Rojo.

## Non-goals (this version)

- The five-day campaign, lessons, quiz, story, endings.
- NPCs: teachers, the student crowd, the porter, the caretaker, Csoki.
- Classroom furniture, the phone, achievements, saved progress (no DataStore).
- Public matchmaking, a tutorial for strangers, Hungarian text, monetization of any kind.
- VR.

## Anti-goals (a failure even if it works)

- Any real person's name in the game. The 79 roster names stay out; Social Deduction uses tags ("Student 1").
- Any change to `HORROR-GAME/`, `RPG-GAME/` or `docs/`. The Roblox game references them only by copying data.
- Spending Robux or needing paid tools.
- Looking like a copy of an existing Roblox game. The school, the entity and the rules are this project's own.

## Constraints

- Luau on Roblox. Tools: Rojo (sync), Lune (runs pure Luau tests outside Roblox), both installed with Rokit.
- Play-testing needs Roblox Studio on the author's PC. The agent cannot run Roblox; it can run `rojo build` and the
  Lune tests.
- Roblox cannot generate audio at runtime. Sounds come from free Creator Store assets, referenced by asset id.
- Publishing needs the Roblox content maturity questionnaire (horror content).
- English UI text, matching the Godot game.
- All work is credited to the author only (repository rule).

## Approaches considered

| Approach | Trade-off | Decision |
|---|---|---|
| **A. Rojo + Luau files in git; the server builds the school from data at start** | Everything in git, the agent can write and change all of it, the layout matches Godot exactly. Needs Rojo; the look is what code builds. | **Picked.** Keeps the "built from data" approach of the Godot game. |
| B. Rojo for code, school built once and saved in Studio, then decorated by hand | Nicer by hand, but the map is a binary Studio file: no diffs, edits collide, layout fixes are manual. | Rejected for now; hand decoration can be layered on A later. |
| C. Studio only, scripts inside the place | Fastest to open, but nothing is in git and the agent cannot edit it. | Rejected. |

## Decided with the author

- Multiplayer modes first; the campaign later, if at all.
- Audience: school and friends, joining through a private server link.
- Approach A.

## Proposals the author has not objected to (agent's calls, can be changed)

- Up to **10 players** per server (Godot: 5).
- Social Deduction gets a **second entity at 8 or more players**. The two entities see each other's tag.
- **Looks:** (changed by the author on 2026-11-20) every player in every mode spawns as the same plain default
  character with fixed colours, never their own avatar. Social Deduction also hides Roblox name tags.
- **Map:** all three floors with walls, doors, stairs, lockers and lamps; no furniture.
- **Spectator camera** for players who are out (missing in Godot).
- Godot's movement, stamina, torch and locker rules are ported unchanged, including the locker stalemate.
- Social Deduction: chat only in the lobby and meetings, a separate chat for players who are out, voice chat off.
- Two entities: separate cooldowns, cannot take each other down, ejection reveals one role.
- Room log names stay in Hungarian as on the map, with the floor added.

## How it works

### Folder and tooling

New top-level folder `ROBLOX-GAME/`, a fourth separate project next to the other three:

```
ROBLOX-GAME/
  AGENTS.md              rules for agents (build, test, conventions), like HORROR-GAME/AGENTS.md
  README.md              how to install the tools, sync, play-test and publish
  rokit.toml             pinned rojo and lune versions
  default.project.json   Rojo tree
  src/shared/            ReplicatedStorage: data and pure logic (no Roblox services)
  src/server/            ServerScriptService: school builder, rounds, entity AI
  src/client/            StarterPlayerScripts: HUD, lobby, meeting, torch, spectator, touch buttons
  tests/                 Lune tests for src/shared
  docs/                  this design
```

The root `AGENTS.md`, `CLAUDE.md` and `README.md` gain a row for the new folder. `.gitignore` ignores built place
files (`*.rbxl`, `*.rbxlx`) and Rokit caches.

### Units

One constant, `STUDS_PER_METRE = 3`, converts every Godot measurement. A Roblox avatar (about 5 studs) then stands
about 1.7 m tall, a door (2.2 m) is 6.6 studs, a wall 9.6 studs, a floor 12 studs. Tune the constant in the first
play test if the school feels too big or small; nothing else should need to change.

### Data ported from Godot (copied, not shared)

- `floor_data.gd` -> `shared/FloorData.luau`: the three floors (origin, scale, rooms with door tokens, solids,
  end walls, lights, patrol points), `WORLD_SCALE`, and `room_rect` / `room_label_at`.
- `rooms.gd` -> `shared/Rooms.luau`: room kinds; `other` rooms stay closed as in the demo.
- From `main.gd`: floor height 4.0, wall height 3.2, door 1.5 x 2.2, wall thickness, the stairwell rectangles
  (`STAIR_X`, `STAIR_Z`, 22 steps), the outer-wall windows, the 14 locker spots, the spawn point in the entrance.
- From `horror_entity.gd`: speeds, sight and hearing ranges, catch distance, how it treats hidden players.
- From `player.gd`: walk 3.0 m/s, sprint 5.5 m/s, stamina (100, drains 20/s while sprinting, refills 12.5/s after
  1 s, exhausted at 0 until back at 30), and the torch (9 m range, 12 s flash cooldown, battery: 15% per flash and a
  slow drain while lit). Roblox's default `WalkSpeed` must be replaced by these, or nobody can be caught.
- From `match.gd` and `docs/multiplayer-modes.md`: every timer and rule below.

### The school

The server builds the school once at start into `Workspace.School`: anchored parts per floor slab, wall strip, lintel,
stair step and ramp (Roblox materials such as Concrete, SmoothPlastic and WoodPlanks stand in for the procedural
textures). Doors are hinged parts that open and close with a `ProximityPrompt` (E); closed rooms get locked doors.
Lighting is night: `ClockTime` 0, dark ambient, a `PointLight` per ceiling lamp from the data. Lockers are models with
a prompt.

Pathfinding uses `PathfindingService` on the built geometry. Door parts carry a `PathfindingModifier` that marks them
passable, and the server opens a door when the entity reaches it, as the Godot entity does.

### Session and rounds

- The server is the authority. Clients send requests through `RemoteEvent`s; the server checks who may send them,
  distance and cooldowns, and broadcasts the result.
- **Lobby:** players wait in the entrance hall. (Changed by the author on 2026-11-20: a main menu replaces the lobby
  panel; it opens on join and with M, and also holds invites, private lobbies by code and settings. The game is
  first person and players can jump.) Any player starts a round from the menu. Later rounds start 12 s after a
  result with the same options. "Stop after this round" (any player) stops the cycle after the current round.
- **Late joiners** spectate the running round and play from the next one.
- **Leaving:** the entity leaving ends the round; anyone else leaving counts as out (Godot rule).

### Hide and Seek (rules from Godot, unchanged)

Phases: Hiding 25 s, Hunt 240 s, Result 12 s. Survivors spawn at the entrance; the entity waits in a far corner.

- **Computer entity** (default): a server-run model built from parts like `entity_model.gd`. It hunts the nearest
  survivor who is not hiding, hears sprinting, and senses roughly where its target is every 15 s.
- **Player entity** (needs 2+ players): the player gets the entity model, a fixed 4.2 m/s walk, no torch, and a black
  screen during Hiding. Catches with a prompt (E) on a survivor in line of sight.
- **Movement:** Godot's walk, sprint (Shift, a touch button on phones) and stamina, with a stamina bar. The
  computer entity hears sprinting survivors.
- **Lockers (Godot behaviour, unchanged):** a prompt hides the survivor inside. A hidden survivor cannot be seen or
  caught by either kind of entity. When the computer entity passes within 2.5 m of an occupied locker and the
  survivor is not holding their breath (Space, a touch button), it walks over to look and lingers, which keeps the
  survivor pinned. There is no time limit inside; a survivor can hide out the round, as in Godot.
- **Torch:** every survivor has a spotlight, switched with F. The flash (T, touch button) stuns the entity for 3 s if
  it is within 9 m and in the cone; the server checks. Godot's 12 s cooldown and battery come along, shown on the HUD.
- **Downed:** 25 s to be revived by a teammate holding E for 3 s (a prompt with `HoldDuration` 3), else out.
- **Win:** survivors when the Hunt ends with one of them not out; the entity when every survivor is downed or out.

### Social Deduction (rules from Godot, plus the second entity)

Players 3 to 10. Phases: Get ready 8 s, Night 360 s, Meeting 45 s plus 6 s to read the result, Result 12 s.

- **Secrecy:** each client is told only its own role (and, with two entities, the partner's tag). Players are shown
  by their tag ("Student 1", "Teacher 2") over the head instead of the Roblox name.
- **Chat:** text chat is open in the lobby and during meetings only. Bubble chat is off in rounds. Players who are out
  chat in their own channel that the living do not see. Voice chat is turned off for the experience, because it would
  give away who is talking.
- **Takedown:** an entity uses a prompt (E) on a crew member, 20 s into the night and then every 30 s. With two
  entities each has its own cooldown; they cannot take each other down. The victim becomes a body and is out
  (spectator).
- **Evidence:** the room log (the server samples every living player's room once a second with `room_label_at`, so it
  is true for everyone), lights within 20 m of a takedown flicker for 1.6 s, and what players see. Room names stay as
  on the Godot map (they are the school's own names, e.g. "Könyvtár", "Tanári") with the floor added: "WC (1st
  floor)". Unnamed rooms show as "Corridor".
- **Meetings:** reporting a body (E) or the meeting key (G, once per player per round, not in the first 15 s). Everyone
  freezes, bodies are removed, the meeting panel shows the last minute of the room log and the vote list.
- **Vote:** one vote or skip each. More than half of the living players' votes ejects; the role is shown. A tie or too
  few votes ejects nobody. The meeting ends early when everyone has voted. Everyone restarts at the entrance.
- **Win:** crew when every entity is ejected or the night ends; entities when living entities >= living crew. An
  ejection reveals only the ejected player's role.

### HUD and controls

- Top line: phase, timer, role, players still up (as in Godot).
- Banner messages for phase changes and results.
- Keyboard: E (Roblox prompts), Shift sprint, F torch, T flash, Space hold breath (in a locker), G meeting, 1-9 vote.
  Phones: Roblox's own movement and prompt buttons plus touch buttons for sprint, torch, flash, breath and meeting;
  the vote list is tappable.

### Sound

A `shared/Sounds.luau` table maps names (entity steps, heartbeat, scare sting, torch click, locker, breath, bell,
door) to Creator Store asset ids. An empty id means that sound is skipped, so the game runs before sounds are picked.

## Testing

- **Agent:** `rojo build` must succeed; Lune tests cover the pure modules: floor data conversion and `room_label_at`
  against values from the Godot version, win checks for both modes, vote tally (majority, tie, skip, early end),
  takedown cooldown, entity count by player count.
- **Author, in Studio:** Test > Clients and Servers with 3 or 4 players, following a checklist in `README.md` for each
  mode (hide, breath, flash stun, catch, revive, takedown, report, meeting, vote, both win paths, a player leaving).
- **First real test:** a private server with friends, PC and phone.

## Left to the builder

- Splitting the server and client code into modules.
- Part counts and how walls with windows are cut, as long as the server builds the school in a few seconds.
- The entity model's look, built from parts, close to `entity_model.gd`.
- Picking free Creator Store sounds (or leaving ids empty).
- UI layout of the lobby, HUD and meeting panels.
