# One-Day Team Campaign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (the author chose inline execution).
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Godot story campaign condensed into one day, as a server-authoritative team game (1-10 players) with
Easy / Normal / Hard difficulty.

**Architecture:** A new `campaign` mode inside the existing `RoundManager`. Pure, Lune-tested modules hold the data,
schedule, rules, answers and difficulty table; server modules under `src/server/Campaign/` run the clock, teachers,
lessons, clues, caretaker, porter and quest; client modules draw the quiz, phone, dialogue, keypad, votes, guidance
marker and ending card. The existing entity AI, lockers, torch, doors, menu, spectating and chat are reused.

**Tech Stack:** Luau, Rojo 7.7.1, Lune 0.11 (tests), luau-lsp (shared modules), Roblox Studio MCP for play tests.

**Spec:** `ROBLOX-GAME/docs/2026-11-20-campaign-design.md` (read it first; the difficulty table and team rules are
binding). Godot sources for every ported value: `HORROR-GAME/scripts/campaign.gd`, `lessons.gd`, `clues.gd`,
`quest.gd`, `endings.gd`.

## Global Constraints

- Invented names only: the 8 suspects of `lessons.gd` (`TEACHER_NAMES`). No real person's name in `ROBLOX-GAME/`;
  never read `HORROR-GAME/scripts/staff.gd` or `docs/data/`.
- Team game: one clock, one culprit, one shared clue list, one shared item inventory, one ending.
- Server authoritative: every remote handler checks phase, alive state, distance and the run id.
- `src/shared` modules stay `--!strict`, no Roblox globals, no `require` (Lune-loadable).
- Metres in code and data, converted with `Config.studs`. Floors 0, 1, 2.
- English UI. No commits unless the author asks. Rebuild `build/TheEmptySchool.rbxlx` after every task.
- Difficulty values come only from `shared/Difficulty.luau`.

## Review Focus

1. **A player leaves or is out while holding a role in the story** (the last voter, the one standing at the altar,
   the only player alive): items stay in the team inventory, votes count only living players, the ritual needs any
   living player in range, and the run ends with the right ending when nobody is left. Tests: `CampaignRules`
   (Task 2), Studio check in Task 9.
2. **A player joins mid-run:** during the day they become a student (alive, no skips); after the accusation they
   spectate. Test: Task 6 Studio check.
3. **Typed answers:** accents, case, spaces and the extra accepted answers match Godot (`normalize`). Tests:
   `Answers` (Task 1).
4. **Clock edge cases:** a lesson where nobody is left alive to attend, the explosion skipping the remaining lessons
   (cancelled, not skipped), and the night ending at 05:00. Tests: `Schedule` and `CampaignRules` (Tasks 1-2).
5. **Votes that never resolve** (ties, everyone skipping, players leaving mid-vote): the vote re-opens on a tie and
   ends early when all living players voted. Tests: `CampaignRules.voteOutcome` (Task 2).

---

## File map

```
src/shared/   Difficulty.luau  CampaignData.luau  Schedule.luau  CampaignRules.luau  Answers.luau
src/server/Campaign/
              CampaignMode.luau  Clock.luau  Npc.luau  Teachers.luau  Lessons.luau  Clues.luau
              Caretaker.luau  Porter.luau  Quest.luau  Votes.luau
src/client/Campaign/
              CampaignState.luau  QuizUi.luau  PhoneUi.luau  DialogueUi.luau  KeypadUi.luau  VoteUi.luau
              EndingCard.luau  Guidance.luau
tests/        difficulty.spec  campaigndata.spec  schedule.spec  campaignrules.spec  answers.spec
```

Remotes added to `shared/Remotes.luau` NAMES: `CampaignState` (server -> client: snapshot table), `QuizStart`
(server -> one client: {lesson, subject, mode, questions = {{text, options?}}}), `QuizAnswer` (client -> server:
lessonIndex, questionIndex, answer string or option index), `QuizResult` (server -> one client: {correct, total}),
`Dialogue` (server -> one client: {name, lines}), `TeamVote` (server -> clients: {id, title, options, seconds} or
nil to close), `TeamVoteCast` (client -> server: id, optionIndex), `Keypad` (server -> one client: open),
`KeypadEnter` (client -> server: code string), `Ending` (server -> clients: {id, title, color, text, stats}).

Snapshot (`CampaignState`), sent to all on change and to a joiner: `{difficulty, minutes, phase, objective, guide
(Vector3?), timetable = {{subject, room, start, status}}, clues = {string}, cluesNeeded, items = {string}, quizRight,
quizTotal, team = {{name, state}}, culpritKnown = bool}`.

---

### Task 1: Pure data, difficulty, schedule and answers

**Files:** Create `src/shared/Difficulty.luau`, `CampaignData.luau`, `Schedule.luau`, `Answers.luau`, tests
`tests/difficulty.spec.luau`, `campaigndata.spec.luau`, `schedule.spec.luau`, `answers.spec.luau`.

**Interfaces (produces):**
- `Difficulty.get(name: string): Level` (unknown -> normal). `Level = {name, lessons: number, quizCount: number,
  quizMode: "choice"|"typed", skipLimit: number, clues: number, guidance: "exact"|"task"|"vague", chaseSpeed: number,
  sight: number, hintInterval: number, revive: boolean, caretaker: "off"|"afternoon"|"night", notes: number,
  ritual: number, paceScale: number}` with the design's values (easy 3/2/choice/inf/6/exact/3.0/10/0/true/off/2/25;
  normal 4/3/typed/3/9/task/4.2/15/15/false/afternoon/4/40; hard 7/4/typed/2/9/vague/4.6/15/10/false/night/4/60);
  paceScale easy 1.6, normal 1, hard 0.55.
- `CampaignData`: `TEACHERS` (id -> name, ported), `SUSPECTS` (ordered ids), `SUBJECTS` (subject -> {room, floor,
  teacher ids, questions = {{text, options, correct (1-based), extra}}}), `TIMETABLES` (3 lists), `TRAITS`, `CHAT`,
  `STRANGE`, `ENDINGS` (id -> {title, color = {r,g,b}, text}), `STORY` = {fuse = {"24",0}, safe = {"229",2},
  lab = {"14",0}, staffClue = {"33",0}}, `CLUE_ROOMS` = ordered list of {label, floor} for clue tables (normal open
  rooms, chosen per run), `AFTER_ROOMS` = {{"205",2},{"GT8",2},{"114",1}}, `teacherOf(subject, day)`.
- `Schedule` (minutes after midnight; day = 1): `OPEN = 390`, `FIRST_BELL = 450`, `LESSON = 45`, `BREAK = 10`,
  `GRACE = 2`, `AFTERNOON = 780`, `DUSK = 1080`, `END = 1740`; `lessonStart(i)`, `lessonEnd(i)` (0-based), the
  explosion at `lessonEnd(count - 1)` jumps the clock to `AFTERNOON`; `pickLessons(row: number, count: number):
  {string}` = first `count` subjects of `TIMETABLES[row]`, `phaseAt(m, count, exploded, accused):
  "arrive"|"grace"|"lesson"|"break"|"afternoon"|"accusation"|"night"|"over"`, `pace(phase, scale): number` (arrive 0.6,
  grace 0.12, break 0.12, lesson 0.8, afternoon 1.2, night 0.75, all * scale; accusation 0).
- `Answers.normalize(text): string` and `Answers.isCorrect(question, typed): boolean` (Godot `normalize`: lower case,
  accents folded with the Godot table, keep a-z 0-9 + - * / = ^).

- [ ] Write the four specs: difficulty values per level and fallback; data sizes (8 teachers, 7 subjects x 4
  questions, 3 timetables of 7, 8 x 10 traits, 9 endings) and that no teacher name appears twice; schedule times
  (`lessonStart(0) = 450`, `lessonEnd(0) = 495`, `lessonStart(1) = 505`), `phaseAt` for each phase incl. "lesson 4 is
  cancelled after the explosion" (phase "afternoon" at its start time when exploded); answers: `"Arany  János"` ==
  `"arany janos"`, `"I x R"` correct for Ohm and `"I / R"` not, empty string never correct.
- [ ] Run `lune run tests/run` (fails), implement, run (passes), `luau-lsp analyze --platform=standard src/shared`,
  rebuild.

### Task 2: Campaign rules

**Files:** Create `src/shared/CampaignRules.luau`, `tests/campaignrules.spec.luau`.

**Interfaces (produces):**
- `CampaignRules.skip(skips: number, limit: number): (number, boolean)` -> new count, expelled.
- `CampaignRules.ratio(right, total): number` (0 when total is 0).
- `CampaignRules.ritualEnding(destroy, ratio, clues, cluesNeeded): number` -> 9, else 4 when ratio >= 0.8 and clues
  >= cluesNeeded, else 2.
- `CampaignRules.allOutEnding(lastWay: "caught"|"expelled"|"ranaway"): number` -> 1 / 3 / 5.
- `CampaignRules.voteOutcome(votes: {[string]: number}, living: number): number?` -> the option index with more than
  half of `living`, else nil; `CampaignRules.voteAtDeadline(votes, random: (n) -> number): number?` -> the option
  with the most votes (ties broken by `random`), nil when nobody voted. Vote deadlines: accusation 60 s,
  cure/destroy 45 s (nil -> cure), deal 45 s (nil -> no), accusation nil -> re-open.
- `CampaignRules.objective(state, guidance): string` where `state = {phase, nextLesson?: {subject, room}, clueRoom?,
  cluesFound, cluesNeeded, accused, questStep?: "redkey"|"redroom"|"fuse"|"vial"|"notes"|"safe"|"altar"|"ritual",
  questRoom?}`; exact guidance names rooms, task guidance names the task only, vague gives one line per phase.
- `CampaignRules.questStep(q): string` from `q = {haveKey, redOpened, fusePlaced, vialTaken, notes, notesNeeded,
  safeOpen, altar = {salt, vial, bell}}` in that order.

- [ ] Specs: skip limit 3 -> third skip expels, easy (math.huge) never; every ending id reachable; vote: 2 of 3
  living pick, 1-1 with 2 living nil until the deadline, deadline picks the plurality, breaks a 1-1 tie with
  `random`, nil with no votes; objective strings contain the room only for "exact"; quest step order.
- [ ] Red, implement, green, analyze, rebuild.

### Task 3: Clock, NPC walker and teachers

**Files:** Create `src/server/Campaign/Clock.luau`, `Npc.luau`, `Teachers.luau`.

**Interfaces (produces):**
- `Clock.new(level, timeScale): Clock`; `clock.minutes`, `clock:start()`, `clock:stop()`, `clock:jumpTo(m)`,
  `clock:setPaused(b)`, signal-like callbacks `clock.onMinute(m)`; it advances on Heartbeat by
  `Schedule.pace(phase, level.paceScale) / timeScale * dt` and writes `ReplicatedStorage.Campaign` attributes
  `Minutes` and `Phase` four times a second.
- `Npc.build(name: string, colors: {torso: Color3, legs: Color3}, at: CFrame, parent): Model` (R15 from
  `HumanoidDescription`, name tag BillboardGui); `Npc.walkTo(model, position): boolean` (PathfindingService, yields,
  opens doors on the way like EntityAI); `Npc.stop(model)`.
- `Teachers.new(ctx, culprit, lessons): Teachers`; `:placeForLesson(i)` (each lesson's teacher walks to its room,
  others to the staff room 33); `:dismiss()` (all walk to the entrance and are removed); a `Talk` prompt (`For` =
  "living") fires `Dialogue` to the player with `CHAT` plus the culprit's `STRANGE` line (index = lessons done).

- [ ] Implement; Studio MCP check (Task 6 runs it).

### Task 4: Lessons and quiz

**Files:** Create `src/server/Campaign/Lessons.luau`, `src/client/Campaign/QuizUi.luau`.

**Interfaces:** `Lessons.new(ctx, level, timetable): Lessons`; `:onBell(i)` checks each living player's room with
`FloorData.roomLabelAt` (root position / STUDS_PER_METRE, `FloorData.floorAt`) during the grace window, sends
`QuizStart` (questions from `CampaignData` shuffled, `level.quizCount`, options only in "choice" mode), records
skips with `CampaignRules.skip`; `QuizAnswer` checked with `Answers.isCorrect` (typed) or the index (choice);
`:allDone(i): boolean` when every living attendee answered all questions (clock then jumps to the lesson end).
`QuizUi`: modal panel (Modal button frees the mouse), a TextBox per question (Enter submits) or numbered buttons.

- [ ] Implement; Studio check in Task 6.

### Task 5: Campaign mode, state, phone, ending card (stage 1 playable)

**Files:** Create `src/server/Campaign/CampaignMode.luau`, client `CampaignState.luau`, `PhoneUi.luau`,
`DialogueUi.luau`, `EndingCard.luau`. Modify `RoundManager.luau` (options carry `difficulty`; the `StartRound`
remote takes a third argument), `shared/Rules.luau` (`canStart("campaign", _, n)` true for n >= 1, with a test),
`MainMenu.luau` (Story buttons: Easy / Normal / Hard), `Main.server.luau` (register mode), `Main.client.luau`,
`Remotes.luau`.

**Interfaces:** `CampaignMode: Mode` (start, playerLeft, playerDied, stop) holding the run state; `Mode.start` picks
the culprit, timetable and lessons, spawns teachers, starts the clock, sends snapshots; the explosion (after lesson
`Schedule.explosionAfter`) plays a flash and the alarm, opens Lab 14 for good, dismisses teachers and cancels the
rest; the front door prompt ("Leave the school") marks the player out (`ranaway`); `finish` sends `Ending` with stats
and calls `ctx.finish`. Phone (Tab): Objective + timetable, Clues, Items, Team. Late joiners: day -> alive student
(no skips), after accusation -> spectator.

- [ ] Implement; rebuild; Studio solo run at timeScale 0.1 on Easy: arrive -> lessons -> quiz (answer via remote) ->
  explosion -> afternoon; front door -> ending 5 card. Record in the ledger.

### Task 6: Clues, dialogue, caretaker, accusation (stage 2)

**Files:** Create `Clues.luau`, `Caretaker.luau`, `Votes.luau` (server), `VoteUi.luau`, `Guidance.luau` (client).

**Interfaces:** `Clues.new(ctx, level, culprit)`; spawns `level.clues` pickups in three waves (arrive/break 1,
break 2, afternoon) on tables in `CLUE_ROOMS`/`AFTER_ROOMS`, texts `TRAITS[culprit][k]` for k in a shuffled spread of
0..9; pickup adds to the team list. `Caretaker.new(ctx, level)` patrols when `level.caretaker` allows; catching a
player expels them (out, `expelled`). `Votes.ask(ctx, title, options, seconds?, onPick)` using `TeamVote` /
`TeamVoteCast` and `CampaignRules.voteOutcome` (tie -> re-open). At `Schedule.DUSK` the clock pauses and the
accusation vote runs over `SUSPECTS` names; wrong -> ending 8; right -> night. `Guidance` (Easy only): a Beam from
the player to `snapshot.guide`.

- [ ] Implement; Studio run: clues collected via prompts (InputHoldBegin on the client), accusation vote cast via
  remote, ending 8 and the right path into the night.

### Task 7: Night: entity, porter, quest, ritual, endings (stage 3)

**Files:** Create `Porter.luau`, `Quest.luau`; modify `EntityAI.luau` (`opts.params = {chaseSpeed, sight,
hintInterval}` override `Config.Entity`), `CampaignMode.luau`, client `KeypadUi.luau`.

**Interfaces:** `Quest.new(ctx, level)`: red room = random open normal room not in STORY (its door locked,
`Doors.setLocked`), porter prompt hands `storage_key` once at night; inside the red room salt + fuse pickups; fuse box
in room 24 (prompt) -> Lab 14 cabinet gives holy water; `level.notes` notes in random rooms carry the code digits
(4-digit code split evenly); safe in 229 opens `Keypad` -> correct code gives the bell; altar in the Aula takes the
three items, then "Start the ritual" (vote not needed: any living player) runs `level.ritual` seconds while the
entity is woken next to it; done -> vote Cure / Destroy -> ending 2/4 or 9; altar also offers "Make a deal" (team vote
-> ending 6). Night: `EntityAI` with the level's params, `onCatch` -> out (`caught`), or on Easy downed with a revive
prompt (as Hide and Seek) and solo wake-up at the entrance (-20 game minutes). 05:00 -> ending 7. Everyone out ->
`CampaignRules.allOutEnding`. Needs `Doors.setLocked(door, locked)` added to `Doors.luau`.

- [ ] Implement; Studio runs at timeScale 0.05 reaching endings 1, 2, 6, 7, 9 by scripted actions; record each.

### Task 8: Difficulty runs, docs, review

- [ ] Studio: start Easy, Normal and Hard; check lesson count, quiz mode, clue count, entity speed from the snapshot
  and attributes.
- [ ] README: Story section (how to play, difficulty table, team rules), checklist items; ledger rulings; memory.
- [ ] Final review by a fresh reviewer (most capable model) with this Review Focus; fix Critical/Important; rebuild.
