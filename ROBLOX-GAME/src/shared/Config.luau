--!strict
-- Every number the game uses, in metres and seconds as in the Godot version (HORROR-GAME/scripts).
-- Roblox code converts metres with Config.studs(m); nothing else knows the stud scale.

local Config = {}

Config.STUDS_PER_METRE = 3

function Config.studs(metres: number): number
	return metres * Config.STUDS_PER_METRE
end

-- The school (main.gd, floor_data.gd).
Config.WORLD_SCALE = 1.25
Config.FLOOR_HEIGHT = 4.0
Config.WALL_HEIGHT = 3.2
Config.WALL_THICKNESS = 0.25
Config.DOOR_WIDTH = 1.5
Config.DOOR_HEIGHT = 2.2
Config.WINDOW_SILL = 0.9
Config.WINDOW_TOP = 2.4
Config.WINDOW_WIDTH = 1.6
Config.WINDOW_PITCH = 3.2
Config.INNER_WINDOWS = { Porta = "E", ["Büfé"] = "W" } -- Room -> side with a window in place of a wall.
Config.INNER_WINDOW_WIDTH = 1.2
Config.STAIR_STEPS = 22

-- The stairwells come from the map: FloorData.STAIRS.
Config.SPAWN = { X = -2.4 * Config.WORLD_SCALE, Y = 0.1, Z = 13.4 * Config.WORLD_SCALE }
Config.MAX_PLAYERS = 10
Config.RESTART_DELAY = 12

-- Modes (match.gd).
Config.HideSeek = {
	hide = 25,
	hunt = 240,
	downed = 25,
	result = 12,
	reviveHold = 3,
}

Config.Deduction = {
	brief = 8,
	night = 360,
	meeting = 45,
	meetingResult = 6,
	result = 12,
	takedownCooldown = 30,
	firstTakedown = 20,
	meetingLockout = 15,
	minPlayers = 3,
	logAge = 60,
	secondEntityAt = 8,
	flickerRange = 20,
	flickerTime = 1.6,
}

-- Players (player.gd).
Config.Player = {
	walk = 3.0,
	sprint = 5.5,
	seeker = 4.2,
	staminaMax = 100,
	staminaDrain = 20,
	staminaRegen = 12.5,
	staminaDelay = 1.0,
	staminaResume = 30,
	-- Movement controller (new on Roblox).
	crouch = 1.6,
	accel = 12, -- player.gd acceleration
	slideBoost = 1.3,
	slideTime = 0.8,
	slideMin = 4.8,
	slideCost = 20, -- stamina
	slideCooldown = 1.2,
}

-- First-person camera motion (studs and degrees). The bob height follows player.gd (0.045 m); its rate is one dip
-- (and one footstep) per 1.2 m walked: 2*pi / 1.2 radians per metre.
Config.Camera = {
	bobAmplitude = 0.2, -- 6.7 cm: easy to feel, not sickening
	bobFrequency = 5.2,
	bobRoll = 0.6, -- degrees of side-to-side roll per stride while walking (more when running)
	breathe = 0.025, -- studs of slow up-and-down while standing still
	strafeRoll = 2.5,
	slideRoll = 4,
	sprintFov = 8,
	crouchOffset = -1.4,
	forwardOffset = -0.55, -- the camera sits at the eyes, at the front of the face, not in the middle of the head
	eyeHeight = 0.15, -- eyes above the middle of the head
	lookRate = 15, -- head pitch updates per second sent to other players
}

Config.Torch = {
	range = 9,
	coneDeg = 35,
	cooldown = 12,
	cost = 15,
	drainPerSec = 0.3,
	stun = 3,
	batteryMax = 100,
}

-- The entity (horror_entity.gd).
Config.Entity = {
	patrolSpeed = 1.9,
	chaseSpeed = 4.2,
	sight = 15,
	proximity = 2.5,
	hearing = 12,
	loseSight = 4,
	attackRange = 1.4,
	attackDuration = 1.5,
	blindAfterStun = 3,
	hintInterval = 15,
	idleTime = 3,
	roamMin = 10,
	waypointBias = 0.35,
	lockerCheck = 2.5,
}

return Config
