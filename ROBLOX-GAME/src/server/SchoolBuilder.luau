-- Builds the empty night school from FloorData, following HORROR-GAME/scripts/main.gd (_build_floor, _build_room,
-- _wall, _wall_windows, _wall_with_door, _slab, _build_flight, _add_lamp, _place_lockers).
-- Everything is computed in metres (x east, z south, y up, as in Godot) and converted with Config.studs at the end.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local FloorData = require(ReplicatedStorage.Shared.FloorData)
local Rooms = require(ReplicatedStorage.Shared.Rooms)
local CampaignData = require(ReplicatedStorage.Shared.CampaignData)
local Doors = require(script.Parent.Doors)
local Furniture = require(script.Parent.Furniture)

local S = Config.studs
local WALL_T = Config.WALL_THICKNESS
local WALL_H = Config.WALL_HEIGHT
local DOOR_W = Config.DOOR_WIDTH
local DOOR_H = Config.DOOR_HEIGHT
local FLOOR_H = Config.FLOOR_HEIGHT

local DOOR_SWING = { N = -1, S = 1, W = 1, E = -1 }
local OUTWARD = { N = { 0, -1 }, S = { 0, 1 }, W = { -1, 0 }, E = { 1, 0 } }

type Style = { material: Enum.Material, color: Color3, transparency: number?, reflectance: number? }

local STYLE: { [string]: Style } = {
	-- The Godot game's photos (HORROR-GAME/textures), imitated with built-in materials: terrazzo floors, beige
	-- tiles on the lower 1.6 m of the walls with plaster above, grey-brown wooden ceilings.
	floor = { material = Enum.Material.Pebble, color = Color3.fromRGB(168, 165, 156), reflectance = 0.04 }, -- polished
	ceiling = { material = Enum.Material.WoodPlanks, color = Color3.fromRGB(112, 98, 88) },
	wall = { material = Enum.Material.Plaster, color = Color3.fromRGB(234, 231, 224) },
	wallTiles = { material = Enum.Material.CeramicTiles, color = Color3.fromRGB(196, 168, 128) },
	board = { material = Enum.Material.Slate, color = Color3.fromRGB(40, 82, 62) },
	boardFrame = { material = Enum.Material.Wood, color = Color3.fromRGB(92, 70, 48) },
	tube = { material = Enum.Material.Neon, color = Color3.fromRGB(236, 244, 214) },
	grille = { material = Enum.Material.Metal, color = Color3.fromRGB(170, 170, 160) },
	planter = { material = Enum.Material.Grass, color = Color3.fromRGB(58, 78, 48) },
	stair = { material = Enum.Material.Concrete, color = Color3.fromRGB(150, 146, 140) },
	closed = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(70, 70, 76) },
	frame = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(56, 51, 46) },
	glass = { material = Enum.Material.Glass, color = Color3.fromRGB(190, 224, 255), transparency = 0.8, reflectance = 0.15 },
	lamp = { material = Enum.Material.Metal, color = Color3.fromRGB(150, 150, 142) },
	locker = { material = Enum.Material.Metal, color = Color3.fromRGB(86, 104, 98) },
	lockerDoor = { material = Enum.Material.Metal, color = Color3.fromRGB(96, 116, 108) },
	plaque = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(30, 92, 160) }, -- the blue room sign
}

export type School = {
	spawn: CFrame,
	farPoint: Vector3,
	patrol: { Vector3 },
	lockers: { Model },
	lamps: { SpotLight },
	seats: { [string]: { Seat } }, -- "<floor>:<room label>" -> its chairs
	rooms: { { floor: number, label: string, kind: string, centre: Vector3 } }, -- every named room (studs)
	pingPong: Model, -- the Aula's ping pong table
}

local DECOR = { Frame = true, Sill = true, Slit = true, Handle = true, Plaque = true, Lamp = true, Tube = true,
	Grille = true, Board = true }
local TILE_H = 1.6 -- metres of tiles at the bottom of every wall

local SchoolBuilder = {}

-- The floor being built.
local cur = {
	index = 0,
	y = 0,
	model = nil :: Instance?,
	bounds = { x0 = 0, z0 = 0, x1 = 0, z1 = 0 },
	building = {} :: { { x0: number, z0: number, x1: number, z1: number } }, -- core, rooms and courtyards (world m)
}
local lamps: { SpotLight } = {}
local seats: { [string]: { Seat } } = {}
local roomList: { { floor: number, label: string, kind: string, centre: Vector3 } } = {}
local STORY_ROOMS: { [string]: boolean } = {}
for _, place in CampaignData.STORY do
	STORY_ROOMS[`{place.floor}:{place.room}`] = true
end
local CLUE_ROOMS: { [string]: boolean } = {}
for _, place in CampaignData.CLUE_ROOMS do
	CLUE_ROOMS[`{place.floor}:{place.room}`] = true
end

-- A part from a CFrame in studs and a size in metres.
local function part(parent: Instance, cf: CFrame, sx: number, sy: number, sz: number, style: Style, collide: boolean, name: string?): Part
	local p = Instance.new("Part")
	p.Name = name or "Part"
	p.Anchored = true
	p.CanTouch = false
	p.CanCollide = collide
	p.Size = Vector3.new(S(sx), S(sy), S(sz))
	p.CFrame = cf
	p.Material = style.material
	p.Color = style.color
	p.Transparency = style.transparency or 0
	p.Reflectance = style.reflectance or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	-- Small decoration casts no shadow and is skipped by raycasts (sight, flash, prompts never need it).
	if name and DECOR[name] then
		p.CastShadow = false
		p.CanQuery = false
	elseif name == "Glass" then
		p.CastShadow = false -- Moonlight and lamp light pass through the windows, as in Godot.
	end
	p.Parent = parent
	return p
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(S(x), S(y), S(z))
end

local function box(cx: number, cy: number, cz: number, sx: number, sy: number, sz: number, style: Style, collide: boolean, name: string?): Part
	return part(cur.model :: Instance, at(cx, cy, cz), sx, sy, sz, style, collide, name)
end

local function toWorld(px: number, py: number): (number, number)
	return FloorData.toWorld(cur.index, px, py)
end

local function inBuilding(x: number, z: number): boolean
	for _, r in cur.building do
		if x > r.x0 and x < r.x1 and z > r.z0 and z < r.z1 then
			return true
		end
	end
	return false
end

-- A wall with the outside on one side (nothing of the building just beyond it): it gets windows. Rooms may reach
-- past the main block, so the test looks at what is on each side, not at the floor's rectangle.
local function isOuterWall(ax: number, az: number, bx: number, bz: number): boolean
	local probe = 0.35
	local mx, mz = (ax + bx) * 0.5, (az + bz) * 0.5
	if math.abs(az - bz) < 0.001 then
		return not inBuilding(mx, mz - probe) or not inBuilding(mx, mz + probe)
	end
	if math.abs(ax - bx) < 0.001 then
		return not inBuilding(mx - probe, mz) or not inBuilding(mx + probe, mz)
	end
	return false
end

-- A wall box split into the tiled lower band and the plaster above where it crosses TILE_H.
local function wallParts(cx: number, cy: number, cz: number, sx: number, sy: number, sz: number)
	local bottom = cy - sy * 0.5 - cur.y
	local top = cy + sy * 0.5 - cur.y
	if bottom < TILE_H - 0.01 and top > TILE_H + 0.01 then
		local low = TILE_H - bottom
		box(cx, cur.y + bottom + low * 0.5, cz, sx, low, sz, STYLE.wallTiles, true, "Wall")
		local up = top - TILE_H
		box(cx, cur.y + TILE_H + up * 0.5, cz, sx, up, sz, STYLE.wall, true, "Wall")
	else
		box(cx, cy, cz, sx, sy, sz, if top <= TILE_H + 0.01 then STYLE.wallTiles else STYLE.wall, true, "Wall")
	end
end

local function wallStrip(from: number, to: number, fixed: number, horizontal: boolean, y0: number, y1: number)
	local mid = (from + to) * 0.5
	local length = to - from
	local cy = cur.y + (y0 + y1) * 0.5
	if horizontal then
		wallParts(mid, cy, fixed, length, y1 - y0, WALL_T)
	else
		wallParts(fixed, cy, mid, WALL_T, y1 - y0, length)
	end
end

-- Glass with a cross-shaped frame and a sill. The glass collides so nobody walks out of the building.
local function windowPane(along: number, fixed: number, horizontal: boolean)
	local height = Config.WINDOW_TOP - Config.WINDOW_SILL
	local y = cur.y + (Config.WINDOW_SILL + Config.WINDOW_TOP) * 0.5
	local base = if horizontal then at(along, y, fixed) else at(fixed, y, along) * CFrame.Angles(0, math.pi * 0.5, 0)
	local parent = cur.model :: Instance
	local w = Config.WINDOW_WIDTH
	part(parent, base, w, height, 0.02, STYLE.glass, true, "Glass")
	part(parent, base, 0.05, height, 0.05, STYLE.frame, false, "Frame")
	part(parent, base, w, 0.05, 0.05, STYLE.frame, false, "Frame")
	part(parent, base * CFrame.new(0, S(-height * 0.5), 0), w, 0.06, 0.12, STYLE.frame, false, "Sill")
end

-- Outer wall with evenly spaced windows. Returns false when the wall is too short for one.
local function wallWindows(ax: number, az: number, bx: number, bz: number): boolean
	local horizontal = math.abs(az - bz) < 0.001
	local lo = if horizontal then math.min(ax, bx) else math.min(az, bz)
	local hi = if horizontal then math.max(ax, bx) else math.max(az, bz)
	local fixed = if horizontal then az else ax
	local count = math.floor((hi - lo - 0.8) / Config.WINDOW_PITCH)
	if count < 1 then
		return false
	end
	local cell = (hi - lo) / count
	local half = WALL_T * 0.5
	local cuts = { lo - half }
	for i = 0, count - 1 do
		local centre = lo + cell * (i + 0.5)
		table.insert(cuts, centre - Config.WINDOW_WIDTH * 0.5)
		table.insert(cuts, centre + Config.WINDOW_WIDTH * 0.5)
	end
	table.insert(cuts, hi + half)
	wallStrip(cuts[1], cuts[#cuts], fixed, horizontal, 0, Config.WINDOW_SILL)
	wallStrip(cuts[1], cuts[#cuts], fixed, horizontal, Config.WINDOW_TOP, WALL_H)
	for i = 1, #cuts, 2 do
		wallStrip(cuts[i], cuts[i + 1], fixed, horizontal, Config.WINDOW_SILL, Config.WINDOW_TOP)
	end
	for i = 0, count - 1 do
		windowPane((cuts[i * 2 + 2] + cuts[i * 2 + 3]) * 0.5, fixed, horizontal)
	end
	return true
end

local function wall(ax: number, az: number, bx: number, bz: number, y0: number?, y1: number?)
	local from, to = y0 or 0, y1 or WALL_H
	if from == 0 and to == WALL_H and isOuterWall(ax, az, bx, bz) and wallWindows(ax, az, bx, bz) then
		return
	end
	local length = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2) + WALL_T
	local cx, cz = (ax + bx) * 0.5, (az + bz) * 0.5
	local cy = cur.y + (from + to) * 0.5
	if math.abs(az - bz) < 0.001 then
		wallParts(cx, cy, cz, length, to - from, WALL_T)
	else
		wallParts(cx, cy, cz, WALL_T, to - from, length)
	end
end

-- The Porta's east wall has a small serving window to the buffet; both rooms cut it, the Porta adds the glass.
local function innerWindow(ax: number, az: number, bz: number, withGlass: boolean)
	local lo, hi = math.min(az, bz), math.max(az, bz)
	local half = WALL_T * 0.5
	local centre = (lo + hi) * 0.5
	local from = centre - Config.INNER_WINDOW_WIDTH * 0.5
	local to = centre + Config.INNER_WINDOW_WIDTH * 0.5
	wallStrip(lo - half, from, ax, false, 0, WALL_H)
	wallStrip(to, hi + half, ax, false, 0, WALL_H)
	wallStrip(from, to, ax, false, 0, Config.WINDOW_SILL)
	wallStrip(from, to, ax, false, Config.WINDOW_TOP, WALL_H)
	if withGlass then
		local height = Config.WINDOW_TOP - Config.WINDOW_SILL
		local y = cur.y + (Config.WINDOW_SILL + Config.WINDOW_TOP) * 0.5
		part(cur.model :: Instance, at(ax, y, centre), 0.02, height, Config.INNER_WINDOW_WIDTH, STYLE.glass, true, "Glass")
	end
end

local function plaque(label: string, x: number, z: number, side: string)
	local o = OUTWARD[side]
	local sx, sz = x + o[1] * (WALL_T * 0.5 + 0.02), z + o[2] * (WALL_T * 0.5 + 0.02)
	-- Local +Z points out of the wall, like the Godot plaque; the text sits on that (Back) face.
	local cf = at(sx, cur.y + 2.6, sz) * CFrame.Angles(0, math.atan2(o[1], o[2]), 0)
	local p = part(cur.model :: Instance, cf, 0.65, 0.24, 0.015, STYLE.plaque, false, "Plaque")
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.CanvasSize = Vector2.new(260, 96)
	gui.LightInfluence = 0.6
	gui.Parent = p
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = label
	text.TextScaled = true
	text.FontFace = Font.fromEnum(Enum.Font.GothamMedium)
	text.TextColor3 = Color3.fromRGB(240, 230, 210)
	text.Parent = gui
end

local function wallWithDoor(ax: number, az: number, bx: number, bz: number, side: string, cx: number, cz: number,
	label: string, withPanel: boolean, closed: boolean)
	local alongX = side == "N" or side == "S"
	local lo = if alongX then math.min(ax, bx) else math.min(az, bz)
	local hi = if alongX then math.max(ax, bx) else math.max(az, bz)
	local mid = if alongX then cx else cz
	local d0, d1 = mid - DOOR_W * 0.5, mid + DOOR_W * 0.5
	local fixed = if alongX then az else ax
	local function point(v: number): (number, number)
		if alongX then
			return v, fixed
		end
		return fixed, v
	end

	local p0x, p0z = point(lo)
	local q0x, q0z = point(d0)
	local q1x, q1z = point(d1)
	local p1x, p1z = point(hi)
	-- wall() adds half a wall's thickness at each end (to close corners); beside a door that would narrow the
	-- doorway to 1.25 m, too narrow for Roblox's pathfinding grid. These pieces stop at the doorway's edge.
	local e0x, e0z = point(d0 - WALL_T * 0.5)
	local e1x, e1z = point(d1 + WALL_T * 0.5)
	if d0 - WALL_T * 0.5 > lo then
		wall(p0x, p0z, e0x, e0z)
	end
	if d1 + WALL_T * 0.5 < hi then
		wall(e1x, e1z, p1x, p1z)
	end
	wall(q0x, q0z, q1x, q1z, DOOR_H, WALL_H) -- Lintel.

	local gx, gz = point(mid)
	if closed and not withPanel then
		local barrier = if alongX
			then box(gx, cur.y + DOOR_H * 0.5, gz, DOOR_W, DOOR_H, 0.1, STYLE.closed, true, "DemoBarrier")
			else box(gx, cur.y + DOOR_H * 0.5, gz, 0.1, DOOR_H, DOOR_W, STYLE.closed, true, "DemoBarrier")
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Closed"
		prompt.ObjectText = Rooms.CLOSED_MESSAGE
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("For", "all")
		prompt.Parent = barrier
	end
	if not withPanel then
		return
	end

	local hx, hz = point(d0 + 0.02)
	local yaw = if alongX then 0 else -math.pi * 0.5
	local door = Doors.create(cur.model :: Instance, at(hx, cur.y, hz) * CFrame.Angles(0, yaw, 0), S(DOOR_W - 0.04),
		S(DOOR_H), DOOR_SWING[side], closed)
	door:SetAttribute("Room", label)
	door:SetAttribute("Floor", cur.index)
	if label ~= "" then
		plaque(label, gx, gz, side)
	end
end

-- The ceiling lights of a room: the same fixture, a softer light without shadows (many rooms), tagged "RoomLight":
-- DayNight switches them on while the school is open and off at night (then only the corridors stay lit).
local function roomLamps(x0: number, z0: number, x1: number, z1: number)
	local w, d = x1 - x0, z1 - z0
	if w < 1.5 or d < 1.5 then
		return
	end
	local nx = math.clamp(math.round(w / 7), 1, 2)
	local nz = math.clamp(math.round(d / 7), 1, 2)
	for i = 1, nx do
		for k = 1, nz do
			local x = x0 + w * (i - 0.5) / nx
			local z = z0 + d * (k - 0.5) / nz
			-- One part: a glowing panel (fewer parts than the corridor fixtures).
			local fixture = box(x, cur.y + WALL_H - 0.04, z, 0.6, 0.06, 1.2, STYLE.tube, false, "Tube")
			CollectionService:AddTag(fixture, "RoomTube")
			local light = Instance.new("SpotLight")
			light.Face = Enum.NormalId.Bottom
			light.Angle = 100
			light.Range = S(5.5)
			light.Brightness = 1.1
			light.Color = Color3.new(1, 0.97, 0.9)
			light.Shadows = false
			light.Parent = fixture
			CollectionService:AddTag(light, "RoomLight")
		end
	end
end

local CHALK = {
	{ "Intervallumok", "A:  3 < x < 4        x ∈ ]3; 4[", "B:  1 ≤ x ≤ 2        x ∈ [1; 2]" },
	{ "Függvények", "f(x) = 2x + 1", "g(x) = x² − 4" },
	{ "Mozgás", "v = s / t", "a = Δv / Δt" },
}

-- A green board with chalk lines on the inner face of a wall without a door (the blackboard photo).
local function board(label: string, side: string, ax: number, az: number, bx: number, bz: number)
	local inward = ({ N = { 0, 1 }, S = { 0, -1 }, W = { 1, 0 }, E = { -1, 0 } })[side]
	local length = math.max(math.abs(bx - ax), math.abs(bz - az))
	local width = math.min(3.0, length - 0.6)
	if width < 1.2 then
		return false
	end
	local off = WALL_T * 0.5 + 0.03
	local cx, cz = (ax + bx) * 0.5 + inward[1] * off, (az + bz) * 0.5 + inward[2] * off
	local cf = at(cx, cur.y + 1.45, cz) * CFrame.Angles(0, math.atan2(inward[1], inward[2]), 0)
	local parent = cur.model :: Instance
	part(parent, cf * CFrame.new(0, 0, S(-0.01)), width + 0.1, 1.2, 0.03, STYLE.boardFrame, false, "Board")
	local slate = part(parent, cf, width, 1.1, 0.04, STYLE.board, false, "Board")
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.CanvasSize = Vector2.new(width * 200, 220)
	gui.LightInfluence = 1
	gui.Parent = slate
	local lines = CHALK[(string.byte(label, -1) or 0) % #CHALK + 1]
	for i, line in lines do
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Position = UDim2.new(0.06, 0, 0, 18 + (i - 1) * 62)
		text.Size = UDim2.new(0.9, 0, 0, if i == 1 then 52 else 46)
		text.TextXAlignment = if i == 1 then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
		text.Text = line
		text.TextScaled = true
		text.FontFace = Font.fromEnum(Enum.Font.PatrickHand)
		text.TextColor3 = Color3.fromRGB(232, 236, 228)
		text.TextTransparency = 0.12
		text.Parent = gui
	end
	return true
end

local function buildRoom(r: FloorData.Room)
	local p0x, p0z = toWorld(r.x0, r.y0)
	local p1x, p1z = toWorld(r.x1, r.y1)
	-- `doors`: the first door of each side (for the board and windows); `bySide`: every door of a side.
	local doors: { [string]: { pos: number, panel: boolean } } = {}
	local bySide: { [string]: { { pos: number, panel: boolean } } } = {}
	for token in string.gmatch(r.doors, "%S+") do
		local side = string.sub(token, 1, 1)
		local upper = string.upper(side)
		local d = { pos = tonumber(string.sub(token, 2)) or -1, panel = side == upper }
		doors[upper] = doors[upper] or d
		bySide[upper] = bySide[upper] or {}
		table.insert(bySide[upper], d)
	end
	local edges = {
		{ "N", p0x, p0z, p1x, p0z },
		{ "S", p0x, p1z, p1x, p1z },
		{ "W", p0x, p0z, p0x, p1z },
		{ "E", p1x, p0z, p1x, p1z },
	}
	local closed = r.kind == "other"
	local front: string? = nil
	if not closed and r.kind == "normal" and r.label ~= "" then
		for _, e in edges do
			if not doors[e[1]] and Config.INNER_WINDOWS[r.label] ~= e[1]
				and not isOuterWall(e[2], e[3], e[4], e[5]) and board(r.label, e[1], e[2], e[3], e[4], e[5]) then
				front = e[1]
				break
			end
		end
	end
	-- Furniture by kind, keeping the doors and the middle clear.
	if not closed and r.kind ~= "corridor" then
		local x0, x1 = math.min(p0x, p1x), math.max(p0x, p1x)
		local z0, z1 = math.min(p0z, p1z), math.max(p0z, p1z)
		local inset = WALL_T * 0.5
		local doorList: { Furniture.Door } = {}
		for side, list in bySide do
			for _, d in list do
				local x, z
				if side == "N" or side == "S" then
					x = if d.pos >= 0 then (toWorld(d.pos, d.pos)) else (x0 + x1) * 0.5
					z = if side == "N" then z0 else z1
				else
					local _, wz = toWorld(d.pos, d.pos)
					z = if d.pos >= 0 then wz else (z0 + z1) * 0.5
					x = if side == "W" then x0 else x1
				end
				table.insert(doorList, { x = x, z = z, side = side })
			end
		end
		roomLamps(x0, z0, x1, z1)
		local list = Furniture.room(cur.model :: Instance, {
			label = r.label,
			kind = r.kind,
			rect = { x0 = x0 + inset, z0 = z0 + inset, x1 = x1 - inset, z1 = z1 - inset },
			y = cur.y,
			doors = doorList,
			front = front,
			story = STORY_ROOMS[`{cur.index}:{r.label}`] == true,
			clue = CLUE_ROOMS[`{cur.index}:{r.label}`] == true,
		})
		if r.label ~= "" then
			local key = `{cur.index}:{r.label}`
			seats[key] = seats[key] or {}
			for _, seat in list do
				table.insert(seats[key], seat)
			end
			table.insert(roomList, { floor = cur.index, label = r.label, kind = r.kind,
				centre = Vector3.new(S((x0 + x1) * 0.5), S(cur.y) + 3, S((z0 + z1) * 0.5)) })
		end
	end
	for _, e in edges do
		local side, ax, az, bx, bz = e[1], e[2], e[3], e[4], e[5]
		local door = doors[side]
		if not door then
			if Config.INNER_WINDOWS[r.label] == side then
				innerWindow(ax, az, bz, r.label == "Porta")
			else
				wall(ax, az, bx, bz)
			end
			continue
		end
		-- Each door of this side gets its own piece of the wall (split halfway between neighbouring doors).
		local alongX = side == "N" or side == "S"
		local list = {}
		for _, d in bySide[side] do
			local at = if alongX then (ax + bx) * 0.5 else (az + bz) * 0.5
			if d.pos >= 0 then
				local wx, wz = toWorld(d.pos, d.pos)
				at = if alongX then wx else wz
			end
			table.insert(list, { at = at, panel = d.panel })
		end
		table.sort(list, function(p, q)
			return p.at < q.at
		end)
		local lo = if alongX then math.min(ax, bx) else math.min(az, bz)
		local hi = if alongX then math.max(ax, bx) else math.max(az, bz)
		for i, d in list do
			local from = if i == 1 then lo else (list[i - 1].at + d.at) * 0.5
			local to = if i == #list then hi else (d.at + list[i + 1].at) * 0.5
			if alongX then
				wallWithDoor(from, az, to, bz, side, d.at, az, r.label, d.panel, closed)
			else
				wallWithDoor(ax, from, bx, to, side, ax, d.at, r.label, d.panel, closed)
			end
		end
	end
end

type Rect = { x0: number, z0: number, x1: number, z1: number }

-- A slab over `rect` minus the `holes`, split into boxes.
local function slab(rect: Rect, yTop: number, thickness: number, holes: { Rect }, style: Style, collide: boolean, name: string)
	local xs, zs = { rect.x0, rect.x1 }, { rect.z0, rect.z1 }
	for _, h in holes do
		table.insert(xs, h.x0)
		table.insert(xs, h.x1)
		table.insert(zs, h.z0)
		table.insert(zs, h.z1)
	end
	table.sort(xs)
	table.sort(zs)
	for i = 1, #xs - 1 do
		for j = 1, #zs - 1 do
			local w, d = xs[i + 1] - xs[i], zs[j + 1] - zs[j]
			if w < 0.01 or d < 0.01 then
				continue
			end
			local cx, cz = xs[i] + w * 0.5, zs[j] + d * 0.5
			local inHole = false
			for _, h in holes do
				if cx >= h.x0 and cx < h.x1 and cz >= h.z0 and cz < h.z1 then
					inHole = true
					break
				end
			end
			if not inHole then
				box(cx, yTop - thickness * 0.5, cz, w, thickness, d, style, collide, name)
			end
		end
	end
end

local function lamp(x: number, z: number)
	-- A metal box with four fluorescent tubes under a grille (the lamp photo).
	local fixture = box(x, cur.y + WALL_H - 0.03, z, 0.6, 0.05, 0.6, STYLE.lamp, false, "Lamp")
	for i = 0, 3 do
		box(x - 0.21 + i * 0.14, cur.y + WALL_H - 0.075, z, 0.035, 0.035, 0.56, STYLE.tube, false, "Tube")
	end
	box(x, cur.y + WALL_H - 0.1, z, 0.6, 0.012, 0.02, STYLE.grille, false, "Grille")
	box(x, cur.y + WALL_H - 0.1, z - 0.18, 0.6, 0.012, 0.02, STYLE.grille, false, "Grille")
	box(x, cur.y + WALL_H - 0.1, z + 0.18, 0.6, 0.012, 0.02, STYLE.grille, false, "Grille")
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 70
	light.Range = S(6.5 * Config.WORLD_SCALE)
	light.Brightness = 1.4
	light.Color = Color3.new(0.9, 0.95, 0.8)
	light.Shadows = true
	light.Parent = fixture
	table.insert(lamps, light)
end

-- Floor or ceiling under the parts of rooms and courtyards that reach past the main block: those pieces, merged
-- into as few boxes as possible (rows of cells), so the building keeps its own outline instead of a big rectangle.
local function outerSlab(core: Rect, pieces: { Rect }, yTop: number, thickness: number, style: Style, collide: boolean,
	name: string)
	local outside: { Rect } = {}
	for _, p in pieces do
		-- p minus the core: up to four strips.
		local strips = {
			{ x0 = p.x0, z0 = p.z0, x1 = p.x1, z1 = math.min(p.z1, core.z0) },
			{ x0 = p.x0, z0 = math.max(p.z0, core.z1), x1 = p.x1, z1 = p.z1 },
			{ x0 = p.x0, z0 = math.max(p.z0, core.z0), x1 = math.min(p.x1, core.x0), z1 = math.min(p.z1, core.z1) },
			{ x0 = math.max(p.x0, core.x1), z0 = math.max(p.z0, core.z0), x1 = p.x1, z1 = math.min(p.z1, core.z1) },
		}
		for _, s in strips do
			if s.x1 - s.x0 > 0.01 and s.z1 - s.z0 > 0.01 then
				table.insert(outside, s)
			end
		end
	end
	if #outside == 0 then
		return
	end
	local xs, zs = {}, {}
	for _, s in outside do
		table.insert(xs, s.x0)
		table.insert(xs, s.x1)
		table.insert(zs, s.z0)
		table.insert(zs, s.z1)
	end
	table.sort(xs)
	table.sort(zs)
	local function covered(x: number, z: number): boolean
		for _, s in outside do
			if x > s.x0 and x < s.x1 and z > s.z0 and z < s.z1 then
				return true
			end
		end
		return false
	end
	for j = 1, #zs - 1 do
		local z0, z1 = zs[j], zs[j + 1]
		if z1 - z0 < 0.01 then
			continue
		end
		local runStart: number? = nil
		for i = 1, #xs do
			local inside = i < #xs and xs[i + 1] - xs[i] > 0.001 and covered((xs[i] + xs[i + 1]) * 0.5, (z0 + z1) * 0.5)
			local skip = i < #xs and xs[i + 1] - xs[i] <= 0.001
			if skip then
				continue
			end
			if inside and not runStart then
				runStart = xs[i]
			elseif not inside and runStart then
				local x0 = runStart :: number
				box((x0 + xs[i]) * 0.5, yTop - thickness * 0.5, (z0 + z1) * 0.5, xs[i] - x0, thickness, z1 - z0, style,
					collide, name)
				runStart = nil
			end
		end
	end
end

local function buildFloor(index: number, data: FloorData.Floor, stairHoles: { Rect }, parent: Instance)
	local model = Instance.new("Model")
	model.Name = `Floor{index}`
	model.Parent = parent
	cur.index = index
	cur.y = index * FLOOR_H
	cur.model = model
	local function worldBox(b: FloorData.Box): Rect
		local ax, az = toWorld(b.x0, b.y0)
		local bx, bz = toWorld(b.x1, b.y1)
		return { x0 = math.min(ax, bx), z0 = math.min(az, bz), x1 = math.max(ax, bx), z1 = math.max(az, bz) }
	end
	local core = worldBox(data.core)
	cur.bounds = core
	local pieces: { Rect } = {}
	cur.building = { core }
	for _, r in data.rooms do
		local w = worldBox(r :: any)
		table.insert(pieces, w)
		table.insert(cur.building, w)
	end
	for _, s in data.solids do
		local w = worldBox(s)
		table.insert(pieces, w)
		table.insert(cur.building, w)
	end

	-- Upper floors have the stairwells cut out of the slab; every floor but the top has holes in its ceiling.
	-- Rooms reaching past the main block get their own pieces of floor and ceiling.
	slab(core, cur.y, 0.5, if index > 0 then stairHoles else {}, STYLE.floor, true, "Floor")
	slab(core, cur.y + WALL_H + 0.3, 0.3, if index < #FloorData.FLOORS - 1 then stairHoles else {}, STYLE.ceiling,
		false, "Ceiling")
	outerSlab(core, pieces, cur.y, 0.5, STYLE.floor, true, "Floor")
	outerSlab(core, pieces, cur.y + WALL_H + 0.3, 0.3, STYLE.ceiling, false, "Ceiling")

	for _, r in data.rooms do
		buildRoom(r)
	end
	for _, s in data.solids do
		local x0, z0 = toWorld(s.x0, s.y0)
		local x1, z1 = toWorld(s.x1, s.y1)
		box((x0 + x1) * 0.5, cur.y + WALL_H * 0.5, (z0 + z1) * 0.5, math.abs(x1 - x0), WALL_H, math.abs(z1 - z0),
			STYLE.planter, true, "Courtyard")
	end
	for _, w in data.endWalls do
		local x0, z0 = toWorld(w.x0, w.y0)
		local x1, z1 = toWorld(w.x1, w.y1)
		wall(x0, z0, x1, z1)
	end
	for _, p in data.lights do
		lamp(toWorld(p.x, p.y))
	end
end

-- Two stacked flights per stairwell. The steps are for looks; players walk on an invisible ramp.
local function flight(rect: Rect, y0: number, topFlight: boolean)
	local width = rect.x1 - rect.x0
	local length = rect.z1 - rect.z0
	local xc = (rect.x0 + rect.x1) * 0.5
	local zc = (rect.z0 + rect.z1) * 0.5
	local rise = FLOOR_H / Config.STAIR_STEPS
	local depth = length / Config.STAIR_STEPS
	for k = 0, Config.STAIR_STEPS - 1 do
		-- The lower flight is a solid wedge; the upper one a thin sawtooth that leaves headroom below.
		local top = (k + 1) * rise
		local height = if topFlight then math.min(top, 0.5) else top
		local step = box(xc, y0 + top - height * 0.5, rect.z1 - (k + 0.5) * depth, width, height, depth, STYLE.stair,
			false, "Step")
		step.CanQuery = false
	end

	local angle = math.atan2(FLOOR_H, length)
	local ramp = part(cur.model :: Instance, at(xc, y0 + FLOOR_H * 0.5 - 0.15, zc) * CFrame.Angles(angle, 0, 0), width,
		0.3, math.sqrt(length * length + FLOOR_H * FLOOR_H), STYLE.stair, true, "Ramp")
	ramp.Transparency = 1

	-- Side walls double as railings one metre above the next floor.
	local wallHeight = FLOOR_H + 1.0
	for _, x in { rect.x0 - 0.05, rect.x1 + 0.05 } do
		box(x, y0 + wallHeight * 0.5, zc, 0.1, wallHeight, length, STYLE.wall, true, "StairWall")
	end
	if topFlight then
		-- Nothing boards at the top floor's open end of the hole, so rail it off.
		box(xc, y0 + FLOOR_H + 0.5, rect.z1 - 0.05, width, 1.0, 0.1, STYLE.wall, true, "Railing")
	else
		-- Close the space under the flight, short of the floor so the ramp's end can be stepped off.
		box(xc, y0 + (FLOOR_H - 0.4) * 0.5, rect.z0 + 0.05, width, FLOOR_H - 0.4, 0.1, STYLE.wall, true, "StairWall")
	end
end

local function locker(parent: Instance, floor: number, px: number, py: number, yaw: number): Model
	local x, z = FloorData.toWorld(floor, px, py)
	local base = at(x, floor * FLOOR_H, z) * CFrame.Angles(0, yaw, 0) -- Local +Z is the front, as in Godot.
	local w, h, d = 0.9, 2.0, 0.6
	local model = Instance.new("Model")
	model.Name = "Locker"
	local body = part(model, base * CFrame.new(0, S(h * 0.5), 0), w, h, d, STYLE.locker, true, "Body")
	local door = part(model, base * CFrame.new(0, S(h * 0.5), S(d * 0.5 + 0.01)), w * 0.92, h * 0.95, 0.02,
		STYLE.lockerDoor, false, "Front")
	part(model, base * CFrame.new(S(w * 0.35), S(1.1), S(d * 0.5 + 0.03)), 0.04, 0.16, 0.03, STYLE.frame, false, "Handle")
	for i = 0, 2 do
		part(model, base * CFrame.new(0, S(1.6 + i * 0.05), S(d * 0.5 + 0.025)), w * 0.45, 0.02, 0.01, STYLE.frame, false,
			"Slit")
	end
	model.PrimaryPart = body

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HidePrompt"
	prompt.ActionText = "Hide"
	prompt.ObjectText = "Locker"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("For", "all")
	prompt.Parent = door

	model:SetAttribute("Occupant", 0)
	CollectionService:AddTag(model, "Locker")
	model.Parent = parent
	return model
end

function SchoolBuilder.build(parent: Instance): School
	lamps = {}
	seats = {}
	roomList = {}
	local stairHoles: { Rect } = FloorData.STAIRS
	for i, data in FloorData.FLOORS do
		buildFloor(i - 1, data, stairHoles, parent)
	end

	local stairs = Instance.new("Model")
	stairs.Name = "Stairs"
	stairs.Parent = parent
	cur.model = stairs
	for _, rect in FloorData.STAIRS do
		for f = 0, 1 do
			flight(rect, f * FLOOR_H, f == 1)
		end
	end

	local lockerFolder = Instance.new("Folder")
	lockerFolder.Name = "Lockers"
	lockerFolder.Parent = parent
	local lockers = {}
	for _, l in FloorData.LOCKERS do
		table.insert(lockers, locker(lockerFolder, l.floor, l.x, l.y, l.yaw))
	end

	-- Waypoints for the entity: a loop through the ground floor, then the 1st, then the 2nd.
	local patrol = {}
	for i, data in FloorData.FLOORS do
		for _, p in data.patrol do
			local x, z = FloorData.toWorld(i - 1, p.x, p.y)
			table.insert(patrol, Vector3.new(S(x), S((i - 1) * FLOOR_H + 0.1), S(z)))
		end
	end
	local spawnPos = Vector3.new(S(Config.SPAWN.X), S(Config.SPAWN.Y), S(Config.SPAWN.Z))
	-- A ping pong table in the Aula, 6 m west of the spawn (clear of the spawn pads, the altar 7 m north and the
	-- patrol points). Long side along x: the players stand at its west and east ends.
	local tableAt = Vector3.new(S(Config.SPAWN.X - 6), 0, S(Config.SPAWN.Z - 1))
	local pong = Instance.new("Model")
	pong.Name = "PingPongTable"
	local function pongPart(name: string, offset: Vector3, size: Vector3, color: Color3, material: Enum.Material,
		collide: boolean): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = collide
		p.CanTouch = false
		p.Size = Vector3.new(S(size.X), S(size.Y), S(size.Z))
		p.CFrame = CFrame.new(tableAt + Vector3.new(S(offset.X), S(offset.Y), S(offset.Z)))
		p.Color = color
		p.Material = material
		p.Parent = pong
		return p
	end
	local top = pongPart("TableTop", Vector3.new(0, 0.74, 0), Vector3.new(2.74, 0.04, 1.525),
		Color3.fromRGB(30, 80, 60), Enum.Material.SmoothPlastic, true)
	pongPart("CentreLine", Vector3.new(0, 0.762, 0), Vector3.new(2.74, 0.002, 0.02), Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic, false)
	pongPart("Net", Vector3.new(0, 0.84, 0), Vector3.new(0.02, 0.15, 1.6), Color3.fromRGB(230, 230, 230),
		Enum.Material.Fabric, false).Transparency = 0.3
	for _, x in { -1.2, 1.2 } do
		pongPart("TableLegs", Vector3.new(x, 0.36, 0), Vector3.new(0.06, 0.72, 1.3), Color3.fromRGB(40, 40, 44),
			Enum.Material.Metal, true)
	end
	pong.PrimaryPart = top
	pong.Parent = parent
	local farPoint = patrol[1]
	for _, p in patrol do
		if (p - spawnPos).Magnitude > (farPoint - spawnPos).Magnitude then
			farPoint = p
		end
	end

	return {
		spawn = CFrame.new(spawnPos + Vector3.new(0, 3, 0)), -- Facing north, as in Godot.
		farPoint = farPoint,
		patrol = patrol,
		lockers = lockers,
		lamps = lamps,
		seats = seats,
		rooms = roomList,
		pingPong = pong, -- the Aula's table (src/server/PingPong.luau)
	}
end

return SchoolBuilder
