# Multiplayer modes: design note

Two round-based modes sit on top of the existing co-op session. The solo campaign and the co-op campaign do not change. Both modes use the school as an empty night map: no lessons, teachers, students, caretaker or story items.

Status: both modes are built. Hide and Seek came first; Social Deduction is the second pull request.

## Shared rules

- **Session.** The host or the dedicated server from [Co-op](../README.md#co-op). Up to 4 clients, plus the host when the host plays.
- **Authority.** Peer 1 owns the match: roles, phase, timers and the win check. This is the hosting player, or the dedicated server, which runs `scripts/match.gd` without a world. Other peers send reports and mirror what peer 1 broadcasts. The game still runs on each device: peer 1 does not simulate the school.
- **Start.** Any player in the lobby can start a round. The first round uses the options picked in the lobby. Later rounds start by themselves 12 seconds after a result, with the same options. Leaving the match from the pause menu returns to the title screen.
- **Late joiners** watch the running round as spectators and play from the next round.
- **No cheating protection.** Positions and catches are reported by the clients and peer 1 checks only who is allowed to report. This is a school game on trusted networks.

## Mode 2: Hide and Seek

One entity hunts the survivors. Built first because it reuses the entity, the lockers and the torch flash.

| Item | Rule |
|---|---|
| Entity | The computer (default) or a random player. A player as the entity needs at least 2 players. |
| Computer entity | Runs on one device: peer 1 when it plays, otherwise the lowest client id. If that player leaves, the next lowest id takes over. |
| Phases | Hiding 25 s, Hunt 240 s, Result 12 s. |
| Hiding | Survivors spawn at the entrance and scatter. The entity waits in a far corner of the school (a player as the entity sees a black screen). |
| Hunt | The entity wakes. The computer entity hunts the nearest survivor who is not hiding, hears sprinting, and senses roughly where its target is every 15 s. A player entity walks at a fixed 4.2 m/s, has no torch and catches by looking at a survivor and pressing E. |
| Counterplay | Lockers hide a survivor. The entity checks the locker only when it passes within 2.5 m and the survivor is not holding their breath (Space). The torch flash (T) stuns the entity for 3 s. |
| Caught | The survivor is downed for 25 s. A free teammate revives by holding E for 3 s. A survivor who is not revived in time is out. |
| Survivors win | The Hunt timer ends and at least one survivor is not out. |
| Entity wins | Every survivor is downed or out at the same time. |
| Leaving | The entity leaving ends the round for the survivors. A survivor leaving counts as out. |

What is synced (all through `scripts/match.gd`):

- Round start: mode, entity id, computer host id, survivor ids (reliable, from peer 1).
- Phase and timer (reliable, from peer 1). Every device counts the timer for display.
- Survivor states: alive, downed, out (reliable, from peer 1). Catch and revive are reports to peer 1.
- Hiding on and off (reliable, from the survivor) so others hide the puppet and the computer entity skips the survivor.
- Entity position and look, 20 times a second (unreliable, from the device that drives it). Every other device shows the same `HorrorEntity` node following that stream, so footsteps, the heartbeat and the flash work as in the campaign.
- Stun (reliable, from the flashing player) to the device that drives the entity.

Not in this mode yet: generators or other objectives, a spectator camera for eliminated players, a relay for players on different networks.

## Mode 1: Social Deduction

One player is secretly the entity. The others are students and teachers. There is no computer entity in this mode, because the point is that nobody knows who it is.

| Item | Rule |
|---|---|
| Players | 3 to 5. One random player is the entity. The rest are crew. Names are tags only: "Student 1", "Teacher 2" and so on (the real peer ids are never shown). |
| Phases | Get ready 8 s, Night 360 s, Meeting 45 s (then 6 s to read the result), Result 12 s. |
| Secrecy | Peer 1 sends each player only their own role. The entity id stays on peer 1 until the round is over. |
| Entity | Looks like any other player. Looks at a crew member and presses E to take them down, 20 s after the night starts and then every 30 s. The crew member becomes a body and is out. |
| Evidence | Three kinds. 1) The room log: every device reports its room when it changes. A meeting shows the last minute of rooms for each living player and for the victim. The log is true, also for the entity. 2) The lights near a takedown flicker for 1.6 s for everyone within 20 m. 3) Seeing a puppet vanish into a locker or walk out of a room. |
| Meetings | Pressing E on a body reports it. Pressing G calls a meeting once per player and round, not in the first 15 s of the night. Everyone is frozen, the bodies are removed and the log is shown in a vote list. |
| Vote | One vote each, or skip. The player with more than half of the living players' votes is ejected and their role is shown. A tie or too few votes ejects nobody. The meeting ends early when all living players have voted. |
| After a meeting | Everyone starts again at the entrance. |
| Crew wins | The entity is ejected, or the night ends with the entity still in. |
| Entity wins | The living crew is not larger than the entity (with one entity, one crew member left). |
| Leaving | The entity leaving ends the round for the crew. A crew member leaving counts as out. |

What is synced: the same channels as Hide and Seek, plus: the secret role (reliable, to one peer), labels, takedown and body reports (reliable, to peer 1, which broadcasts the body), room reports, votes and the meeting result.

Not in this mode yet: crew tasks (the crew can only win by voting or surviving), a spectator camera or ghost play for players who are out, and touch controls for G.

## Testing

Real multi-player play is not tested by the author. The checks run headless with the Godot binary: a solo round with the computer entity, two processes (host and client) with a player as the entity, a dedicated server with two clients and the computer entity, and four processes for Social Deduction (takedown, body report, meeting, vote and the result). See the pull request for the exact list.
