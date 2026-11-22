-- First-person view effects on top of Roblox's own camera (which keeps CameraSubject, CameraMode and Modal working):
--   * head bob on a figure-eight (Lissajous) curve, scaled by speed, with a footstep at the bottom of each dip
--   * roll when strafing and when sliding, a dip on hard landings (springs)
--   * field of view = the menu setting + a few degrees while sprinting (spring)
--   * crouch lowers the camera (Humanoid.CameraOffset, spring); a small forward offset unless a wall is right there
--   * the camera sits at the eyes (the front of the face), not inside the head; looking down you see your hips,
--     legs and feet, never your shoulders, so the body does not fill the view
--   * standing still, a slow breathing rise and fall
-- Only translations and roll are added after the camera has updated: Roblox's camera reads its look direction back
-- from Camera.CFrame each frame, and neither changes it, so nothing drifts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Maid = require(ReplicatedStorage.Shared.Maid)
local Movement = require(ReplicatedStorage.Shared.Movement)
local Spring = require(ReplicatedStorage.Shared.Spring)
local ClientSettings = require(script.Parent.ClientSettings)
local Footsteps = require(script.Parent.Footsteps)
local MovementController = require(script.Parent.MovementController)

local player = Players.LocalPlayer
local C = Config.Camera
local TAU = math.pi * 2

-- R15 parts that stay visible in first person (never the head, the hat, or a player entity's look).
local BODY = {
	-- No arms (the first-person hands, Viewmodel, replace them) and no chest or shoulders: from the eyes they would
	-- fill the bottom of the view.
	LowerTorso = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
	RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
}

local CameraController = {}

function CameraController.init()
	local roll = Spring.new(0, 0.85, 10)
	local dip = Spring.new(0, 0.55, 14)
	local fov = Spring.new(ClientSettings.values.fov, 1, 9)
	local lower = Spring.new(0, 1, 12)
	local ahead = Spring.new(0, 1, 14) -- the eyes' forward offset (pulls back smoothly at walls)
	local phase = 0
	local lastStep = 0
	local lowestVy = 0
	local bodyParts: { BasePart } = {}
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local maid = Maid.new()
	local function onCharacter(character: Model)
		maid:clean()
		bodyParts = {}
		phase, lastStep, lowestVy = 0, 0, 0
		rayParams.FilterDescendantsInstances = { character }
		local function consider(d: Instance)
			if d:IsA("BasePart") and BODY[d.Name] and d.Parent == character then
				table.insert(bodyParts, d)
			end
		end
		for _, d in character:GetChildren() do
			consider(d)
		end
		maid:give(character.ChildAdded:Connect(consider))
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if humanoid then
			maid:give(humanoid.StateChanged:Connect(function(_, new)
				if new == Enum.HumanoidStateType.Landed then
					local amount = Movement.landingDip(lowestVy)
					if amount > 0 then
						dip:impulse(-amount * 14)
						Footsteps.land(humanoid.FloorMaterial, amount)
					end
					lowestVy = 0
				end
			end))
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end

	RunService:BindToRenderStep("ViewEffects", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		local camera = workspace.CurrentCamera
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?

		-- Field of view applies everywhere (menu, spectating).
		fov.target = ClientSettings.values.fov + (if MovementController.sprinting then C.sprintFov else 0)
		camera.FieldOfView = fov:update(dt)

		if not character or not humanoid or not root then
			return
		end
		local active = camera.CameraSubject == humanoid and camera.CameraType == Enum.CameraType.Custom
			and player.CameraMode == Enum.CameraMode.LockFirstPerson
			and not player:GetAttribute("Hidden") and not root.Anchored

		-- Crouch and a small forward offset (none when a wall is right in front, so the camera never pokes through).
		lower.target = if active and (MovementController.crouched or MovementController.sliding) then C.crouchOffset else 0
		local head = character:FindFirstChild("Head") :: BasePart?
		local forward = C.forwardOffset
		if head and workspace:Raycast(head.Position, root.CFrame.LookVector * 1.6, rayParams) then
			forward = 0
		end
		ahead.target = if active then forward else 0
		humanoid.CameraOffset = Vector3.new(0, lower:update(dt) + (if active then C.eyeHeight else 0), ahead:update(dt))

		if not active then
			phase = 0
			return
		end

		local v = root.AssemblyLinearVelocity
		lowestVy = math.min(lowestVy, v.Y)
		local flat = Vector3.new(v.X, 0, v.Z)
		local speed = flat.Magnitude / Config.STUDS_PER_METRE
		local onFloor = humanoid.FloorMaterial ~= Enum.Material.Air

		-- Bob: the phase advances with distance walked; a footstep at the bottom of each vertical dip.
		local amount = 0
		if onFloor and speed > 0.3 and not MovementController.sliding then
			phase += dt * speed * C.bobFrequency
			amount = math.clamp(speed / Config.Player.sprint, 0.35, 1.2)
			-- bobY below is lowest at phase = pi + 2*pi*k.
			local step = math.floor((phase - math.pi) / TAU)
			if step > lastStep then
				lastStep = step
				Footsteps.step(humanoid.FloorMaterial, speed)
			end
		end
		-- Running bobs harder, with a side-to-side roll on each stride (a little while walking, more running).
		local run = (if MovementController.sprinting then 1.7 else 1) * (if ClientSettings.values.bobbing then 1 else 0)
		local bobX = math.cos(phase * 0.5) * C.bobAmplitude * 0.6 * amount * run
		local bobY = -math.abs(math.sin(phase * 0.5)) * C.bobAmplitude * amount * run
		local strideRoll = math.sin(phase * 0.5) * C.bobRoll * amount * (if MovementController.sprinting then 2 else 1)
		-- Standing still: a slow breath.
		if amount == 0 then
			bobY += math.sin(os.clock() * 1.6) * C.breathe
		end

		-- Roll: lean against the strafe direction, more while sliding.
		local strafe = root.CFrame.RightVector:Dot(flat) / Config.studs(Config.Player.sprint)
		roll.target = -strafe * C.strafeRoll + (if MovementController.sliding then -C.slideRoll else 0)

		-- Dizzy from walking with the phone up (Phone.luau): a slow sway.
		local dizzy = (player:GetAttribute("Dizzy") or 0) :: number
		local sway = if dizzy > 0.2 then math.sin(os.clock() * 1.7) * (dizzy - 0.2) * 7 else 0
		camera.CFrame = camera.CFrame
			* CFrame.new(bobX, bobY + dip:update(dt), 0)
			* CFrame.Angles(0, 0, math.rad(roll:update(dt) + strideRoll + sway))

		-- Your own body stays visible (Roblox hides it in first person every frame; this runs right after).
		for _, part in bodyParts do
			if part.Transparency < 1 then
				part.LocalTransparencyModifier = 0
			end
		end
	end)
end

return CameraController
