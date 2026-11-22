-- First-person hands (phone_viewmodel.gd): the phone in the right hand, its flashlight on the back, and the hand-slot
-- item in the left hand. Local parts under the camera, so only you see them. Every frame they follow the camera
-- with sway (they lag behind a turn), bob while walking, drop a little when sprinting or crouching and pull back from
-- walls. F taps the phone (the lens lights or goes dark), T lifts it for the camera flash. The phone comes up to
-- your face for the one-hand screen (Phone.luau) and the hands go away in two-hand mode.
-- The light other players see is still the server's (Torch.luau, on the head).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Spring = require(ReplicatedStorage.Shared.Spring)
local ItemLooks = require(script.Parent.ItemLooks)
local MovementController = require(script.Parent.MovementController)

local player = Players.LocalPlayer
local Viewmodel = {}

local SKIN = Color3.fromRGB(234, 184, 146) -- matches Characters.luau
local SLEEVE = Color3.fromRGB(38, 52, 86)
local PHONE = Color3.fromRGB(24, 24, 28)

-- Poses relative to the camera (studs). The phone's screen faces you; the lens on its back points ahead.
-- The phone is in the right hand (lowered: low right, lens ahead; raised: in the middle of your view); the held item
-- is in the left hand.
local PHONE_DOWN = CFrame.new(0.44, -0.64, -1.35) * CFrame.Angles(math.rad(18), math.rad(-10), math.rad(-4))
local PHONE_UP = CFrame.new(0.02, -0.33, -0.74) * CFrame.Angles(math.rad(-2), math.rad(-3), 0)
local ITEM = CFrame.new(-0.5, -0.68, -1.4) * CFrame.Angles(math.rad(12), math.rad(10), math.rad(4))

local model: Model
local phone: Part
local screen: Part
local lens: Part
local leftArm: Model
local rightArm: Model
local held: Part
local phoneState = "down" -- "down" | "one" | "two"
local heldId: string? = nil

local function part(parent: Instance, name: string, size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Parent = parent
	return p
end

-- A forearm and hand, as a model whose pivot is the hand.
local function arm(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	local hand = part(m, "Hand", Vector3.new(0.17, 0.2, 0.22), SKIN)
	local thumb = part(m, "Thumb", Vector3.new(0.05, 0.12, 0.05), SKIN)
	thumb.CFrame = CFrame.new(if name == "LeftArm" then 0.09 else -0.09, 0.08, -0.04) * CFrame.Angles(0, 0, math.rad(20))
	local wrist = part(m, "Wrist", Vector3.new(0.13, 0.13, 0.08), SKIN)
	wrist.CFrame = CFrame.new(0, -0.08, 0.13)
	local fore = part(m, "Forearm", Vector3.new(0.17, 0.17, 1.1), SLEEVE, Enum.Material.Fabric)
	fore.CFrame = CFrame.new(0, -0.2, 0.68) * CFrame.Angles(math.rad(-16), 0, 0)
	m.PrimaryPart = hand
	m.WorldPivot = CFrame.new()
	m.Parent = model
	return m
end

local function build()
	model = Instance.new("Model")
	model.Name = "Viewmodel"
	leftArm = arm("LeftArm")
	rightArm = arm("RightArm")
	phone = part(model, "Phone", Vector3.new(0.23, 0.46, 0.03), PHONE, Enum.Material.SmoothPlastic)
	screen = part(model, "Screen", Vector3.new(0.21, 0.42, 0.005), Color3.fromRGB(14, 18, 28), Enum.Material.Glass)
	lens = part(model, "Lens", Vector3.new(0.012, 0.045, 0.045), Color3.fromRGB(70, 70, 70), Enum.Material.SmoothPlastic)
	lens.Shape = Enum.PartType.Cylinder
	held = part(model, "Held", Vector3.new(0.1, 0.1, 0.1), Color3.new(1, 1, 1))
	held.Transparency = 1
end

function Viewmodel.phonePart(): Part
	return screen
end

function Viewmodel.setPhone(state: string)
	phoneState = state
end

function Viewmodel.setHeld(id: string?)
	heldId = id
	if id then
		local look = ItemLooks.of(id) -- room keys look like the storage key
		held.Size = look.size
		held.Color = look.color
		held.Material = if id == "vial" then Enum.Material.Glass else Enum.Material.SmoothPlastic
	end
end

local function visible(): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local state = player:GetAttribute("State")
	return humanoid ~= nil and workspace.CurrentCamera.CameraSubject == humanoid
		and workspace.CurrentCamera.CameraType == Enum.CameraType.Custom -- not while looking at a test paper
		and (state == "alive" or state == "lobby") and not player:GetAttribute("Hidden")
		and player.CameraMode == Enum.CameraMode.LockFirstPerson
end

local function setShown(m: Instance, shown: boolean)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d ~= held then
			d.LocalTransparencyModifier = if shown then 0 else 1
		end
	end
	if m:IsA("BasePart") then
		m.LocalTransparencyModifier = if shown then 0 else 1
	end
end

function Viewmodel.init(_remotes: Folder)
	build()
	local swayX = Spring.new(0, 0.7, 14)
	local swayY = Spring.new(0, 0.7, 14)
	local raise = Spring.new(0, 1, 16) -- 0 lowered, 1 at your face
	local low = Spring.new(0, 1, 10) -- sprint/crouch drop
	local kick = Spring.new(0, 0.45, 22) -- flash lift
	local tap = Spring.new(0, 0.5, 30) -- thumb tap
	local push = Spring.new(0, 1, 20) -- wall pull-back
	local phase = 0
	local flashUntil = 0
	local lastFlashAt = player:GetAttribute("FlashReadyAt") or 0
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	player:GetAttributeChangedSignal("TorchOn"):Connect(function()
		tap:impulse(-6)
	end)
	player:GetAttributeChangedSignal("FlashReadyAt"):Connect(function()
		local at = player:GetAttribute("FlashReadyAt") or 0
		if at > lastFlashAt then
			kick:impulse(9)
			flashUntil = os.clock() + 0.18
		end
		lastFlashAt = at
	end)

	RunService:BindToRenderStep("Viewmodel", Enum.RenderPriority.Camera.Value + 2, function(dt: number)
		local camera = workspace.CurrentCamera
		if model.Parent ~= camera then
			model.Parent = camera
		end
		local show = visible()
		local allowed = player:GetAttribute("TorchAllowed") ~= false
		local twoHands = phoneState == "two"
		setShown(rightArm, show and allowed and not twoHands)
		setShown(phone, show and allowed and not twoHands)
		setShown(screen, show and allowed and not twoHands)
		setShown(lens, show and allowed and not twoHands)
		-- No human hands at all for the Hide and Seek player seeker (it wears the entity's look).
		-- No left arm after the entity took it (Hide and Seek): no item hand either.
		local armless = player:GetAttribute("LostArm") == true
		setShown(leftArm, show and allowed and not twoHands and not armless)
		held.LocalTransparencyModifier = if show and allowed and heldId and not twoHands and not armless then 0 else 1
		held.Transparency = if heldId then 0 else 1
		if not show then
			return
		end

		-- Sway: the hands lag behind the mouse.
		local delta = UserInputService:GetMouseDelta()
		swayX.target = math.clamp(-delta.X * 0.004, -0.12, 0.12)
		swayY.target = math.clamp(delta.Y * 0.004, -0.1, 0.1)
		local sx, sy = swayX:update(dt), swayY:update(dt)

		-- Bob from the walking speed.
		local character = player.Character :: Model
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local speed = 0
		if root then
			local v = root.AssemblyLinearVelocity
			speed = Vector3.new(v.X, 0, v.Z).Magnitude / Config.STUDS_PER_METRE
			rayParams.FilterDescendantsInstances = { character, model }
		end
		if speed > 0.3 then
			phase += dt * speed * 2.2
		end
		local amount = math.clamp(speed / Config.Player.sprint, 0, 1.2)
		local run = if MovementController.sprinting then 1.8 else 1 -- the hands pump when you run
		local bobX = math.cos(phase) * 0.035 * amount * run
		local bobY = -math.abs(math.sin(phase)) * 0.045 * amount * run

		low.target = if MovementController.crouched then 0.08 elseif MovementController.sprinting then 0.14 else 0
		raise.target = if phoneState == "one" then 1 else 0

		-- Pull back from walls right in front.
		local cf = camera.CFrame
		local hit = workspace:Raycast(cf.Position, cf.LookVector * 2.2, rayParams)
		push.target = if hit then math.clamp(2.2 - hit.Distance, 0, 0.9) else 0

		local r, l, k, t, p = raise:update(dt), low:update(dt), kick:update(dt), tap:update(dt), push:update(dt)
		local base = cf * CFrame.new(sx + bobX, sy + bobY - l, p) * CFrame.Angles(sy * 0.6, sx * 0.6, 0)
		local sprintTilt = CFrame.Angles(0, 0, if MovementController.sprinting then math.rad(10) else 0)

		-- Left hand and phone (lowered pose blended into the raised pose).
		local phoneHand = base * PHONE_DOWN:Lerp(PHONE_UP, r) * sprintTilt
			* CFrame.Angles(math.rad(-k * 4 + t * 2), 0, 0) * CFrame.new(0, k * 0.05, 0)
		rightArm:PivotTo(phoneHand)
		local phoneCf = phoneHand * CFrame.new(0.01, 0.26, 0.06) * CFrame.Angles(0, math.pi, 0) -- in the palm, in front of the fingers
		phone.CFrame = phoneCf
		screen.CFrame = phoneCf * CFrame.new(0, 0, -0.0175)
		lens.CFrame = phoneCf * CFrame.new(0.07, 0.17, 0.018) * CFrame.Angles(0, math.rad(90), 0)
		local on = player:GetAttribute("TorchOn") == true
		local flashing = os.clock() < flashUntil
		lens.Material = if on or flashing then Enum.Material.Neon else Enum.Material.SmoothPlastic
		lens.Color = if flashing then Color3.new(1, 1, 1) elseif on then Color3.fromRGB(255, 244, 220)
			else Color3.fromRGB(70, 70, 70)

		-- Right hand with the held item.
		local itemHand = base * ITEM * sprintTilt
		leftArm:PivotTo(itemHand)
		held.CFrame = itemHand * CFrame.new(0, 0.14 + held.Size.Y / 2 - 0.06, -0.06)
	end)
end

return Viewmodel
