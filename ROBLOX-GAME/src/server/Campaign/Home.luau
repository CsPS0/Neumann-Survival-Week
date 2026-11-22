-- Your room at home (docs/2026-11-22-campaign-story-design.md): where you end up when you go home in the afternoon,
-- or when the guard walks you out. A small bedroom far from the school with a bed, a desk, a lamp and a window on
-- the night. The door takes you back to the school (in through a broken window at the far end); the bed ends your
-- run ("went home"). Players at home are still "alive" but carry the AtHome attribute: the entity, the guard and the
-- votes leave them out (CampaignMode.alive).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Pickups = require(script.Parent.Pickups)

local S = Config.studs
local ORIGIN = Vector3.new(0, 400, 3000) -- far above and away from the school

local Home = {}

local function block(parent: Instance, name: string, cf: CFrame, size: Vector3, color: Color3,
	material: Enum.Material?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

export type Opts = {
	folder: Instance,
	onGoBack: (Player) -> (),
	onSleep: (Player) -> (),
}

export type HomeRoom = { spawn: CFrame, model: Model }

-- Builds the room once per run.
function Home.build(opts: Opts): HomeRoom
	local model = Instance.new("Model")
	model.Name = "Home"
	local w, d, h = S(4.2), S(4.2), S(2.7) -- metres -> studs
	local o = CFrame.new(ORIGIN)
	local wall = Color3.fromRGB(118, 134, 160)
	block(model, "Floor", o * CFrame.new(0, -0.5, 0), Vector3.new(w, 1, d), Color3.fromRGB(120, 86, 60),
		Enum.Material.WoodPlanks)
	block(model, "Ceiling", o * CFrame.new(0, h + 0.5, 0), Vector3.new(w, 1, d), Color3.fromRGB(220, 220, 214))
	block(model, "WallBack", o * CFrame.new(0, h / 2, -d / 2 - 0.5), Vector3.new(w + 2, h, 1), wall)
	block(model, "WallLeft", o * CFrame.new(-w / 2 - 0.5, h / 2, 0), Vector3.new(1, h, d), wall)
	block(model, "WallRight", o * CFrame.new(w / 2 + 0.5, h / 2, 0), Vector3.new(1, h, d), wall)
	-- The front wall with the door (right) and the window (left).
	local door = S(0.9)
	block(model, "WallFront", o * CFrame.new(-door / 2 - 0.5, h / 2, d / 2 + 0.5), Vector3.new(w - door + 1, h, 1), wall)
	block(model, "WallOverDoor", o * CFrame.new(w / 2 - door / 2, h - 0.6, d / 2 + 0.5), Vector3.new(door, 1.2, 1), wall)
	local doorPart = block(model, "Door", o * CFrame.new(w / 2 - door / 2, (h - 1.2) / 2, d / 2 + 0.3),
		Vector3.new(door, h - 1.2, 0.3), Color3.fromRGB(96, 70, 48), Enum.Material.Wood)
	local knob = block(model, "Knob", doorPart.CFrame * CFrame.new(-door / 2 + 0.4, 0, -0.25), Vector3.new(0.25, 0.25, 0.25),
		Color3.fromRGB(200, 180, 120), Enum.Material.Metal)
	knob.Shape = Enum.PartType.Ball
	-- The window on the back wall: the night sky and the moon behind glass.
	-- Glass a little in front of the wall, the sky panel on the wall face, the moon between them.
	local win = o * CFrame.new(-S(0.8), h * 0.58, -d / 2 + 0.16)
	block(model, "Sky", win * CFrame.new(0, 0, -0.12), Vector3.new(S(1.3), S(1.0), 0.04), Color3.fromRGB(28, 40, 86),
		Enum.Material.Neon)
	local moon = block(model, "Moon", win * CFrame.new(S(0.35), S(0.2), -0.08), Vector3.new(0.04, 0.9, 0.9),
		Color3.fromRGB(230, 230, 210), Enum.Material.Neon)
	moon.Shape = Enum.PartType.Cylinder
	moon.CFrame = moon.CFrame * CFrame.Angles(0, math.pi / 2, 0)
	block(model, "Glass", win, Vector3.new(S(1.3), S(1.0), 0.1), Color3.fromRGB(170, 190, 210), Enum.Material.Glass)
		.Transparency = 0.7
	for _, f in { { 0, S(0.5) + 0.1, S(1.4), 0.2 }, { 0, -S(0.5) - 0.1, S(1.4), 0.2 }, { S(0.65) + 0.1, 0, 0.2, S(1.2) },
		{ -S(0.65) - 0.1, 0, 0.2, S(1.2) }, { 0, 0, 0.12, S(1.0) } } do
		block(model, "Frame", win * CFrame.new(f[1], f[2], 0.05), Vector3.new(f[3], f[4], 0.25), Color3.fromRGB(240, 240, 236))
	end
	-- The bed in the left back corner.
	local bed = o * CFrame.new(-w / 2 + S(0.55), 0, -d / 2 + S(1.05))
	block(model, "BedFrame", bed * CFrame.new(0, 0.9, 0), Vector3.new(S(1.0), 1.4, S(2.0)), Color3.fromRGB(90, 64, 46),
		Enum.Material.Wood)
	block(model, "Mattress", bed * CFrame.new(0, 1.9, 0), Vector3.new(S(0.95), 0.7, S(1.95)), Color3.fromRGB(235, 235, 240),
		Enum.Material.Fabric)
	local blanket = block(model, "Blanket", bed * CFrame.new(0, 2.3, S(0.25)), Vector3.new(S(1.0), 0.25, S(1.4)),
		Color3.fromRGB(60, 90, 150), Enum.Material.Fabric)
	block(model, "Pillow", bed * CFrame.new(0, 2.4, -S(0.75)), Vector3.new(S(0.7), 0.4, S(0.35)),
		Color3.fromRGB(245, 245, 250), Enum.Material.Fabric)
	-- The desk with a lamp, a laptop and a school bag.
	local desk = o * CFrame.new(w / 2 - S(0.45), 0, -d / 2 + S(0.6))
	block(model, "Desk", desk * CFrame.new(0, S(0.74), 0), Vector3.new(S(0.8), 0.25, S(1.2)), Color3.fromRGB(200, 190, 170),
		Enum.Material.Wood)
	for _, leg in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		block(model, "Leg", desk * CFrame.new(leg[1] * S(0.36), S(0.37), leg[2] * S(0.56)), Vector3.new(0.3, S(0.74), 0.3),
			Color3.fromRGB(80, 80, 84), Enum.Material.Metal)
	end
	local lampBase = block(model, "Lamp", desk * CFrame.new(0, S(0.74) + 1.1, -S(0.4)), Vector3.new(0.5, 2, 0.5),
		Color3.fromRGB(40, 40, 44), Enum.Material.Metal)
	local shade = block(model, "Shade", lampBase.CFrame * CFrame.new(0, 1.2, 0), Vector3.new(1.2, 0.8, 1.2),
		Color3.fromRGB(250, 220, 150), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 214, 160)
	light.Brightness = 1.6
	light.Range = S(5)
	light.Shadows = true
	light.Parent = shade
	block(model, "Laptop", desk * CFrame.new(0, S(0.74) + 0.2, S(0.15)), Vector3.new(1.6, 0.12, 1.1),
		Color3.fromRGB(50, 52, 58), Enum.Material.Metal)
	block(model, "Screen", desk * CFrame.new(0, S(0.74) + 0.75, S(0.15) - 0.55) * CFrame.Angles(math.rad(-10), 0, 0),
		Vector3.new(1.6, 1.0, 0.08), Color3.fromRGB(60, 120, 200), Enum.Material.Neon)
	block(model, "Bag", o * CFrame.new(w / 2 - S(0.5), 0.9, S(0.3)), Vector3.new(1.4, 1.8, 0.8), Color3.fromRGB(150, 40, 40),
		Enum.Material.Fabric)
	block(model, "Rug", o * CFrame.new(0, 0.03, S(0.4)), Vector3.new(S(1.6), 0.06, S(1.1)), Color3.fromRGB(140, 110, 80),
		Enum.Material.Fabric)
	block(model, "Poster", o * CFrame.new(-w / 2 + 0.05, h * 0.6, S(0.6)), Vector3.new(0.08, S(0.8), S(0.6)),
		Color3.fromRGB(230, 120, 60))
	model.Parent = opts.folder

	Pickups.prompt(doorPart, "Go back to the school", "Door", 1, opts.onGoBack)
	Pickups.prompt(blanket, "Go to sleep (stay home: you are out)", "Bed", 1.5, opts.onSleep)

	-- Stand in the middle of the room, facing the window.
	local spawn = o * CFrame.new(0, 3, S(0.8)) * CFrame.Angles(0, 0, 0)
	return { spawn = spawn, model = model }
end

return Home
