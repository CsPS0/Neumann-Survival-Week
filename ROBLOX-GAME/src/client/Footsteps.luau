-- Your own footsteps, played by CameraController at the bottom of each head-bob dip, with a pitch per floor
-- material. Sounds come from src/shared/Sounds.luau (footstep_<Material> or footstep); empty ids fall back to Roblox's
-- built-in step sound. Roblox's default "Running" loop on your own character is muted, so steps never double up.
-- Other players still hear your default footsteps.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sounds = require(ReplicatedStorage.Shared.Sounds)
local ClientSettings = require(script.Parent.ClientSettings)

local player = Players.LocalPlayer

local BUILT_IN_STEP = "rbxasset://sounds/action_footsteps_plastic.mp3"
local BUILT_IN_LAND = "rbxasset://sounds/action_jump_land.mp3"

local PITCH: { [string]: number } = {
	Concrete = 0.9,
	SmoothPlastic = 1.0,
	Plastic = 1.0,
	WoodPlanks = 1.12,
	Wood = 1.12,
	Metal = 1.3,
	DiamondPlate = 1.3,
	Grass = 0.8,
	Glass = 1.4,
}

local Footsteps = {}

local function soundId(material: Enum.Material): string
	local specific = Sounds.IDS["footstep_" .. material.Name]
	if specific and specific ~= "" then
		return specific
	end
	local general = Sounds.IDS.footstep
	return if general and general ~= "" then general else BUILT_IN_STEP
end

local function play(id: string, volume: number, pitch: number, region: NumberRange?)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = pitch * (0.94 + math.random() * 0.12)
	sound.SoundGroup = ClientSettings.group()
	if region then
		sound.PlaybackRegionsEnabled = true
		sound.PlaybackRegion = region
	end
	sound.Parent = root
	sound:Play()
	task.delay(1.5, function()
		sound:Destroy()
	end)
end

function Footsteps.step(material: Enum.Material, speed: number)
	local id = soundId(material)
	-- The built-in file is a loop of several steps: play one step from its start.
	local region = if id == BUILT_IN_STEP then NumberRange.new(0, 0.22) else nil
	play(id, math.clamp(0.25 + speed * 0.06, 0.25, 0.6), PITCH[material.Name] or 1, region)
end

function Footsteps.land(material: Enum.Material, amount: number)
	local id = Sounds.IDS.land
	play(if id and id ~= "" then id else BUILT_IN_LAND, 0.3 + amount * 0.5, PITCH[material.Name] or 1, nil)
end

-- Mutes Roblox's default running loop on your own character (it is added by the default character sounds script).
function Footsteps.init()
	local function mute(d: Instance)
		if d:IsA("Sound") and d.Name == "Running" then
			d.Volume = 0
		end
	end
	local function onCharacter(character: Model)
		for _, d in character:GetDescendants() do
			mute(d)
		end
		character.DescendantAdded:Connect(mute)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

return Footsteps
