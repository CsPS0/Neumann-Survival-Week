--!nocheck
-- Tidies the hand-drawn map in school-map.json so the school is one connected building:
--   * neighbouring rooms that almost touch (a gap up to 0.4 m, an overlap up to 1 m) get one shared wall;
--   * room edges that almost line up along a corridor (within 0.3 m) become one straight wall;
--   * rooms that almost reach the building's outline (within 0.4 m) are pulled onto it;
--   * the upper floors' stairwells sit exactly over the ground floor's (the game builds them from the ground floor);
--   * named rooms you can enter but drew without a door get one, and every door is moved to open onto free floor
--     (door-rules.luau, the same rules as the import).
-- Run from ROBLOX-GAME/: `lune run tools/map-editor/tidy-map`. The first run keeps the untouched map as
-- school-map.before-tidy.json. Every change is printed. Then run import-map as usual.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local DoorRules = require("./door-rules")

local MAP = "tools/map-editor/school-map.json"
local BACKUP = "tools/map-editor/school-map.before-tidy.json"
local ORIGIN = { { 42.6, 21.9 }, { 20.3, 21.9 }, { 20.3, 21.9 } } -- as in import-map.luau
local GAP = 0.4 -- gaps up to this between neighbours are closed (wider ones may be meant)
local OVERLAP = 1.0 -- overlaps up to this become a shared wall (rooms never overlap)
local LINE = 0.3 -- edges this close in line along a corridor become one wall
local STEP = 0.05 -- coordinates are rounded to this
local OPEN = { classroom = true, it = true, lab = true, office = true, library = true, wc = true, gym = true,
	changing = true, entrance = true, dining = true, kitchen = true, medical = true }

local text = fs.readFile(MAP)
local map = serde.decode("json", text)
if not fs.isFile(BACKUP) then
	fs.writeFile(BACKUP, text)
	print("kept the untouched map as " .. BACKUP)
end

local changes = {}
local function note(s: string)
	table.insert(changes, s)
end
local function round(v: number): number
	return math.round(v / STEP) * STEP
end
local function nameOf(b): string
	if b.kind == "solid" then
		return "a courtyard"
	elseif b.kind == "stairs" then
		return "the stairs"
	end
	local label = b.src.label or ""
	return if label ~= "" then label else `an unnamed {b.src.type}`
end
local function overlap(a0: number, a1: number, b0: number, b1: number): number
	return math.min(a1, b1) - math.max(a0, b0)
end

for fi, f in map.floors do
	local boxes = {}
	local function add(src, kind: string, fixed: boolean)
		src.x0, src.x1 = math.min(src.x0, src.x1), math.max(src.x0, src.x1)
		src.y0, src.y1 = math.min(src.y0, src.y1), math.max(src.y0, src.y1)
		table.insert(boxes, { src = src, kind = kind, fixed = fixed })
	end

	-- Stairs: the ground floor's are the real ones; upper floors get exact copies over them.
	local ground = {}
	for _, r in map.floors[1].rooms do
		if r.type == "stairs" then
			table.insert(ground, r)
		end
	end
	for _, r in f.rooms do
		if r.type == "stairs" and fi > 1 then
			local dx = ORIGIN[fi][1] - ORIGIN[1][1]
			local dy = ORIGIN[fi][2] - ORIGIN[1][2]
			local best, bestD = nil, math.huge
			for _, g in ground do
				local d = math.abs((g.x0 + g.x1) / 2 + dx - (r.x0 + r.x1) / 2) + math.abs((g.y0 + g.y1) / 2 + dy - (r.y0 + r.y1) / 2)
				if d < bestD then
					best, bestD = g, d
				end
			end
			if best and bestD > 0.01 then
				note(string.format("%s: stairs moved %.1f m to sit over the ground floor's.", f.name, bestD))
				r.x0, r.x1 = round(math.min(best.x0, best.x1) + dx), round(math.max(best.x0, best.x1) + dx)
				r.y0, r.y1 = round(math.min(best.y0, best.y1) + dy), round(math.max(best.y0, best.y1) + dy)
			end
		end
		add(r, if r.type == "stairs" then "stairs" else "room", r.type == "stairs")
	end
	for _, b in f.solids do
		add(b, "solid", false)
	end
	local core = f.rect

	local function set(b, edge: string, value: number, why: string)
		if b.fixed or math.abs(b.src[edge] - value) < 0.001 then
			return
		end
		if math.abs(b.src[edge] - value) >= 0.05 then
			note(string.format("%s: %s's %s edge %.2f -> %.2f (%s)", f.name, nameOf(b), edge, b.src[edge], value, why))
		end
		b.src[edge] = value
	end

	-- An edge that already is a shared wall with a facing neighbour stays where it is when lining up walls.
	local function locked(b, edge: string): boolean
		local axis = string.sub(edge, 1, 1)
		local other = if axis == "x" then "y" else "x"
		local facing = axis .. (if string.sub(edge, 2, 2) == "0" then "1" else "0")
		for _, c in boxes do
			if c ~= b and math.abs(c.src[facing] - b.src[edge]) < 0.001
				and overlap(b.src[other .. "0"], b.src[other .. "1"], c.src[other .. "0"], c.src[other .. "1"]) > 0.3 then
				return true
			end
		end
		return false
	end

	local function settle()
		for _ = 1, 8 do
			-- 1. Edges that almost line up along a corridor become one straight wall: chains of rooms stacked next to
			-- each other (at most 0.6 m apart the other way, edges within 0.3 m) get one value: a shared wall's or a
			-- stairwell's if the chain has one, else the longest wall's.
			for _, axis in { "x", "y" } do
				local other = if axis == "x" then "y" else "x"
				for _, edge in { axis .. "0", axis .. "1" } do
					local parent = {}
					local function find(i: number): number
						while parent[i] and parent[i] ~= i do
							i = parent[i]
						end
						return i
					end
					for i, a in boxes do
						parent[i] = i
					end
					for i, a in boxes do
						for j, b in boxes do
							if i < j and a.kind ~= "solid" and b.kind ~= "solid" then
								local d = math.abs(a.src[edge] - b.src[edge])
								local apart = -overlap(a.src[other .. "0"], a.src[other .. "1"], b.src[other .. "0"],
									b.src[other .. "1"])
								if d <= LINE and apart <= 0.6 then
									parent[find(i)] = find(j)
								end
							end
						end
					end
					local groups = {}
					for i in boxes do
						local r = find(i)
						groups[r] = groups[r] or {}
						table.insert(groups[r], i)
					end
					for _, members in groups do
						if #members > 1 then
							local keep, keepRank = nil, -math.huge
							for _, i in members do
								local b = boxes[i]
								local len = b.src[other .. "1"] - b.src[other .. "0"]
								local rank = (if b.fixed then 2000 elseif locked(b, edge) then 1000 else 0) + len
								if rank > keepRank then
									keep, keepRank = b, rank
								end
							end
							for _, i in members do
								local b = boxes[i]
								if b ~= keep and not locked(b, edge) then
									set(b, edge, keep.src[edge], "in line with " .. nameOf(keep))
								end
							end
						end
					end
				end
			end
			-- 2. Neighbours with a small gap or overlap get one shared wall.
			for i, a in boxes do
				for j, b in boxes do
					if i ~= j then
						for _, axis in { "x", "y" } do
							local other = if axis == "x" then "y" else "x"
							if overlap(a.src[other .. "0"], a.src[other .. "1"], b.src[other .. "0"], b.src[other .. "1"]) > 0.3 then
								local hi, lo = axis .. "1", axis .. "0"
								local d = b.src[lo] - a.src[hi] -- a's far wall to b's near wall: + gap, - overlap
								if math.abs(d) > 0.001 and (d <= GAP and d >= -OVERLAP) and not (a.fixed and b.fixed) then
									local v = if a.fixed then a.src[hi] elseif b.fixed then b.src[lo]
										else round((a.src[hi] + b.src[lo]) / 2)
									local why = if d > 0 then string.format("%.2f m gap", d) else string.format("%.2f m overlap", -d)
									set(a, hi, v, why .. " with " .. nameOf(b))
									set(b, lo, v, why .. " with " .. nameOf(a))
								end
							end
						end
					end
				end
			end
			-- 3. Rooms that almost reach the building's outline are pulled onto it.
			for _, b in boxes do
				for _, edge in { "x0", "x1", "y0", "y1" } do
					local d = math.abs(b.src[edge] - core[edge])
					if d > 0.001 and d <= GAP then
						set(b, edge, core[edge], "the building's outline")
					end
				end
			end
		end
		for _, b in boxes do
			for _, edge in { "x0", "x1", "y0", "y1" } do
				b.src[edge] = round(b.src[edge])
			end
		end
	end
	settle()

	-- Sealed empty floor (space between rooms the map leaves undrawn, with no way in) becomes a closed room, so
	-- nobody walks or spawns into it and no door opens onto it. Odd-shaped pockets are only reported.
	local grid = DoorRules.grid(f)
	local seen = {}
	for k = 0, grid.ny - 1 do
		for i = 0, grid.nx - 1 do
			local id = grid.key(i, k)
			if grid.free[id] and not grid.main[id] and not seen[id] then
				local cells, queue, head = 0, { { i, k } }, 1
				local members = {}
				seen[id] = true
				while head <= #queue do
					local a, b = queue[head][1], queue[head][2]
					head += 1
					cells += 1
					members[grid.key(a, b)] = true
					for _, n in { { a + 1, b }, { a - 1, b }, { a, b + 1 }, { a, b - 1 } } do
						local nid = grid.key(n[1], n[2])
						if n[1] >= 0 and n[1] < grid.nx and n[2] >= 0 and n[2] < grid.ny and grid.free[nid]
							and not grid.main[nid] and not seen[nid] then
							seen[nid] = true
							table.insert(queue, n)
						end
					end
				end
				if cells * grid.cell * grid.cell >= 0.5 then
					-- Cover the pocket with rectangles: runs of cells per row, rows with the same run merged.
					local open = {} -- "i0:i1" -> rectangle still growing downwards
					local rects = {}
					for row = 0, grid.ny - 1 do
						local runs = {}
						local col = 0
						while col < grid.nx do
							if members[grid.key(col, row)] then
								local start = col
								while col + 1 < grid.nx and members[grid.key(col + 1, row)] do
									col += 1
								end
								runs[`{start}:{col}`] = { start, col }
							end
							col += 1
						end
						for runKey, rect in open do
							if not runs[runKey] then
								table.insert(rects, rect)
								open[runKey] = nil
							end
						end
						for runKey, run in runs do
							if open[runKey] then
								open[runKey].k1 = row
							else
								open[runKey] = { i0 = run[1], i1 = run[2], k0 = row, k1 = row }
							end
						end
					end
					for _, rect in open do
						table.insert(rects, rect)
					end
					for _, rc in rects do
						local bx0, by0 = round(grid.x0 + rc.i0 * grid.cell), round(grid.y0 + rc.k0 * grid.cell)
						local bx1, by1 = round(grid.x0 + (rc.i1 + 1) * grid.cell), round(grid.y0 + (rc.k1 + 1) * grid.cell)
						if (bx1 - bx0) * (by1 - by0) >= 0.2 then
							local room = { label = "", realName = "", type = "closed", doors = "", notes =
								"Added by tidy-map: empty space with no way in.", x0 = bx0, y0 = by0, x1 = bx1, y1 = by1 }
							table.insert(f.rooms, room)
							add(room, "room", false)
							note(string.format("%s: sealed empty space %.1f x %.1f m at %.1f, %.1f is now a closed room.",
								f.name, bx1 - bx0, by1 - by0, bx0, by0))
						end
					end
				end
			end
		end
	end

	settle() -- the closed rooms just added share walls with their neighbours too

	-- Rooms you can go into but that have no door get one (the door rules then move it onto free floor).
	for _, r in f.rooms do
		if OPEN[r.type] and (r.doors or "") == "" and (r.label or "") ~= "" then
			r.doors = "S"
			note(`{f.name}: {if (r.label or "") ~= "" then r.label else "an unnamed room"} had no door; one was added.`)
		end
	end
	DoorRules.fix(f, note)

	-- What is still wrong: overlaps between rooms bigger than a wall.
	for i, a in boxes do
		for j, b in boxes do
			if i < j and a.kind ~= "solid" and b.kind ~= "solid" then
				local ox = overlap(a.src.x0, a.src.x1, b.src.x0, b.src.x1)
				local oy = overlap(a.src.y0, a.src.y1, b.src.y0, b.src.y1)
				if ox > 0.05 and oy > 0.05 then
					note(string.format("%s: CHECK %s and %s overlap by %.1f x %.1f m.", f.name, nameOf(a), nameOf(b), ox, oy))
				end
			end
		end
	end
end

map.savedAt = os.date("!%Y-%m-%dT%H:%M:%SZ")
fs.writeFile(MAP, serde.encode("json", map, true))
for _, c in changes do
	print(c)
end
print(`{#changes} changes written to {MAP}`)
