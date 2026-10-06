# The Empty School (HORROR-GAME)

A first-person 3D horror game set in the Neumann school, built with Godot 4.7.

Magyarul: [README.hu.md](README.hu.md)

Five days at the Neumann school. Something in the building is not what it seems. Attend your lessons, watch the teachers, and find out who it is before it finds you.

Status: playable demo. Rooms marked "Not available in the demo." stay closed.

## How to run

1. Install [Godot 4.7](https://godotengine.org/download) (standard build, no .NET needed).
2. Clone the repository.
3. In the Godot Project Manager, choose Import and select `HORROR-GAME/project.godot`.
4. Let the first import finish, then press F5 (Run Project).

Notes:
- A fresh clone runs as is. The staff roster falls back to `scripts/staff_placeholder.gd`, which holds invented names only.
- On Windows the renderer uses Direct3D 12. Other platforms use Godot's default driver.
- Export presets and builds are not committed (`export_presets.cfg` and `build/` are gitignored). Create your own export preset in Godot to build an executable or APK.

## Controls

| Key | Action |
|---|---|
| W, A, S, D | Move |
| Shift | Sprint (limited stamina, refills when you stop) |
| Mouse | Look |
| F | Flashlight (battery-limited) |
| Q | Phone |
| Tab | Next phone page: map, tasks, clues, finds, neu_mecha |
| Left / Right arrow | Switch the floor on the phone map |
| E | Interact: doors, items, teachers, lockers |
| Space | Hold breath while hiding in a locker |
| G | Name the entity (from day 4) |
| 1 to 4 | Pick a dialog choice |
| Esc | Pause menu |
| R | Restart after an ending |

## The school

- Three floors built in code from floor plan data (`scripts/floor_data.gd`), with corridors, stairwells, classrooms, computer rooms, WCs, the Aula and the Porta desk.
- Furniture is procedural: desks, chairs, boards, PCs, cabinets and toilet stalls.
- Six photo textures (`textures/`) cover walls, floors, ceilings, doors, lamps and the blackboard. Other materials and all sounds are generated at runtime.

## The five-day campaign

- **Days 1 to 3: school days.** The day opens at 06:00. Bells ring for 7 lessons. Walk to the right room in time and answer a 3-question quiz. Skip 6 lessons and you are expelled. After the last bell you go home through the front door, or stay and risk the caretaker.
- **Day 4 and day 5: hunt days.** There are no lessons. You name the teacher you suspect. If you are right, the story quest unlocks and the entity hunts you.
- **Day and night.** Lamps flicker at dusk. Nights are nearly pitch dark, so the flashlight is the only reliable light.

### Lessons and quizzes

Seven subjects (Maths, Literature, Programming, Physics, History, English, Networks), each with its own room, teacher and question pool. The timetable changes every school day. Your quiz score counts towards the best ending.

### Deduction

One of eight invented teachers is the entity, picked at random each run. Teachers talk when you press E. Clues hidden around the school each point to exactly one teacher, and the culprit lets more strange lines slip each day. Read the clues on your phone, then press G to accuse.

### Exorcism quest

Four chained tasks end in a ritual at the Aula altar:

1. Get the storage key at the Porta (borrow it or steal it), open the red locked room, take the salt and the fuse.
2. Put the fuse in the fuse box to power the lab cabinet, get the lab key from the Porta board, take the holy water.
3. Find four hidden notes, work out the safe code, open the old safe on the second floor, take the silver bell.
4. Place the salt, holy water and bell on the altar, then survive the ritual at night (40 seconds).

On day 5 the altar also offers a deal with the demon.

## Characters

- **The entity:** a tall, pale figure with glowing eyes. It is inert in daylight and wakes at night. It patrols every floor on a navigation mesh, investigates sprint noise and chases on sight. Hide in a locker to break its line of sight.
- **Teachers:** follow daily routines, stand in their rooms during lessons and leave the building at dusk. Background teachers fill the corridors on school days.
- **The caretaker:** patrols after hours. If he catches you, you are expelled.
- **Csoki:** the caretaker's dog. It barks when the entity or the caretaker is near. A dog biscuit makes it follow you.
- **The porter:** stands behind the Porta desk, lends keys and checks student cards.
- **Students:** a crowd sits in classrooms during lessons and walks the corridors during breaks.

All character names in the committed code are invented.

## Endings

| # | Ending | How |
|---|---|---|
| 1 | Caught | The entity catches you while it hunts. |
| 2 | Banished | You complete the ritual. |
| 3 | Expelled | Too many skipped lessons, the caretaker catches you, or a school day closes with you still inside. |
| 4 | Top student | You complete the ritual with at least 80% quiz score and 9 clues. |
| 5 | Ran away | You leave through the front door before the last bell, or on a hunt day. |
| 6 | Pact | You make the deal at the altar. |
| 7 | Overtime | Day 5 ends without an answer. |
| 8 | Wrong person | You accuse the wrong teacher. |

## Extras

- Achievements and seen endings, saved with your settings in `user://profile.cfg`.
- Settings: volume, mouse sensitivity, field of view, brightness, easy map (shows your position on the phone map) and scare flashes.
- The daily neu_mecha feed on the phone: each day a post hides a mecha chameleon somewhere in the school.
- Hidden pages, secrets and cards to find (phone page "Finds").

## Experimental features

These features exist in the code but are early and untested on real hardware:

- **Touch controls (Android):** an on-screen joystick, a look area and buttons for F, Q, E, Tab and Esc. Mobile devices use a lower render scale.
- **Co-op (up to 4 players):** Host Co-op and Join Co-op in the main menu, with a lobby, a ping marker (middle mouse button) and proximity voice. Join currently connects to the same computer only (127.0.0.1).
- **VR (OpenXR):** the game switches to VR when an OpenXR runtime is present, otherwise it runs in standard mode.

## Code layout

| Path | What it holds |
|---|---|
| `scenes/main.tscn` | Main scene. `scripts/main.gd` builds the school, places story objects and runs the HUD and game flow. |
| `scripts/campaign.gd` | Days, bells, lessons, stats, the culprit and endings. |
| `scripts/quest.gd` | The four-step exorcism quest. |
| `scripts/player.gd` | First-person controller, flashlight, phone, interaction. |
| `scripts/horror_entity.gd` | Entity AI: idle, patrol, chase, attack. |
| `scripts/teacher_npc.gd`, `staff_manager.gd`, `caretaker.gd`, `porter.gd`, `csoki.gd`, `crowd.gd` | NPCs. |
| `scripts/lessons.gd`, `lesson_ui.gd`, `clues.gd`, `endings.gd` | Game data and their UI. |
| `scripts/floor_data.gd`, `rooms.gd`, `furniture.gd`, `textures.gd`, `sound_bank.gd` | World, materials and procedural sound. |
| `scripts/menu.gd`, `settings_ui.gd`, `profile.gd`, `achievements.gd` | Menus, settings and saved profile. |
| `scripts/staff_source.gd` | Loads the gitignored `scripts/staff.gd` when present, else the committed placeholder. |
| `scripts/net_session.gd`, `input_bridge.gd`, `touch_controls.gd`, `xr_manager.gd` | Co-op, touch and VR. |
