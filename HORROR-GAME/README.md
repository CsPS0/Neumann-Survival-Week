# The Empty School (HORROR-GAME)

A first-person 3D horror game set in the Neumann school, built with Godot 4.7.

Five days at the Neumann school. Something in the building is not what it seems. Attend your lessons, watch the teachers, and find out who it is before it finds you.

Status: playable demo. Rooms marked "Not available in the demo." stay closed.

Contents:

- [How to run](#how-to-run)
- [Platforms and builds](#platforms-and-builds)
- [Controls](#controls)
- [The school](#the-school) and [the five-day campaign](#the-five-day-campaign)
- [Characters](#characters) and [endings](#endings)
- [Extras and graphics settings](#extras)
- [Co-op](#co-op) with [the school server VM](#the-school-server-vm-ova) and [troubleshooting](#co-op-troubleshooting)
- [Multiplayer modes](#multiplayer-modes)
- [Code layout](#code-layout) and [releases](#releases)
- Other documents: [build guide](docs/BUILD-GUIDE.md), [multiplayer design note](docs/multiplayer-modes.md), [server folder](server/README.md), [VM guide](server/vm/GUIDE.md), [handoff notes](HANDOFF.md)

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

## Platforms and builds

| Platform | Output | Status |
|---|---|---|
| Windows | One `.exe` with the data pack embedded (about 111 MB). Unsigned, so SmartScreen warns. | Built and checked on Arch with Godot 4.7.2. |
| Linux | One `.x86_64` file (about 75 MB). Needs a Vulkan driver. | Built and booted headless. |
| Windows VR | OpenXR build. | Not verified. |
| Android phone | Debug or release APK with touch controls. | Built. Not tested on a real phone. |
| Meta Quest | APK with the OpenXR rig. | Built. Not tested on a headset. |
| macOS | Unsigned build. | Not verified. Needs a local preset. |

- Builds are not committed. `export_presets.cfg` and `build/` are gitignored. The tracked preset file is `.github/godot/export_presets.ci.cfg`.
- The quickest build is `tools/build.sh` (Linux and macOS) or `tools/build.bat` (Windows), run from this folder. Both check Godot and the export templates, copy the CI presets and print a summary.
- Every command, prerequisite and Android note is in [docs/BUILD-GUIDE.md](docs/BUILD-GUIDE.md).
- Build the Windows client at home, not at school. School PCs usually have no Godot, no export templates and a restricted network.

## Controls

| Key | Action |
|---|---|
| W, A, S, D | Move |
| Shift | Sprint (limited stamina, refills when you stop) |
| Mouse | Look |
| F | Flashlight (battery-limited) |
| T | Flash burst: stuns the entity for 3 s when it is within 9 m and in front of you. Costs 15 battery, 12 s cooldown |
| Q | Phone |
| H | Phone mode: one hand (map and tasks, the light stays on) or two hands (full screen, every app, no light) |
| B | Drop the bag, or pick a dropped bag up again within 2.2 m (E on the bag works too) |
| X | Switch the active hand, left or right (phone and torch swap sides) |
| V | Put the item in your hand into a pocket or the bag, or take the next stored item into the empty hand |
| Tab | Phone up: next phone app (map, tasks, clues, finds, neu_mecha, e-Kréten, Diákhirdetmények). Phone down: open or close the inventory grid (equipped slots and bag). The hotbar at the bottom always shows the hand, both pockets and the bag |
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

- Three floors built in code from floor plan data (`scripts/floor_data.gd`), laid out after the school's fire evacuation plans: the ground floor has the west and east wings, four courtyards, the dining hall (Ebédlő), the Aula with four stairwells, the gym (Tornaterem), the entrance, the Porta desk and two WCs. The two upper floors have two roof terraces between two long corridors, with a cross hall, corner classrooms, computer rooms, WCs and stores. Plan coordinates are metres and north is up on every floor.
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
- Settings: volume, mouse sensitivity, field of view, brightness, easy map (shows your position on the phone map) scare flashes and graphics.
- Graphics: a Low, Medium or High preset, or each setting alone: render scale, real-time lamps, shadows, view distance, ambient occlusion and volumetric fog, anti-aliasing (off, FXAA, MSAA 2x), VSync and an FPS limit. The first start picks Low on integrated graphics and phones, High on a discrete card. With real-time lamps off, the school lamps and sun shadows are replaced by flat ambient light that still brightens by day, flickers at dusk and during pranks, and keeps a faint glow at night. The flashlight stays. For very old GPUs, start the game with `--rendering-method gl_compatibility --rendering-driver opengl3` to use the Compatibility renderer. That renderer has no ambient occlusion or volumetric fog. This path is untested on real hardware.
- The phone holds the tasks, so the HUD only shows the day, floor, time, battery and what is in your hand. The map zooms up to 6x and follows you when the easy map is on.
- e-Kréten on the phone, a copy of the e-Kréta school system: today's timetable, grades from your quizzes and the day 3 test, absences and messages from the school. All data is invented.
- Neumann Diákhirdetmények on the phone, a student notice board: lost items that hint where a collectible lies (marked found once you have it) and news that adds lore. New posts arrive every day.
- The daily neu_mecha feed on the phone: each day a post hides a mecha chameleon somewhere in the school.
- Hidden pages, secrets and cards to find (phone page "Finds").

## Experimental features

These features exist in the code but are early and untested on real hardware:

- **Touch controls (Android):** the overlay shows by itself on Android and hides while a menu, dialog or the safe keypad is open, or when a physical keyboard or mouse is used. Left half of the screen: floating stick (push to the edge to sprint). Right half: look. Buttons: E, F, Q, Tab, Hands, Bag, Swap, Stow, Pause (the Back button also pauses), Name (day 4), Ping (co-op), hold breath while hiding, and on the phone: floor, zoom and pan. The answer sheet has a Hand in button, the safe has a keypad and the ending card has a Play again button. Try it on a desktop with `godot --path . -- --touch`. Mobile devices use a lower render scale and the game runs in landscape.
- **Co-op:** Host Co-op and Join Co-op in the main menu, with a lobby, a ping marker (middle mouse button) and proximity voice. See [Co-op](#co-op).
- **Hide and Seek and Social Deduction (multiplayer):** from the Co-op lobby, one entity hunts the other players through the empty school, or one secret entity hides among the crew. See [Multiplayer modes](#multiplayer-modes).
- **VR (OpenXR):** the game switches to VR when an OpenXR runtime is present, otherwise it runs in standard mode.

## Co-op

Co-op uses Godot's ENet multiplayer over UDP. The game runs on each player's device. The host or server only relays positions and events. There are three ways to run a session:

| Way | Players | Use it when |
|---|---|---|
| A player hosts from the game | Up to 4 joining players | You play at home or on a small network. |
| A headless dedicated server (script or Docker) | Set with `--max-players` | A spare PC or server runs the room. |
| The school server VM (.ova) | 4 rooms with up to 10 players each by default | You host a class on the teacher's Windows PC. |

Social Deduction needs 3 to 5 players. Hide and Seek needs at least 2 players when a player is the entity.

### Host and join from the game

1. The host chooses Host Co-op. The lobby shows a four digit room code (for example `4821`) and an address (for example `192.168.1.20:7777`).
2. Other players choose Join Co-op, then type the code or the address and press Join. Rooms found on the local network also appear as buttons.
3. Any player in the lobby starts a match mode. See [Multiplayer modes](#multiplayer-modes).

How the room code works:

- The code has four digits. The host announces its code and address by UDP broadcast on the local network (port 7778). A joining player broadcasts a query and the host that holds the code answers with its address.
- A code therefore works for players on the same Wi-Fi or network, and for a host on the same computer. For players on another network, use the address.
- A host picks a code that no room on its network announces. If two hosts end up with the same code, the host with the larger address picks a new code and the lobby shows it.

### Dedicated server

A headless server needs no window and does not play. Players join it like any host. Start it with the Godot 4.7 binary, from this folder:

| Platform | Command |
|---|---|
| Windows | `server\run-server.bat --port 7777 --max-players 4` |
| Linux and macOS | `server/run-server.sh --port 7777 --max-players 4` |
| Any | `godot --headless --path . res://scenes/dedicated_server.tscn -- --port 7777` |
| Docker | `docker compose -f server/docker-compose.yml up --build` |
| Docker (plain) | `docker build -f server/Dockerfile -t empty-school-server .` then `docker run --rm -p 7777:7777/udp -e NEUMANN_PUBLIC_HOST=203.0.113.5 empty-school-server` |

The scripts use `godot` from the PATH. Set `GODOT` to the binary path otherwise, for example `/Applications/Godot.app/Contents/MacOS/Godot` on macOS. Options: `--port`, `--max-players`, `--public-host`, `--code`. Docker reads `NEUMANN_PORT`, `NEUMANN_MAX_PLAYERS`, `NEUMANN_PUBLIC_HOST` and `NEUMANN_CODE`. A fixed code (`--code 4821`) is never changed.

The server prints its address and room code at start. Pass `--public-host` with the address players use to reach it, so the code leads players to the right address: `127.0.0.1` for the same computer, the LAN address for a local network, the public IP for the internet.

### The school server VM (.ova)

The VM is a Debian 12 appliance with Docker. It boots straight into a running game server with no desktop. It starts 4 dedicated server containers, one per room, on UDP ports 7777 to 7780. Each room holds up to 10 players by default. Use it to host a class on the teacher's Windows 10 PC, which needs no Godot.

The files are in [`server/vm/`](server/vm). The longer guide with a pendrive checklist is [server/vm/GUIDE.md](server/vm/GUIDE.md).

**Status.** The build script and the guide state that the appliance was built, imported into VirtualBox and tested with 40 players, and report the CPU and RAM use. The `.ova` is not in the repository (about 574 MB, gitignored). Each person who needs it builds it. Check this section after your first import and correct it if a step differs.

**1. Build the .ova (once, at home).** You need Oracle VirtualBox 7 or newer (with `VBoxManage`), HashiCorp Packer 1.10 or newer, `tar`, an internet connection and about 10 GB of free disk. The build takes 20 to 40 minutes.

| Machine | Command, from this folder |
|---|---|
| Windows | `.\server\vm\build-ova.ps1` or `.\server\vm\build-ova.bat`. Install Packer first with `winget install Hashicorp.Packer`. |
| Linux, or Git Bash on Windows | `server/vm/build-ova.sh` |

Add the RAM in MB as an argument to change the default of 1024, for example `server/vm/build-ova.sh 2048`. The result is `server/vm/output/TheEmptySchoolServer.ova`. The build excludes `scripts/staff.gd`, so the server image holds no real names.

**2. Carry it to school.** Copy the `.ova`, the prebuilt Windows client (`TheEmptySchool.exe`) and, as a fallback, the VirtualBox installer to a USB drive.

**3. Import it on the teacher's PC.**

1. Install VirtualBox if it is missing.
2. Open VirtualBox and choose File, Import Appliance.
3. Select `TheEmptySchoolServer.ova` and choose Import.
4. Open the VM settings, then Network, then Adapter 1. Set Attached to `Bridged Adapter` and select the PC's active network adapter. A wired connection is best.

Use a bridged adapter. The VM then has its own address on the school network and needs no port forwarding. The default NAT mode hides the rooms from the other PCs.

**4. Start it.** Select the VM and choose Start. The rooms start by themselves after about 20 to 30 seconds. The console shows the address and one line per room:

```text
  The Empty School server
  Address: 192.168.1.50
  4 rooms, up to 10 players each.

  Room 1: 192.168.1.50:7777   code 4535
  Room 2: 192.168.1.50:7778   code 0699
  Room 3: 192.168.1.50:7779   code 3742
  Room 4: 192.168.1.50:7780   code 4146
```

Leave the VM running. You can minimize its window. No login is needed. The codes are random and change each time the rooms start.

**5. Join the rooms.**

1. Start `TheEmptySchool.exe` on each student PC.
2. Choose Join Co-op.
3. Type the address and port of the room, for example `192.168.1.50:7777`. Use the address first: the VM runs the rooms in Docker's own network, and the code lookup by broadcast was not confirmed to cross it. If the four digit code finds the room on your network, you can use it too.
4. Give each group its own room: group 1 in room 1, group 2 in room 2, and so on.
5. In the lobby, any player starts a mode. See [Multiplayer modes](#multiplayer-modes).

All PCs must be on the same network as the VM. A guest or isolated Wi-Fi often blocks traffic between devices.

**6. Manage the VM.** Log in at the VM console as `neumann` with the password `neumann`. Change the password if the VM stays on a shared network.

| Task | Command |
|---|---|
| Change rooms, first port or players per room | Edit `/etc/neumann/rooms.conf` (`ROOMS`, `FIRST_PORT`, `MAX_PLAYERS`), then run `sudo systemctl restart neumann-rooms` |
| Show the new address and codes after a network change | `sudo systemctl restart neumann-rooms` |
| Read a room log | `sudo docker logs -f neumann-room-1` |
| Turn on SSH (off by default) | `sudo systemctl enable --now ssh` |

**Known limits.** The in-game Host Co-op still accepts 4 joining players. Only the VM and the dedicated server reach 10 per room. Social Deduction caps at 5 players. The measured RAM and CPU figures in the guide come from one test run. Re-check them on the teacher's low-spec PC.

### Ports

- UDP 7777 for the game (change it with `--port`). The VM uses 7777 to 7780, one port per room.
- UDP 7778 for room code lookup on the local network. In the VM this port is also the second room's game port.
- Forward the game port on the router for players on other networks. TCP is not used.

### Co-op troubleshooting

| Problem | Fix |
|---|---|
| The VM console says "No network address yet" | The adapter is not bridged or has no network. Set Adapter 1 to Bridged Adapter, then run `sudo systemctl restart neumann-rooms`. |
| Players cannot reach the VM | Check that the student PC and the VM share a network. Test the address from the PC. Allow VirtualBox and UDP 7777 to 7780 in the Windows firewall on the host. |
| "No room 1234 found on this network" | The code lookup uses broadcast, which Wi-Fi isolation, VLANs and Docker bridges block. Join with the address and port instead. |
| The address shown by the VM is wrong after a move | The address comes from DHCP. Restart the rooms with `sudo systemctl restart neumann-rooms`. |
| VirtualBox says VT-x or AMD-V is disabled | Turn on virtualization in the BIOS of the teacher's PC. Hyper-V can conflict on Windows 10. |
| A room is full | Join another room, or raise `MAX_PLAYERS` in `rooms.conf` and restart the rooms. |
| Hosting on Android fails with `Could not open UDP port 7777 (error 20)` | The APK lacks the INTERNET permission. Rebuild with `tools/build.sh` or `tools/build.bat`, which add it, and reinstall. |
| Docker on macOS or Windows shows no codes | Docker there does not pass LAN broadcasts. Join with the address. |
| The game is slow on a school PC | Use Settings, Graphics: preset Low, real-time lamps off, render scale 60 to 75 percent, FPS limit 30 or 60. |

Limits of all modes: connections are direct and there is no relay service. Players on different networks need a reachable host, either a forwarded port or a server with a public address. Android players join with the code or the address like everyone else.

## Multiplayer modes

Open the Co-op lobby (Host Co-op or Join Co-op) and press a start button for a mode. Any player can start. The design note is [docs/multiplayer-modes.md](docs/multiplayer-modes.md).

- **Hide and Seek.** 25 seconds to hide, then 4 minutes of hunting in the empty night school. The entity is the computer (the default) or a random player, which needs at least 2 players. Survivors hide in lockers (E, Space holds the breath), flash the torch (T) to stun the entity for 3 seconds, and revive downed teammates by holding E for 3 seconds. A caught survivor has 25 seconds to be revived. Survivors win when time runs out with one of them up. The entity wins when nobody is standing. A new round starts 12 seconds after each result. Leave from the pause menu.
- **Social Deduction.** 3 to 5 players. One random player is secretly the entity, the others are students and teachers. The entity takes crew members down with E (every 30 s). Finding a body (E) or pressing G (once per player) starts a 45 second meeting with the room log of the last minute. Vote with the number keys: more than half of the living players ejects someone. The crew wins by ejecting the entity or by surviving the 6 minute night. The entity wins when one crew member is left. Lights near a takedown flicker.
- **Works with the dedicated server.** The server runs the round logic without a world. With the computer as the entity, one player device runs it.

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
| `scripts/match.gd`, `match_world.gd`, `body_marker.gd` | Match modes: round logic on the host or the dedicated server (`match.gd`, autoload `Match`), its effect on the school (`match_world.gd`) and the body in Social Deduction. |
| `scripts/net_session.gd`, `dedicated_server.gd`, `input_bridge.gd`, `touch_controls.gd`, `xr_manager.gd` | Co-op, the headless server (`server/` holds its launch files), touch and VR. |

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
