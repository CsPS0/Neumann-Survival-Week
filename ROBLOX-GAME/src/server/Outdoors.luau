-- What the windows look out on: grass around the school, a street with pavements on every side, trees, street
-- lamps (lit at night) and a ring of plain neighbouring blocks. Plain parts, no collisions with anything a player
-- can reach (the building's own walls keep everyone in).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local FloorData = require(ReplicatedStorage.Shared.FloorData)

local S = Config.studs

local Outdoors = {}

local function block(parent: Instance, name: string, cf: CFrame, size: Vector3, color: Color3,
	material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanTouch = false
	p.CanQuery = false
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Returns the street lamps' lights (DayNight-independent: they glow when it is dark, see `setNight`).
function Outdoors.build(parent: Instance): { PointLight }
	local folder = Instance.new("Folder")
	folder.Name = "Outdoors"
	-- The ground floor's footprint in world metres.
	local g = FloorData.FLOORS[1]
	local x0, z0 = FloorData.toWorld(0, g.rect.x0, g.rect.y0)
	local x1, z1 = FloorData.toWorld(0, g.rect.x1, g.rect.y1)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local w, d = x1 - x0, z1 - z0
	-- Grass, then a ring road 14 m out with pavements.
	block(folder, "Grass", CFrame.new(S(cx), S(-0.6) - 0.05, S(cz)), Vector3.new(S(w + 160), S(1.2), S(d + 160)),
		Color3.fromRGB(74, 104, 56), Enum.Material.Grass)
	local ring = 14
	local road = 8
	local lights: { PointLight } = {}
	for _, side in { "N", "S", "W", "E" } do
		local horizontal = side == "N" or side == "S"
		local len = (if horizontal then w else d) + 2 * (ring + road)
		local off = (if horizontal then d else w) / 2 + ring + road / 2
		local sign = if side == "N" or side == "W" then -1 else 1
		local rx = if horizontal then cx else cx + sign * off
		local rz = if horizontal then cz + sign * off else cz
		local size = if horizontal then Vector3.new(S(len), 0.2, S(road)) else Vector3.new(S(road), 0.2, S(len))
		block(folder, "Road", CFrame.new(S(rx), 0.06, S(rz)), size, Color3.fromRGB(52, 52, 56), Enum.Material.Asphalt)
		local pav = if horizontal then Vector3.new(S(len), 0.3, S(2.5)) else Vector3.new(S(2.5), 0.3, S(len))
		local inner = road / 2 + 1.25
		block(folder, "Pavement", CFrame.new(S(rx - (if horizontal then 0 else sign * inner)), 0.1,
			S(rz - (if horizontal then sign * inner else 0))), pav, Color3.fromRGB(150, 146, 140), Enum.Material.Pavement)
		-- Street lamps and trees along the inner pavement, neighbours beyond the road.
		local step = 18
		local n = math.floor(len / step)
		for i = 0, n do
			local along = -len / 2 + i * step + 4
			local lx = if horizontal then rx + along else rx - sign * (inner + 0.8)
			local lz = if horizontal then rz - sign * (inner + 0.8) else rz + along
			local post = block(folder, "LampPost", CFrame.new(S(lx), S(2.5), S(lz)), Vector3.new(0.5, S(5), 0.5),
				Color3.fromRGB(40, 42, 46), Enum.Material.Metal)
			local head = block(folder, "LampHead", post.CFrame * CFrame.new(0, S(2.55), 0), Vector3.new(1.4, 0.5, 1.4),
				Color3.fromRGB(255, 210, 150), Enum.Material.Neon)
			local light = Instance.new("PointLight")
			light.Range = S(10)
			light.Brightness = 1.4
			light.Color = Color3.fromRGB(255, 200, 140)
			light.Shadows = false
			light.Parent = head
			table.insert(lights, light)
			-- A tree between lamps, on the grass side.
			local tx = if horizontal then lx + step / 2 else lx - sign * 4
			local tz = if horizontal then lz - sign * 4 else lz + step / 2
			block(folder, "Trunk", CFrame.new(S(tx), S(1.6), S(tz)), Vector3.new(1.2, S(3.2), 1.2),
				Color3.fromRGB(86, 62, 42), Enum.Material.Wood)
			block(folder, "Leaves", CFrame.new(S(tx), S(4.4), S(tz)), Vector3.new(S(4.2), S(4.2), S(4.2)),
				Color3.fromRGB(58, 94, 46), Enum.Material.Grass, Enum.PartType.Ball)
			-- A neighbouring block across the road every other step.
			if i % 2 == 0 then
				local bh = 9 + (i * 7 % 13)
				local bx = if horizontal then rx + along else rx + sign * (road / 2 + 9)
				local bz = if horizontal then rz + sign * (road / 2 + 9) else rz + along
				local house = block(folder, "Neighbour", CFrame.new(S(bx), S(bh / 2), S(bz)),
					Vector3.new(S(12), S(bh), S(12)), Color3.fromRGB(180 - i % 3 * 20, 170, 156), Enum.Material.Concrete)
				-- Windows: a few lit stripes facing the school.
				for k = 1, math.floor(bh / 3) do
					local face = if horizontal then CFrame.new(0, S(-bh / 2 + k * 3 - 1), S(-sign * 6.02))
						else CFrame.new(S(-sign * 6.02), S(-bh / 2 + k * 3 - 1), 0)
					block(folder, "NeighbourWindow", house.CFrame * face,
						if horizontal then Vector3.new(S(9), S(1), 0.1) else Vector3.new(0.1, S(1), S(9)),
						if (i + k) % 3 == 0 then Color3.fromRGB(255, 220, 150) else Color3.fromRGB(40, 46, 56),
						if (i + k) % 3 == 0 then Enum.Material.Neon else Enum.Material.Glass)
				end
			end
		end
	end
	folder.Parent = parent
	return lights
end

-- Street lamps glow only when it is dark (`daylight` 0..1 from DayNight).
function Outdoors.setDaylight(lights: { PointLight }, daylight: number)
	local on = daylight < 0.35
	for _, l in lights do
		l.Enabled = on
		local head = l.Parent :: BasePart
		head.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
end

return Outdoors
