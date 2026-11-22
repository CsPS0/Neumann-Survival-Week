-- The school's background: the hum of the lamp above you, students talking and birds outside by day, wind, a low
-- drone and distant knocks at night, dust drifting in the lamps' light, and lamps that stutter now and then after
-- dark. Also the click of the phone flashlight. Volumes follow the time of day (src/shared/Daylight.luau) and the
-- menu's volume setting. Everything here is local: nothing is sent to the server.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Daylight = require(ReplicatedStorage.Shared.Daylight)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local ClientSettings = require(script.Parent.ClientSettings)
local Effects = require(script.Parent.Effects)

local S = Config.studs
local player = Players.LocalPlayer

local Ambience = {}

-- Highest volume of each loop.
local LOUDEST = {
	hum = 0.22,
	chatter = 0.16,
	birds = 0.1,
	wind = 0.12,
	drone = 0.08,
}

local function loop(name: string): Sound?
	local id = Sounds.IDS[name]
	if not id or id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "Ambience_" .. name
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = 0
	sound.SoundGroup = ClientSettings.group()
	sound.Parent = SoundService
	sound:Play()
	return sound
end

local function lampsOf(school: Instance): { SpotLight }
	local list = {}
	for _, d in school:GetDescendants() do
		if d:IsA("SpotLight") then
			table.insert(list, d)
		end
	end
	return list
end

-- Specks of dust sinking slowly through each lamp's light.
local function addDust(light: SpotLight)
	local part = light.Parent
	if not part or not part:IsA("BasePart") or part:FindFirstChild("Dust") then
		return
	end
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "Dust"
	dust.Rate = 1.2
	dust.Lifetime = NumberRange.new(6, 9)
	dust.Speed = NumberRange.new(0.1, 0.35)
	dust.SpreadAngle = Vector2.new(70, 70)
	dust.EmissionDirection = Enum.NormalId.Bottom
	dust.Acceleration = Vector3.new(0, -0.04, 0)
	dust.Drag = 0.6
	dust.Size = NumberSequence.new(0.05)
	dust.LightEmission = 0.5
	dust.LightInfluence = 1
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.45),
		NumberSequenceKeypoint.new(0.8, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Color = ColorSequence.new(Color3.fromRGB(235, 230, 210))
	dust.RotSpeed = NumberRange.new(-20, 20)
	dust.Parent = part
end

local function stutter(light: SpotLight)
	task.spawn(function()
		local stop = os.clock() + 0.3 + math.random() * 0.9
		while os.clock() < stop do
			light.Enabled = math.random() < 0.4
			task.wait(0.05 + math.random() * 0.08)
		end
		light.Enabled = true
	end)
end

function Ambience.init()
	local loops: { [string]: Sound? } = {}
	for name in LOUDEST do
		loops[name] = loop(name)
	end

	player:GetAttributeChangedSignal("TorchOn"):Connect(function()
		Effects.play("torchClick")
	end)

	task.spawn(function()
		local school = workspace:WaitForChild("School", 60)
		if not school then
			return
		end
		task.wait(1) -- the server builds the school before anyone joins; let it replicate
		local lamps = lampsOf(school)
		for _, light in lamps do
			addDust(light)
		end

		local nextStutter = os.clock() + 8
		local nextBump = os.clock() + 20
		local volumes: { [string]: number } = {}
		while true do
			local dt = task.wait(0.25)
			local camera = workspace.CurrentCamera
			local at = if camera then camera.CFrame.Position else Vector3.zero
			local day = Daylight.at(Lighting.ClockTime)
			local mode = ReplicatedStorage:GetAttribute("Mode")

			-- The nearest lit lamp sets the hum.
			local nearest, nearestLight = math.huge, nil
			for _, light in lamps do
				local part = light.Parent
				if light.Enabled and part and part:IsA("BasePart") then
					local d = (part.Position - at).Magnitude
					if d < nearest then
						nearest, nearestLight = d, light
					end
				end
			end
			local underLamp = math.clamp(1 - nearest / S(7), 0, 1)

			-- People talking near you.
			local near = 0
			local people = workspace:FindFirstChild("People")
			if people then
				for _, m in people:GetChildren() do
					if m:IsA("Model") and not m:GetAttribute("Victim") and (m:GetPivot().Position - at).Magnitude < S(25) then
						near += 1
					end
				end
			end

			local target = {
				hum = underLamp * (0.35 + 0.65 * (1 - day * 0.7)),
				chatter = math.min(1, near / 6) * day,
				birds = day,
				wind = 1 - day,
				drone = if mode == "hideseek" or mode == "deduction" or mode == "campaign" then 1 - day else 0,
			}
			for name, sound in loops do
				if sound then
					local goal = (target[name] or 0) * LOUDEST[name]
					local v = volumes[name] or 0
					v += math.clamp(goal - v, -dt * 0.15, dt * 0.15)
					volumes[name] = v
					sound.Volume = v * ClientSettings.values.ambience
				end
			end

			-- After dark: a lamp near you stutters now and then, and something knocks somewhere in the building.
			local now = os.clock()
			if day < 0.2 and now >= nextStutter then
				nextStutter = now + 6 + math.random() * 14
				if nearestLight and nearest < S(20) then
					stutter(nearestLight)
				end
			end
			if day < 0.2 and mode ~= "none" and mode ~= nil and now >= nextBump then
				nextBump = now + 25 + math.random() * 40
				local angle = math.random() * math.pi * 2
				local dist = S(15 + math.random() * 15)
				Effects.play("bump", at + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist))
			end
		end
	end)
end

return Ambience
