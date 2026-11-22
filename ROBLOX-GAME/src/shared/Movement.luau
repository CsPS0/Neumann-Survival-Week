--!strict
-- Movement maths for the client controller, in metres and seconds: speed per stance, acceleration, the slide and
-- the landing dip. Pure, so it is tested in Lune.

export type Stance = "walk" | "sprint" | "crouch"
export type Params = {
	walk: number,
	sprint: number,
	crouch: number,
	accel: number, -- m/s per second towards the target speed
	slideBoost: number, -- slide start speed = sprint speed * boost
	slideTime: number, -- seconds until the slide has slowed to crouch speed
	slideMin: number, -- horizontal speed needed to start a slide
}

local Movement = {}

function Movement.targetSpeed(stance: Stance, p: Params): number
	if stance == "sprint" then
		return p.sprint
	elseif stance == "crouch" then
		return p.crouch
	end
	return p.walk
end

-- Moves `current` towards `target` by at most accel * dt.
function Movement.approach(current: number, target: number, accel: number, dt: number): number
	local step = accel * dt
	if math.abs(target - current) <= step then
		return target
	end
	return current + math.sign(target - current) * step
end

function Movement.canSlide(horizontalSpeed: number, p: Params): boolean
	return horizontalSpeed >= p.slideMin
end

-- Speed `elapsed` seconds into a slide that started at `startSpeed`: a boost that eases out to crouch speed.
function Movement.slideSpeed(startSpeed: number, elapsed: number, p: Params): number
	if elapsed >= p.slideTime then
		return p.crouch
	end
	local left = 1 - elapsed / p.slideTime
	local boosted = startSpeed * p.slideBoost
	return p.crouch + (boosted - p.crouch) * left * left
end

-- Camera dip in studs for a landing at vertical speed `vy` (studs/s, negative = falling). Small hops do nothing.
function Movement.landingDip(vy: number): number
	local fall = -vy
	if fall <= 15 then
		return 0
	end
	return math.clamp((fall - 15) / 65, 0, 1) * 0.9
end

return Movement
