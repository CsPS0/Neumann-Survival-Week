# The Empty School on Roblox

The two multiplayer modes of [The Empty School](../HORROR-GAME/README.md), Hide and Seek and Social Deduction,
and its story as one school day, rebuilt on Roblox so friends can play online without hosting a server. The school
is built from the same floor-plan data as the Godot game.

Status: all three are built. Hide and Seek against the computer entity and the story with hands, phone, bags and the new entity (solo, all three difficulties,
endings 1, 2, 3, 5, 6, 7, 8 and 9 reached by scripted runs) have been tested in Studio; the player entity, Social
Deduction and the story with several players need a test with friends (checklist below).
Design: [docs/2026-11-19-multiplayer-modes-design.md](docs/2026-11-19-multiplayer-modes-design.md),
[docs/2026-11-20-campaign-design.md](docs/2026-11-20-campaign-design.md).

## How to play

The game is first person. Everyone spawns as the same plain character in the Aula, and the main menu opens: any
player picks a mode there. Rounds then repeat by themselves 12 seconds after each result until someone presses "Stop
after this round" in the menu. M opens the menu at any time (a Menu button on phones); while it is open the mouse is
free.

**Main menu:** start a round, stop the round cycle, invite friends, create a private lobby (you get a 5-character
code), join a lobby by code, and settings (field of view, mouse sensitivity, volume, FPS counter; saved per player).
Private lobbies, invites and saved settings use Roblox services that only work in the published game (saved
settings in Studio need Game Settings > Security > "Enable Studio Access to API Services").

| Key | Phone | Action |
|---|---|---|
| WASD, mouse | joystick, drag | walk, look (first person) |
| Space | Jump | jump |
| C or Ctrl | Crouch | crouch (toggle); while sprinting fast: slide (costs stamina, 1.2 s cooldown) |
| M | Menu | open or close the main menu |
| Shift | Run | sprint (about 5 s, then rest) |
| E | tap the prompt | doors, lockers, catch, revive (hold), take down, report a body, teachers and story objects; inside a locker: leave |
| F | Light | the phone's flashlight on and off (the phone battery drains while it is on) |
| T | Flash | the phone's camera flash: stuns the entity for 3 s (12 s cooldown, 15% battery) |
| Space | Hold breath | inside a locker: the computer entity does not check your locker |
| G | Meeting | Social Deduction: call a meeting (once per round, not in the first 15 s) |
| 1-9 | tap | vote in a meeting or a story vote; Easy quiz answers (1-4) |
| P | Phone | raise the phone to your face (one hand) or put it away |
| H | | with the phone up: switch one hand / two hands (full screen, mouse) |
| | | phone Route app: pick a room (Left/Right floor, Up/Down, Space) and glowing dots on the floor lead you there |
| Arrows, Space, Backspace | tap | one-hand phone: move, open, back (they do not walk or jump while the phone is up) |
| Tab | Items | story: what you carry (hand, pockets, the bag on your back) |
| B | Drop bag | story: drop your bag; at your dropped bag, B puts it back on |
| U | | story: use a power bank from your hand or a pocket (+35% phone battery) |
| R | tap the prompt | story: offer the deal at the altar |
| Left / Right | < > | switch the player you watch when you are out |

- **Hide and Seek:** 25 s to hide, then a 4 minute hunt. The entity is the computer or a random player (2+
  players). A caught survivor is downed for 25 s; a teammate holds E for 3 s to get them up. Survivors win when the
  time runs out with someone not out; the entity wins when nobody is standing.
- **Social Deduction:** 3 to 10 players, one secret entity (two from 8 players). Everyone shows a tag ("Student 1",
  "Teacher 2"). The entity takes people down with E (20 s into the night, then every 30 s). A body report or G starts
  a 45 s meeting with the room log of the last minute; more than half of the living players' votes ejects someone.
  Text chat only works in the lobby and in meetings; players who are out chat among themselves.
- **The school is alive by day:** in the lobby and in the story until Lab 14 explodes the sun shines and students,
  teachers (lobby only), cleaners and kitchen staff fill the school near you. In lessons the students sit in the
  classrooms (your lesson's room gets its class), in breaks they walk the corridors; after the explosion everyone
  walks out. People never block you: you walk through them. Hide and Seek and Social Deduction are at night, with a
  few students who stayed late: in Hide and Seek they run from the entity, and the entity can take them (everyone
  hears the scream); in Social Deduction the entity can take one with E instead of a player, and the body can be
  reported.
- **Story** (solo or co-op, everyone on the server plays together and gets one shared ending): one school day from
  06:30 to 05:00. Go to your lessons (be in the room when the bell rings, then answer the quiz), find clues about
  the possessed teacher and talk to the teachers (E) in the breaks. Lab 14 explodes after the last lesson and the
  school empties; at 18:00 the team votes who the entity is. Right: the night hunt and the exorcism quest (the
  porter's storage key, the red room, the fuse box, the Lab 14 cabinet, the notes with the safe code, the safe in
  room 229, the altar in the Aula and the ritual). Nine endings. Teacher names are invented.

  **Hands, pockets and bag.** You carry one thing in your hand, one small thing in each pocket (key, holy water,
  papers, power bank) and up to 8 things in your bag; big things (salt, fuse, bell) only fit your hand or the bag. The
  bag slows you down while it is on your back. To use something (fuse box, red door, altar) it must be in your hand
  or a pocket: drop the bag (B), open it (E) and take it out. Anyone can open a dropped bag, which is how you share
  with friends. Every paper you read joins one "papers" stack; the safe code is only on the notes. The phone in your
  right hand is also your light. In the afternoon the entity shows itself for a moment: look at what it wears.

  | Difficulty | Run | Lessons | Quiz | Help | Night |
  |---|---|---|---|---|---|
  | Easy | up to ~45 min | 3 | 2 questions, multiple choice | objective names the room, a marker shows where | slow entity, caught = a teammate revives you (solo: you wake at the entrance) |
  | Normal | ~45-60 min | 4 | 3 typed questions | objective names the task | 3 skipped lessons expel you; caught = out |
  | Hard | 1-2 hours | 7 | 4 typed questions | one vague line | 2 skips expel; faster entity; the caretaker also patrols at night |

## Set up

1. Install [Roblox Studio](https://create.roblox.com/) and sign in.
2. Install [Rokit](https://github.com/rojo-rbx/rokit/releases) (unzip, run `rokit self-install`, open a new terminal).
3. In this folder run `rokit install`. It installs the pinned Rojo, Lune and luau-lsp.
4. Run `rojo plugin install` once to add the Rojo plugin to Studio.

## Work on it

- `rojo serve` in this folder, then in Studio open a new Baseplate, open the Rojo plugin and press Connect. Code
  changes sync into Studio while it runs.
- Play-test with several players: Test > Clients and Servers, pick the number of players, Start.
- Or, without live sync: build a place file (`mkdir build` once, then
  `rojo build default.project.json -o build/TheEmptySchool.rbxlx`), open it in Studio and press Play.
- Checks outside Roblox: `lune run tests/run` (rules), `lune run tools/compile-check` (every source file compiles),
  `lune run tools/school-dryrun` (part counts, blocked doorways).
- Fast test round from the Studio command bar while playing (server side):
  `game.ServerStorage.TestHooks.StartRound:Invoke({mode = "hideseek", entity = "computer"}, {timeScale = 0.1})`
  runs every timer ten times faster.
- Sounds: free Creator Store audio ids in `src/shared/Sounds.luau` (swap any id there; empty ids are skipped). The
  background (lamp hum, chatter, birds, wind, drone, knocks, dust, lamp stutter) is `src/client/Ambience.luau`.

## Play-test checklist

**The school** (Play, one player):

- [ ] The school appears within a few seconds; the Output window prints `school built: ... parts`.
- [ ] You start in the Aula as the plain default character (not your own avatar), in first person, and the main
  menu is open with a free mouse. M closes and opens it; Space jumps.
- [ ] Settings: field of view, mouse sensitivity, volume and the FPS counter change at once.
- [ ] Looking down shows your arms, body and legs; facing a wall up close, the camera never sees through it.
- [ ] Walking bobs the view gently with a footstep at each dip; strafing (A/D) tilts it a little; a jump from the
  stairs dips the view on landing; Shift widens the view a few degrees.
- [ ] C crouches (lower view, slower); C while sprinting slides a short way and ends crouched; jumping stands up.
- [ ] With 2 players: each sees the other look up and down (head and upper body tilt).
- [ ] All four stairwells lead from the ground floor to the 1st and the 2nd floor and back down.
- [ ] Doors open and close with E. Closed rooms say "Not available in the demo." and stay shut.
- [ ] The 14 lockers stand in the corridors and block no open door. E hides you (first person, see out through the
  door), E again lets you out facing the corridor.
- [ ] Shift sprints for about 5 s, the green bar empties and turns red, then refills. F switches the phone light, T flashes. You see your hands and the phone; the phone lifts to your face with P.
- [ ] Windows: you cannot walk out of the building.

**Hide and Seek, computer entity** (Play, one player is enough):

- [ ] The main menu starts it and closes; 25 s hiding, then "The entity is awake."
- [ ] The entity patrols, opens doors, chases you on sight and catches you; the round ends and restarts after 12 s.
- [ ] Sprinting near it makes it come; it comes to your locker unless you hold Space; in a locker it never catches you.
- [ ] T aimed at it stops it for 3 s.
- [ ] "Stop after this round" in the menu (M) stops the cycle after the current round.

**Hide and Seek, player entity** (Test > Clients and Servers, 3 players):

- [ ] The entity player sees a black screen while the others hide, then walks at a fixed speed with the entity look.
- [ ] E on a survivor downs them; another survivor holds E for 3 s to revive; unrevived after 25 s = out and
  spectating (Left/Right switches who you watch).
- [ ] A flash freezes the entity player for 3 s with a white screen.
- [ ] The entity player leaving ends the round; a survivor leaving counts as out.

**Social Deduction** (Clients and Servers, 4 players; 8 if the PC copes):

- [ ] Everyone looks the same and shows a tag; each player sees only their own role (two entities see each other's
  tag at 8+ players).
- [ ] The entity cannot take down before 20 s, then every 30 s; lamps nearby flicker; a body can be reported.
- [ ] G calls a meeting once per player and not in the first 15 s.
- [ ] The meeting shows the rooms of the last minute with floors; votes eject with a majority and show the role; a tie
  or skips eject nobody; everyone returns to the Aula and the night continues.
- [ ] Chat only works in meetings; out players chat only with each other; a player who joins during a meeting is not
  in the vote list.
- [ ] Both endings: vote out the entity (crew wins) and let the entity take people down (entity wins).
- [ ] Phone (Test > Device emulator): every action above has a touch button or a tappable prompt.

**Story** (Play solo, then Clients and Servers with 2-3 players):

- [ ] The menu's Story buttons start Easy, Normal and Hard; the top bar shows the clock, P raises the phone,
  arrows/Space/Backspace work it, H goes full screen.
- [ ] Standing in the lesson's room when the bell rings opens the quiz (Easy: buttons; Normal/Hard: type and
  Enter); a missed lesson counts as a skip on the phone.
- [ ] Clue tables lie in empty rooms; reading one adds it to everyone's phone. A teacher talks when you press E.
- [ ] After the last lesson Lab 14 explodes, the teachers leave, the caretaker patrols (Normal, Hard).
- [ ] At 18:00 the vote opens for everyone; a wrong name ends the story (Wrong person).
- [ ] The night quest works with two players splitting the work: one drops a bag, the other opens it and takes
  the fuse; two players with the same bag open never duplicate or lose an item. The ritual needs someone at the
  altar; the cure/destroy vote ends it. On Easy a caught player can be revived.
- [ ] A player who goes out or leaves drops a bag holding everything they carried; the others can open it.
- [ ] In the afternoon the entity appears for a moment wearing the possessed teacher's colours and item.
- [ ] The front door (hold E) takes you out of the story; the last one out ends it.
- [ ] A friend joining during the day becomes a student; during the night they watch.

## Performance check (60 FPS = 16.6 ms per frame)

Measure in the real game window with Studio in front, or better in the published game in the Roblox app (Studio's
Play runs the server and the client inside the editor and is heavier than the real game).

1. Play, open the menu (M), turn on "FPS counter" in Settings, close the menu and walk the corridors for a minute,
   then stand still in the Aula. (In Studio, Shift+F5 is "Stop", not the stats; Shift+F5 shows stats only in the
   Roblox app.)
2. The FPS should stay at 60 (Roblox caps it there unless you raise the frame rate limit in the Roblox menu). Note
   the lowest value you see while walking and turning.
3. Ctrl+F6 opens the MicroProfiler. Ctrl+P pauses it; hover the frame bars at the top: every bar should stay under
   the 16.6 ms line. Click a tall bar to see what it was (render, physics, scripts).
4. Ctrl+F7 (or the MicroProfiler menu > Dump) saves the last frames as an HTML file to look at or send.
5. If the MicroProfiler shows most of the frame in "Present" while the GPU timeline is nearly empty, the game is
   not the problem: something outside Roblox holds the window back (found on the author's PC on 2026-11-20: even an
   empty Studio scene ran at 9 FPS). Suspects: tools that inject into every program and add window effects (for
   example Windhawk's "Translucent Windows" mod), overlays, or a frame limit in the graphics driver. On the author's
   PC the fix was Windhawk off plus, in NVIDIA Control Panel > Manage 3D settings > Program Settings > Roblox
   Studio: Monitor Technology "Fixed Refresh" and Low Latency Mode "Off" (G-SYNC in windowed mode made Studio stall).
6. If frames are long because of rendering: in the Studio command bar while playing, `game.Lighting.PrioritizeLightingQuality = false`
   (cheaper shadows, shorter view distance), then `game.Lighting.LightingStyle = Enum.LightingStyle.Soft` (the
   cheapest look). Report which one helped; the project file sets both.

What is already done for speed: the school is built once by code with every part anchored, CanTouch off, and small
decoration (window frames, sills, plaques, lamp fixtures, locker handles) without shadows or raycasts; prompts are
filtered from a cached set; the HUD and meters update 10-20 times a second; head pitch goes out 15 times a second on
an UnreliableRemoteEvent. StreamingEnabled stays off: the school has about 2,100 parts, and the client code needs the
whole school, the entity and the other players present (lamp flicker, lockers, heartbeat, spectating).

## Publish (for a private test with friends)

1. In Studio: File > Publish to Roblox, create a new experience.
2. Game Settings: set the maximum players to 10; under Avatar keep R15.
3. Fill in the content maturity questionnaire (it is a horror game) in the Creator Hub.
4. Turn voice chat off for the experience (Creator Hub > the experience > Communication), so voices do not give away
   who is who in Social Deduction.
5. Give friends access: either keep the experience public and share the link, or use private servers (check the
   current private server options in the Creator Hub) and send the private server link.
