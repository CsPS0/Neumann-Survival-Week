-- Furniture by room kind (HORROR-GAME/scripts/furniture.gd, extended): desks and chairs in classrooms, PCs in the
-- IT rooms, stalls, basins and mirrors in the WCs, shelf rows and reading tables in the library, PCs and filing
-- cabinets in offices, a fridge, stoves and sinks in kitchens, hoops and mats in the gym, the key board at the Porta...
-- Built by SchoolBuilder for each room.
-- Everything is laid out in the room's own frame: u runs along the front wall, v from the front wall into the room.
-- Rules: a 2 m wide strip 1.3 m into the room in front of every door; a clear middle (6 m in the story rooms,
-- 2.4 m in the clue rooms where quest objects and clue papers appear, 1 m elsewhere); aisles of at least 0.9 m.
-- Chairs are Seats that players cannot sit on by touching them; people (People.luau) are seated with Seat:Sit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local S = Config.studs

export type Rect = { x0: number, z0: number, x1: number, z1: number }
export type Door = { x: number, z: number, side: string }
export type Room = {
	label: string,
	kind: string,
	rect: Rect, -- world metres, inner faces of the walls approximately
	y: number, -- floor height (metres)
	doors: { Door },
	front: string?, -- the wall with the board (classrooms), "N" | "S" | "W" | "E"
	story: boolean, -- a story room: a bigger clear middle
	clue: boolean?, -- a room clue papers can appear in: a small clear middle
}

local WOOD = Color3.fromRGB(176, 140, 98)
local DARK_WOOD = Color3.fromRGB(96, 70, 50)
local METAL = Color3.fromRGB(120, 124, 130)
local CHAIR_COLORS = { Color3.fromRGB(46, 86, 140), Color3.fromRGB(52, 120, 90), Color3.fromRGB(150, 60, 50) }
local WHITE = Color3.fromRGB(226, 224, 216)

local Furniture = {}

-- The room being furnished.
local cur: { parent: Instance, room: Room, clear: { Rect }, seats: { Seat } } = nil :: any

local function overlaps(a: Rect, b: Rect): boolean
	return a.x0 < b.x1 and a.x1 > b.x0 and a.z0 < b.z1 and a.z1 > b.z0
end

-- Frame of the room: the front wall's side decides how (u, v) map to world (x, z).
local function frame(front: string): (number, number, number, number, number, number)
	local r = cur.room.rect
	-- origin (x, z), u axis (ux, uz), v axis (vx, vz)
	if front == "N" then
		return r.x0, r.z0, 1, 0, 0, 1
	elseif front == "S" then
		return r.x1, r.z1, -1, 0, 0, -1
	elseif front == "W" then
		return r.x0, r.z1, 0, -1, 1, 0
	end
	return r.x1, r.z0, 0, 1, -1, 0
end

local function size(front: string): (number, number) -- (along u, along v)
	local r = cur.room.rect
	if front == "N" or front == "S" then
		return r.x1 - r.x0, r.z1 - r.z0
	end
	return r.z1 - r.z0, r.x1 - r.x0
end

-- World rect of a footprint centred at (u, v) with size (w along u, d along v).
local function footprint(front: string, u: number, v: number, w: number, d: number): (Rect, number, number)
	local ox, oz, ux, uz, vx, vz = frame(front)
	local cx, cz = ox + ux * u + vx * v, oz + uz * u + vz * v
	local wx = math.abs(ux) * w + math.abs(vx) * d
	local wz = math.abs(uz) * w + math.abs(vz) * d
	return { x0 = cx - wx / 2, z0 = cz - wz / 2, x1 = cx + wx / 2, z1 = cz + wz / 2 }, cx, cz
end

local function free(rect: Rect): boolean
	local r = cur.room.rect
	if rect.x0 < r.x0 + 0.05 or rect.z0 < r.z0 + 0.05 or rect.x1 > r.x1 - 0.05 or rect.z1 > r.z1 - 0.05 then
		return false
	end
	for _, c in cur.clear do
		if overlaps(rect, c) then
			return false
		end
	end
	return true
end

local function block(parent: Instance, name: string, cf: CFrame, sx: number, sy: number, sz: number, color: Color3,
	material: Enum.Material?, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanTouch = false
	p.CanCollide = collide ~= false
	-- Big solid pieces (desks, shelves, cupboards, counters) cast shadows; small decoration does not.
	p.CastShadow = collide ~= false and (sx * sz >= 0.3 or sy >= 1.2)
	p.Size = Vector3.new(S(sx), S(sy), S(sz))
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- The CFrame of a piece centred at (u, v) on the floor, `h` metres above it, facing `facing` (+1 towards the front
-- wall, -1 away from it).
local function place(front: string, u: number, v: number, h: number, facing: number): CFrame
	local ox, oz, ux, uz, vx, vz = frame(front)
	local cx, cz = ox + ux * u + vx * v, oz + uz * u + vz * v
	-- Look direction: towards the front wall is -v.
	local lx, lz = -vx * facing, -vz * facing
	local pos = Vector3.new(S(cx), S(cur.room.y + h), S(cz))
	return CFrame.lookAt(pos, pos + Vector3.new(lx, 0, lz))
end

-- One piece: claims its footprint (so pieces never overlap) and builds it. Returns the base CFrame or nil.
local function piece(front: string, u: number, v: number, w: number, d: number, facing: number,
	build: (cf: CFrame) -> ()): CFrame?
	local rect = footprint(front, u, v, w, d)
	if not free(rect) then
		return nil
	end
	table.insert(cur.clear, rect)
	local cf = place(front, u, v, 0, facing)
	build(cf)
	return cf
end

-- A chair (seat + back). `cf` stands on the floor facing the way the sitter looks.
local function chair(cf: CFrame, color: Color3)
	local seat = Instance.new("Seat")
	seat.Name = "Chair"
	seat.Anchored = true
	seat.CanTouch = false -- nobody sits by walking into it
	seat.CastShadow = false
	seat.Size = Vector3.new(S(0.42), S(0.05), S(0.42))
	seat.CFrame = cf * CFrame.new(0, S(0.45), 0)
	seat.Color = color
	seat.Material = Enum.Material.Plastic
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.Parent = cur.parent
	table.insert(cur.seats, seat)
	block(cur.parent, "ChairBack", cf * CFrame.new(0, S(0.72), S(0.2)), 0.42, 0.42, 0.04, color, Enum.Material.Plastic,
		false)
	block(cur.parent, "ChairLegs", cf * CFrame.new(0, S(0.22), 0), 0.36, 0.44, 0.36, METAL, Enum.Material.Metal, false)
		.Transparency = 0.55
end

-- A desk: top and a front panel; `cf` on the floor, the sitter on its +Z side (behind it) looking -Z.
local function desk(cf: CFrame, w: number, d: number, h: number, color: Color3)
	block(cur.parent, "Desk", cf * CFrame.new(0, S(h - 0.02), 0), w, 0.04, d, color, Enum.Material.Wood)
	block(cur.parent, "DeskPanel", cf * CFrame.new(0, S((h - 0.04) / 2), S(-d / 2 + 0.03)), w, h - 0.04, 0.03, METAL,
		Enum.Material.Metal)
end

local function pc(cf: CFrame, h: number)
	local screen = block(cur.parent, "Monitor", cf * CFrame.new(0, S(h + 0.24), S(-0.12)), 0.5, 0.32, 0.04,
		Color3.fromRGB(20, 20, 24), Enum.Material.SmoothPlastic, false)
	local glow = block(cur.parent, "Screen", screen.CFrame * CFrame.new(0, 0, S(0.022)), 0.46, 0.28, 0.005,
		Color3.fromRGB(60, 110, 170), Enum.Material.Neon, false)
	glow.CanQuery = false
	block(cur.parent, "Keyboard", cf * CFrame.new(0, S(h + 0.01), S(0.1)), 0.42, 0.02, 0.14,
		Color3.fromRGB(36, 36, 40), Enum.Material.SmoothPlastic, false)
end

-- Rows of desks facing the front wall (classrooms, IT rooms, labs). `pcs` puts a PC on every desk.
local function rows(front: string, deskW: number, seatsPer: number, pcs: boolean, startV: number)
	local W, D = size(front)
	local pitchU = deskW + 0.9
	local cols = math.max(1, math.floor((W - 1.0 + 0.9) / pitchU))
	local spanU = cols * pitchU - 0.9
	local firstU = (W - spanU) / 2 + deskW / 2
	-- A desk whose place is taken (a walkway, a door) slides sideways up to 1 m to the nearest free spot.
	local SHIFTS = { 0, -0.25, 0.25, -0.5, 0.5, -0.75, 0.75, -1, 1 }
	local function spot(c: number, tv: number): number?
		for _, du in SHIFTS do
			local u = firstU + c * pitchU + du
			if free((footprint(front, u, tv + 0.3, deskW, 1.2))) then
				return u
			end
		end
		return nil
	end
	-- Shallow rooms: try starting the rows closer to the board and keep the start that fits the most desks.
	local starts = { startV }
	for sv = startV - 0.1, 0.35, -0.1 do
		table.insert(starts, sv)
	end
	local best, bestCount = startV, -1
	for _, sv in starts do
		local count = 0
		local tv = sv
		while tv + 0.9 < D - 0.05 do -- free() keeps the chair off the back wall
			local here = 0
			for c = 0, cols - 1 do
				if spot(c, tv) then
					here += 1
				end
			end
			count += here
			tv += if here > 0 then 1.55 else 0.1 -- nothing fits here (a walkway): try a little further back
		end
		if count > bestCount then
			best, bestCount = sv, count
		end
	end
	local v = best
	local color = CHAIR_COLORS[(string.byte(cur.room.label, -1) or 1) % #CHAIR_COLORS + 1]
	while v + 0.9 < D - 0.05 do
		local here = 0
		for c = 0, cols - 1 do
			local u = spot(c, v)
			here += if u and piece(front, u, v + 0.3, deskW, 1.2, 1, function(cf)
				desk(cf, deskW, 0.6, 0.75, if pcs then Color3.fromRGB(150, 150, 146) else WOOD)
				for s = 1, seatsPer do
					local off = (s - (seatsPer + 1) / 2) * (deskW / seatsPer)
					if pcs then
						pc(cf * CFrame.new(S(off), 0, 0), 0.75)
					end
					chair(cf * CFrame.new(S(off), 0, S(0.55)), color)
				end
			end) then 1 else 0
		end
		v += if here > 0 then 1.55 else 0.1
	end
end

-- Pieces along the walls that have no door zone, `depth` deep, `step` apart, at most `limit` of them. `build(cf, i)`
-- gets the piece's number; in `cf` local +Z points at the wall and -Z into the room. Returns how many fit.
local function alongWalls(depth: number, width: number, step: number, build: (cf: CFrame, i: number) -> (),
	limit: number?): number
	local n = 0
	for _, side in { "N", "S", "W", "E" } do
		local W = size(side)
		local u = 0.5 + width / 2
		while u < W - 0.5 - width / 2 do
			if limit and n >= limit then
				return n
			end
			piece(side, u, depth / 2 + 0.05, width, depth, -1, function(cf)
				n += 1
				build(cf, n)
			end)
			u += step
		end
	end
	return n
end

-- Small things that finish a room, each against a free bit of wall.
local function bin(cf: CFrame)
	block(cur.parent, "Bin", cf * CFrame.new(0, S(0.2), 0), 0.3, 0.4, 0.3, Color3.fromRGB(60, 70, 66),
		Enum.Material.Plastic)
end

local function plant(cf: CFrame)
	block(cur.parent, "PlantPot", cf * CFrame.new(0, S(0.2), 0), 0.35, 0.4, 0.35, Color3.fromRGB(150, 80, 50),
		Enum.Material.Slate)
	local leaves = block(cur.parent, "Plant", cf * CFrame.new(0, S(0.75), 0), 0.55, 0.7, 0.55,
		Color3.fromRGB(60, 120, 60), Enum.Material.Grass, false)
	leaves.Shape = Enum.PartType.Ball
end

local function cabinet(cf: CFrame)
	local body = block(cur.parent, "FilingCabinet", cf * CFrame.new(0, S(0.65), 0), 0.5, 1.3, 0.45,
		Color3.fromRGB(150, 154, 160), Enum.Material.Metal)
	for k = 0, 3 do
		block(cur.parent, "DrawerHandle", body.CFrame * CFrame.new(0, S(0.45 - k * 0.3), S(-0.23)), 0.14, 0.02, 0.02,
			METAL, Enum.Material.Metal, false)
	end
end

-- A wash basin on the wall with a mirror above it.
local function sink(cf: CFrame, mirror: boolean)
	block(cur.parent, "Sink", cf * CFrame.new(0, S(0.82), S(-0.02)), 0.5, 0.14, 0.4, WHITE, Enum.Material.Marble)
	block(cur.parent, "SinkPipe", cf * CFrame.new(0, S(0.38), S(0.12)), 0.08, 0.76, 0.08, METAL, Enum.Material.Metal,
		false)
	block(cur.parent, "Tap", cf * CFrame.new(0, S(0.95), S(0.14)), 0.04, 0.12, 0.12, METAL, Enum.Material.Metal, false)
	if mirror then
		block(cur.parent, "Mirror", cf * CFrame.new(0, S(1.5), S(0.27)), 0.5, 0.65, 0.02, Color3.fromRGB(190, 210, 220),
			Enum.Material.Glass, false).Reflectance = 0.4
	end
end

-- A table with two chairs on each long side (reading tables, the staff room's).
local function tableFour(cf: CFrame, color: Color3)
	block(cur.parent, "Table", cf * CFrame.new(0, S(0.74), 0), 1.6, 0.05, 0.9, WOOD, Enum.Material.Wood)
	block(cur.parent, "TableLegs", cf * CFrame.new(0, S(0.36), 0), 1.4, 0.72, 0.06, METAL, Enum.Material.Metal)
	for _, x in { -0.4, 0.4 } do
		chair(cf * CFrame.new(S(x), 0, S(0.65)), color)
		chair(cf * CFrame.new(S(x), 0, S(-0.65)) * CFrame.Angles(0, math.pi, 0), color)
	end
end

local function teacherDesk(front: string)
	local W = size(front)
	piece(front, W * 0.25, 1.1, 1.4, 1.3, -1, function(cf)
		desk(cf, 1.4, 0.7, 0.76, DARK_WOOD)
		chair(cf * CFrame.new(0, 0, S(0.6)), Color3.fromRGB(40, 40, 44))
	end)
end

local function cupboard(front: string)
	local W, D = size(front)
	piece(front, W - 0.9, D - 0.35, 1.2, 0.5, -1, function(cf)
		block(cur.parent, "Cupboard", cf * CFrame.new(0, S(0.9), 0), 1.2, 1.8, 0.45, WHITE, Enum.Material.Wood)
	end)
end

local BUILDERS: { [string]: (front: string) -> () } = {
	normal = function(front)
		teacherDesk(front)
		rows(front, 1.3, 2, false, 2.4)
		cupboard(front)
		alongWalls(0.3, 0.3, 0.5, bin, 1)
	end,
	computer = function(front)
		teacherDesk(front)
		rows(front, 1.6, 2, true, 2.4)
		-- PCs along the walls too, the sitter facing the wall (what fits around the rows and the doors).
		local color = CHAIR_COLORS[(string.byte(cur.room.label, -1) or 1) % #CHAIR_COLORS + 1]
		for _, side in { "N", "S", "W", "E" } do
			local W = size(side)
			local u = 0.8
			while u < W - 0.7 do
				piece(side, u, 0.68, 1.2, 1.24, 1, function(cf)
					local top = cf * CFrame.new(0, 0, S(-0.32))
					desk(top, 1.2, 0.6, 0.75, Color3.fromRGB(150, 150, 146))
					pc(top, 0.75)
					chair(cf * CFrame.new(0, 0, S(0.3)), color)
				end)
				u += 1.45
			end
		end
		local W = size(front)
		piece(front, W - 0.5, 0.45, 0.6, 0.6, -1, function(cf)
			local rack = block(cur.parent, "ServerRack", cf * CFrame.new(0, S(0.95), 0), 0.6, 1.9, 0.6,
				Color3.fromRGB(28, 28, 32), Enum.Material.Metal)
			for i = 0, 5 do
				block(cur.parent, "RackLight", rack.CFrame * CFrame.new(S(-0.2), S(-0.6 + i * 0.25), S(-0.302)), 0.03,
					0.03, 0.005, if i % 2 == 0 then Color3.fromRGB(60, 220, 90) else Color3.fromRGB(240, 170, 40),
					Enum.Material.Neon, false)
			end
		end)
	end,
	lab = function(front)
		teacherDesk(front)
		rows(front, 2.4, 3, false, 2.4)
		-- A fume hood, then benches with sinks along the free walls.
		alongWalls(0.75, 1.4, 1.6, function(cf, i)
			block(cur.parent, "LabBench", cf * CFrame.new(0, S(0.45), 0), 1.4, 0.9, 0.7, Color3.fromRGB(40, 44, 48),
				Enum.Material.Slate)
			if i == 1 then
				block(cur.parent, "FumeHood", cf * CFrame.new(0, S(1.55), S(0.05)), 1.4, 1.3, 0.6,
					Color3.fromRGB(200, 204, 206), Enum.Material.Metal)
				block(cur.parent, "HoodGlass", cf * CFrame.new(0, S(1.3), S(-0.26)), 1.3, 0.7, 0.02,
					Color3.fromRGB(180, 210, 220), Enum.Material.Glass, false).Transparency = 0.5
			else
				block(cur.parent, "LabSink", cf * CFrame.new(0, S(0.92), 0), 0.45, 0.06, 0.4, Color3.fromRGB(70, 74, 78),
					Enum.Material.Metal, false)
				block(cur.parent, "Tap", cf * CFrame.new(0, S(1.08), S(0.25)), 0.04, 0.3, 0.04, METAL,
					Enum.Material.Metal, false)
			end
		end, 4)
	end,
	changing = function()
		alongWalls(0.45, 1.6, 2.0, function(cf)
			block(cur.parent, "Bench", cf * CFrame.new(0, S(0.42), 0), 1.6, 0.06, 0.4, WOOD, Enum.Material.Wood)
			block(cur.parent, "BenchLegs", cf * CFrame.new(0, S(0.2), 0), 1.5, 0.4, 0.06, METAL, Enum.Material.Metal)
			block(cur.parent, "Hooks", cf * CFrame.new(0, S(1.6), S(0.2)), 1.6, 0.06, 0.05, METAL, Enum.Material.Metal, false)
		end)
		alongWalls(0.12, 0.7, 0.8, function(cf)
			block(cur.parent, "Mirror", cf * CFrame.new(0, S(1.45), S(0.04)), 0.6, 0.9, 0.02,
				Color3.fromRGB(190, 210, 220), Enum.Material.Glass, false).Reflectance = 0.4
		end, 1)
		alongWalls(0.3, 0.3, 0.5, bin, 1)
	end,
	library = function(front)
		local W, D = size(front)
		-- The librarian's desk with a PC, facing the room.
		piece(front, W * 0.3, 1.0, 1.6, 1.3, -1, function(cf)
			desk(cf, 1.6, 0.7, 0.76, DARK_WOOD)
			pc(cf * CFrame.new(S(-0.3), 0, 0), 0.76)
			chair(cf * CFrame.new(0, 0, S(0.6)), Color3.fromRGB(40, 40, 44))
		end)
		local function shelf(cf: CFrame, w: number, double: boolean)
			block(cur.parent, "Shelf", cf * CFrame.new(0, S(1.0), 0), w, 2.0, if double then 0.5 else 0.38, DARK_WOOD,
				Enum.Material.Wood)
			local faces: { number } = if double then { -0.2, 0.2 } else { -0.05 }
			for row = 0, 3 do
				for k, z in faces do
					block(cur.parent, "Books", cf * CFrame.new(0, S(0.35 + row * 0.45), S(z)), w - 0.1, 0.3,
						if double then 0.14 else 0.26, CHAIR_COLORS[(row + k) % #CHAIR_COLORS + 1],
						Enum.Material.Fabric, false)
				end
			end
		end
		-- Free-standing shelves and reading tables in rows, books along the walls.
		local v, row = 2.6, 0
		while v < D - 0.8 do
			local u = 1.4
			while u < W - 1.0 do
				if row % 2 == 0 then
					piece(front, u, v, 1.8, 0.5, 1, function(cf)
						shelf(cf, 1.8, true)
					end)
				else
					piece(front, u, v, 1.7, 2.3, 1, function(cf)
						tableFour(cf, CHAIR_COLORS[1])
					end)
				end
				u += 2.4
			end
			v += if row % 2 == 0 then 1.7 else 2.6
			row += 1
		end
		alongWalls(0.4, 1.8, 2.0, function(cf)
			shelf(cf, 1.8, false)
		end)
		alongWalls(0.4, 0.4, 0.5, plant, 1)
	end,
	office = function(front)
		local W, D = size(front)
		for _, uv in { { W * 0.3, 1.2 }, { W * 0.7, D - 1.3 } } do
			piece(front, uv[1], uv[2], 1.4, 1.4, 1, function(cf)
				desk(cf, 1.4, 0.7, 0.75, DARK_WOOD)
				pc(cf, 0.75)
				chair(cf * CFrame.new(0, 0, S(0.6)), Color3.fromRGB(40, 40, 44))
			end)
		end
		cupboard(front)
		alongWalls(0.45, 0.5, 0.7, cabinet, 3)
		alongWalls(0.4, 0.4, 0.5, plant, 1)
		alongWalls(0.3, 0.3, 0.5, bin, 1)
	end,
	dining = function(front)
		local W, D = size(front)
		local v = 1.6
		while v < D - 1.2 do
			local u = 1.6
			while u < W - 1.6 do
				piece(front, u, v, 2.4, 1.9, 1, function(cf)
					block(cur.parent, "Table", cf * CFrame.new(0, S(0.74), 0), 2.4, 0.05, 0.8, WOOD, Enum.Material.Wood)
					block(cur.parent, "TableLegs", cf * CFrame.new(0, S(0.36), 0), 2.2, 0.72, 0.06, METAL, Enum.Material.Metal)
					for side = -1, 1, 2 do
						block(cur.parent, "Bench", cf * CFrame.new(0, S(0.44), S(side * 0.75)), 2.3, 0.05, 0.3, WOOD,
							Enum.Material.Wood)
					end
				end)
				u += 3.2
			end
			v += 2.6
		end
		-- A tray rack and a water cooler by the walls, bins.
		alongWalls(0.45, 1.0, 1.2, function(cf, i)
			if i == 1 then
				block(cur.parent, "TrayRack", cf * CFrame.new(0, S(0.75), 0), 1.0, 1.5, 0.4, METAL, Enum.Material.Metal)
			else
				block(cur.parent, "WaterCooler", cf * CFrame.new(0, S(0.55), 0), 0.35, 1.1, 0.35, WHITE,
					Enum.Material.Plastic)
				block(cur.parent, "WaterBottle", cf * CFrame.new(0, S(1.3), 0), 0.28, 0.4, 0.28,
					Color3.fromRGB(150, 200, 235), Enum.Material.Glass, false).Transparency = 0.3
			end
		end, 2)
		alongWalls(0.3, 0.3, 2.0, bin, 2)
	end,
	kitchen = function()
		-- Counters along the walls: a fridge first, then stoves and sinks among the worktops.
		-- Counters are 1.8 m long (few parts); every third has a stove top, every fifth a sink.
		alongWalls(0.65, 1.8, 1.8, function(cf, i)
			if i == 1 then
				block(cur.parent, "Fridge", cf * CFrame.new(S(-0.45), S(0.95), 0), 0.8, 1.9, 0.6,
					Color3.fromRGB(210, 212, 214), Enum.Material.Metal)
				block(cur.parent, "Counter", cf * CFrame.new(S(0.45), S(0.45), 0), 0.9, 0.9, 0.6,
					Color3.fromRGB(190, 192, 194), Enum.Material.Metal)
				return
			end
			block(cur.parent, "Counter", cf * CFrame.new(0, S(0.45), 0), 1.8, 0.9, 0.6, Color3.fromRGB(190, 192, 194),
				Enum.Material.Metal)
			if i % 3 == 2 then
				block(cur.parent, "Stove", cf * CFrame.new(0, S(0.91), 0), 0.8, 0.02, 0.55, Color3.fromRGB(30, 30, 32),
					Enum.Material.Metal, false)
				for _, x in { -0.2, 0.2 } do
					block(cur.parent, "Burner", cf * CFrame.new(S(x), S(0.925), 0), 0.18, 0.01, 0.42,
						Color3.fromRGB(70, 60, 56), Enum.Material.Metal, false)
				end
			elseif i % 5 == 4 then
				block(cur.parent, "KitchenSink", cf * CFrame.new(0, S(0.9), 0), 0.5, 0.04, 0.4, METAL,
					Enum.Material.Metal, false)
				block(cur.parent, "Tap", cf * CFrame.new(0, S(1.05), S(0.22)), 0.04, 0.26, 0.04, METAL,
					Enum.Material.Metal, false)
			end
		end)
	end,
	wc = function(front)
		local W = size(front)
		-- Stalls along the front wall: partitions, a toilet against the wall, the door swung open inside.
		local u, besidePrevious = 0.6, false
		while u + 0.5 < W - 0.4 do
			besidePrevious = piece(front, u, 0.8, 1.0, 1.5, -1, function(cf)
				local stall = Color3.fromRGB(150, 170, 186)
				block(cur.parent, "StallWall", cf * CFrame.new(S(0.5), S(1.0), 0), 0.04, 2.0, 1.5, stall)
				if not besidePrevious then
					block(cur.parent, "StallWall", cf * CFrame.new(S(-0.5), S(1.0), 0), 0.04, 2.0, 1.5, stall)
				end
				block(cur.parent, "StallDoor", cf * CFrame.new(S(0.44), S(1.05), S(-0.38)), 0.03, 1.8, 0.7, stall,
					Enum.Material.SmoothPlastic, false)
				block(cur.parent, "Toilet", cf * CFrame.new(0, S(0.22), S(0.35)), 0.38, 0.44, 0.55, WHITE,
					Enum.Material.Marble)
				block(cur.parent, "Cistern", cf * CFrame.new(0, S(0.6), S(0.66)), 0.4, 0.35, 0.16, WHITE,
					Enum.Material.Marble)
				block(cur.parent, "PaperRoll", cf * CFrame.new(S(0.42), S(0.7), S(0.2)), 0.08, 0.12, 0.12, WHITE,
					Enum.Material.Fabric, false)
			end) ~= nil
			u += 1.05
		end
		-- Wash basins with mirrors on the other walls, a hand dryer and a bin.
		alongWalls(0.5, 0.6, 0.75, function(cf)
			sink(cf, true)
		end, 3)
		alongWalls(0.25, 0.35, 0.5, function(cf)
			block(cur.parent, "HandDryer", cf * CFrame.new(0, S(1.2), S(0.02)), 0.3, 0.3, 0.2, WHITE, Enum.Material.Plastic,
				false)
		end, 1)
		alongWalls(0.3, 0.3, 0.5, bin, 1)
	end,
	gym = function(front)
		local W, D = size(front)
		-- Wall bars in 2.7 m sections (three bays each, eight rungs: few parts).
		local u = 1.85
		while u < W - 1.6 do
			piece(front, u, 0.16, 2.7, 0.2, -1, function(cf)
				for k = 0, 7 do
					block(cur.parent, "WallBar", cf * CFrame.new(0, S(0.3 + k * 0.3), 0), 2.7, 0.04, 0.04, WOOD,
						Enum.Material.Wood, false)
				end
				for _, x in { -1.35, -0.45, 0.45, 1.35 } do
					block(cur.parent, "WallBarPost", cf * CFrame.new(S(x), S(1.3), 0), 0.06, 2.6, 0.08,
						WOOD, Enum.Material.Wood)
				end
			end)
			u += 2.8
		end
		local benchU = 1.6
		while benchU < W - 1.6 do
			piece(front, benchU, D - 0.4, 2.4, 0.4, 1, function(cf)
				block(cur.parent, "Bench", cf * CFrame.new(0, S(0.4), 0), 2.4, 0.06, 0.3, WOOD, Enum.Material.Wood)
			end)
			benchU += 4
		end
		-- A basketball hoop high on each end wall.
		local ends = if front == "N" or front == "S" then { "W", "E" } else { "N", "S" }
		for _, side in ends do
			local L = size(side)
			piece(side, L / 2, 0.15, 1.8, 0.2, -1, function(cf)
				block(cur.parent, "Backboard", cf * CFrame.new(0, S(2.75), S(0.02)), 1.8, 0.8, 0.05, WHITE,
					Enum.Material.SmoothPlastic) -- solid: the basketball bounces off it (above everyone's head)
				local rim = block(cur.parent, "Rim", cf * CFrame.new(0, S(2.45), S(-0.3)), 0.03, 0.45, 0.45,
					Color3.fromRGB(230, 110, 40), Enum.Material.Metal, false)
				rim.Shape = Enum.PartType.Cylinder
				rim.CFrame = rim.CFrame * CFrame.Angles(0, 0, math.pi / 2)
			end)
		end
		-- Mats and a vaulting box in the big gym.
		if W > 12 and D > 8 then
			for i, uv in { { W * 0.25, D * 0.62 }, { W * 0.75, D * 0.62 } } do
				piece(front, uv[1], uv[2], 2.0, 1.0, 1, function(cf)
					block(cur.parent, "Mat", cf * CFrame.new(0, S(0.05), 0), 2.0, 0.1, 1.0, Color3.fromRGB(40, 80, 150),
						Enum.Material.Fabric)
				end)
				if i == 1 then
					piece(front, uv[1], uv[2] - 1.6, 1.4, 0.6, 1, function(cf)
						block(cur.parent, "VaultingBox", cf * CFrame.new(0, S(0.5), 0), 1.4, 1.0, 0.6, WOOD,
							Enum.Material.Wood)
						block(cur.parent, "VaultingTop", cf * CFrame.new(0, S(1.03), 0), 1.4, 0.06, 0.6,
							Color3.fromRGB(200, 180, 150), Enum.Material.Fabric)
					end)
				end
			end
		end
	end,
	medical = function(front)
		local W = size(front)
		piece(front, W * 0.3, 1.2, 0.9, 2.0, -1, function(cf)
			block(cur.parent, "Bed", cf * CFrame.new(0, S(0.5), 0), 0.9, 0.2, 2.0, WHITE, Enum.Material.Fabric)
			block(cur.parent, "BedFrame", cf * CFrame.new(0, S(0.2), 0), 0.8, 0.4, 1.9, METAL, Enum.Material.Metal)
		end)
		piece(front, W * 0.72, 1.1, 1.2, 1.3, -1, function(cf)
			desk(cf, 1.2, 0.6, 0.75, WHITE)
			chair(cf * CFrame.new(0, 0, S(0.55)), Color3.fromRGB(40, 40, 44))
		end)
		cupboard(front)
		alongWalls(0.5, 0.6, 0.75, function(cf)
			sink(cf, true)
		end, 1)
		alongWalls(0.3, 0.3, 0.5, bin, 1)
	end,
	storage = function()
		-- A mop bucket first, then shelves of boxes.
		alongWalls(0.45, 0.45, 0.6, function(cf)
			block(cur.parent, "MopBucket", cf * CFrame.new(0, S(0.18), 0), 0.4, 0.36, 0.35,
				Color3.fromRGB(220, 190, 40), Enum.Material.Plastic)
			block(cur.parent, "Mop", cf * CFrame.new(S(0.1), S(0.75), 0) * CFrame.Angles(0, 0, math.rad(8)), 0.04, 1.3,
				0.04, WOOD, Enum.Material.Wood, false)
		end, 1)
		alongWalls(0.5, 1.4, 1.6, function(cf)
			block(cur.parent, "Shelf", cf * CFrame.new(0, S(1.0), 0), 1.4, 2.0, 0.45, METAL, Enum.Material.Metal)
			block(cur.parent, "Boxes", cf * CFrame.new(0, S(0.6), S(-0.02)), 1.2, 0.35, 0.36,
				Color3.fromRGB(160, 120, 76), Enum.Material.Cardboard, false)
			block(cur.parent, "Boxes", cf * CFrame.new(S(0.2), S(1.45), S(-0.02)), 0.7, 0.3, 0.36,
				Color3.fromRGB(176, 136, 90), Enum.Material.Cardboard, false)
		end)
	end,
	entrance = function(front)
		local W = size(front)
		if cur.room.label == "Porta" then
			-- Beside the porter (he stands in the middle of the room).
			piece(front, W / 2 - 1.3, 1.0, 1.6, 1.4, 1, function(cf)
				desk(cf, 1.6, 0.7, 0.9, DARK_WOOD)
				chair(cf * CFrame.new(0, 0, S(0.6)), Color3.fromRGB(40, 40, 44))
			end)
			-- The key board: a hook and a brass key for every room.
			alongWalls(0.12, 1.0, 1.2, function(cf)
				local board = block(cur.parent, "KeyBoard", cf * CFrame.new(0, S(1.5), S(0.03)), 1.0, 0.7, 0.03,
					Color3.fromRGB(120, 90, 60), Enum.Material.Wood, false)
				for row = 0, 3 do
					for col = 0, 5 do
						block(cur.parent, "Key", board.CFrame * CFrame.new(S(-0.4 + col * 0.16), S(0.24 - row * 0.16),
							S(-0.025)), 0.03, 0.07, 0.01, Color3.fromRGB(196, 160, 70), Enum.Material.Metal, false)
					end
				end
			end, 1)
		else
			-- The entrance hall: a notice board and a bench.
			alongWalls(0.12, 1.4, 1.6, function(cf)
				block(cur.parent, "NoticeBoard", cf * CFrame.new(0, S(1.5), S(0.03)), 1.4, 0.9, 0.03,
					Color3.fromRGB(170, 130, 90), Enum.Material.Fabric, false)
				for k = 0, 3 do
					block(cur.parent, "Notice", cf * CFrame.new(S(-0.45 + k * 0.3), S(1.55 + (k % 2) * 0.12), S(0.01)),
						0.21, 0.28, 0.005, WHITE, Enum.Material.SmoothPlastic, false)
				end
			end, 1)
			alongWalls(0.45, 1.6, 2.0, function(cf)
				block(cur.parent, "Bench", cf * CFrame.new(0, S(0.42), 0), 1.6, 0.06, 0.4, WOOD, Enum.Material.Wood)
				block(cur.parent, "BenchLegs", cf * CFrame.new(0, S(0.2), 0), 1.5, 0.4, 0.06, METAL, Enum.Material.Metal)
			end, 1)
		end
		alongWalls(0.3, 0.3, 0.5, bin, 1)
	end,
}

-- The wall a room "faces": the board wall if given, else the wall opposite its first door.
local function frontOf(room: Room): string
	if room.front then
		return room.front
	end
	-- No board: face the longest wall without a door.
	local hasDoor = {}
	for _, d in room.doors do
		hasDoor[d.side] = true
	end
	local r = room.rect
	local best, bestLen = nil, -1
	for _, side in { "N", "S", "W", "E" } do
		local len = if side == "N" or side == "S" then r.x1 - r.x0 else r.z1 - r.z0
		if not hasDoor[side] and len > bestLen then
			best, bestLen = side, len
		end
	end
	if best then
		return best
	end
	local opposite = { N = "S", S = "N", W = "E", E = "W" }
	local d = room.doors[1]
	return if d then opposite[d.side] else "N"
end

-- Furnishes one room; returns its seats.
function Furniture.room(parent: Instance, room: Room): { Seat }
	local build = BUILDERS[room.kind]
	if not build then
		return {}
	end
	local r = room.rect
	if r.x1 - r.x0 < 1.5 or r.z1 - r.z0 < 1.5 then
		return {} -- too small to furnish
	end
	local model = Instance.new("Model")
	model.Name = "Furniture"
	model:SetAttribute("Room", room.label)
	-- Keep clear: in front of every door and the middle of the room.
	local clear: { Rect } = {}
	-- In front of each door: 2 m wide (the door is 0.9 m; narrower gaps vanish on the pathfinding grid) and 1.3 m in.
	for _, d in room.doors do
		local inward = ({ N = { 0, 1 }, S = { 0, -1 }, W = { 1, 0 }, E = { -1, 0 } })[d.side]
		local ex, ez = d.x + inward[1] * 1.3, d.z + inward[2] * 1.3
		local along = if d.side == "N" or d.side == "S" then { 1.0, 0 } else { 0, 1.0 }
		table.insert(clear, { x0 = math.min(d.x, ex) - along[1], z0 = math.min(d.z, ez) - along[2],
			x1 = math.max(d.x, ex) + along[1], z1 = math.max(d.z, ez) + along[2] })
	end
	-- The middle stays free where the story puts things: quest objects in the story rooms, clue papers, notes and
	-- power banks (up to 1 m from the centre) in the clue rooms. Every other room keeps a small free centre (people
	-- and the phone's route aim there); the real classrooms are small, a bigger one leaves no desk rows.
	-- WCs are too small for both: their stalls reach the middle.
	local half = if room.story then 3.0 elseif room.clue then 1.2 elseif room.kind == "wc" then 0 else 0.5
	local cx, cz = (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2
	if half > 0 then
		table.insert(clear, { x0 = cx - half, z0 = cz - half, x1 = cx + half, z1 = cz + half })
	end
	-- A 1.4 m walkway joins each door to the middle (straight in, then across): a room with two or more doors can be
	-- the only way between two parts of the school (the map importer opens rooms into each other), and people, clue
	-- papers and the phone's route all aim at the middle.
	do
		for _, d in room.doors do
			if d.side == "N" or d.side == "S" then
				table.insert(clear, { x0 = d.x - 0.7, x1 = d.x + 0.7,
					z0 = math.min(d.z, cz) - 0.7, z1 = math.max(d.z, cz) + 0.7 })
				table.insert(clear, { x0 = math.min(d.x, cx) - 0.7, x1 = math.max(d.x, cx) + 0.7,
					z0 = cz - 0.7, z1 = cz + 0.7 })
			else
				table.insert(clear, { z0 = d.z - 0.7, z1 = d.z + 0.7,
					x0 = math.min(d.x, cx) - 0.7, x1 = math.max(d.x, cx) + 0.7 })
				table.insert(clear, { z0 = math.min(d.z, cz) - 0.7, z1 = math.max(d.z, cz) + 0.7,
					x0 = cx - 0.7, x1 = cx + 0.7 })
			end
		end
	end
	cur = { parent = model, room = room, clear = clear, seats = {} }
	build(frontOf(room))
	model.Parent = parent
	local seats = cur.seats
	cur = nil :: any
	return seats
end

return Furniture
