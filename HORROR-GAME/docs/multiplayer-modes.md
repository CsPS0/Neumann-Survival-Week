# Multiplayer modes: design note

Two round-based modes sit on top of the existing co-op session. The solo campaign and the co-op campaign do not change. Both modes use the school as an empty night map: no lessons, teachers, students, caretaker or story items.

Status: Hide and Seek is built. Social Deduction is designed here and ships in a second pull request.

## Shared rules

- **Session.** The host or the dedicated server from [Co-op and dedicated server](../README.md#co-op-and-dedicated-server). Up to 4 clients, plus the host when the host plays.
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

## Mode 1: Social Deduction (second pull request)

One player is secretly the entity. The others are students and teachers. Players never get a bot entity in this mode, because the idea is that nobody knows who it is.

| Item | Rule |
|---|---|
| Roles | 1 entity for up to 5 players. The rest are crew. Crew roles (student or teacher) are a name tag only. |
| Entity ability | Takes a crew member down when close, with a 30 s cooldown. Looks like any other player. |
| Information about the entity | The crew gathers it from: the room log (who was in which room at which time, reported by each device when it changes rooms), clue pickups that the entity's real movements generate (for example "Someone left room 24 at 14:10"), and the lights near a takedown flickering for a moment. Existing clue and find pickups are reused for the carriers. |
| Meetings | Finding a body or pressing the meeting button on the Aula table starts a vote: 60 s, one vote each, skip allowed. The player with the most votes and more than half of the living players' votes is ejected and their role is shown. |
| Crew wins | The entity is ejected, or the crew collects all the clue pickups. |
| Entity wins | The living crew is not larger than the living entities. |
| Authority | Peer 1 keeps roles secret: it sends each player only their own role until the round ends. |

This mode adds the vote UI and the room log. It reuses the lobby, `match.gd` phases and the world layer from Hide and Seek.

## Testing

Real multi-player play is not tested by the author. The checks run headless with the Godot binary: a solo round with the computer entity, two processes (host and client) with a player as the entity, and a dedicated server with two clients and the computer entity. See the pull request for the exact list.
