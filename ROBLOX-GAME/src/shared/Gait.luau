--!strict
-- How the walk and run animations follow the speed (players: client/CharacterAnimation, people: server Npc).
-- Roblox's default R15 walk (913402848) matches the ground at 6.4 studs/s and its run (913376220) at 12.8 studs/s
-- for a body of height scale 1 (the numbers Roblox's own Animate script uses). Its Animate mixes the two at normal
-- speed between those paces, so at this game's walk (3 m/s, 9 studs/s) the body half-jogs and the feet slide. Here
-- a walk is a pure walk and a sprint a pure run, each sped up or slowed down so the feet keep to the ground; only a
-- short band between them crossfades.

local Gait = {}

Gait.WALK_PACE = 6.4 -- studs/s at which the walk animation plays at speed 1
Gait.RUN_PACE = 12.8
Gait.BLEND_FROM = 11 -- studs/s: pure walk below, pure run above BLEND_TO
Gait.BLEND_TO = 14
Gait.STILL = 0.6 -- studs/s: slower than this is standing

export type Pose = { idle: number, walk: number, run: number, walkSpeed: number, runSpeed: number }

-- Weights (0..1, summing to 1) and playback speeds for a horizontal speed in studs/s and a body height scale.
function Gait.pose(speed: number, heightScale: number?): Pose
	local h = math.max(heightScale or 1, 0.3)
	if speed < Gait.STILL then
		return { idle = 1, walk = 0, run = 0, walkSpeed = 1, runSpeed = 1 }
	end
	local blend = math.clamp((speed - Gait.BLEND_FROM * h) / ((Gait.BLEND_TO - Gait.BLEND_FROM) * h), 0, 1)
	return {
		idle = 0,
		walk = 1 - blend,
		run = blend,
		walkSpeed = math.clamp(speed / (Gait.WALK_PACE * h), 0.4, 2.2),
		runSpeed = math.clamp(speed / (Gait.RUN_PACE * h), 0.6, 1.8),
	}
end

return Gait
