-- NPCs (the story's teachers, porter and caretaker, the people in the school): an R15 character from a
-- HumanoidDescription, a name tag (unless nameless), Roblox's default animations played by the server, and walking
-- with PathfindingService. A new walk cancels the one before. Doors open on the way, as for the entity.
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Gait = require(ReplicatedStorage.Shared.Gait)
local Doors = require(script.Parent.Parent.Doors)

local S = Config.studs

local Npc = {}

local walkToken: { [Model]: number } = {}

local SKIN = Color3.fromRGB(226, 182, 150)

export type Look = {
	skin: Color3?,
	height: number?, -- body scale, 1 = default
	width: number?,
	nameless: boolean?, -- no name tag (people in the crowd)
}

-- Roblox's default R15 animations (the ids of the Animate script a new character comes with). The Animate script is
-- a LocalScript and never runs in an NPC, so the server plays them: idle, walk, run and sit.
local ANIMS = {
	idle = "rbxassetid://507766388",
	walk = "rbxassetid://913402848",
	run = "rbxassetid://913376220",
	sit = "rbxassetid://2506281703",
}

local function animate(model: Model, humanoid: Humanoid)
	local old = model:FindFirstChild("Animate")
	if old then
		old:Destroy()
	end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local tracks: { [string]: AnimationTrack } = {}
	for name, id in ANIMS do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if ok and track then
			track.Looped = true
			track.Priority = if name == "sit" then Enum.AnimationPriority.Action else Enum.AnimationPriority.Core
			tracks[name] = track
		end
	end
	local playing: string? = nil
	local function play(name: string, speed: number?)
		local track = tracks[name]
		if not track then
			return
		end
		if playing ~= name then
			if playing and tracks[playing] then
				tracks[playing]:Stop(0.2)
			end
			track:Play(0.2)
			playing = name
		end
		if speed then
			track:AdjustSpeed(speed)
		end
	end
	play("idle")
	humanoid.Running:Connect(function(speed)
		if humanoid.Sit then
			return
		end
		-- Timed to the real speed so the feet keep to the ground (src/shared/Gait.luau).
		local scale = humanoid:FindFirstChild("BodyHeightScale") :: NumberValue?
		local pose = Gait.pose(speed, if scale then scale.Value else 1)
		if pose.idle >= 1 then
			play("idle")
		elseif pose.run > 0.5 then
			play("run", pose.runSpeed)
		else
			play("walk", pose.walkSpeed)
		end
	end)
	humanoid.Seated:Connect(function(active)
		play(if active then "sit" else "idle")
	end)
end

function Npc.build(name: string, torso: Color3, legs: Color3, at: CFrame, parent: Instance, look: Look?): Model
	local d = Instance.new("HumanoidDescription")
	local skin = look and look.skin or SKIN
	d.HeadColor, d.LeftArmColor, d.RightArmColor = skin, skin, skin
	d.TorsoColor = torso
	d.LeftLegColor, d.RightLegColor = legs, legs
	if look and look.height then
		d.HeightScale = look.height
		d.HeadScale = 0.9 + look.height * 0.1
	end
	if look and look.width then
		d.WidthScale = look.width
		d.DepthScale = look.width
	end
	local model = Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	model.Name = name
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayName = name
	humanoid.DisplayDistanceType = if look and look.nameless then Enum.HumanoidDisplayDistanceType.None
		else Enum.HumanoidDisplayDistanceType.Subject
	humanoid.NameDisplayDistance = S(8)
	humanoid.WalkSpeed = S(1.4)
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	model:PivotTo(at)
	model.Parent = parent
	animate(model, humanoid)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	game:GetService("CollectionService"):AddTag(model, "Npc") -- people react when bumped (NpcReactions)
	return model
end

-- Feet position (studs) of the centre of a room, from FloorData metres.
function Npc.roomPoint(FloorData: any, floor: number, label: string): Vector3?
	local r = FloorData.roomRect(floor, label)
	if not r then
		return nil
	end
	return Vector3.new(S((r.x0 + r.x1) / 2), S(floor * Config.FLOOR_HEIGHT) + 3, S((r.z0 + r.z1) / 2))
end

local function openDoorsNear(position: Vector3)
	for _, door in CollectionService:GetTagged("Door") do
		local panel = (door :: Model).PrimaryPart
		if panel and not door:GetAttribute("Open") and not door:GetAttribute("Locked")
			and (panel.Position - position).Magnitude < 6 then
			Doors.setOpen(door :: Model, true)
		end
	end
end

-- Walks to `target` (studs); yields until there or given up. Returns true when it arrived.
function Npc.walkTo(model: Model, target: Vector3, speed: number?): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return false
	end
	walkToken[model] = (walkToken[model] or 0) + 1
	local token = walkToken[model]
	if speed then
		humanoid.WalkSpeed = S(speed)
	end
	local path = PathfindingService:CreatePath({ AgentRadius = 1.5, AgentHeight = 5.5, AgentCanJump = false,
		WaypointSpacing = 6 })
	local ok = pcall(function()
		path:ComputeAsync(root.Position, target)
	end)
	local waypoints = if ok and path.Status == Enum.PathStatus.Success then path:GetWaypoints() else nil
	if not waypoints then
		humanoid:MoveTo(target)
		humanoid.MoveToFinished:Wait()
		return walkToken[model] == token and (root.Position - target).Magnitude < 6
	end
	-- Stuck on a wall corner (the path keeps a 0.5 m margin, bodies are wider): step aside and go on; after a few
	-- tries give up, so a stuck walker never hangs its caller.
	local nudges = 0
	for i = 2, #waypoints do
		if walkToken[model] ~= token or not model.Parent then
			return false
		end
		local wp = waypoints[i].Position
		humanoid:MoveTo(wp)
		local started = os.clock()
		local lastPos, lastMove = root.Position, os.clock()
		while model.Parent and walkToken[model] == token do
			openDoorsNear(root.Position)
			local flat = Vector3.new(wp.X - root.Position.X, 0, wp.Z - root.Position.Z)
			if flat.Magnitude < 2.5 or os.clock() - started > 6 then
				break
			end
			if (root.Position - lastPos).Magnitude > 1 then
				lastPos, lastMove = root.Position, os.clock()
			elseif os.clock() - lastMove > 1.2 then
				nudges += 1
				if nudges > 4 then
					return false
				end
				local side = flat.Unit:Cross(Vector3.yAxis) * (if math.random() < 0.5 then 3 else -3)
				humanoid:MoveTo(root.Position + side - flat.Unit * 1.5)
				task.wait(0.5)
				if walkToken[model] ~= token then
					return false
				end
				humanoid:MoveTo(wp)
				lastPos, lastMove = root.Position, os.clock()
			end
			task.wait(0.15)
		end
	end
	return walkToken[model] == token
end

-- Walks in the background (a new walk or stop cancels it).
function Npc.goTo(model: Model, target: Vector3, speed: number?, onArrive: (() -> ())?)
	task.spawn(function()
		if Npc.walkTo(model, target, speed) and onArrive then
			onArrive()
		end
	end)
end

function Npc.stop(model: Model)
	walkToken[model] = (walkToken[model] or 0) + 1
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and root then
		humanoid:MoveTo(root.Position)
	end
end

function Npc.remove(model: Model)
	walkToken[model] = nil
	model:Destroy()
end

return Npc
