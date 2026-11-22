--!strict
-- Round rules of both modes (HORROR-GAME/scripts/match.gd, player.gd, docs/multiplayer-modes.md), as pure functions.
-- Callers pass the numbers from Config, so this module needs nothing else.

export type Mode = "hideseek" | "deduction" | "campaign" | "freeroam"
export type EntityChoice = "computer" | "player"
export type Stamina = { value: number, exhausted: boolean, delay: number }
export type StaminaParams = {
	staminaMax: number,
	staminaDrain: number,
	staminaRegen: number,
	staminaDelay: number,
	staminaResume: number,
}
type Vec = { X: number, Y: number, Z: number }

local Rules = {}

function Rules.canStart(mode: Mode, entity: EntityChoice, players: number): (boolean, string?)
	if mode == "campaign" or mode == "freeroam" then
		return players >= 1, if players >= 1 then nil else "Nobody is here to play."
	end
	if mode == "deduction" then
		if entity ~= "player" then
			return false, "Social Deduction has no computer entity."
		end
		if players < 3 then
			return false, "Social Deduction needs at least 3 players."
		end
	elseif entity == "player" and players < 2 then
		return false, "A player entity needs at least 2 players."
	end
	return true, nil
end

-- Social Deduction entities, decided once at round start.
function Rules.entityCount(players: number, secondAt: number): number
	return if players >= secondAt then 2 else 1
end

-- states: survivor -> "alive" | "downed" | "out". The entity wins when nobody is up (also when everyone left);
-- the survivors win when time runs out with someone not out.
-- A held ("downed") survivor can still fight the entity off, so they keep the round going; when time runs out,
-- only survivors still up count.
function Rules.hideSeekResult(states: { [any]: string }, timeUp: boolean): ("survivors" | "entity")?
	local held = false
	for _, state in states do
		if state == "alive" then
			return if timeUp then "survivors" else nil
		elseif state == "downed" then
			held = true
		end
	end
	return if held and not timeUp then nil else "entity"
end

function Rules.deductionResult(livingEntities: number, livingCrew: number, timeUp: boolean): ("crew" | "entity")?
	if livingEntities == 0 then
		return "crew"
	end
	if livingEntities >= livingCrew then
		return "entity"
	end
	return if timeUp then "crew" else nil
end

-- votes: voter -> target or "skip". A target needs more than half of the living players' votes; skip never ejects.
function Rules.tallyVotes(votes: { [string]: string }, living: number): (string?, { [string]: number })
	local counts: { [string]: number } = {}
	for _, target in votes do
		counts[target] = (counts[target] or 0) + 1
	end
	for target, count in counts do
		if target ~= "skip" and count > living / 2 then
			return target, counts
		end
	end
	return nil, counts
end

-- When an entity may take someone down next: `first` seconds into the night, then `cooldown` after its last one.
function Rules.takedownReadyAt(nightStart: number, last: number?, first: number, cooldown: number): number
	return if last then last + cooldown else nightStart + first
end

function Rules.canCallMeeting(now: number, nightStart: number, used: boolean, lockout: number): boolean
	return not used and now - nightStart >= lockout
end

function Rules.newStamina(max: number): Stamina
	return { value = max, exhausted = false, delay = 0 }
end

-- One frame of stamina. Holding sprint keeps the refill delay, even when exhausted or standing. Returns whether the
-- player sprints this frame.
function Rules.stepStamina(s: Stamina, held: boolean, moving: boolean, dt: number, p: StaminaParams): boolean
	local sprinting = held and moving and not s.exhausted
	if sprinting then
		s.value -= p.staminaDrain * dt
		if s.value <= 0 then
			s.value = 0
			s.exhausted = true
		end
	end
	if held then
		s.delay = p.staminaDelay
	else
		s.delay -= dt
		if s.delay <= 0 then
			s.value = math.min(p.staminaMax, s.value + p.staminaRegen * dt)
		end
	end
	if s.exhausted and s.value >= p.staminaResume then
		s.exhausted = false
	end
	return sprinting
end

-- The torch flash hits a target within maxDist and within coneDeg of the look direction.
function Rules.flashHits(origin: Vec, look: Vec, target: Vec, maxDist: number, coneDeg: number): boolean
	local dx, dy, dz = target.X - origin.X, target.Y - origin.Y, target.Z - origin.Z
	local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
	if dist > maxDist then
		return false
	end
	if dist < 1e-6 then
		return true
	end
	local lookLen = math.sqrt(look.X * look.X + look.Y * look.Y + look.Z * look.Z)
	if lookLen < 1e-6 then
		return false
	end
	local cos = (dx * look.X + dy * look.Y + dz * look.Z) / (dist * lookLen)
	return math.deg(math.acos(math.clamp(cos, -1, 1))) <= coneDeg
end

return Rules
