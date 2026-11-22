--!strict
-- Sound asset ids ("rbxassetid://<number>"), all free sounds from the Roblox Creator Store (checked to load in Studio
-- on 2026-11-21). An empty id means the sound is skipped. To change one: search the Creator Store (Toolbox > Audio) in
-- Studio, copy the asset id and paste it here.

local Sounds = {}

Sounds.IDS = {
	sting = "rbxassetid://92700004957359", -- scare sting: the hunt starts, someone is caught or taken down nearby
	heartbeat = "rbxassetid://139481207162657", -- one heartbeat, repeated while the entity is within 12 m
	entitySteps = "", -- the entity's footsteps
	torchClick = "rbxassetid://9070807695", -- phone flashlight on or off
	locker = "rbxassetid://9116742347", -- locker door
	breath = "", -- holding breath
	door = "rbxassetid://96136915248428", -- a door opening
	bell = "rbxassetid://2783281207", -- school bell
	scream = "rbxassetid://9125652432", -- a student taken by the entity (heard across the school)
	bump = "rbxassetid://9113135029", -- distant knocks and creaks in the empty school at night
	bark = "rbxassetid://135016436724006", -- Csoki barks (the entity or the caretaker is near)
	pong = "rbxassetid://9117374562", -- a ping pong ball on the table
	bounce = "rbxassetid://377958030", -- a basketball on the gym floor
	achievement = "rbxassetid://85188102085028", -- an achievement unlocked (only you hear it)
	-- Loops played by the client's ambience (src/client/Ambience.luau).
	hum = "rbxassetid://4227579935", -- fluorescent lamp hum, louder under a lamp
	chatter = "rbxassetid://9112811168", -- students talking, by day while people are in the school
	birds = "rbxassetid://9112831284", -- birds outside, by day
	wind = "rbxassetid://551546110", -- wind on the windows, at night
	drone = "rbxassetid://1842083079", -- a low uneasy drone, at night
	-- Your own footsteps and landings (empty: Roblox's built-in step and landing sounds). Per floor material:
	-- footstep_Concrete, footstep_WoodPlanks, footstep_SmoothPlastic, footstep_Grass, footstep_Metal ...
	footstep = "",
	land = "",
} :: { [string]: string }

Sounds.VOLUME = {
	sting = 0.8,
	heartbeat = 0.7,
	torchClick = 0.35,
	locker = 0.6,
	door = 0.45,
	bell = 0.5,
	scream = 1,
	bump = 0.5,
	bark = 0.8,
	pong = 0.6,
	bounce = 0.6,
	achievement = 0.5,
} :: { [string]: number }

-- Seconds after which a one-shot sound is cut (a heartbeat clip holds several beats; one is wanted).
Sounds.LENGTH = {
	heartbeat = 1.0,
	pong = 0.35, -- one tap of the clip
	bounce = 0.6,
} :: { [string]: number }

-- How far (metres) a sound played at a point carries; 30 m when not listed.
Sounds.RANGE = {
	scream = 90,
	bump = 45,
	door = 20,
	locker = 20,
	bark = 45,
	pong = 15,
	bounce = 25,
} :: { [string]: number }

return Sounds
