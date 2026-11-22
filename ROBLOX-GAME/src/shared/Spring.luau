--!strict
-- A damped harmonic spring for camera motion: position follows `target` with stiffness `speed` (angular frequency)
-- and `damping` (1 = critically damped, below 1 overshoots). Long frames are split into small steps, so a hitch
-- never makes it explode.

local Spring = {}
Spring.__index = Spring

export type Spring = typeof(setmetatable(
	{} :: { position: number, velocity: number, target: number, damping: number, speed: number },
	Spring
))

local MAX_STEP = 1 / 120

function Spring.new(initial: number, damping: number, speed: number): Spring
	return setmetatable({
		position = initial,
		velocity = 0,
		target = initial,
		damping = damping,
		speed = speed,
	}, Spring)
end

function Spring.update(self: Spring, dt: number): number
	local left = math.min(dt, 0.5)
	local k = self.speed * self.speed
	local c = 2 * self.damping * self.speed
	while left > 0 do
		local h = math.min(left, MAX_STEP)
		local accel = -k * (self.position - self.target) - c * self.velocity
		self.velocity += accel * h
		self.position += self.velocity * h
		left -= h
	end
	return self.position
end

function Spring.impulse(self: Spring, velocity: number)
	self.velocity += velocity
end

return Spring
