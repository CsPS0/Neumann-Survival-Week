# A living school: furniture, people, daylight and atmosphere

Date: 2026-11-21. Status: approved by the user's answers in chat (2026-11-21).

## Intent

The school feels empty. Fill it the way the real one is: furnished rooms, people, daylight by day, sounds and light
that make the night scarier.

## Decided with the user

- **Night people are victims** (Hide and Seek, Social Deduction): a few students stayed late. They wander, panic and
  run when the entity is near, and the entity can take them; everyone hears the scream, which hints where the entity
  is. In Social Deduction their bodies can be reported like a player's.
- **Daytime:** the lobby is a sunny school day; the story follows its clock (sun by day, dusk at 18:00, night after).
  Hide and Seek and Social Deduction stay at night.
- **People everywhere** (from 2026-11-20): students, teachers and workers (cleaner, kitchen staff, the caretaker).

## Design

### Furniture (server, `src/server/Furniture.luau`, built by `SchoolBuilder` per room kind)

- Classroom (`normal`): rows of two-seat desks facing the board wall, the teacher's desk at the front, a cupboard.
- IT room (`computer`): PC desks along the walls and in rows (monitor with a glowing screen, keyboard), a server
  cabinet with blinking lights.
- `changing`: benches and coat hooks; `library`: shelves; `office`: desks with chairs and a cabinet; `dining`: long
  tables with benches; `kitchen`: counters and a stove; `wc`: stalls with doors; `gym`: wall bars and benches;
  `lab`: lab benches; `medical`: a bed and a cabinet; `storage`: shelves and boxes.
- Rules (as built after Studio pathfinding checks): a 2 m wide strip 1.3 m into the room at every door, a clear
  middle (6 m in the story rooms 14, 24, 33 and 229, 2.4 m in the 20 clue rooms, 1 m elsewhere; a 3.4 m square
  everywhere left the small real classrooms with no desk rows), 1.4 m walkways from each door to the middle in rooms
  with two or more doors (some are the only way into a wing), aisles at least 1 m (people and the entity walk
  through). Chairs are `Seat`s with touch sitting off, so people can be seated but players never sit by accident.
- Budget: the school may grow to about 7,000 parts if the frame rate stays at 60 (desks are 2-3 parts each).

### Daylight and outdoors (server `src/server/DayNight.luau`, client effects)

- Lighting follows a time of day: lobby 10:30 (sun), story the `CampaignMinutes` clock, Hide and Seek and Social
  Deduction 00:30 (night). Day: bright sun, blue sky, light haze; dusk: orange low sun; night: today's look.
- Outside the windows: grass around the building, a street with pavements, a few trees, lamp posts and neighbouring
  blocks, so the windows show something by day and night.

### Atmosphere

- Sounds from Roblox's free audio library (`Sounds.IDS`): fluorescent hum near lamps, distant doors and footsteps,
  wind on the windows, school chatter by day, the bell, screams. No uploads.
- Light: dust in the lamps' light, lamps that flicker more at night, the screens of the IT rooms glowing.

### People (server `src/server/People.luau`)

- Built with the existing `Npc` module (pathfinding, doors). At most about 24 near players at a time; far away ones
  are not simulated.
- Lobby and story day: students in small groups, teachers, a cleaner, kitchen staff. In lessons students sit in
  classrooms (the lesson's room gets the class), in breaks they walk the corridors; at the story's explosion
  everyone walks out and is gone.
- Hide and Seek and Social Deduction: 4-6 victims wander; in Hide and Seek they run from the entity (computer or
  player) within 12 m. In Social Deduction they do not run (running from one player would give the secret entity
  away), and taking one counts as the entity's takedown (same cooldown).
  The computer entity takes one it reaches; the player entity takes one with E. A take is a scream for everyone at
  that spot; in Social Deduction the body stays and can be reported (counts like a player's body for meetings),
  in Hide and Seek it is gone.
- The story's teachers and porter stay as they are (the suspects).

## Testing

Dry run (0 blocked doors with furniture), Lune tests for furniture placement rules on every room, Studio
screenshots by day and night, a story run, a Hide and Seek round with a victim taken, FPS check.
