-- Small story objects: a table with a paper, a box, a cabinet... each a part with a ProximityPrompt that checks the
-- player is alive and close before it acts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local FloorData = require(ReplicatedStorage.Shared.FloorData)
local Characters = require(script.Parent.Parent.Characters)

local S = Config.studs

local Pickups = {}

-- A spot in a room (metres -> studs), offset from its centre by (dx, dz) metres, at the floor.
function Pickups.spot(floor: number, room: string, dx: number?, dz: number?): Vector3?
	local r = FloorData.roomRect(floor, room)
	if not r then
		return nil
	end
	local x = (r.x0 + r.x1) / 2 + (dx or 0)
	local z = (r.z0 + r.z1) / 2 + (dz or 0)
	return Vector3.new(S(x), S(floor * Config.FLOOR_HEIGHT), S(z))
end

function Pickups.part(parent: Instance, name: string, at: Vector3, size: Vector3, color: Color3,
	material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanTouch = false
	p.Size = Vector3.new(S(size.X), S(size.Y), S(size.Z))
	p.CFrame = CFrame.new(at + Vector3.new(0, S(size.Y) / 2, 0))
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A prompt that only fires for alive players within reach; `onUse(player)` decides what happens.
function Pickups.prompt(part: BasePart, action: string, object: string, hold: number?,
	onUse: (Player) -> ()): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold or 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 9
	prompt:SetAttribute("For", "living")
	prompt.Triggered:Connect(function(player)
		local root = Characters.root(player)
		if player:GetAttribute("State") == "alive" and root and (root.Position - part.Position).Magnitude < 16 then
			onUse(player)
		end
	end)
	prompt.Parent = part
	return prompt
end

-- A small table with a paper on it (clues and notes).
function Pickups.paper(parent: Instance, name: string, at: Vector3, label: string, onRead: (Player, Model) -> ()): Model
	local model = Instance.new("Model")
	model.Name = name
	Pickups.part(model, "Table", at, Vector3.new(0.9, 0.75, 0.6), Color3.fromRGB(120, 92, 64), Enum.Material.WoodPlanks)
	local paper = Pickups.part(model, "Paper", at + Vector3.new(0, S(0.75), 0), Vector3.new(0.3, 0.01, 0.21),
		Color3.fromRGB(236, 230, 210))
	paper.CanCollide = false
	Pickups.prompt(paper, "Read", label, 0.4, function(player)
		onRead(player, model)
	end)
	model.Parent = parent
	return model
end

return Pickups
