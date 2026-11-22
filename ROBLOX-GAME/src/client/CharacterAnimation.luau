-- Your own character's animations, in place of Roblox's default Animate script (which half-jogs at this game's walk:
-- src/shared/Gait.luau). Idle, walk, run, jump, fall, sit and climb, with the walk and run timed to your real speed so
-- the feet keep to the ground. Your client plays them on your character, so everyone else sees them too.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Gait = require(ReplicatedStorage.Shared.Gait)
local Maid = require(ReplicatedStorage.Shared.Maid)

local player = Players.LocalPlayer
local CharacterAnimation = {}

-- Roblox's default R15 animations (the ids its Animate script uses).
local IDS = {
	idle = "rbxassetid://507766388",
	walk = "rbxassetid://913402848",
	run = "rbxassetid://913376220",
	jump = "rbxassetid://507765000",
	fall = "rbxassetid://507767968",
	sit = "rbxassetid://2506281703",
	climb = "rbxassetid://507765644",
}
local LOOPED = { idle = true, walk = true, run = true, fall = true, sit = true, climb = true }
local FADE = 0.2

local maid = Maid.new()

local function onCharacter(character: Model)
	maid:clean()
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	-- Roblox's Animate script: off, and whatever it started stops.
	local default = character:WaitForChild("Animate", 3)
	if default then
		default:Destroy()
	end
	local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 5) :: Animator?
	if not animator then
		return
	end
	for _, track in animator:GetPlayingAnimationTracks() do
		track:Stop(0)
	end
	local tracks: { [string]: AnimationTrack } = {}
	for name, id in IDS do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if ok and track then
			track.Looped = LOOPED[name] == true
			track.Priority = if name == "idle" or name == "walk" or name == "run" then Enum.AnimationPriority.Core
				else Enum.AnimationPriority.Movement
			tracks[name] = track
		end
	end
	-- The ground loops always play; their weights change. The others play over them when needed.
	for _, name in { "idle", "walk", "run" } do
		local track = tracks[name]
		if track then
			track:Play(0, if name == "idle" then 1 else 0.001)
		end
	end
	local over: string? = nil -- "jump" | "fall" | "sit" | "climb"
	local function setOver(name: string?)
		if over == name then
			return
		end
		if over and tracks[over] then
			tracks[over]:Stop(FADE)
		end
		over = name
		if name and tracks[name] then
			tracks[name]:Play(if name == "jump" then 0.1 else FADE)
		end
	end
	local fallingSince = 0
	maid:give(humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping then
			setOver("jump")
		elseif new == Enum.HumanoidStateType.Freefall then
			fallingSince = os.clock()
		elseif new == Enum.HumanoidStateType.Seated then
			setOver("sit")
		elseif new == Enum.HumanoidStateType.Climbing then
			setOver("climb")
		elseif new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running
			or new == Enum.HumanoidStateType.RunningNoPhysics then
			setOver(nil)
		end
	end))
	local root = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not root then
		return
	end
	local heightScale = (humanoid:FindFirstChild("BodyHeightScale") :: NumberValue?)
	maid:give(RunService.RenderStepped:Connect(function()
		if not character.Parent then
			return
		end
		local state = humanoid:GetState()
		if state == Enum.HumanoidStateType.Freefall and over ~= "fall" and os.clock() - fallingSince > 0.3 then
			setOver("fall")
		end
		if over == "climb" and tracks.climb then
			tracks.climb:AdjustSpeed(root.AssemblyLinearVelocity.Y / 6)
		end
		local v = root.AssemblyLinearVelocity
		local speed = if root.Anchored or humanoid.Sit then 0 else Vector3.new(v.X, 0, v.Z).Magnitude
		local pose = Gait.pose(speed, if heightScale then heightScale.Value else 1)
		local function set(name: string, weight: number, playback: number)
			local track = tracks[name]
			if track then
				track:AdjustWeight(math.max(weight, 0.001), FADE)
				track:AdjustSpeed(playback)
			end
		end
		set("idle", pose.idle, 1)
		set("walk", pose.walk, pose.walkSpeed)
		set("run", pose.run, pose.runSpeed)
	end))
end

function CharacterAnimation.init()
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

return CharacterAnimation
