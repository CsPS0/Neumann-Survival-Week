-- The entity's look (HORROR-GAME/scripts/entity_model.gd, remade): a teacher mutated into something else, hunched
-- and lopsided, a huge clawed right arm, a glowing growth on the shoulder, a split jaw (see dress below).
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
	local offset = CFrame.new(m(pos.X), m(pos.Y) - Config.studs(ROOT_HEIGHT), m(pos.Z)) * at.Rotation
	p.CFrame = root.CFrame * offset
	-- A Weld (not a WeldConstraint): its C0 is the resting offset, which EntityAnimator moves on each client.
	local weld = Instance.new("Weld")
	weld.Name = "Joint"
	weld.Part0 = root
	weld.Part1 = p
	weld.C0 = offset
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
-- A mutated teacher: hunched, swollen and lopsided. The right arm has grown into a huge limb ending in three bone
-- claws; a fleshy mass bursts from the right shoulder, dotted with glowing pustules and a cluster of small eyes; bone
-- spikes run down the spine; tendrils trail from the back; the jaw hangs split open. The left side keeps something
-- human: a thin arm and the shreds of the teacher's clothes. Parts named in ANIM are moved by the client
-- (EntityAnimator.luau): breathing, a twitching head, the jaw, the big arm, the tendrils and the pulsing pustules.
local function dress(model: Instance, root: BasePart, look: Look?): BasePart
	local jacket = if look then look.jacket else CLOTH
	local trousers = if look then look.trousers else CLOTH
	local SKIN2 = Color3.fromRGB(134, 130, 112) -- grey-green, waxy
	local VEIN = Color3.fromRGB(70, 34, 66)
	local MASS = Color3.fromRGB(110, 44, 52) -- swollen tissue, wet
	local PUS = Color3.fromRGB(255, 132, 46)
	local function wet(p: Part): Part
		p.Material = Enum.Material.Glass -- a wet sheen
		p.Reflectance = 0.08
		return p
	end
	local function anim(p: Part, kind: string): Part
		p:SetAttribute("Anim", kind)
		return p
	end

	-- Legs: thick thighs, thin bent shins, long clawed feet.
	for side = -1, 1, 2 do
		piece(model, root, "Thigh", Vector3.new(0.15, 0.5, 0.16), at(0.12 * side, 0.74, 0.03, -12, 0, 4 * side), trousers,
			Enum.Material.Fabric)
		piece(model, root, "Rag", Vector3.new(0.06, 0.24, 0.012), at(0.12 * side + 0.03, 0.5, -0.07, 0, 0, 10 * side),
			trousers, Enum.Material.Fabric)
		piece(model, root, "Shin", Vector3.new(0.08, 0.46, 0.08), at(0.13 * side, 0.27, 0.06, 14, 0, 0), SKIN2)
		piece(model, root, "Foot", Vector3.new(0.1, 0.05, 0.22), at(0.13 * side, 0.03, -0.04), SKIN2)
		for t = -1, 1 do
			piece(model, root, "Claw", Vector3.new(0.018, 0.018, 0.08), at(0.13 * side + t * 0.03, 0.02, -0.18, -10, 0, 0),
				BONE)
		end
	end

	-- Torso: hunched forward, swollen, veins under waxy skin, the ribs pushed out through a split.
	local torso = anim(piece(model, root, "Torso", Vector3.new(0.4, 0.72, 0.3), at(0, 1.35, -0.02, 18, 0, -4), SKIN2),
		"breathe")
	wet(piece(model, root, "Split", Vector3.new(0.16, 0.42, 0.04), at(0.02, 1.33, -0.17, 18, 0, -4), MASS))
	for i = 0, 3 do
		piece(model, root, "Rib", Vector3.new(0.2, 0.02, 0.04), at(0.02, 1.5 - i * 0.09, -0.19 + i * 0.02, 18, 0,
			if i % 2 == 0 then 6 else -6), BONE)
	end
	for i = 0, 4 do
		piece(model, root, "Vein", Vector3.new(0.012, 0.3, 0.012), at(-0.16 + i * 0.07, 1.25 + (i % 2) * 0.1, -0.15, 18, 0,
			(i - 2) * 9), VEIN)
	end
	piece(model, root, "Belly", Vector3.new(0.34, 0.24, 0.28), at(0, 0.98, 0.0), trousers, Enum.Material.Fabric)

	-- What is left of the clothes: the left half of the jacket and a torn collar.
	piece(model, root, "Jacket", Vector3.new(0.18, 0.6, 0.32), at(-0.12, 1.36, 0.0, 18, 0, -6), jacket, Enum.Material.Fabric)
	for i, len in { 0.28, 0.4, 0.22 } do
		piece(model, root, "Strip", Vector3.new(0.05, len, 0.012), at(-0.18 + (i - 1) * 0.06, 0.98 - len / 2 + 0.05, -0.14,
			10, 0, (i - 2) * 6), jacket, Enum.Material.Fabric)
	end
	piece(model, root, "Collar", Vector3.new(0.3, 0.06, 0.24), at(-0.03, 1.72, 0.04, 18, 0, -8), jacket, Enum.Material.Fabric)

	-- The mass bursting from the right shoulder: swollen tissue, pustules that glow, a cluster of small eyes.
	local mass = wet(anim(piece(model, root, "Mass", Vector3.new(0.42, 0.38, 0.36), at(0.24, 1.74, 0.06, 0, 0, 20), MASS,
		nil, Enum.PartType.Ball), "pulse"))
	wet(piece(model, root, "Mass", Vector3.new(0.26, 0.24, 0.24), at(0.38, 1.6, 0.14), MASS, nil, Enum.PartType.Ball))
	for i, p in { { 0.32, 1.86, -0.08 }, { 0.42, 1.7, -0.06 }, { 0.2, 1.62, -0.1 }, { 0.46, 1.56, 0.06 } } do
		anim(piece(model, root, "Pustule", Vector3.new(0.06, 0.06, 0.06), at(p[1], p[2], p[3]), PUS, Enum.Material.Neon,
			Enum.PartType.Ball), "glow")
		local _ = i
	end
	for i, p in { { 0.28, 1.8, -0.13 }, { 0.34, 1.75, -0.13 }, { 0.3, 1.7, -0.14 } } do
		piece(model, root, "SmallEye", Vector3.new(0.03, 0.03, 0.03), at(p[1], p[2], p[3]), EYE, Enum.Material.Neon,
			Enum.PartType.Ball)
		local _ = i
	end
	local _ = mass

	-- The mutated right arm: thick, lumpy, hanging almost to the floor, three bone claws.
	local arm = anim(piece(model, root, "BigArm", Vector3.new(0.18, 0.62, 0.18), at(0.36, 1.32, -0.02, 0, 0, 12), SKIN2),
		"arm")
	wet(piece(model, root, "ArmGrowth", Vector3.new(0.16, 0.2, 0.16), at(0.4, 1.4, 0.06, 0, 0, 12), MASS, nil,
		Enum.PartType.Ball))
	local fore = anim(piece(model, root, "BigForearm", Vector3.new(0.22, 0.6, 0.22), at(0.44, 0.78, -0.06, -8, 0, 6),
		SKIN2), "arm")
	for i = 0, 2 do
		anim(piece(model, root, "Vein", Vector3.new(0.014, 0.4, 0.014), at(0.38 + i * 0.05, 0.8, -0.18, -8, 0, 6), VEIN),
			"arm")
	end
	anim(piece(model, root, "Hand", Vector3.new(0.2, 0.12, 0.16), at(0.47, 0.44, -0.1), SKIN2), "arm")
	for c = -1, 1 do
		anim(piece(model, root, "BigClaw", Vector3.new(0.03, 0.34, 0.04), at(0.47 + c * 0.06, 0.24, -0.16, -15, 0, c * 6),
			BONE), "arm")
	end
	local _ = arm
	local _ = fore

	-- The thin left arm (still human), with the sleeve's shreds.
	piece(model, root, "UpperArm", Vector3.new(0.07, 0.56, 0.07), at(-0.25, 1.38, 0, 0, 0, -6), SKIN2)
	piece(model, root, "Sleeve", Vector3.new(0.1, 0.3, 0.1), at(-0.25, 1.5, 0, 0, 0, -6), jacket, Enum.Material.Fabric)
	piece(model, root, "Forearm", Vector3.new(0.06, 0.5, 0.06), at(-0.28, 0.86, -0.04, -6, 0, -4), SKIN2)
	piece(model, root, "Hand", Vector3.new(0.07, 0.1, 0.03), at(-0.29, 0.55, -0.06), SKIN2)
	for f = -1, 1 do
		piece(model, root, "Finger", Vector3.new(0.016, 0.16, 0.016), at(-0.29 + f * 0.022, 0.42, -0.06), SKIN2)
		piece(model, root, "Tip", Vector3.new(0.018, 0.04, 0.018), at(-0.29 + f * 0.022, 0.33, -0.06), BONE)
	end

	-- Bone spikes along the spine; tendrils trailing from the back.
	for i = 0, 4 do
		piece(model, root, "Spike", Vector3.new(0.035, 0.14 - i * 0.015, 0.035), at(0, 1.72 - i * 0.14, 0.2 + i * 0.01, -40,
			0, 0), BONE)
	end
	for i, x in { -0.1, 0.02, 0.14 } do
		local t = wet(anim(piece(model, root, "Tendril", Vector3.new(0.03, 0.55, 0.03), at(x, 1.15, 0.26, 28 + i * 8, 0,
			(i - 2) * 15), MASS), "tendril"))
		t:SetAttribute("Phase", i)
	end

	-- Neck and head: thrust forward, the skull swollen on one side, one big human eye, the jaw split and hanging.
	piece(model, root, "Neck", Vector3.new(0.1, 0.24, 0.1), at(0, 1.88, -0.12, 35, 0, 0), SKIN2)
	local head = anim(piece(model, root, "Head", Vector3.new(0.22, 0.26, 0.24), at(0, 2.0, -0.22, 10, 0, -6), SKIN2),
		"head")
	anim(wet(piece(model, root, "Swelling", Vector3.new(0.16, 0.16, 0.16), at(0.08, 2.08, -0.18), MASS, nil,
		Enum.PartType.Ball)), "head")
	for side = -1, 1, 2 do
		anim(piece(model, root, "Socket", Vector3.new(0.07, 0.06, 0.02), at(0.055 * side, 2.04, -0.34),
			Color3.new(0, 0, 0)), "head")
	end
	anim(piece(model, root, "Eye", Vector3.new(0.045, 0.045, 0.045), at(-0.055, 2.04, -0.35), EYE, Enum.Material.Neon,
		Enum.PartType.Ball), "head")
	anim(piece(model, root, "Eye", Vector3.new(0.025, 0.025, 0.025), at(0.055, 2.05, -0.35), EYE, Enum.Material.Neon,
		Enum.PartType.Ball), "head")
	anim(piece(model, root, "UpperTeeth", Vector3.new(0.14, 0.03, 0.02), at(0, 1.93, -0.34), BONE), "head")
	local jaw = anim(piece(model, root, "Jaw", Vector3.new(0.16, 0.05, 0.18), at(0, 1.85, -0.26, -35, 0, 0), SKIN2), "jaw")
	anim(wet(piece(model, root, "Mouth", Vector3.new(0.12, 0.04, 0.12), at(0, 1.89, -0.26, -15, 0, 0), MASS)), "jaw")
	for t = -2, 2 do
		anim(piece(model, root, "Tooth", Vector3.new(0.014, 0.035, 0.01), at(t * 0.024, 1.88, -0.34, -35, 0, 0), BONE),
			"jaw")
	end
	local _ = jaw
	local _ = torso

	if look and look.mark then
		mark(model, root, look.mark)
	end
	-- Where the animated parts turn (model space, studs), for EntityAnimator.
	local function pivot(x: number, y: number, z: number): Vector3
		return Vector3.new(m(x), m(y) - Config.studs(ROOT_HEIGHT), m(z))
	end
	model:SetAttribute("ArmPivot", pivot(0.36, 1.62, 0))
	model:SetAttribute("HeadPivot", pivot(0, 1.86, -0.12))
	model:SetAttribute("JawPivot", pivot(0, 1.9, -0.2))
	game:GetService("CollectionService"):AddTag(model, "EntityBody")
	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Color = Color3.new(1, 0.25, 0.08)
	glow.Range = Config.studs(3)
	glow.Brightness = 1
	glow.Parent = head
	-- A faint dark haze around its feet.
	local haze = Instance.new("ParticleEmitter")
	haze.Name = "Haze"
	haze.Texture = "rbxasset://textures/particles/smoke_main.dds"
	haze.Color = ColorSequence.new(Color3.fromRGB(30, 14, 20))
	haze.Size = NumberSequence.new(1.5, 3)
	haze.Transparency = NumberSequence.new(0.75, 1)
	haze.Lifetime = NumberRange.new(1.5, 2.5)
	haze.Rate = 6
	haze.Speed = NumberRange.new(0.3, 0.8)
	haze.SpreadAngle = Vector2.new(180, 20)
	haze.Parent = root
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
