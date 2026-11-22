-- Turns the map editor's school-map.json into the game's map: the generated blocks of src/shared/FloorData.luau
-- (rooms, solids, stairs, lights, patrol) and src/shared/Rooms.luau (what each room is, its real name).
-- Run from ROBLOX-GAME/: `lune run tools/map-editor/import-map` (reads tools/map-editor/school-map.json).
-- Prints warnings for things to fix in the editor; it never edits the map file.
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local MAP = "tools/map-editor/school-map.json"
local FLOOR_FILE = "src/shared/FloorData.luau"
local ROOMS_FILE = "src/shared/Rooms.luau"
local BEGIN = "-- BEGIN GENERATED MAP"
local FINISH = "-- END GENERATED MAP"

-- Plan origin of each floor (the plan point at world 0, 0) and metres per plan unit: unchanged from the hand map,
-- so the floors stay stacked as before.
local ORIGIN = { { 42.6, 21.9 }, { 20.3, 21.9 }, { 20.3, 21.9 } }
local SCALE = 1.0 -- 0.8 * WORLD_SCALE 1.25

-- Editor types -> game room kinds ("other" = closed in the game).
local KIND = {
	classroom = "normal", it = "computer", lab = "lab", office = "office", library = "library", wc = "wc",
	gym = "gym", changing = "changing", entrance = "entrance", dining = "dining", kitchen = "kitchen",
	storage = "storage", medical = "medical", corridor = "corridor", closed = "other",
}

local map = serde.decode("json", fs.readFile(MAP))
local warnings = {}
local function warn(text: string)
	table.insert(warnings, text)
end

local function r1(v: number): string
	local s = string.format("%.2f", v)
	s = string.gsub(s, "0+$", "")
	s = string.gsub(s, "%.$", "")
	if s == "-0" then
		s = "0"
	end
	return s
end

local function q(s: string): string
	return string.format("%q", s)
end

-- "201 - Iskolatitkár" -> label "201", real name "Iskolatitkár" (a code before " - ").
local function splitLabel(label: string, real: string): (string, string)
	local code, rest = string.match(label, "^(%S+)%s+%-%s+(.+)$")
	if code and (string.match(code, "%d") or string.match(code, "^GT")) then
		label = code
		if real == "" or real == label .. " - " .. rest or string.match(real, "^%S+%s+%-") then
			real = rest
		end
	end
	local realCode, realRest = string.match(real, "^(%S+)%s+%-%s+(.+)$")
	if realCode == label and realRest then
		real = realRest
	end
	return label, real
end

local function inside(px: number, py: number, b): boolean
	return px > b.x0 and px < b.x1 and py > b.y0 and py < b.y1
end

-- Stairs: the ground floor's stair rooms decide every stairwell (a staircase has to line up on all floors).
local groundStairs = {}
for _, r in map.floors[1].rooms do
	if r.type == "stairs" then
		table.insert(groundStairs, r)
	end
end
if #groundStairs == 0 then
	error("no stairs drawn on the ground floor")
end
local stairsWorld = {}
for _, s in groundStairs do
	table.insert(stairsWorld, {
		x0 = (math.min(s.x0, s.x1) - ORIGIN[1][1]) * SCALE, z0 = (math.min(s.y0, s.y1) - ORIGIN[1][2]) * SCALE,
		x1 = (math.max(s.x0, s.x1) - ORIGIN[1][1]) * SCALE, z1 = (math.max(s.y0, s.y1) - ORIGIN[1][2]) * SCALE,
	})
end
-- Tell where the upper floors' own stairs are off from the ground floor's.
for fi = 2, #map.floors do
	for _, s in map.floors[fi].rooms do
		if s.type == "stairs" then
			local cx = ((s.x0 + s.x1) / 2 - ORIGIN[fi][1]) * SCALE
			local cz = ((s.y0 + s.y1) / 2 - ORIGIN[fi][2]) * SCALE
			local best = math.huge
			for _, w in stairsWorld do
				best = math.min(best, math.sqrt(((w.x0 + w.x1) / 2 - cx) ^ 2 + ((w.z0 + w.z1) / 2 - cz) ^ 2))
			end
			if best > 0.5 then
				warn(string.format("%s: stairs drawn %.1f m away from the ground floor's; the game uses the ground floor's.",
					map.floors[fi].name, best))
			end
		end
	end
end

local DoorRules = require("./door-rules")
local norm = DoorRules.norm

for _, f in map.floors do
	DoorRules.fix(f, warn)
end

local kinds = {} -- label -> kind (an open kind wins over "other" when a label repeats)
local realNames = {} -- label -> real name
local out = { BEGIN .. " (tools/map-editor/import-map.luau from school-map.json: edit the map, not this block)" }
local floorNames = {}

for fi, f in map.floors do
	local rooms, solids = {}, {}
	local core = f.rect
	local bx0, by0, bx1, by1 = core.x0, core.y0, core.x1, core.y1
	for _, r in f.rooms do
		local x0, x1 = math.min(r.x0, r.x1), math.max(r.x0, r.x1)
		local y0, y1 = math.min(r.y0, r.y1), math.max(r.y0, r.y1)
		if r.type == "stairs" then
			continue
		end
		local label, real = splitLabel(r.label or "", r.realName or "")
		local kind = KIND[r.type] or "other"
		if label ~= "" then
			if not kinds[label] or kinds[label] == "other" then
				kinds[label] = kind
			end
			if real ~= "" and real ~= label then
				realNames[label] = real
			end
		end
		if (r.doors or "") == "" and kind ~= "other" and kind ~= "storage" and kind ~= "corridor" then
			warn(`{f.name}: room {if label ~= "" then label else "(no code)"} has no door; you cannot get in.`)
		end
		bx0, by0, bx1, by1 = math.min(bx0, x0), math.min(by0, y0), math.max(bx1, x1), math.max(by1, y1)
		table.insert(rooms, string.format("\t\troom(%s, %s, %s, %s, %s, %s, %s),", q(label), r1(x0), r1(y0), r1(x1), r1(y1),
			q(r.doors or ""), q(kind)))
	end
	for _, b in f.solids do
		local x0, x1 = math.min(b.x0, b.x1), math.max(b.x0, b.x1)
		local y0, y1 = math.min(b.y0, b.y1), math.max(b.y0, b.y1)
		bx0, by0, bx1, by1 = math.min(bx0, x0), math.min(by0, y0), math.max(bx1, x1), math.max(by1, y1)
		table.insert(solids, string.format("box(%s, %s, %s, %s)", r1(x0), r1(y0), r1(x1), r1(y1)))
	end
	local function inRoom(x: number, y: number, margin: number): boolean
		for _, r in f.rooms do
			local b = norm(r)
			if r.type ~= "stairs" and x > b.x0 - margin and x < b.x1 + margin and y > b.y0 - margin and y < b.y1 + margin then
				return true
			end
		end
		return false
	end
	-- Lights and patrol points must not sit inside a solid block; patrol points stay out of rooms (corridors only).
	local isPatrol = false
	local function free(p): boolean
		if isPatrol and inRoom(p.x, p.y, 0.15) then
			return false
		end
		for _, b in f.solids do
			if inside(p.x, p.y, { x0 = math.min(b.x0, b.x1), y0 = math.min(b.y0, b.y1), x1 = math.max(b.x0, b.x1),
				y1 = math.max(b.y0, b.y1) }) then
				return false
			end
		end
		return true
	end
	-- A point that landed in a room or courtyard after the map changed moves to the nearest free spot within 12 m
	-- (rings of 0.25 m); only when there is none it is left out.
	local function nearestFree(p): { x: number, y: number }?
		if free(p) then
			return p
		end
		for ring = 1, 48 do
			local r = ring * 0.25
			for k = 0, 31 do
				local a = k / 32 * math.pi * 2
				local q = { x = p.x + math.cos(a) * r, y = p.y + math.sin(a) * r }
				if q.x > bx0 and q.x < bx1 and q.y > by0 and q.y < by1 and free(q) then
					return q
				end
			end
		end
		return nil
	end
	local function points(list, what: string): string
		isPatrol = what == "patrol"
		local kept = {}
		for _, p in list do
			local q = nearestFree(p)
			local line = q and string.format("v(%s, %s)", r1(q.x), r1(q.y))
			if line and table.find(kept, line) then
				continue -- two old points moved to the same spot
			elseif line then
				table.insert(kept, line)
			else
				warn(string.format("%s: %s point at %.1f, %.1f is inside a courtyard or room; left out.", f.name, what, p.x, p.y))
			end
		end
		return table.concat(kept, ", ")
	end
	local endWalls = {}
	for _, b in f.endWalls or {} do
		if inRoom((b.x0 + b.x1) / 2, (b.y0 + b.y1) / 2, 0) then
			continue -- an old corridor end that a room now covers: nothing left to close off
		end
		table.insert(endWalls, string.format("box(%s, %s, %s, %s)", r1(b.x0), r1(b.y0), r1(b.x1), r1(b.y1)))
	end
	local name = ({ "GROUND", "FIRST", "SECOND" })[fi]
	table.insert(floorNames, name)
	table.insert(out, `local {name}: Floor = \{`)
	table.insert(out, string.format("\torigin = v(%s, %s),", r1(ORIGIN[fi][1]), r1(ORIGIN[fi][2])))
	table.insert(out, "\tscale = 0.8 * WORLD_SCALE,")
	table.insert(out, string.format("\tcore = box(%s, %s, %s, %s), -- the main block; rooms may reach past it",
		r1(core.x0), r1(core.y0), r1(core.x1), r1(core.y1)))
	table.insert(out, string.format("\trect = box(%s, %s, %s, %s),", r1(bx0), r1(by0), r1(bx1), r1(by1)))
	table.insert(out, "\trooms = {")
	for _, line in rooms do
		table.insert(out, line)
	end
	table.insert(out, "\t},")
	table.insert(out, "\tsolids = { " .. table.concat(solids, ", ") .. " },")
	table.insert(out, "\tendWalls = { " .. table.concat(endWalls, ", ") .. " },")
	table.insert(out, "\tlights = { " .. points(f.lights, "light") .. " },")
	table.insert(out, "\tpatrol = { " .. points(f.patrol, "patrol") .. " },")
	table.insert(out, "}")
end
table.insert(out, "")
table.insert(out, "-- Stairwells in world metres (x east, z south), the same on every floor.")
table.insert(out, "local STAIRS: { Rect } = {")
for _, s in stairsWorld do
	table.insert(out, string.format("\t{ x0 = %s, z0 = %s, x1 = %s, z1 = %s },", r1(s.x0), r1(s.z0), r1(s.x1), r1(s.z1)))
end
table.insert(out, "}")
table.insert(out, FINISH)

local function replaceBlock(path: string, block: string)
	local text = fs.readFile(path)
	local a = string.find(text, BEGIN, 1, true)
	local b = string.find(text, FINISH, 1, true)
	if not a or not b then
		error(`{path} has no generated-map markers`)
	end
	local tail = string.sub(text, b + #FINISH)
	fs.writeFile(path, string.sub(text, 1, a - 1) .. block .. tail)
end

replaceBlock(FLOOR_FILE, table.concat(out, "\n"))

-- Rooms.luau: kinds and real names.
local labels = {}
for label in kinds do
	table.insert(labels, label)
end
table.sort(labels)
local rk = { BEGIN .. " (tools/map-editor/import-map.luau from school-map.json: edit the map, not this block)",
	"local KIND: { [string]: Kind } = {" }
for _, label in labels do
	table.insert(rk, string.format("\t[%s] = %s,", q(label), q(kinds[label])))
end
table.insert(rk, "}")
table.insert(rk, "local REAL: { [string]: string } = {")
for _, label in labels do
	if realNames[label] then
		table.insert(rk, string.format("\t[%s] = %s,", q(label), q(realNames[label])))
	end
end
table.insert(rk, "}")
table.insert(rk, FINISH)
replaceBlock(ROOMS_FILE, table.concat(rk, "\n"))

print(`imported {#map.floors} floors, {#labels} room codes, {#stairsWorld} stairwells`)
for _, w in warnings do
	print("warning: " .. w)
end
