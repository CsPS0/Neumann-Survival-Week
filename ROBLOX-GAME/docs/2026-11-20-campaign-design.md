# The Empty School on Roblox: the one-day team campaign (design)

Date: 2026-11-20. Status: draft, waiting for approval.

## Why

The author wants the Godot game's story campaign on Roblox, playable alone or with friends on the same server. The
Godot campaign runs over five days (about 7,500 lines of GDScript). For now the whole story is condensed into **one
day**, so a team can play a complete run with a real ending in one sitting (about 35-40 minutes). The five-day
version can grow from it later.

## Decided with the author

- **Team game, shared ending.** One server = one school, one clock, one culprit, one story, one ending for everyone.
- **Approach A:** the whole story in one condensed day (not only day 1 of five).
- **Invented names only.** Roblox's Community Standards forbid sharing real people's personal information, so the
  Roblox game uses only invented Hungarian names: the 8 suspects of `lessons.gd` and the invented background staff of
  `staff_placeholder.gd`. The real school (the Neumann school, its building and room numbers) stays. The real staff
  roster never enters `ROBLOX-GAME/`.

## Goals

- A complete one-day run: lessons with quizzes, the Lab 14 explosion, clues, talking to teachers, the team's
  accusation, the night hunt, the exorcism quest, the ritual and the endings.
- Solo play works: a team of one.
- Co-op with up to 10 players on one server, started from the main menu like the other modes.
- Reuse what exists: the school, doors, lockers, torch, movement and camera, the entity AI, the menu, round manager,
  spectating, chat and sounds.

## Non-goals (this version)

- Days 2-5, saving between sessions, achievements.
- The student crowd, background teachers, Csoki, the dream, the haunting pranks, finds and the mecha feed, e-Kréten,
  the notice board, the phone map. These are stage 4, later.
- The Porta's full key board (hooks for every room, signing, stealing, the student card). Only the keys the story
  needs exist.

## Anti-goals

- Any real person's name anywhere in `ROBLOX-GAME/`.
- A run that can soft-lock: every story step must stay reachable whoever left, died or holds the items.
- One player being able to end the run for everyone by accident (the front door, a wrong accusation) without the
  team agreeing.

## Difficulty (decided with the author)

Picked in the menu when the story starts (Easy / Normal / Hard), shown on the HUD, the same for the whole team.
Difficulty mostly changes how long and how demanding the run is. All numbers live in one pure table
(`shared/Difficulty.luau`) so they can be tuned in one place.

| | Easy | Normal | Hard |
|---|---|---|---|
| Run length (target) | at most 45 min | about 60 min | 1-2 hours |
| Lessons | 3 | 4 | 7 (Godot's full timetable) |
| Quiz | 2 questions, multiple choice (numbers or click) | 3 questions, typed | 4 questions, typed (Godot's test day) |
| Skips before expulsion | never expelled | 3 | 2 |
| Clues to find | 6 | 9 | 9 |
| Guidance | the objective names the exact room and item ("Clue: room 205"); a marker points the way | the objective names the task, not the place | vague objective ("Find out who it is") |
| Entity at night | slow (3.0 m/s), sight 10 m, no position hints | Godot values (4.2 m/s, sight 15 m, hint every 15 s) | faster (4.6 m/s), hint every 10 s |
| Caught at night | downed: a teammate revives (hold E 3 s) within 30 s, else out; solo: wake at the entrance, 20 game minutes lost | out | out |
| Caretaker | off | patrols the afternoon | patrols the afternoon and the night until the hunt starts |
| Safe code | 2 notes (two digits each) | 4 notes | 4 notes |
| Ritual | 25 s | 40 s | 60 s |
| Clock | faster in every phase | as the table below | slower, Godot's paces |

## The day (condensed timeline)

The game clock runs from 06:30 to 05:00 the next morning. Real time per phase is the target for **Normal**, not a
promise; Easy and Hard scale it through the difficulty table.

| Phase | Game clock | Real time | What happens |
|---|---|---|---|
| Arrive | 06:30-07:30 | ~1.5 min | Spawn at the entrance; the phone shows the timetable. Explore. |
| Lessons 1-4 | 07:30-11:10 | ~12 min | Four 45-minute lessons with 10-minute breaks. A lesson is attended when the player is inside its room within the 2-minute grace after the bell; then a 3-question typed quiz opens for that player. Breaks: search for clues, talk to teachers. |
| Explosion | after lesson 3 | | Lab 14 explodes (sound, flash, alarm); lesson 4 is cancelled (not skipped). The school empties: teachers leave, the lab door stays blown open. |
| Afternoon | 11:10-18:00 | ~6 min | Free investigation. The caretaker patrols; if he catches a player, that player is expelled (out). The phone and the HUD say: "Find out who it is. At dusk, name the entity together." |
| Accusation | 18:00 | until the team votes | The clock stops; a vote list of the 8 suspects opens for every living player (keys 1-8). More than half of the living players' votes names a suspect; a tie re-runs the vote. Wrong suspect: ending 8. Right: night falls. |
| Night (hunt) | 18:00-05:00 | up to ~15 min | Lethal. The entity hunts (computer entity). The quest unlocks. 05:00 without a finished ritual: ending 7. |

Clock pace (game minutes per real second) is data in a pure module, tuned to the real-time targets: arrive 0.6,
break 0.12 (as Godot's 0.133), lesson grace at break pace, a lesson with nobody left to attend at 1.0, afternoon 1.2,
night 0.75. A finished quiz jumps the clock to the lesson's end only when every living player in the room has finished
(Godot jumps for the one player).

## Team rules

- **Attendance and skips are per player.** Missing a lesson's grace counts a skip for that player. 3 skips (of 4
  lessons) expels that player: out, spectating. A blackout-free version of Godot's limit (6 of 21) scaled to one day.
- **Quiz score is the team's.** Every answer counts towards one team ratio (right / total).
- **Clues are the team's.** Any player picking up a clue adds it to the team's list on everyone's phone.
- **Items are the team's.** Story items go into one shared team inventory (shown on the phone) and any living player
  can use them at the fuse box, the safe or the altar. Nothing is lost when a player leaves or is caught.
- **Out:** a player caught by the entity at night, expelled (skips or the caretaker), or leaving through the front
  door is out for the rest of the run and spectates. A player who joins mid-run joins as a student during the day
  (before the accusation) and spectates after it.
- **Ending when everyone is out:** if every player is out, the run ends with the ending of the last way out: caught
  (1), expelled (3) or ran away (5).
- **Front door:** "Leave the school (you are out)" with a confirm prompt; it never ends the run while others play.
- **Team choices** (accusation, cure or destroy, the deal) are votes by the living players with the same majority rule
  as Social Deduction (`Rules.tallyVotes`); the vote panel reuses the meeting UI style.

## Rulings after the builder check (agent's calls, 2026-11-20)

- **Votes always end.** Deadline: accusation 60 s, cure/destroy 45 s, the deal 45 s. Majority of the living ends it
  early. At the deadline the option with the most votes wins; a tie between the leaders is broken at random. With
  no votes at all: the accusation re-opens, cure/destroy defaults to cure, the deal defaults to no.
- **Quiz and clock.** The clock keeps running in a lesson (lesson pace 0.8 x the difficulty scale, about a minute
  on Normal). The quiz closes at the lesson's end; unanswered questions count as wrong. When every attendee has
  finished, the clock jumps to the lesson's end.
- **No cancelled lesson.** The difficulty's lesson count is the number of lessons held (3 / 4 / 7). Lab 14 explodes
  at the end of the last lesson and the clock jumps to the afternoon (13:00). Lessons are the first N subjects of a
  random timetable row; the culprit may or may not teach one; the strange lines are heard by talking in breaks
  (index = breaks so far, capped at 3).
- **Joining mid-run:** a new optional `Mode.playerJoined(player)` hook in `RoundManager`; the campaign makes day-time
  joiners alive students (no skips) and night-time joiners spectators. Other modes keep spectating.
- **No auto-restart:** a campaign run ends in the lobby (`Cycle` off).

## Story content (ported from Godot data, condensed)

- **Teachers:** the 8 invented suspects (`lessons.gd` `TEACHER_NAMES`). One is the culprit, picked at random each run.
  Each stands in their lesson room during their lessons, walks between rooms in breaks, and leaves at the explosion.
  E talks: small talk (`clues.gd` `CHAT`); the culprit adds one strange line (`STRANGE`), a new one after each
  lesson.
- **Lessons:** 4 of the 7 subjects per run (the subjects of the culprit's day, rooms and questions from
  `lessons.gd`); typed answers with Godot's `normalize` and extra accepted answers.
- **Clues:** 9 clue texts from `clues.gd` `TRAITS` for the culprit (true clues), spawned as pickups on clue tables:
  3 before lesson 1 / in break 1, 3 in break 2, 3 in the afternoon (the after-hours rooms 205, GT8, 114 and the staff
  room table in 33). The clue texts point at one teacher through initials, ink, smell, place and item.
- **Quest (night):** Godot's chain, kept but with the Porta simplified:
  1. **Red room:** a random normal room is locked red; the porter at the Porta desk hands the team the storage key
     (E, once per run). Inside: salt and a fuse.
  2. **Fuse box** in room 24: put the fuse in; the Lab 14 cabinet gets power; take the holy water from it.
  3. **Four notes** in random rooms give one digit each; the **old safe** in room 229 opens with the 4-digit code
     (typed on a keypad UI); inside: the silver bell.
  4. **Altar** in the Aula: place salt, holy water and bell; start the ritual and survive 40 seconds near the altar
     while the entity attacks. A player caught during the ritual is out; the ritual fails only if no living player
     stays within 6 m (then it can be restarted).
- **After the ritual:** the possessed teacher lies at the altar; the team votes cure or destroy.
- **The deal:** the altar also offers the pact before the ritual (team vote): ending 6.
- **Endings** (texts from `endings.gd`): 1 Caught, 2 Banished, 3 Expelled, 4 Top student (ritual, cure, team quiz
  >= 80% and all 9 clues), 5 Ran away, 6 Pact, 7 Overtime, 8 Wrong person, 9 Destroyed. The ending card shows the
  title, the text and the run stats (quiz, clues, time, who is out), then the result phase returns everyone to the
  lobby.

## How it fits the existing game

- **A new mode** `campaign` in `RoundManager` (menu button "Story: one day (1-10 players)"), using the existing
  `RoundContext`, phases, spectating, `finish`, late-join handling. `Rules.canStart` allows 1+ players.
- **Server modules** (new): `CampaignMode` (the mode), `Clock` (game time, phases and pace), `Teachers` (NPC
  routines, dialogue), `Porter`, `Caretaker`, `Lessons`, `Clues`, `Quest` (items, red room, fuse box, safe, altar,
  ritual), `Pickups`. **Shared pure modules** (Lune-tested): `CampaignData` (lessons, clues, endings, timetable, ported
  values), `Schedule` (lesson times, phase at a time, pace), `CampaignRules` (attendance, skips, team quiz ratio,
  ending choice, vote outcome, soft-lock checks), `Answers` (`normalize`, `isCorrect`).
- **Client modules** (new): `QuizUi` (typed answers), `PhoneUi` (Tab: objective and timetable, clues, team items,
  team list), `DialogueUi`, `KeypadUi`, `VoteUi` (generalised from the meeting panel), `EndingCard`.
- **NPCs** reuse the entity's rig builder style and PathfindingService walking; teachers are plain R15 rigs built from
  a fixed `HumanoidDescription` per teacher (colours by teacher), with name tags. The caretaker uses the same walker.
  The entity at night is the existing `EntityAI`.
- **Doors:** lesson rooms open during the day; the red room, Lab 14 (until the explosion) and closed demo rooms
  stay locked; the explosion opens Lab 14 for good.

## Stages (each playable on its own)

1. **School day:** clock, timetable, teachers in rooms, lessons and quizzes, skips and expulsion, the explosion, the
   front door, the ending card (endings 3, 5). Phone page 1.
2. **Mystery:** clues, team clue list, dialogue and the culprit's slips, the caretaker, the dusk accusation vote
   (ending 8), the phone's clues page.
3. **Night:** the hunt, the porter, the quest chain, the ritual, cure or destroy, the deal, all remaining endings.
4. **Later:** the crowd, background staff, Csoki, the dream, haunting pranks, finds, e-Kréten, the phone map,
   days 2-5.

## Testing

- **Lune unit tests** for the pure modules: schedule times and phases, pace, attendance and skip rules, quiz answer
  matching (Godot's accepted answers), team quiz ratio, ending choice for every ending, vote outcomes, the soft-lock
  check (every quest step still reachable when any player leaves).
- **Studio solo runs through the MCP** with a time-scale test hook (as for Hide and Seek): a full day in a few
  minutes, each ending reached at least once by scripted actions.
- **The author's multiplayer test** (Clients and Servers, 2-3 players) for the team rules: shared clues and items,
  votes, one player caught or expelled while the others finish.

## Left to the builder

- Exact clock pace values (to hit the real-time targets), room picks for clue tables and notes, NPC walking routes.
- UI layouts (phone, quiz, keypad, vote, ending card).
- The look of the altar, fuse box, safe, cabinet, red room and item pickups (parts, as the rest of the school).
- Sounds: new ids in `Sounds.luau` (bell, explosion, alarm, ritual), empty until picked.
