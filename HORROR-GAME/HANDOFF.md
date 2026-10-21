# Handoff: continue the horror game in a new chat

Open the new chat **in `D:\Projects\PROJECTS\Neumann-Survival-Week\HORROR-GAME`** so the rules in `AGENTS.md` / `CLAUDE.md` load.
Engine: **Godot 4.7.2** (executable at `D:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe`).

## Where things stand
- Godot 4.7.2 first-person horror game in the Neumann school, three floors built from `docs/floor-plans/` via `scripts/floor_data.gd`.
- It is a **five-day campaign** (spec `docs/specs/2026-10-01-five-day-campaign-design.md`, plan `docs/plans/2026-10-01-five-day-campaign.md`):
  - Days 1-3 are school days: 7 lessons (07:30 start, 45 min + 10 min breaks, last bell 13:45). Be in the room within 2 game minutes (about 15 s) of the bell to take a 3-question quiz; skipping 6 lessons gets you expelled. Three clues per day (a classroom, the staff office, a room unlocked at the last bell). Scripted day encounters (glimpses, chases) and an after-hours caretaker. The entity cannot kill: a catch is a blackout.
  - Day 4: accuse the teacher who is the entity (G key). Wrong = ending 8. Right starts the hunt and the old story chain (salt, holy water, bell, altar ritual). Day 5 adds the altar pact.
  - 8 endings, achievements, saved settings, main menu with settings/achievements/endings pages.
- The building is built 1.25x larger than the plan measurements (`FloorData.WORLD_SCALE`, one knob). Plan-tied metre constants in `main.gd` scale with it, human-sized ones do not (see `AGENTS.md` Gotchas).
- **The people layer** (spec `docs/specs/2026-10-02-staff-students-csoki-design.md`, plan `docs/plans/2026-10-02-staff-students-csoki.md`) fills the school on school days (1-3; days 4-5 are hunt days with nobody but the entity, the caretaker and Csoki):
  - **8 invented suspects** (`lessons.gd`): the only possible entity, the only teachers who talk and give clues, one of them teaches each subject (`teacher_of(subject, day)`; maths alternates). Their names are not in the roster and share no roster surname.
  - **79 real roster people** (`staff.gd`, from `docs/data/staff-roster.txt`): friendly background only, never the entity. At most 8 exist at once as ambient teachers (`staff_manager.gd`), near the player: stationed in the nearby classrooms during a lesson (the class's homeroom teacher where it has one), walking a corridor in a break. They never talk. Group `ambient_staff`.
  - **564 students in 21 classes** (`Classes.size_of` summed) (`classes.gd`, `crowd.gd`): one MultiMesh crowd, at most 150 drawn. Lessons: the classes near the player sit in their rooms (the player's own class is `11.a`: 24 classmates plus the player). Breaks: walkers on the corridor polylines. They panic and hide near a visible entity and a scream plays.
  - **Csoki** (`csoki.gd`): the caretaker's dog in the ground-floor hall, barks at the visible entity or the nearby caretaker, can be petted ("good_boy" event). Collision layer 16, group `csoki`.
  - Caps: 8 suspects + 8 ambient = 16 teachers, `MAX_CROWD = 150`, 1 dog. Performance probe (below) on the dev machine (RTX 3070, vsync off): 1.2 to 2.9 ms average frame at the three busiest spots, so the caps were not lowered.
- **The demo update** (spec `docs/specs/2026-10-02-demo-update-design.md`, plan `docs/plans/2026-10-02-demo-update.md`):
  - **Stamina:** sprint lasts about 5 s, refills in about 8 s after a 1 s pause; exhausted until 30 %. A thin bar under the status text (top left).
  - **Scare flash:** a split-second black frame and a sting when the entity shows up; while it is around every other NPC
    (teachers, ambient staff, Csoki, the porter, the crowd) vanishes. 20 s cooldown, "Scare flashes" setting.
  - **Phone map:** the whole floor, no "you are here" (Left/Right switch floors); the "Easy map" setting brings the marker back.
    The phone has 5 pages: map, timetable/tasks, clues, finds, neu_mecha.
  - **Honest rooms, locked-down demo** (`rooms.gd`): normal/computer/wc/gym/entrance rooms are open; every `other` room is
    closed ("Not available in the demo"), no key opens it, NPCs never path into it. Lessons moved to open rooms
    (Maths 23, Physics 28, Literature 113, English 121, History 109, Programming GT11-12, Networks GT2). Fixed story rooms:
    fuse box 24, old safe 229, staff clue 33, Lab 14; after-hours clue rooms 205, GT8, 114.
  - **Day 1 story:** the opening ("something happened in Lab 14"), the student card sticker (find the signed form in a
    1st-floor classroom, give it to Mr. Bakó at the Porta, or the card expires at midnight and he lends nothing from day 2),
    and Lab 14: key 14 is never lent, it has to be stolen from the key board while the porter is away (breaks 2, 4, 6 or
    the "leak in the WC" trick). Three lab pages finish the Lab 14 task. The red room key now comes from the Porta too.
  - **Finds:** 12 pages, 5 secrets, 8 teacher cards on corner tables (Finds page on the phone), batteries, three dog
    biscuits (Csoki follows you for 3 game hours), a master key card (opens the day's after-hours door once), and the
    daily **neu_mecha** chameleon: one figure a day with a rendered photo in the feed and a small reward.
- **Furniture** (`scripts/furniture.gd`, procedural, built before the navmesh bake): every open classroom has rows of
  desks and chairs, a teacher's desk, a board and (where free) a cabinet, radiator and bin; GT rooms have PCs (rows or
  along the side walls, emissive screens, a teacher PC); every WC has 3-5 stalls with toilets, 2-3 sinks, a mirror
  strip and a bin, with a clear strip from the door to the far wall. Students sit on the chairs (`crowd.seats`). Rules
  for adding more are in `AGENTS.md` ("Furniture").
- Verified: tests t01-t36 all PASS headless, boot check clean, `perf.gd` PASS in a window (1.7-3.1 ms average frame at
  eight spots on the dev machine, including a classroom, a GT room and a WC; furniture added about 60 draw calls in the hall), the Windows exe rebuilt and started. Not verified: sound by ear, other machines,
  the real garden (it is a closed door in the demo).

## Tests
The test scripts are **not in the repo** (never committed): they live in `C:\Users\solti\AppData\Local\Temp\neu-tests\`.
`t01_campaign` ... `t14_scale` are the campaign and world tests. The people layer added `t15`-`t23`, the demo update `t24`-`t33`, teacher bodies and faces `t35` (`t34_doorgap` is a door-gap regression test):

| Test | Asserts |
|---|---|
| `t15_roster` | the roster file has 79 rows, `staff.gd` matches it, 21 homeroom classes, no contact data, name policy |
| `t16_suspects` | 8 distinct invented suspects, 9 distinct clues each, `teacher_of`, culprit is a suspect, 8 teachers spawn, accusation list |
| `t17_classes` | 21 classes and their sizes, at least 22 classrooms with real rects, no two classes share a room, 11.a is in the lesson room, corridor and `csoki` data |
| `t18_crowd_lessons` | seated crowd per lesson, cap 150, nobody within 1 m of the player or on a table, none before school, after the last bell or on hunt days |
| `t19_crowd_flow` | corridor walkers in breaks, few before school, cap, panic near an awake entity, one scream, return when it sleeps, empty after the last bell |
| `t20_staff_manager` | ambient teachers in breaks and lessons, roster names only, no suspects, no duplicates, total teachers <= 16, they move and are kept (not teleported) when the player steps |
| `t21_csoki` | bark sound, layer 16, group `csoki` only, ray hits the dog but the player walks through it, marker reachable, walks around, barks once near the entity |
| `t22_full_people` | day 1 end to end: every 10 game minutes teachers <= 16, ambient <= 8, crowd <= 150, one Csoki, 8 suspects; the day-1 bell glimpse hides and returns the students; day 2 has no stale ambient teachers; day 4 after the accusation has no crowd, no ambient teachers, no culprit node, a quiet Csoki; culprit always a suspect over 20 campaigns |
| `t23_final_fixes` | final-review fixes: ambient E label has no repeated word, every corridor segment of all floors is wall-free (ray probe, lanes and heights) with vertices on the navmesh, the dog is silent behind an ending card, 11.a is 25, stationed teachers keep off clue tables, break teachers are not freed and respawned |
| `t24_stamina` | drain, 1 s delay, refill, exhaustion at 0 until 30, revive refill, HUD bar, `out_of_breath` at 10 exhaustions |
| `t25_scare_flash` | trigger hides teachers/Csoki/crowd, black frame, cooldown, return after the entity sleeps, blocked behind a choice list or an ending, setting off = no black frame, bad config value falls back |
| `t26_map` | whole-floor fit for each floor, Left/Right floor switch, no marker unless "Easy map" |
| `t27_rooms` | room types, lessons in open rooms, every `other` door demo-locked and never opened, barrier message, navmesh reachability of all 45 open rooms and none of the 70 closed ones, story objects and clue spots in open rooms |
| `t28_finds` | 25 finds, table placement (in the room, clear of walls, door swing, other tables), carved and reachable, counted once, achievements, the red room never a find room (300 re-rolls) |
| `t29_porta` | lending, no key 14, stealing and the 6 m sight rule, board lock, distraction, break trips, stuck porter returned, day-5 night doze, no key opens a demo door, the key board UI (only 1-9 pick, Leave) |
| `t30_day_one` | opening, form room upstairs and reachable, sticker through the porter menu, card expiry on day 2, the steal path still finishes the story, the vial needs the hunt and the fuse |
| `t31_items` | batteries, biscuits, master key card placement; the card never opens a demo door or Lab 14; Csoki follows and stops |
| `t32_mecha` | one figure per day, placement, reward and fallbacks, feed posts, `mecha_master` |
| `t33_full_demo` | the whole demo end to end: day 1 story in order (opening, sticker, key, key 14 stolen at break 2, lab pages, finds of each kind, mecha, biscuit for Csoki, a caught steal), all 21 lessons, days 2-3, the day-4 hunt chain through the fixed rooms, the day-5 ritual and its ending; sample-point checks (demo doors, nothing in closed rooms, stamina, scare flash during the glimpse, caps, one Csoki and one porter); a second run without the sticker finishes by stealing |
| `t36_furniture` | furniture in every open classroom (teacher desk, 12+ desks), GT room (8+ PCs) and WC (3+ toilets, 2+ sinks, mirror); none in Lab 14, the Porta or closed rooms; clear of door swings, every table and story object, the room centre and the ambient fallback station, the WC door strip; spawn reaches every room centre and each room's door reaches its tables; one seat per desk, every seated student on a chair, 24 in room 23; lesson rooms seat 24 (GT2 12+) |
| `t35_bodies` | every named person has a gender tag, stable name-seeded faces (twice and across two fresh scenes), 3+ skin tones and hair colours across the suspects, female vs male body with the same capsule, <= 40 meshes, shared materials, scare flash turns NPC collision off and restores each layer |
| `perf.gd` | **non-headless** frame-time probe (not a pass/fail regression test): eight spots (ground-floor hall in a break, the player's classroom mid-lesson, a 1st-floor corridor in a break, the Porta with the porter and the key board, Lab 14 with its pages, classroom 121, GT11-12 and the 1st-floor WC mid-lesson), prints fps, average frame ms, script+physics ms, draw calls and live counts, `PERF PASS` when every average is under 12 ms and neither the scare flash nor a day start (teacher respawn, mecha photo render) has a frame over 30 ms |

If the scripts are gone, recreate them from the plan (each task lists what its test asserts) using the template in its "Global Constraints". Pattern: `extends SceneTree`, instance `res://scenes/main.tscn`, set `main.profile.path` to a `user://neu_test_*.cfg` file, await a timer, call `main._start_game()`, drive the clock with `main.daynight.minutes`, answer quizzes with `main.choice_ui.chosen.emit(i)`, assert, print `PASS`. `perf.gd`: same start, then `DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)`, put the player at each spot, wait 3 s, accumulate frame times with `Time.get_ticks_usec()` across `await process_frame` for 5 s, print `Performance.get_monitor(Performance.TIME_PROCESS)`, `TIME_PHYSICS_PROCESS` and `RENDER_TOTAL_DRAW_CALLS_IN_FRAME`; run it without `--headless`.

```
GODOT="C:/Users/solti/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
T="C:/Users/solti/AppData/Local/Temp/neu-tests"
for t in "$T"/t[0-9]*.gd; do echo "== $t"; "$GODOT" --headless --path . --script "$t" 2>&1 | grep -E "PASS|FAIL|SCRIPT ERROR|Parse Error"; done
"$GODOT" --headless --path . res://scenes/main.tscn --quit-after 240   # banner only = clean
"$GODOT" --path . --script "$T/perf.gd"                                  # window; PERF PASS
```
Godot exits 0 even on errors: read the output, each test must print `PASS` and nothing red (navmesh and ObjectDB-leak warnings are harmless; `t09` prints one intentional parse-error line). `t12_full`, `t22_full_people`, `t33_full_demo` and the whole set take minutes: run them in the background.

## Open items
- Play it in the editor once (F5): the real-time feel of the 75 s breaks, the caretaker's difficulty, the crowd and the sounds have never been judged by a human.
- Teachers have male/female bodies and procedural low-poly faces seeded from the name (`teacher_npc.gd` `face_params`,
  `staff.gd` `GENDER`). No real photos, by decision (privacy). Students are still faceless capsules.
- Candidate next steps: ambient audio, the real school drawing the user will supply (replace the plans in `floor_data.gd`), flashlight stuns the demon, faces for students.
- Rule files are git-ignored locally on purpose; nothing is committed. Never add yourself as contributor.

## Known small things (deferred on purpose)
- The `ending_N` toast and the completionist toast overwrite each other.
- The checkbox squares on the settings panel are hard to see.
- The caretaker never loses the player once spotted.
- A stale "Day N" message can still show under the ending card.
- `_deal_kind` is not reset when an ending fires.
- Stamina: the breathing sound keeps playing for a moment after a revive.
- Teacher bodies: the leg swing can poke through a skirt; gender is a given-name lookup in the staff generator (`gen_staff.py` in the tests folder).
- Scare flash: the restore sets `visible = true` on every teacher, ambient teacher, Csoki and the porter, so it assumes
  nothing else hides them; `main.gd` calls the private `_set_hidden`; the crowd runs `_apply([])` every frame while hidden;
  the flash and the panic scream never overlap (by design).
- Phone map: the ground floor is wide, so its small corridor-side rooms get tiny or
  no labels; the HUD objective text still names rooms when "Easy map" is off; a few long collapsed lines (`phone_map.gd`
  around 66/83/91, `player.gd:122`).
- Rooms: the garden door sits on the entrance hall's east wall, shared with the Porta (cosmetic); the room lists exist three
  times (`Classes.STORY`, `Rooms.STORY_ROOMS`, `main.RESERVED_ROOMS`); closed rooms keep small navmesh islands inside
  (the entity may pick a point there and stop at the door).
- Finds: teachers are not kept off find tables (harmless); the secret ids are generic (`toy`, `tape`, `photo`).
- Porta: the `go_away` timer runs while the game is paused; the break-2/4/6 trip is skipped if he is still walking back
  from a distraction; the sight ray ignores NPCs in between; the board
  lock ends at nightfall (he dozes) rather than the next morning; key 14 can also be stolen at night on days 1-3.
- Day 1: the form pickup stays after the card expired; `porta.has_form` duplicates the inventory; a toast
  can replace the opening text before its 7 s are up.
- Items: Csoki (layer 16, follows at 2.5 m) can catch the E press meant for a door; a second biscuit while it already
  follows is wasted; it keeps following after an ending; the master key card opens the day's after-hours clue room
  before the last bell (by design, so that clue can be taken early); the Finds page's "Items" count has no total.
- neu_mecha: the page reward leaves its page pickup in Lab 14 (re-readable, not counted twice); the chameleon is small
  in the photo; the photo's flash light lives in the shared world for 2 frames; `post_added`/`photo_for` are only used by
  tests.
- Crowd: corridors in `floor_data.gd` are separate polylines, not one connected network, so each walker keeps to its own line and nobody crosses between corridors or takes the stairs.
- Crowd: students sit on the furniture's chairs facing the board (or the wall PCs); a class bigger than its room's chair
  count is only partly drawn (GT2 seats 16, so the Networks lesson shows about 15 classmates), and the students are plain capsules with sphere heads, no faces or animation.
- Crowd: `_screamed` resets as soon as no student is panicked, so students walking out of the 25 m range can cause a second scream while the entity is still visible.
- Crowd: the corridor flow budget is split over the (up to 3) floors in range instead of only the player's floor; `_point_on` allocates an Array per walker per frame (`_advance` costs about 0.3 ms per call with about 100 walkers, 10 percent of a frame, so left alone).
- Ambient teachers: they are freed beyond `NEAR + 10` and respawn at every bell, so teachers at the edge of the range can pop in and out as the player walks.
- Csoki barks every 6 s for as long as the entity stays visible and within 20 m; the bark has no fade.
- The `halmos` first waypoint was moved from plan (453,440) to (453,420) to stay reachable; other fixed waypoints and the dog markers are plan coordinates too, so a layout change in `floor_data.gd` can strand one: re-run `t14_scale`, `t20_staff_manager` and `t21_csoki`.

## Gotchas
- Navmesh paths float above the floor; `main.gd` calibrates `path_height_offset` (`_nav_offset`, also used by teachers, ambient teachers, the dog and the caretaker). Corridors narrower than 2x agent radius (0.4) are impassable.
- Build clue and furniture tables before the navmesh bake.
- Tests that jump the clock must mark lessons resolved (`campaign._resolved.fill(true)`, `_ended.fill(true)`) or the 6-skip expulsion fires.
- Tests must never write `user://profile.cfg`: set `main.profile.path` to a `user://neu_test_*.cfg` first and delete it afterwards.
- Scripted tests: await a timer before reading nodes; write test scripts with the Write tool (the PowerShell tool mis-parses large here-strings).
- Ambient teachers are not in group `teachers`; Csoki is in neither. Count live ones with `is_queued_for_deletion()` filtered.

## Recent Features & Milestones Completed

1. **Finishing Touches (G1–G10 Tasks)**:
   - Door interaction priority over Csoki; dog biscuit waste prevention during follow.
   - Csoki follow reset after ending screens; phone "Items" count correctly reflects all batteries.
   - Neu_mecha page reward deduplication with Lab 14; signed form cleanup on expired card.
   - Scare flash individual NPC visibility restoration; porter trip timer pause synchronisation.
   - All 36 headless regression tests passing (`36 pass, 0 fail`).

2. **Mobile Readiness & Touch HUD**:
   - `scripts/input_bridge.gd`: Unified abstraction layer for Desktop (KBM), Mobile (Touch), and VR controller inputs.
   - `scenes/touch_controls.tscn` & `scripts/touch_controls.gd`: CanvasLayer 85 HUD with floating dynamic thumbstick, look drag surface, and buttons (Interact, Flashlight, Phone, Tab, Pause). Auto-detected and toggled.
   - `scripts/platform_config.gd`: Platform tiering and performance scaling.

3. **Co-op Multiplayer Architecture**:
   - `scripts/net_session.gd`: High-level multiplayer session manager (`ENetMultiplayerPeer`), LAN UDP beacon discovery, and 6-character room codes. Offline single-player fully preserved.
   - `scenes/player_puppet.tscn` & `scripts/player_puppet.gd`: Synchronized 3D student representations with flashlight beams and nametags.
   - Downed/Revive system: Downed state upon entity catch with 60s bleedout and 3s teammate revive interaction.
   - `scripts/proximity_voice.gd` & `scripts/ping_wheel.gd`: 3D spatial voice component and contextual ping markers.
   - `scripts/menu.gd`: "Host Co-op" and "Join Co-op" lobby UI.

4. **OpenXR VR Integration**:
   - `scripts/xr_manager.gd`: Dynamic OpenXR server runtime detection and initialization. Safe desktop fallback when no headset is detected.
   - `scenes/xr_player_rig.tscn` & `scripts/xr_player_rig.gd`: `XROrigin3D`, `XRCamera3D`, and motion-tracked hand controllers with torch aiming, physics ray interaction, and comfort vignette.

5. **Stealth & AI Perception**:
   - `scripts/hiding_spot.gd`: Lockers, under-desk spots, and WC stalls with breathing hold mechanics.
   - Multi-sensory entity AI perception: Sight cone, sound/footstep propagation, flashlight beam detection, hiding spot search probabilities.

6. **Authentic Reference Textures & 6×6 Tiling**:
   - Imported authentic Neumann school reference captures from `docs/textures/` into `textures/`:
     - `floor_real.jpg` (terrazzo floor tiles)
     - `wall_real.jpg` (ochre ceramic hallway wall tiles)
     - `door_real.jpg` (classroom wood door with real "23 tanterem" blue badge)
     - `ceiling_real.jpg` (wood-slat lambéria ceiling)
     - `blackboard_real.jpg` (maths chalkboard with real handwriting)
     - `lamp_real.jpg` (troffer fluorescent light fixture)
   - `scripts/textures.gd`: World-space triplanar mapping with 6×6 tiling grid (`uv1_scale = Vector3.ONE * 1.5`), yielding 6 repeating tile rows from floor to ceiling (4 m wall) and 6 tiles across corridor widths.
   - `scripts/furniture.gd`: Classroom chalkboards updated with `Textures.chalkboard()` without altering vertex or node counts.

7. **Dedicated Server VM Appliance (`TheEmptySchoolServer.ova`)**:
   - `server/vm/`: Minimal Debian 12 + Docker appliance, exports to `server/vm/output/TheEmptySchoolServer.ova` (~574.3 MB).
   - Hosts 4 isolated room containers (`neumann-room-1` through `neumann-room-4` on UDP 7777..7780), supporting up to 10 players each.
   - `server/vm/files/neumann-rooms`: Fixed IP routing detection (`ip -4 route get 1.1.1.1` excluding Docker bridge subnets) so the physical bridged IP and 4-digit room codes (`4535`, `0699`, `3742`, `4146`) appear immediately on the TTY1 console banner upon boot.
   - SSH pre-enabled (`neumann` / `neumann`) and keyed access configured.
   - Complete documentation in `server/README.md` and `server/vm/GUIDE.md`.

8. **Settings Menu Reorganization**:
   - `scripts/settings_ui.gd` & `scripts/menu.gd`: Reorganized settings into 4 clean categories with styled headers and separators:
     1. **Audio & Display**: Volume, Brightness, FOV, Fullscreen.
     2. **Controls**: Sensitivity, Invert Y.
     3. **Gameplay & Accessibility**: Easy Map (position marker), Scare Flashes.
     4. **Graphics & Performance**: Preset, Render Scale, Real-time Lamps toggle, Shadows, View Distance, AO & Fog, AA, VSync, FPS Limit.
   - Live formatted numeric value indicators beside all sliders (e.g. `30%`, `1.00x`, `100°`, `0.0025`, `250 m`, `60 FPS`).
   - Scroll view minimum height increased to 480 px.

9. **40-Player Full Concurrency Stress Test**:
   - Maxed out all 4 server rooms with 10 simulated clients each simultaneously (40 concurrent headless clients).
   - Simulated unoptimized low-end hardware & congested network: 15–20 FPS cap, 15–35 ms processing hitches, 4 Hz throttled position sync with jitter.
   - All 4 rooms played through to win conditions:
     - Room 1 (7777): Hide & Seek (Bot Seeker) — active evasion/hunt consensus.
     - Room 2 (7778): Hide & Seek (Player Entity) — Survivors Won.
     - Room 3 (7779): Social Deduction — Entity identified and ejected, Crew Won.
     - Room 4 (7780): Co-op Campaign — Progressed through Days 1 to 5, completed quizzes, gathered clues, accused culprit, completed Aula altar ritual, Players Won.
   - Measured server footprint at 40 concurrent players: ~38–41 MB RAM per room container (~160 MB for all 4 containers combined), ~10% total CPU on 1 virtual core. 0 disconnects, 0 socket errors.

## IRL School Deployment (USB Pendrive Guide)

**Rule: Never build the game at school.** School PCs lack administrative rights, Godot, and export templates, and school firewalls frequently block development mirrors.

Copy these to your USB drive before leaving home:
1. `server/vm/output/TheEmptySchoolServer.ova` (~574.3 MB): Imported into VirtualBox on the teacher PC (Network Adapter 1 -> Bridged Adapter).
2. `build/windows/TheEmptySchool.exe`: Standalone Windows client binary with embedded PCK (`embed_pck=true`). Runs directly on student PCs without installing Godot.
3. `VirtualBox-7.x.x-Win.exe` (optional fallback): Kept on the USB drive in case the teacher PC lacks VirtualBox.

## Context & Objectives for Claude

The user is switching to Claude to address gameplay issues, puzzle balance, and Polish in the school game.
- Focus areas for Claude:
  - Story & campaign flow (Days 1–5), clues, dialogues, and quiz questions in `campaign.gd`, `lessons.gd`, `clues.gd`.
  - Hungarian player-facing texts and tone (consistent with the rest of the game).
  - NPC/teacher behaviors, pathing, or student character models.
  - Gameplay balance (stamina, entity difficulty, item spots).
- Important rules for Claude:
  - Godot 4.7.2 only (`D:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe`).
  - Never add yourself or any AI as an author or contributor.
  - Do not touch `../RPG-GAME`, `../docs`, or `server/`.
  - Do not reset, stash, or reformat uncommitted files.
  - Always verify with the headless boot check (`$GODOT --headless --path . res://scenes/main.tscn --quit-after 240`) before reporting success.
  - The user will return to this session after your work to perform the final release builds (`TheEmptySchool.exe`) and packaging.

## Multi-Platform Builds

All 6 target presets are configured in `export_presets.cfg` and built into `build/<platform>/`:

| Platform | Preset Name | Command | Output Path |
|---|---|---|---|
| Windows | `Windows Desktop` | `$GODOT --headless --path . --export-release "Windows Desktop" "build/windows/TheEmptySchool.exe"` | `build/windows/TheEmptySchool.exe` |
| Linux | `Linux/X11` | `$GODOT --headless --path . --export-release "Linux/X11" "build/linux/TheEmptySchool.x86_64"` | `build/linux/TheEmptySchool.x86_64` |
| macOS | `macOS` | `$GODOT --headless --path . --export-release "macOS" "build/macos/TheEmptySchool.zip"` | `build/macos/TheEmptySchool.zip` |
| Android | `Android` | `$GODOT --headless --path . --export-debug "Android" "build/mobile/TheEmptySchool.apk"` | `build/mobile/TheEmptySchool.apk` |
| Windows VR | `Windows VR` | `$GODOT --headless --path . --export-release "Windows VR" "build/vr/TheEmptySchool_VR.exe"` | `build/vr/TheEmptySchool_VR.exe` |
| Meta Quest VR | `Android VR (Quest)` | `$GODOT --headless --path . --export-debug "Android VR (Quest)" "build/vr/TheEmptySchool_Quest.apk"` | `build/vr/TheEmptySchool_Quest.apk` |

Export notes:
- Output binaries live in `build/` (ignored by `.gitignore` and `.gdignore`; never commit them).
- Desktop platforms use S3TC/BPTC; Mobile and Quest use ETC2/ASTC.
- VR targets enable the `openxr` custom feature flag.
- Android uses `--export-debug` with the debug keystore for development.
- Desktop executables embed the `.pck` bundle (`binary_format/embed_pck=true`).

## First message to paste in the new chat
"Read HANDOFF.md and AGENTS.md, then confirm the project boots (`D:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . res://scenes/main.tscn --quit-after 240`). I want to fix some problems with the school game before returning to the other session for final build and export."


