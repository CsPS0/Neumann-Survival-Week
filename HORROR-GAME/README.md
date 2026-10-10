# The Empty School (HORROR-GAME)

A first-person 3D horror game set in the Neumann school, built with Godot 4.7.

Five days at the Neumann school. Something in the building is not what it seems. Attend your lessons, watch the teachers, and find out who it is before it finds you.

Status: playable demo. Rooms marked "Not available in the demo." stay closed.

## How to run

1. Install [Godot 4.7](https://godotengine.org/download) (standard build, no .NET needed).
2. Clone the repository.
3. In the Godot Project Manager, choose Import and select `HORROR-GAME/project.godot`.
4. Let the first import finish, then press F5 (Run Project).

Notes:
- A fresh clone runs as is. The staff roster falls back to `scripts/staff_placeholder.gd`, which holds invented names only.
- Two named students (in the player's class during lessons, in the corridors during breaks) show a face wrapped over the head with three expressions: neutral in lessons, smile in breaks, sad once the entity is awake. The real names and photos are gitignored (`scripts/student_faces_local.gd` and `assets/faces_local/`). A fresh clone falls back to `scripts/student_faces_placeholder.gd`, which holds invented names and generated faces.
- On Windows the renderer uses Direct3D 12. Other platforms use Godot's default driver.
- Export presets and builds are not committed (`export_presets.cfg` and `build/` are gitignored). Create your own export preset in Godot to build an executable or APK. Tagged releases are built by GitHub Actions, see Releases below.

## Controls

| Key | Action |
|---|---|
| W, A, S, D | Move |
| Shift | Sprint (limited stamina, refills when you stop) |
| Mouse | Look |
| F | Flashlight (battery-limited) |
| Q | Phone |
| H | Phone mode: one hand (map and tasks, the light stays on) or two hands (full screen, every app, no light) |
| B | Drop the bag, or pick a dropped bag up again within 2.2 m (E on the bag works too) |
| X | Switch the active hand, left or right (phone and torch swap sides) |
| V | Put the item in your hand into a pocket or the bag, or take the next stored item into the empty hand |
| Tab | Phone up: next phone app (map, tasks, clues, finds, neu_mecha, e-Kréten, Diákhirdetmények). Phone down: show or hide the inventory list |
| Left / Right arrow | Phone: floor on the map, section in e-Kréten, list position on the notice board |
| + / - or mouse wheel | Phone: zoom the map (other apps: scroll the list) |
| I, J, K, L | Phone: pan the zoomed map, scroll lists with I and K |
| E | Interact: doors, items, teachers, lockers |
| Space | Hold breath while hiding in a locker |
| G | Name the entity (from day 4) |
| 1 to 4 | Pick a dialog choice |
| Esc | Pause menu |
| R | Restart after an ending |

### Carrying items

- You have one active hand, two pockets (one item each) and a bag on your back (8 slots). New items go to the hand, then the pockets, then the bag.
- The bag weighs 3 kg empty and more with items. Each kg slows you by 3%, up to 30%. Drop it (B) to move at full speed.
- Items in a dropped bag are out of reach: doors, the porter and the ritual do not see them. Pick the bag up again to use them.
- If everything is full, ordinary pickups are refused. Keys from the porter and story items are never lost: they go into your hand. Keys prefer a pocket, then the bag.
- The phone needs the active hand: an item you hold goes into a pocket or the bag when you raise it.
- One-hand phone: map and tasks only, no zoom or pan, and the light stays on. Two-hand phone: the phone fills the screen with every app, but the light goes out until you lower it or press H.

## The school

- Three floors built in code from floor plan data (`scripts/floor_data.gd`), with corridors, stairwells, classrooms, computer rooms, WCs, the Aula and the Porta desk.
- Furniture is procedural: desks, chairs, boards, PCs, cabinets and toilet stalls.
- Six photo textures (`textures/`) cover walls, floors, ceilings, doors, lamps and the blackboard. Other materials and all sounds are generated at runtime.

## The five-day campaign

- **Days 1 to 3: school days.** The day opens at 06:00. Bells ring for 7 lessons. Walk to the right room in time and answer a 3-question quiz on a paper answer sheet. Skip 6 lessons and you are expelled. After the last bell you go home through the front door, or stay and risk the caretaker.
- **Day 1: the explosion.** The morning is calm. After the third lesson Lab 14 explodes, the alarm rings and everyone is sent home. You choose: go home, or stay and find out what happened. The lab door is blown open until the next morning, but the caretaker patrols.
- **Day 2 onwards: the outbreak.** The chemistry club's strange object has cracked and something left it. Some teachers and students fall ill (green skin, coughing, slumped at their desks). The teacher who hosts the demon never falls ill. Lab 14 is sealed again and the cracked object sits on its table.
- **Day 3: test day and the haunting.** Every lesson is a 4-question test. The new student card is handed out at the Porta today and expires at midnight. The demon starts to prank you: flickering lights, a knock, a slammed door, a whisper and a short blackout flash. None of it hurts you.
- **Day 4 and day 5: hunt days.** There are no lessons. You name the teacher you suspect. If you are right, the story quest unlocks and the entity hunts you. The clock runs faster until nightfall (3x on day 4, 4x on day 5), so there is less time to collect proof. You can finish the game on day 4 or day 5: the ritual only needs night.
- **The dream.** Once a day on the hunt days you fall asleep at your desk and the demon follows you into the dream. Run to the front door within 60 seconds to wake up and keep a new clue. If it catches you or time runs out, you wake up late and lose 40 minutes. A dream never kills you.
- **Cure or destroy.** When the ritual ends, the possessed teacher lies on the floor of the Aula. You choose to cure them (ending 2 or 4) or destroy the body with the demon (ending 9).
- **Day and night.** Lamps flicker at dusk. Nights are nearly pitch dark, so the flashlight is the only reliable light.

### Lessons and quizzes

Seven subjects (Maths, Literature, Programming, Physics, History, English, Networks), each with its own room, teacher and question pool. The timetable changes every school day. You type each answer on the sheet and press Enter. Case, spaces and accents do not matter, and some questions accept more than one wording. Decisions (the accusation, the altar, the Porta lists) still use the numbered choice list, and VR keeps the choice list for quiz questions too. Your quiz score counts towards the best ending.

### Classrooms and keys

Every classroom, computer room and the gym is locked at the start of each day. The WCs, the Porta and the entrance hall stay shut but unlocked. The teacher opens each of the seven lesson classrooms 5 minutes before its lesson and locks it again after the lesson, once you are out of it. On hunt days they stay locked. To get in at any other room or time, ask the porter for a key:

- The key board in the Porta has a hook for every room number from 1 to 300 in order, then GT1 to GT50. A key hangs only on the hook of a room that exists, and it leaves the hook while you hold it.
- A key is a physical item. The porter and the board put it in a pocket first, then the bag, and the hand only when both are full. A key in a dropped bag is out of reach, so pick the bag up before you open a door or hand the key back.

- You sign for the key and the porter writes down the time.
- You hold one signed key at a time. Bring it back before you ask for another.
- Close the room before you hand the key back. With the key on you, closing an open door also locks it.
- The porter never lends key 14.


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
- **The porter:** stands behind the Porta desk, lends keys against a signature, takes them back once the room is closed, and checks student cards.
- **Students:** a crowd sits in classrooms during lessons and walks the corridors during breaks.

All character names in the committed code are invented.

## Endings

| # | Ending | How |
|---|---|---|
| 1 | Caught | The entity catches you while it hunts. |
| 2 | Banished | You complete the ritual and cure the teacher. |
| 3 | Expelled | Too many skipped lessons, the caretaker catches you, or a school day closes with you still inside. |
| 4 | Top student | You complete the ritual and cure the teacher with at least 80% quiz score and 9 clues. |
| 5 | Ran away | You leave through the front door before the last bell, or on a hunt day. |
| 6 | Pact | You make the deal at the altar. |
| 7 | Overtime | Day 5 ends without an answer. |
| 8 | Wrong person | You accuse the wrong teacher. |
| 9 | Destroyed | You complete the ritual and destroy the host. |

## Extras

- Achievements and seen endings, saved with your settings in `user://profile.cfg`.
- Settings: volume, mouse sensitivity, field of view, brightness, easy map (shows your position on the phone map) and scare flashes.
- The phone holds the tasks, so the HUD only shows the day, floor, time, battery and what is in your hand. The map zooms up to 6x and follows you when the easy map is on.
- e-Kréten on the phone, a copy of the e-Kréta school system: today's timetable, grades from your quizzes and the day 3 test, absences and messages from the school. All data is invented.
- Neumann Diákhirdetmények on the phone, a student notice board: lost items that hint where a collectible lies (marked found once you have it) and news that adds lore. New posts arrive every day.
- The daily neu_mecha feed on the phone: each day a post hides a mecha chameleon somewhere in the school.
- Hidden pages, secrets and cards to find (phone page "Finds").

## Experimental features

These features exist in the code but are early and untested on real hardware:

- **Touch controls (Android):** the overlay shows by itself on Android and hides while a menu, dialog or the safe keypad is open, or when a physical keyboard or mouse is used. Left half of the screen: floating stick (push to the edge to sprint). Right half: look. Buttons: E, F, Q, Tab, Hands, Bag, Swap, Stow, Pause (the Back button also pauses), Name (day 4), Ping (co-op), hold breath while hiding, and on the phone: floor, zoom and pan. The answer sheet has a Hand in button, the safe has a keypad and the ending card has a Play again button. Try it on a desktop with `godot --path . -- --touch`. Mobile devices use a lower render scale and the game runs in landscape.
- **Co-op (up to 4 players):** Host Co-op and Join Co-op in the main menu, with a lobby, a ping marker (middle mouse button) and proximity voice. Join currently connects to the same computer only (127.0.0.1).
- **VR (OpenXR):** the game switches to VR when an OpenXR runtime is present, otherwise it runs in standard mode.

## Code layout

| Path | What it holds |
|---|---|
| `scenes/main.tscn` | Main scene. `scripts/main.gd` builds the school, places story objects and runs the HUD and game flow. |
| `scripts/campaign.gd` | Days, bells, lessons, stats, the culprit and endings. |
| `scripts/quest.gd` | The four-step exorcism quest. |
| `scripts/player.gd` | First-person controller, flashlight, phone, interaction. |
| `scripts/inventory.gd` | Hand, pockets and bag: slots, weight and the speed penalty. `scripts/dropped_bag.gd` is the bag on the floor. |
| `scripts/horror_entity.gd` | Entity AI: idle, patrol, chase, attack. |
| `scripts/teacher_npc.gd`, `staff_manager.gd`, `caretaker.gd`, `porter.gd`, `csoki.gd`, `crowd.gd` | NPCs. |
| `scripts/lessons.gd`, `lesson_ui.gd`, `answer_sheet.gd`, `clues.gd`, `endings.gd` | Game data and their UI. The answer sheet is the paper the quiz answers are typed on. |
| `scripts/floor_data.gd`, `rooms.gd`, `furniture.gd`, `textures.gd`, `sound_bank.gd` | World, materials and procedural sound. |
| `scripts/phone_viewmodel.gd`, `phone_map.gd`, `ekreta.gd`, `bulletin.gd` | The phone: its apps, map zoom, and the data behind e-Kréten and the notice board. |
| `scripts/menu.gd`, `settings_ui.gd`, `profile.gd`, `achievements.gd` | Menus, settings and saved profile. |
| `scripts/staff_source.gd` | Loads the gitignored `scripts/staff.gd` when present, else the committed placeholder. |
| `scripts/net_session.gd`, `input_bridge.gd`, `touch_controls.gd`, `xr_manager.gd` | Co-op, touch and VR. |

## Releases

Pushing a tag that starts with `demo` or `v` builds the game and publishes a GitHub Release. Branch pushes and pull requests never start a build. Git tags cannot contain spaces, so use `demo-1.0` instead of `demo 1.0`.

```
git tag demo-1.0
git push origin demo-1.0
```

- The workflow is `.github/workflows/release.yml`. It uses the CI export presets in `.github/godot/export_presets.ci.cfg`.
- Linux, Windows and Windows VR zips are always built. Tags that start with `demo` are marked as pre-releases.
- The build uses the committed placeholder roster and student faces, never real names.
- Android and Quest APKs need three repository secrets: `ANDROID_KEYSTORE_BASE64` (the release keystore encoded with base64), `ANDROID_KEYSTORE_USER` (the key alias) and `ANDROID_KEYSTORE_PASSWORD`. Without them those two builds are skipped.
