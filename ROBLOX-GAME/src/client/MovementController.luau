-- The local player's movement: walk, sprint (Shift) with stamina (player.gd values), crouch (C, toggle) and a slide
-- (C while sprinting fast: a short physics push that eases out to crouch speed). Speed eases towards its target
-- (12 m/s per second); a server SpeedLock (downed, stunned, the seeker) overrides it at once. Sprinting and sliding
-- are reported to the server, which the entity hears. The only script that writes the local Humanoid.WalkSpeed.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Maid = require(ReplicatedStorage.Shared.Maid)
local Movement = require(ReplicatedStorage.Shared.Movement)
local Rules = require(ReplicatedStorage.Shared.Rules)

local player = Players.LocalPlayer
local P = Config.Player
local S = Config.studs

local MovementController = {
	stamina = Rules.newStamina(P.staminaMax),
	sprinting = false, -- moving at sprint this frame
	crouched = false,
	sliding = false,
	speed = P.walk, -- metres per second the controller aims for right now
}

local held = false
local slideStart = 0
local slideFrom = 0
local slideReadyAt = 0
local slideForce: LinearVelocity? = nil
local reported = false

local function canAct(): boolean
	local state = player:GetAttribute("State")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return (state == "alive" or state == "lobby") and not player:GetAttribute("Hidden")
		and player:GetAttribute("SpeedLock") == nil and root ~= nil and not root.Anchored
end

local function stopSlide()
	MovementController.sliding = false
	if slideForce then
		slideForce:Destroy()
		slideForce = nil
	end
end

local function startSlide(root: BasePart, flat: Vector3)
	local attachment = root:FindFirstChild("RootAttachment") :: Attachment?
	if not attachment then
		return
	end
	MovementController.sliding = true
	MovementController.stamina.value -= P.slideCost
	slideStart = os.clock()
	slideFrom = flat.Magnitude / Config.STUDS_PER_METRE
	slideReadyAt = slideStart + P.slideCooldown
	local force = Instance.new("LinearVelocity")
	force.Name = "Slide"
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	force.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	force.MaxAxesForce = Vector3.new(1e5, 0, 1e5) -- Horizontal only: gravity and slopes still work.
	force.VectorVelocity = flat.Unit * S(Movement.slideSpeed(slideFrom, 0, P))
	force.Parent = root
	slideForce = force
end

local function toggleCrouch()
	if not canAct() then
		return
	end
	if MovementController.crouched then
		MovementController.crouched = false
		stopSlide()
		return
	end
	MovementController.crouched = true
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local v = root.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	local onFloor = humanoid.FloorMaterial ~= Enum.Material.Air
	if MovementController.sprinting and onFloor and os.clock() >= slideReadyAt
		and MovementController.stamina.value >= P.slideCost
		and Movement.canSlide(flat.Magnitude / Config.STUDS_PER_METRE, P) then
		startSlide(root, flat)
	end
end

local function step(dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return
	end
	local lock = player:GetAttribute("SpeedLock")
	local free = canAct()
	if not free then
		MovementController.crouched = MovementController.crouched and lock == nil
		stopSlide()
	end

	local moving = humanoid.MoveDirection.Magnitude > 0.1
	if MovementController.sliding then
		local elapsed = os.clock() - slideStart
		if elapsed >= P.slideTime or humanoid.FloorMaterial == Enum.Material.Air or not slideForce then
			stopSlide()
		elseif slideForce then
			slideForce.VectorVelocity = slideForce.VectorVelocity.Unit * S(Movement.slideSpeed(slideFrom, elapsed, P))
		end
	end

	local wantsSprint = held and not MovementController.crouched and free
	local sprinting = Rules.stepStamina(MovementController.stamina, wantsSprint, moving, dt, P)
	MovementController.sprinting = sprinting

	if lock then
		humanoid.WalkSpeed = lock
		MovementController.speed = lock / Config.STUDS_PER_METRE
	else
		local stance: Movement.Stance = if MovementController.crouched then "crouch"
			elseif sprinting then "sprint" else "walk"
		local carry = player:GetAttribute("CarrySpeed") or 1 -- a heavy bag on your back
		MovementController.speed = Movement.approach(MovementController.speed, Movement.targetSpeed(stance, P) * carry,
			P.accel, dt)
		humanoid.WalkSpeed = S(MovementController.speed)
	end

	local noisy = sprinting or MovementController.sliding
	if noisy ~= reported then
		reported = noisy
		local remote = ReplicatedStorage.Remotes:FindFirstChild("Sprint") :: RemoteEvent?
		if remote then
			remote:FireServer(noisy)
		end
	end
end

function MovementController.init()
	local ClientSettings = require(script.Parent.ClientSettings)
	ClientSettings.bind("Sprint", "sprint", function(_, state)
		held = state == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Pass
	end, true, { Enum.KeyCode.ButtonL3 })
	ContextActionService:SetTitle("Sprint", "Run")
	ContextActionService:SetPosition("Sprint", UDim2.new(1, -170, 1, -150))

	ClientSettings.bind("Crouch", "crouch", function(_, state)
		if state == Enum.UserInputState.Begin then
			toggleCrouch()
		end
		return Enum.ContextActionResult.Sink
	end, true, { Enum.KeyCode.ButtonR3 })
	ContextActionService:SetTitle("Crouch", "Crouch")
	ContextActionService:SetPosition("Crouch", UDim2.new(1, -290, 1, -90))

	-- Per character: fresh stamina, standing, and jumping ends a crouch or slide.
	local maid = Maid.new()
	local function onCharacter(character: Model)
		maid:clean()
		MovementController.stamina = Rules.newStamina(P.staminaMax)
		MovementController.crouched = false
		MovementController.speed = P.walk
		stopSlide()
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if humanoid then
			maid:give(humanoid.StateChanged:Connect(function(_, new)
				if new == Enum.HumanoidStateType.Jumping then
					MovementController.crouched = false
					stopSlide()
				end
			end))
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	RunService:BindToRenderStep("Movement", Enum.RenderPriority.Input.Value + 1, step)
end

return MovementController
