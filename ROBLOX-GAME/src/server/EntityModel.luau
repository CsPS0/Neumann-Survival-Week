-- The entity's look (HORROR-GAME/scripts/entity_model.gd, made gorier): tall and gaunt, grey skin with open wounds,
-- a torn-open chest with ribs, a hanging jaw full of teeth, black eye sockets that bleed, long fingers with red tips.
-- In the story it wears the shreds of the possessed teacher's clothes and one thing of theirs (CampaignData.LOOKS,
-- ENTITY_MARKS); elsewhere, torn black cloth. Gore stays within Roblox's "Moderate" label: wounds and light blood,
-- no pools or gushing. Built from parts around a HumanoidRootPart, scaled to 90% to fit under the 2.2 m doorways.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local SCALE = 0.9
local SKIN = Color3.fromRGB(122, 118, 110)
local CLOTH = Color3.fromRGB(8, 8, 9)
local FLESH = Color3.fromRGB(72, 10, 12)
local BLOOD = Color3.fromRGB(70, 6, 8)
local BONE = Color3.fromRGB(214, 206, 186)
local EYE = Color3.new(1, 0.05, 0.02)
local ROOT_HEIGHT = 1.0 -- metres: centre of the root above the floor
local SPOT_EVERY = 2 -- seconds between blood spots while it moves (story only)
local SPOT_LIFE = 20
local MAX_SPOTS = 25

export type Look = { jacket: Color3, trousers: Color3, mark: string? }

local EntityModel = {}

local function m(v: number): number
	return Config.studs(v * SCALE)
end

-- One visual part welded to the root. `at` is in metres above the floor (Godot model coordinates), facing -Z.
local function piece(model: Instance, root: BasePart, name: string, size: Vector3, at: CFrame, color: Color3,
	material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = Vector3.new(m(size.X), m(size.Y), m(size.Z))
	p.Color = color
	-- Skin and flesh are rough and matte; only the eyes, metal and cloth keep their own material.
	p.Material = material or (if color == SKIN or color == FLESH or color == BLOOD then Enum.Material.Concrete
		else Enum.Material.SmoothPlastic)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	local pos = at.Position
	p.CFrame = root.CFrame * CFrame.new(m(pos.X), m(pos.Y) - Config.studs(ROOT_HEIGHT), m(pos.Z)) * at.Rotation
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = p
	weld.Parent = p
	p.Parent = model
	return p
end

local function at(x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
end

-- The teacher's thing (CampaignData.ENTITY_MARKS).
local function mark(model: Instance, root: BasePart, id: string)
	local brass = Color3.fromRGB(190, 150, 70)
	if id == "lanyard_key" or id == "usb_lanyard" then
		piece(model, root, "Lanyard", Vector3.new(0.02, 0.36, 0.01), at(0, 1.7, -0.13), Color3.fromRGB(30, 60, 140))
		if id == "lanyard_key" then
			piece(model, root, "Key", Vector3.new(0.03, 0.08, 0.01), at(0, 1.49, -0.135), brass, Enum.Material.Metal)
		else
			piece(model, root, "Usb", Vector3.new(0.035, 0.07, 0.015), at(0, 1.49, -0.135), Color3.fromRGB(20, 20, 24))
		end
	elseif id == "bell_bracelet" then
		piece(model, root, "Bracelet", Vector3.new(0.09, 0.025, 0.09), at(-0.22, 0.42, 0), Color3.fromRGB(200, 200, 210),
			Enum.Material.Metal)
		piece(model, root, "Bell", Vector3.new(0.04, 0.04, 0.04), at(-0.22, 0.38, -0.05), Color3.fromRGB(215, 215, 225),
			Enum.Material.Metal, Enum.PartType.Ball)
	elseif id == "fuse_wire" then
		piece(model, root, "Spool", Vector3.new(0.05, 0.1, 0.1), at(0.16, 0.95, -0.08, 0, 0, 0), Color3.fromRGB(180, 120, 60),
			Enum.Material.Metal, Enum.PartType.Cylinder)
	elseif id == "black_feather" then
		piece(model, root, "Feather", Vector3.new(0.02, 0.22, 0.05), at(0.09, 2.3, 0.04, 0, 0, -25), Color3.fromRGB(12, 12, 14))
	elseif id == "red_ribbon" then
		piece(model, root, "Ribbon", Vector3.new(0.12, 0.04, 0.12), at(0, 1.9, 0), Color3.fromRGB(190, 20, 30), Enum.Material.Fabric)
		piece(model, root, "RibbonEnd", Vector3.new(0.03, 0.16, 0.01), at(0.03, 1.8, -0.07, 0, 0, 12),
			Color3.fromRGB(190, 20, 30), Enum.Material.Fabric)
	elseif id == "cable_arm" then
		for i = 0, 3 do
			piece(model, root, "Cable", Vector3.new(0.1, 0.022, 0.1), at(0.22, 1.05 + i * 0.09, 0, 0, i * 30, 8),
				Color3.fromRGB(40, 110, 200), Enum.Material.Plastic)
		end
	elseif id == "crest_ring" then
		piece(model, root, "Ring", Vector3.new(0.035, 0.02, 0.035), at(-0.22, 0.27, -0.02), brass, Enum.Material.Metal)
		piece(model, root, "Keyring", Vector3.new(0.07, 0.07, 0.01), at(-0.12, 0.92, -0.1), brass, Enum.Material.Metal,
			Enum.PartType.Cylinder)
	end
end

-- Adds the visual parts to `model`, welded to `root` (whose centre stands ROOT_HEIGHT above the floor).
local function dress(model: Instance, root: BasePart, look: Look?): BasePart
	local jacket = if look then look.jacket else CLOTH
	local trousers = if look then look.trousers else CLOTH
	-- Legs in torn trousers, bare grey shins showing through the rips.
	for side = -1, 1, 2 do
		piece(model, root, "Leg", Vector3.new(0.1, 0.62, 0.1), at(0.1 * side, 0.64, 0), trousers, Enum.Material.Fabric)
		piece(model, root, "Shin", Vector3.new(0.075, 0.36, 0.075), at(0.1 * side, 0.18, 0), SKIN)
		piece(model, root, "Rag", Vector3.new(0.05, 0.22, 0.012), at(0.1 * side + 0.03, 0.26, -0.05, 0, 0, 8 * side),
			trousers, Enum.Material.Fabric)
	end
	-- Torso: the jacket hangs open in shreds over a torn chest; ribs over raw flesh.
	piece(model, root, "Torso", Vector3.new(0.3, 1.0, 0.2), at(0, 1.4, 0.02), FLESH)
	for side = -1, 1, 2 do
		piece(model, root, "Jacket", Vector3.new(0.1, 0.95, 0.24), at(0.12 * side, 1.42, 0, 0, 0, -3 * side), jacket,
			Enum.Material.Fabric)
		piece(model, root, "Shoulder", Vector3.new(0.1, 0.08, 0.18), at(0.2 * side, 1.86, 0), jacket, Enum.Material.Fabric)
	end
	piece(model, root, "Back", Vector3.new(0.34, 0.95, 0.04), at(0, 1.42, 0.11), jacket, Enum.Material.Fabric)
	for i = 0, 3 do
		piece(model, root, "Rib", Vector3.new(0.16, 0.022, 0.03), at(0, 1.72 - i * 0.1, -0.1, 0, 0, if i % 2 == 0 then 4 else -4),
			BONE)
	end
	for i, len in { 0.3, 0.42, 0.24, 0.36 } do
		piece(model, root, "Strip", Vector3.new(0.05, len, 0.012), at(-0.15 + (i - 1) * 0.1, 0.92 - len / 2 + 0.05, -0.11,
			0, 0, (i - 2.5) * 5), jacket, Enum.Material.Fabric)
	end
	-- Long arms with wounds; long fingers with red tips.
	for side = -1, 1, 2 do
		piece(model, root, "UpperArm", Vector3.new(0.07, 0.7, 0.07), at(0.22 * side, 1.45, 0), SKIN)
		piece(model, root, "Wound", Vector3.new(0.072, 0.14, 0.04), at(0.22 * side, 1.5, -0.02), FLESH)
		piece(model, root, "Forearm", Vector3.new(0.06, 0.7, 0.06), at(0.22 * side, 0.75, 0), SKIN)
		piece(model, root, "Wound", Vector3.new(0.062, 0.1, 0.035), at(0.22 * side, 0.85, 0.02), FLESH)
		piece(model, root, "Hand", Vector3.new(0.08, 0.12, 0.03), at(0.22 * side, 0.36, 0), SKIN)
		for f = -1, 1 do
			piece(model, root, "Finger", Vector3.new(0.018, 0.17, 0.018), at(0.22 * side + f * 0.025, 0.215, 0), SKIN)
			piece(model, root, "Tip", Vector3.new(0.02, 0.04, 0.02), at(0.22 * side + f * 0.025, 0.12, 0), BLOOD)
		end
	end
	-- Neck with a gash, the head, black sockets with red eyes, blood running from them, an open jaw with teeth.
	piece(model, root, "Neck", Vector3.new(0.08, 0.3, 0.08), at(0, 1.95, 0), SKIN)
	piece(model, root, "Gash", Vector3.new(0.085, 0.03, 0.05), at(0, 1.93, -0.02, 0, 0, 10), FLESH)
	local head = piece(model, root, "Head", Vector3.new(0.2, 0.3, 0.24), at(0, 2.14, 0), SKIN)
	for side = -1, 1, 2 do
		piece(model, root, "Socket", Vector3.new(0.065, 0.06, 0.02), at(0.05 * side, 2.18, -0.115), Color3.new(0, 0, 0))
		piece(model, root, "Eye", Vector3.new(0.03, 0.03, 0.03), at(0.05 * side, 2.18, -0.12), EYE, Enum.Material.Neon,
			Enum.PartType.Ball)
		piece(model, root, "Tear", Vector3.new(0.012, 0.14, 0.01), at(0.05 * side, 2.08, -0.121), BLOOD)
	end
	piece(model, root, "Mouth", Vector3.new(0.12, 0.05, 0.02), at(0, 2.03, -0.118), FLESH)
	for t = -2, 2 do
		piece(model, root, "Tooth", Vector3.new(0.014, 0.025, 0.01), at(t * 0.022, 2.045, -0.125), BONE)
	end
	piece(model, root, "Jaw", Vector3.new(0.15, 0.05, 0.16), at(0, 1.96, -0.04, -25, 0, 0), SKIN)
	for t = -1, 1 do
		piece(model, root, "Tooth", Vector3.new(0.014, 0.025, 0.01), at(t * 0.025, 1.99, -0.11, -25, 0, 0), BONE)
	end
	piece(model, root, "Drool", Vector3.new(0.012, 0.1, 0.01), at(0.02, 1.9, -0.11), BLOOD)
	if look and look.mark then
		mark(model, root, look.mark)
	end
	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Color = Color3.new(1, 0.1, 0.05)
	glow.Range = Config.studs(3)
	glow.Brightness = 1
	glow.Parent = head
	return head
end

-- A free-standing entity with its own Humanoid (the computer entity, and the story's afternoon glimpses).
function EntityModel.build(look: Look?): Model
	local model = Instance.new("Model")
	model.Name = "Entity"
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = true
	root.CFrame = CFrame.new(0, Config.studs(ROOT_HEIGHT), 0)
	root.Parent = model
	model.PrimaryPart = root
	dress(model, root, look)
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = Config.studs(ROOT_HEIGHT) - root.Size.Y / 2
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.Parent = model
	return model
end

-- Puts the entity's look on a player's character (Hide and Seek with a player entity) and hides the avatar.
function EntityModel.attachTo(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	for _, d in character:GetDescendants() do
		if (d:IsA("BasePart") and d ~= root) or d:IsA("Decal") then
			(d :: any).Transparency = 1
		end
	end
	local look = Instance.new("Model")
	look.Name = "EntityLook"
	look.Parent = character
	-- A player's root sits about 3 studs (1 m) above the floor, the same as the entity's.
	dress(look, root, nil)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

function EntityModel.setAggressive(model: Instance, on: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("PointLight") and d.Name == "Glow" then
			d.Brightness = if on then 3 else 1
			d.Range = Config.studs(if on then 5 else 3)
		end
	end
end

-- Story only: blood drips from the chest and hands, and small spots on the floor where it walks. Stops when the
-- model is destroyed. `folder` holds the spots (the story folder, so they go with the run).
function EntityModel.setTrail(model: Model, folder: Instance)
	for _, name in { "Torso", "Hand" } do
		for _, p in model:GetChildren() do
			if p.Name == name and p:IsA("BasePart") then
				local drip = Instance.new("ParticleEmitter")
				drip.Name = "Drip"
				drip.Texture = "rbxasset://textures/particles/smoke_main.dds"
				drip.Color = ColorSequence.new(BLOOD)
				drip.LightEmission = 0
				drip.Size = NumberSequence.new(0.12, 0.05)
				drip.Transparency = NumberSequence.new(0.1, 0.6)
				drip.Lifetime = NumberRange.new(0.6, 0.9)
				drip.Rate = if name == "Torso" then 3 else 1.5
				drip.Speed = NumberRange.new(0)
				drip.Acceleration = Vector3.new(0, -Config.studs(9.8), 0)
				drip.EmissionDirection = Enum.NormalId.Bottom
				drip.Parent = p
			end
		end
	end
	local root = model.PrimaryPart :: BasePart
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model, folder }
	local spots: { Part } = {}
	task.spawn(function()
		while model.Parent and folder.Parent do
			task.wait(SPOT_EVERY)
			local v = root.AssemblyLinearVelocity
			if Vector3.new(v.X, 0, v.Z).Magnitude > 1 then
				local hit = workspace:Raycast(root.Position, Vector3.new(0, -Config.studs(2), 0), params)
				if hit then
					local spot = Instance.new("Part")
					spot.Name = "BloodSpot"
					spot.Shape = Enum.PartType.Cylinder
					local d = Config.studs(0.2 + math.random() * 0.15)
					spot.Size = Vector3.new(0.04, d, d)
					spot.CFrame = CFrame.new(hit.Position + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(90))
					spot.Color = BLOOD
					spot.Material = Enum.Material.SmoothPlastic
					spot.Anchored = true
					spot.CanCollide = false
					spot.CanQuery = false
					spot.CanTouch = false
					spot.CastShadow = false
					spot.Parent = folder
					table.insert(spots, spot)
					if #spots > MAX_SPOTS then
						table.remove(spots, 1):Destroy()
					end
					task.delay(SPOT_LIFE, function()
						local i = table.find(spots, spot)
						if i then
							table.remove(spots, i)
						end
						spot:Destroy()
					end)
				end
			end
		end
	end)
end

return EntityModel
