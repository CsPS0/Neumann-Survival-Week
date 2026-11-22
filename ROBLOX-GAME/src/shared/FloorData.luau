--!strict
-- The three floor plans, drawn in the map editor (tools/map-editor; the generated block below) on top of the real
-- floor plans (plan units: metres at WORLD_SCALE 1.25). A plan point p is world metres (p - origin) * scale. Floors are 0 (ground), 1, 2.
-- Room doors: space-separated tokens "<side><position>", N/S/E/W = door, lowercase = doorless opening, position
-- optional (middle of the edge). Corridors and the dog's route are not needed on Roblox.

export type Point = { x: number, y: number }
-- kind: what the room is (Rooms.Kind: "normal", "computer", "office", "storage", ..., "other" = closed).
export type Room = { label: string, x0: number, y0: number, x1: number, y1: number, doors: string, kind: string }
export type Box = { x0: number, y0: number, x1: number, y1: number }
export type Floor = {
	origin: Point,
	scale: number,
	core: Box, -- the main block; walls on its edge (or on any room's outside face) get windows
	rect: Box, -- everything on the floor, rooms reaching past the core included
	rooms: { Room },
	solids: { Box },
	endWalls: { Box },
	lights: { Point },
	patrol: { Point },
}
export type Rect = { x0: number, z0: number, x1: number, z1: number }

local WORLD_SCALE = 1.25

local function v(x: number, y: number): Point
	return { x = x, y = y }
end

local function box(x0: number, y0: number, x1: number, y1: number): Box
	return { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
end

local function room(label: string, x0: number, y0: number, x1: number, y1: number, doors: string, kind: string): Room
	return { label = label, x0 = x0, y0 = y0, x1 = x1, y1 = y1, doors = doors, kind = kind }
end

-- BEGIN GENERATED MAP (tools/map-editor/import-map.luau from school-map.json: edit the map, not this block)
local GROUND: Floor = {
	origin = v(42.6, 21.9),
	scale = 0.8 * WORLD_SCALE,
	core = box(0, 0, 104, 43.8), -- the main block; rooms may reach past it
	rect = box(-1.5, -3, 106.1, 44.6),
	rooms = {
		room("GT11-12", -1.5, 0, 13.15, 5.95, "S10.8", "computer"),
		room("19", 13.15, 0, 16.95, 6.3, "S13.95", "storage"),
		room("19/b", 16.95, 0, 20.7, 6.3, "S18.4", "storage"),
		room("20", 20.7, -3, 24.75, 5.9, "S22.9", "storage"),
		room("21", 24.75, -3, 28.65, 5.9, "S26.9", "storage"),
		room("Konyha", 33.8, -2.8, 53.35, 6.15, "S36.7", "kitchen"),
		room("27", 58.6, -2.9, 66.25, 6.15, "S", "gym"),
		room("28", 66.25, 0, 74.85, 6.15, "S", "normal"),
		room("", 53.35, 0, 58.6, 6.15, "S", "corridor"),
		room("30", 77.95, 0, 81.05, 6.1, "S", "storage"),
		room("32", 81.05, 0, 84.6, 6.1, "S", "storage"),
		room("33", 84.6, 0, 92.9, 6.1, "S", "normal"),
		room("35", 92.9, 0, 101.95, 6.1, "S", "normal"),
		room("16/a", -1.5, 5.95, 7, 10.15, "E", "storage"),
		room("14", -1.5, 13.7, 7, 24.45, "E16", "normal"),
		room("8", -1.5, 24.45, 7, 27.8, "E", "office"),
		room("GT2", -1.5, 27.8, 7, 32.15, "E", "computer"),
		room("GT1", -1.5, 32.15, 7, 36.8, "E", "computer"),
		room("5", -1.5, 36.8, 13.15, 42.8, "N8.5", "normal"),
		room("3", 13.15, 36.8, 23.1, 42.8, "N", "office"),
		room("Cisco", 10.1, 9.1, 14.5, 12.05, "W", "lab"),
		room("15", 10.1, 12.05, 14.5, 15.1, "W", "office"),
		room("13", 10.1, 15.1, 14.5, 17.55, "W", "office"),
		room("12", 10.1, 17.55, 14.5, 19.8, "W", "office"),
		room("11", 10.1, 19.8, 14.5, 22.75, "W", "office"),
		room("10", 10.1, 22.75, 14.5, 26, "W", "office"),
		room("Gazd.", 10.2, 27.5, 14.5, 30.15, "W", "office"),
		room("Fejl.", 10.2, 30.15, 14.5, 34.5, "W", "office"),
		room("GT3-GT4", 14.5, 16.7, 21.05, 27.65, "e19.6", "computer"),
		room("23", 21.05, 16.7, 29.6, 22.25, "E W19.6", "normal"),
		room("24", 21.05, 22.25, 29.3, 27.65, "E w24.9", "normal"),
		room("Könyvtár", 57.7, 16.7, 65.05, 27.5, "W", "library"),
		room("38", 65.05, 16.7, 70.7, 23.35, "E", "storage"),
		room("39", 65.05, 23.35, 70.7, 27.5, "E", "office"),
		room("Tornaterem", 74, 12.1, 106.1, 30.5, "W21.6 n103.9", "gym"),
		room("31", 74, 9.1, 85.7, 12.1, "N78.7", "changing"),
		room("34", 85.7, 9.1, 97.2, 12.1, "N92.7", "changing"),
		room("40", 74, 30.5, 85.2, 33.9, "S78.2", "changing"),
		room("41", 85.2, 30.5, 93.3, 33.9, "S89.2", "changing"),
		room("42", 95.2, 30.5, 101.85, 36.75, "W35.8", "normal"),
		room("GT47", 58.8, 36.75, 67.4, 44.5, "N62.2", "computer"),
		room("46", 67.4, 36.75, 75.95, 43, "N71.6", "normal"),
		room("45", 75.95, 36.75, 84.3, 43, "N81", "normal"),
		room("44", 84.3, 36.75, 93.05, 43, "N89.8", "normal"),
		room("43", 93.05, 36.75, 101.85, 43, "N94.1", "normal"),
		room("WC", 30.6, 39.9, 36.5, 43, "N33.7", "wc"),
		room("Bejárat", 36.5, 39.9, 42.45, 43, "N39.7", "entrance"),
		room("Porta", 42.45, 39.9, 47.85, 43, "N43.25", "entrance"),
		room("Büfé", 47.85, 39.9, 54.4, 43, "N49.6", "kitchen"),
		room("WC", 54.4, 39.9, 58.8, 43, "N57.5", "wc"),
		room("Ebédlő", 33.9, 6.15, 53.4, 20.5, "n36.7 s41.3 w19.5 e19.5", "dining"),
		room("", 27.2, 42.35, 30.6, 44.6, "N28.9", "storage"),
		room("", 23.1, 38.85, 25.1, 41.95, "E", "storage"),
		room("", 25.1, 42.35, 27.2, 44.6, "N", "storage"),
		room("16/b", -1.5, 10.15, 7, 13.7, "E", "storage"),
		room("42/b", 93.3, 30.5, 95.2, 33.9, "S94.1", "normal"),
		room("", 101.95, 0, 104, 6.2, "", "other"),
		room("", 101.9, 6.2, 104, 12.1, "", "other"),
		room("", 101.85, 30.5, 104, 43, "", "other"),
		room("", 67.4, 43, 104, 43.8, "", "other"),
		room("", 23.1, 41.95, 25.1, 42.8, "", "other"),
		room("", 0, 42.8, 25.1, 43.8, "", "other"),
		room("", 30.6, 43, 58.8, 43.8, "", "other"),
	},
	solids = { box(14.5, 9.1, 28.3, 16.1), box(15.45, 27.65, 28.9, 35.3), box(59.8, 9, 70.4, 16.7), box(59.8, 27.5, 70.8, 35.3), box(14.5, 27.65, 15.45, 34.2), box(14.5, 16.1, 28.4, 16.7), box(100.7, 6.1, 101.9, 12.1), box(74.85, 0, 77.95, 5.7), box(28.65, 0, 33.8, 5.9) },
	endWalls = { box(104, 6.2, 104, 13.2) },
	lights = { v(6, 8), v(20, 8), v(60, 8), v(76, 8), v(92, 8), v(10, 18), v(10, 30), v(22, 36.6), v(31, 24), v(54, 24), v(42.6, 36), v(38, 30), v(47.5, 30), v(69.5, 18), v(71, 30), v(64, 36.6), v(80, 36.6), v(80, 22), v(95, 22), v(39.5, 41.7), v(48.2, 41.7) },
	patrol = { v(10, 8), v(26, 8), v(40, 24), v(60, 8), v(69.5, 8), v(71, 24), v(88, 36.6), v(42.6, 37), v(20, 36.6), v(9.9, 24.23) },
}
local FIRST: Floor = {
	origin = v(20.3, 21.9),
	scale = 0.8 * WORLD_SCALE,
	core = box(0, 0, 40.6, 43.8), -- the main block; rooms may reach past it
	rect = box(0, 0, 40.6, 43.8),
	rooms = {
		room("109", 0, 0, 7.55, 8.65, "E6.4", "normal"),
		room("Tanári", 12.45, 34.95, 27.85, 43.8, "W35.8", "office"),
		room("GT10", 0, 34.95, 7.55, 43.8, "E37", "computer"),
		room("125", 33, 0, 40.6, 8.6, "W6.7", "normal"),
		room("WC", 27.45, 0, 33, 4.6, "S", "wc"),
		room("129", 33.3, 17.9, 40.6, 25.9, "W19.4", "normal"),
		room("133", 33.3, 35.1, 40.6, 43.8, "W36.3", "normal"),
		room("113", 13.1, 0, 20.3, 8.2, "W6.5 E6.7", "normal"),
		room("121", 20.3, 0, 27.45, 8.2, "E6.8 w6.7", "normal"),
		room("114", 13, 17.95, 20.3, 26.15, "W19.3 E21.5", "normal"),
		room("120", 20.3, 17.95, 27.6, 26.15, "E18.9 w21.5", "normal"),
		room("WC", 7.55, 0, 13.1, 4.6, "S", "wc"),
		room("WC", 7.55, 39, 12.45, 43, "N11.4", "wc"),
		room("WC", 27.85, 39.3, 33.3, 43, "N32.3", "wc"),
		room("105/b", 0, 17.7, 7.55, 22.05, "E18.5", "office"),
		room("105/a", 0, 22.05, 7.55, 25.9, "E22.9", "office"),
		room("", 4.9, 8.65, 7.55, 11.95, "", "storage"),
		room("", 4.9, 11.95, 7.55, 14.8, "", "storage"),
		room("", 4.9, 14.8, 7.55, 17.7, "", "storage"),
		room("", 4.8, 25.9, 7.55, 28.6, "", "storage"),
		room("", 4.8, 28.6, 7.55, 31.7, "", "storage"),
		room("", 4.8, 31.7, 7.55, 34.95, "", "storage"),
		room("", 33.3, 32, 36, 35.1, "", "storage"),
		room("", 33.3, 28.9, 36, 32, "", "storage"),
		room("", 33.3, 25.9, 36, 28.9, "", "storage"),
		room("", 33.3, 14.9, 35.9, 17.9, "", "storage"),
		room("", 33.3, 11.9, 35.9, 14.9, "", "storage"),
		room("", 33.3, 8.6, 35.9, 11.9, "", "storage"),
		room("", 0, 8.65, 4.9, 17.7, "", "other"),
		room("", 35.9, 8.6, 40.6, 17.9, "", "other"),
		room("", 0, 25.9, 4.8, 34.95, "", "other"),
		room("", 36, 25.9, 40.6, 35.1, "", "other"),
		room("", 7.55, 43, 12.45, 43.8, "", "other"),
		room("", 27.85, 43, 33.3, 43.8, "", "other"),
	},
	solids = { box(12.9, 8.2, 27.7, 17.95), box(12.9, 26.15, 27.7, 34.95) },
	endWalls = { box(20.3, 17.9, 20.3, 20.5), box(20.3, 22.5, 20.3, 26.1) },
	lights = { v(9.4, 7), v(9.4, 16), v(9.4, 30), v(9.4, 38), v(31.2, 7), v(31.2, 16), v(31.2, 30), v(31.2, 38), v(20.3, 21.5) },
	patrol = { v(9.4, 8), v(27.8, 21.5), v(31.2, 8), v(31.2, 36), v(9.4, 36) },
}
local SECOND: Floor = {
	origin = v(20.3, 21.9),
	scale = 0.8 * WORLD_SCALE,
	core = box(0, 0, 40.6, 43.8), -- the main block; rooms may reach past it
	rect = box(0, 0, 40.6, 43.8),
	rooms = {
		room("GT9", 0, 0, 7.55, 8.55, "E6.4", "computer"),
		room("205", 0, 18, 7.55, 26.15, "E24", "normal"),
		room("WC", 7.6, 38.7, 12.9, 42.55, "E39.8", "wc"),
		room("GT5", 12.9, 17.9, 20.4, 26.1, "E19.3", "computer"),
		room("225", 33.05, 0, 40.6, 9, "W7", "normal"),
		room("229", 33.05, 18.05, 40.6, 26.2, "W19.4", "normal"),
		room("233", 33.3, 35, 40.6, 43.8, "W36.3", "normal"),
		room("GT7", 12.8, 0, 20.3, 8.2, "W6.5 E6.7", "computer"),
		room("GT8", 20.3, 0, 27.85, 8.2, "E6.8 w6.7", "computer"),
		room("GT6", 20.4, 17.9, 27.6, 26.1, "w19.3 E21.5", "computer"),
		room("Tanári", 12.9, 35.05, 20.1, 43.8, "E38.7 w39.8", "office"),
		room("WC", 27.85, 0, 33.05, 4.6, "S", "wc"),
		room("WC", 7.55, 0, 12.8, 4.6, "S", "wc"),
		room("WC", 27.9, 38.6, 33.3, 42.4, "N32.2", "wc"),
		room("Tárgyaló", 20.1, 35.05, 27.9, 43.8, "E36.1 w38.7", "office"),
		room("201", 0, 35, 7.6, 39.05, "E35.8 s3.8", "office"),
		room("Igazgatói Iroda", 0, 39.05, 7.6, 43.8, "N3.8", "office"),
		room("", 4.6, 8.55, 7.55, 11.95, "", "storage"),
		room("", 4.6, 11.95, 7.55, 15.05, "", "storage"),
		room("", 4.6, 15.05, 7.55, 18, "", "storage"),
		room("", 4.7, 26.15, 7.55, 29.2, "", "storage"),
		room("", 4.7, 29.2, 7.55, 31.95, "", "storage"),
		room("", 4.7, 31.95, 7.55, 35, "", "storage"),
		room("", 33.3, 9, 36.2, 12.05, "", "storage"),
		room("", 33.3, 12.05, 36.2, 15.05, "", "storage"),
		room("", 33.3, 15.05, 36.2, 18.05, "", "storage"),
		room("", 33.3, 26.2, 36, 29.35, "", "storage"),
		room("", 33.3, 29.35, 36, 32, "", "storage"),
		room("", 33.3, 32, 36, 35, "", "storage"),
		room("", 0, 8.55, 4.6, 18, "", "other"),
		room("", 36.2, 9, 40.6, 12.05, "", "other"),
		room("", 36.2, 12.05, 40.6, 15.05, "", "other"),
		room("", 36.2, 15.05, 40.6, 18.05, "", "other"),
		room("", 0, 26.15, 4.7, 35, "", "other"),
		room("", 36, 26.2, 40.6, 35, "", "other"),
		room("", 27.9, 42.4, 33.3, 43.8, "", "other"),
		room("", 7.6, 42.55, 12.9, 43.8, "", "other"),
	},
	solids = { box(12.9, 8.2, 27.8, 17.9), box(12.9, 26.1, 27.7, 35.05) },
	endWalls = {  },
	lights = { v(9.4, 7), v(9.4, 16), v(9.4, 30), v(9.4, 38), v(31.2, 7), v(31.2, 16), v(31.2, 30), v(31.2, 38), v(20.3, 21.5) },
	patrol = { v(9.4, 8), v(27.8, 21.5), v(31.2, 8), v(31.2, 36), v(9.4, 36) },
}

-- Stairwells in world metres (x east, z south), the same on every floor.
local STAIRS: { Rect } = {
	{ x0 = -10.9, z0 = -12.9, x1 = -8.7, z1 = -5 },
	{ x0 = -10.9, z0 = 5.7, x1 = -8.7, z1 = 13.6 },
	{ x0 = 10.8, z0 = 5.7, x1 = 13, z1 = 13.6 },
	{ x0 = 10.8, z0 = -12.9, x1 = 13, z1 = -5 },
}
-- END GENERATED MAP

local FloorData = {}

FloorData.WORLD_SCALE = WORLD_SCALE
FloorData.FLOORS = { GROUND, FIRST, SECOND } :: { Floor }
FloorData.STAIRS = STAIRS
FloorData.FLOOR_NAMES = { "ground floor", "1st floor", "2nd floor" }

-- Lockers stand against corridor walls between classroom doors (main._place_lockers): plan units, yaw in radians
-- (PI/2 faces east, -PI/2 west, 0 south, PI north).
local PI = math.pi
FloorData.LOCKERS = {
	{ floor = 0, x = 9.0, y = 20.4, yaw = PI * 0.5 },
	{ floor = 0, x = 9.0, y = 26.4, yaw = PI * 0.5 },
	{ floor = 0, x = 12.2, y = 6.7, yaw = 0.0 }, -- between the doors of GT11-12 (10.8) and 19 (13.9)
	{ floor = 0, x = 22.0, y = 8.7, yaw = PI }, -- against the courtyard (starts at 9.1)
	{ floor = 0, x = 70.5, y = 15.5, yaw = -PI * 0.5 },
	{ floor = 0, x = 71.25, y = 31.0, yaw = PI * 0.5 }, -- against the courtyard (ends at 70.8)
	-- Upper floors: Godot has y 14.0 (in front of the door at 14.0) and 24.5 on the west side (half across the door
	-- at 24.0 of Tanári / 205); moved into the free wall between the doors.
	{ floor = 1, x = 8.0, y = 15.25, yaw = PI * 0.5 },
	{ floor = 1, x = 8.0, y = 25.7, yaw = PI * 0.5 },
	{ floor = 1, x = 32.6, y = 21.9, yaw = -PI * 0.5 }, -- the east stairs fill 9-17 and 27.6-35.5
	{ floor = 1, x = 32.6, y = 24.5, yaw = -PI * 0.5 },
	{ floor = 2, x = 8.0, y = 15.25, yaw = PI * 0.5 },
	{ floor = 2, x = 8.0, y = 25.7, yaw = PI * 0.5 },
	{ floor = 2, x = 32.6, y = 21.9, yaw = -PI * 0.5 },
	{ floor = 2, x = 32.6, y = 24.5, yaw = -PI * 0.5 },
}

local function floorOf(index: number): Floor
	return FloorData.FLOORS[index + 1]
end

-- World metres (x, z) of a plan point on a floor.
function FloorData.toWorld(floor: number, px: number, py: number): (number, number)
	local data = floorOf(floor)
	return (px - data.origin.x) * data.scale, (py - data.origin.y) * data.scale
end

local function worldRect(floor: number, r: Room): Rect
	local ax, az = FloorData.toWorld(floor, r.x0, r.y0)
	local bx, bz = FloorData.toWorld(floor, r.x1, r.y1)
	return { x0 = math.min(ax, bx), z0 = math.min(az, bz), x1 = math.max(ax, bx), z1 = math.max(az, bz) }
end

-- World rectangle of the first room with this label on a floor, nil when there is none.
function FloorData.roomRect(floor: number, label: string): Rect?
	for _, r in floorOf(floor).rooms do
		if r.label == label then
			return worldRect(floor, r)
		end
	end
	return nil
end

-- Label of the room containing a world point, "Corridor" when none does. Unnamed rooms count as the corridor.
-- Like Godot's Rect2.has_point: the start edge is inside, the end edge is not.
function FloorData.roomLabelAt(floor: number, x: number, z: number): string
	for _, r in floorOf(floor).rooms do
		if r.label ~= "" then
			local w = worldRect(floor, r)
			if x >= w.x0 and x < w.x1 and z >= w.z0 and z < w.z1 then
				return r.label
			end
		end
	end
	return "Corridor"
end

-- The room log entry for a point: "WC (1st floor)".
function FloorData.logLabel(floor: number, x: number, z: number): string
	return `{FloorData.roomLabelAt(floor, x, z)} ({FloorData.FLOOR_NAMES[floor + 1]})`
end

-- Floor index of a height in metres (floors are 4 m apart).
function FloorData.floorAt(y: number): number
	return math.clamp(math.round(y / 4.0), 0, #FloorData.FLOORS - 1)
end

return FloorData
