--!nocheck
-- Door rules shared by import-map.luau and tidy-map.luau: every door opens onto free floor.
local DoorRules = {}

local function r1(v: number): string
	local s = string.format("%.2f", v)
	s = string.gsub(s, "0+$", "")
	s = string.gsub(s, "%.$", "")
	if s == "-0" then
		s = "0"
	end
	return s
end

local function inside(px: number, py: number, b): boolean
	return px > b.x0 and px < b.x1 and py > b.y0 and py < b.y1
end

-- Doors: a door must open onto free floor (a corridor or hall), not into another room's wall or outdoors. A door
-- placed past the end of its wall is pulled back onto it; a door that opens into a room is moved along its wall, or
-- to another wall, to the nearest spot that opens onto free floor. Two doors on the same spot of a shared wall become
-- one door (the second becomes an opening). Every change is reported.
local DOOR_W = 1.5 -- the opening the game cuts (Config.DOOR_WIDTH)
local END = DOOR_W / 2 + 0.05 -- a door's centre stays this far from the ends of its wall
function DoorRules.parse(text: string)
	local list = {}
	for token in string.gmatch(text or "", "%S+") do
		local side = string.sub(token, 1, 1)
		table.insert(list, { side = string.upper(side), panel = side == string.upper(side),
			pos = tonumber(string.sub(token, 2)) })
	end
	return list
end
function DoorRules.format(list): string
	local parts = {}
	for _, d in list do
		local side = if d.panel then d.side else string.lower(d.side)
		table.insert(parts, side .. (if d.pos then r1(d.pos) else ""))
	end
	return table.concat(parts, " ")
end
function DoorRules.norm(b)
	return { x0 = math.min(b.x0, b.x1), y0 = math.min(b.y0, b.y1), x1 = math.max(b.x0, b.x1), y1 = math.max(b.y0, b.y1) }
end

-- Free floor of a floor plan on a 0.2 m grid: inside the building, not in a room or courtyard. `main` marks the free
-- floor joined to a stairwell (the corridors people can reach); the rest are sealed pockets. Stairwells are rooms of
-- type "stairs" (the ground floor's are copied onto the upper floors by tidy-map).
local OPEN = { classroom = true, it = true, lab = true, office = true, library = true, wc = true, gym = true,
	changing = true, entrance = true, dining = true, kitchen = true, medical = true, storage = true, corridor = true }
local CELL = 0.2
-- A point on a room's wall line belongs to the room (two rooms sharing a wall leave no floor between them).
local function within(px: number, py: number, b): boolean
	return px >= b.x0 - 0.001 and px <= b.x1 + 0.001 and py >= b.y0 - 0.001 and py <= b.y1 + 0.001
end
function DoorRules.grid(f)
	local core = DoorRules.norm(f.rect)
	local x0, y0, x1, y1 = core.x0, core.y0, core.x1, core.y1
	for _, r in f.rooms do
		local b = DoorRules.norm(r)
		x0, y0, x1, y1 = math.min(x0, b.x0), math.min(y0, b.y0), math.max(x1, b.x1), math.max(y1, b.y1)
	end
	local nx, ny = math.ceil((x1 - x0) / CELL), math.ceil((y1 - y0) / CELL)
	local rooms, stairs, solids = {}, {}, {}
	for _, r in f.rooms do
		table.insert(if r.type == "stairs" then stairs else rooms, DoorRules.norm(r))
	end
	for _, b in f.solids do
		table.insert(solids, DoorRules.norm(b))
	end
	local freeCell, main = {}, {}
	local function key(i: number, k: number): number
		return k * nx + i
	end
	for k = 0, ny - 1 do
		for i = 0, nx - 1 do
			local x, y = x0 + (i + 0.5) * CELL, y0 + (k + 0.5) * CELL
			local ok = inside(x, y, core)
			for _, b in stairs do
				if inside(x, y, b) then
					ok = true
				end
			end
			if ok then
				for _, b in rooms do
					if within(x, y, b) then
						ok = false
						break
					end
				end
			end
			if ok then
				for _, b in solids do
					if within(x, y, b) then
						ok = false
						break
					end
				end
			end
			freeCell[key(i, k)] = ok or nil
		end
	end
	local queue = {}
	for k = 0, ny - 1 do
		for i = 0, nx - 1 do
			local x, y = x0 + (i + 0.5) * CELL, y0 + (k + 0.5) * CELL
			for _, b in stairs do
				if inside(x, y, b) and freeCell[key(i, k)] then
					main[key(i, k)] = true
					table.insert(queue, { i, k })
				end
			end
		end
	end
	local head = 1
	while head <= #queue do
		local i, k = queue[head][1], queue[head][2]
		head += 1
		for _, n in { { i + 1, k }, { i - 1, k }, { i, k + 1 }, { i, k - 1 } } do
			local a, b = n[1], n[2]
			if a >= 0 and a < nx and b >= 0 and b < ny and freeCell[key(a, b)] and not main[key(a, b)] then
				main[key(a, b)] = true
				table.insert(queue, n)
			end
		end
	end
	local g = { x0 = x0, y0 = y0, nx = nx, ny = ny, cell = CELL, free = freeCell, main = main, key = key }
	-- Is a point on free floor joined to the stairs?
	function g.reachable(x: number, y: number): boolean
		local i, k = math.floor((x - x0) / CELL), math.floor((y - y0) / CELL)
		return i >= 0 and i < nx and k >= 0 and k < ny and main[key(i, k)] == true
	end
	return g
end

function DoorRules.fix(f, warn: (string) -> ())
	local grid = DoorRules.grid(f)
	local rooms = {}
	for _, r in f.rooms do
		if r.type ~= "stairs" then
			table.insert(rooms, { src = r, box = DoorRules.norm(r) })
		end
	end
	local solids = {}
	for _, b in f.solids do
		table.insert(solids, DoorRules.norm(b))
	end
	local core = DoorRules.norm(f.rect)
	local function roomAt(x: number, y: number, except)
		for _, o in rooms do
			if o ~= except and inside(x, y, o.box) then
				return o
			end
		end
		return nil
	end
	local function blocked(x: number, y: number, except): boolean
		if not inside(x, y, core) and not roomAt(x, y, nil) then
			return true -- outdoors
		end
		for _, b in solids do
			if inside(x, y, b) then
				return true
			end
		end
		local other = roomAt(x, y, except)
		if other then
			return true
		end
		-- Free floor counts only when it is joined to the stairs (not a sealed pocket nobody reaches).
		return roomAt(x, y, nil) == nil and not grid.reachable(x, y)
	end
	-- The point just outside a door of `o` on `side` at `pos`, and the wall's extent.
	local function outsideAt(o, side: string, pos: number): (number, number)
		local b = o.box
		if side == "N" then
			return pos, b.y0 - 0.4
		elseif side == "S" then
			return pos, b.y1 + 0.4
		elseif side == "W" then
			return b.x0 - 0.4, pos
		end
		return b.x1 + 0.4, pos
	end
	local function extent(o, side: string): (number, number)
		local b = o.box
		if side == "N" or side == "S" then
			return b.x0, b.x1
		end
		return b.y0, b.y1
	end
	local function free(o, side: string, pos: number): boolean
		for _, off in { -DOOR_W / 2 - 0.15, 0, DOOR_W / 2 + 0.15 } do
			local x, y = outsideAt(o, side, pos + off)
			if blocked(x, y, o) then
				return false
			end
		end
		return true
	end
	local name = function(o)
		return if (o.src.label or "") ~= "" then o.src.label else "(no code)"
	end
	for _, o in rooms do
		local doors = DoorRules.parse(o.src.doors)
		local changed = false
		for _, d in doors do
			local lo, hi = extent(o, d.side)
			local pos = d.pos or (lo + hi) / 2
			if pos < lo + END - 0.01 or pos > hi - END + 0.01 then
				pos = math.clamp(pos, lo + END, math.max(lo + END, hi - END))
				d.pos = pos
				changed = true
				warn(`{f.name}: {name(o)}'s {d.side} door was past the end of its wall; pulled back onto it.`)
			end
			if not d.panel then
				continue -- an opening between two rooms is meant to join them
			end
			local x, y = outsideAt(o, d.side, pos)
			local other = roomAt(x, y, o)
			local merged = false
			if other then
				-- A door into a neighbour joins the two rooms only when the neighbour has a door or an opening on the
				-- facing wall at the same spot (the game cuts a gap in each room's own wall).
				local facing = ({ N = "S", S = "N", W = "E", E = "W" })[d.side]
				local list = DoorRules.parse(other.src.doors)
				local ea, eb = extent(other, facing)
				for _, od in list do
					if od.side ~= facing then
						continue -- a door on another wall of the neighbour is not this connection
					end
					local opos = od.pos or (ea + eb) / 2
					local news = true
					if math.abs(opos - pos) < 0.05 then
						news = od.panel -- already joined; only a second door panel on the spot is news
						od.panel = false -- the same spot: one door panel is enough
						merged = true
					elseif math.abs(opos - pos) < DOOR_W and pos >= ea + END and pos <= eb - END then
						od.pos, od.panel = pos, false -- nearly the same spot: line the neighbour's gap up with this door
						merged = true
					elseif not od.panel and opos >= lo + END and opos <= hi - END then
						pos, d.pos = opos, opos -- the neighbour's opening is meant to join us: put the door there
						changed = true
						merged = true
					end
					if merged then
						other.src.doors = DoorRules.format(list)
					end
					if merged and news then
						warn(string.format("%s: %s and %s joined by a door at %s %.1f.", f.name, name(o), name(other),
							d.side, pos))
					end
					if merged then
						break
					end
				end
			end
			if not merged and not free(o, d.side, pos) then
				-- Nearest free spot: this wall first, then the other walls.
				local best, bestCost = nil, math.huge
				for _, side in { "N", "S", "W", "E" } do
					local a, b = extent(o, side)
					local p = a + END
					while p <= b - END do
						if free(o, side, p) then
							local cost = math.abs(p - pos) + (if side == d.side then 0 else 100)
							if cost < bestCost then
								best, bestCost = { side = side, pos = p }, cost
							end
						end
						p += 0.1
					end
				end
				if best then
					warn(string.format("%s: %s's %s door opened into a wall; moved to %s %.1f.", f.name, name(o), d.side,
						best.side, best.pos))
					d.side = best.side
					d.pos = math.round(best.pos * 10) / 10
					changed = true
				else
					-- No wall reaches free floor (a kitchen behind the dining hall, the head's office behind the
					-- secretary's): open into a neighbouring room you can walk into, the middle of the shared wall.
					local pick, pickScore = nil, -math.huge
					for _, side in { "N", "S", "W", "E" } do
						local a, b = extent(o, side)
						local p = a + END
						while p <= b - END do
							local x, y = outsideAt(o, side, p)
							local n = roomAt(x, y, o)
							if n and OPEN[n.src.type] then
								local score = (if (n.src.doors or "") ~= "" then 100 else 0) - math.abs(p - (a + b) / 2)
								if score > pickScore then
									pick, pickScore = { side = side, pos = p, room = n }, score
								end
							end
							p += 0.1
						end
					end
					if pick then
						local n = pick.room
						local facingSide = ({ N = "S", S = "N", W = "E", E = "W" })[pick.side]
						local list = DoorRules.parse(n.src.doors)
						d.side, d.pos = pick.side, math.round(pick.pos * 10) / 10
						table.insert(list, { side = facingSide, panel = false, pos = d.pos })
						n.src.doors = DoorRules.format(list)
						changed = true
						warn(`{f.name}: {name(o)}'s door now opens into {name(n)} (no wall reaches a corridor).`)
					else
						warn(`{f.name}: {name(o)}'s {d.side} door opens into a wall and no free spot was found.`)
					end
				end
			end
		end
		-- Two doors of one wall closer than a door's width would overlap: keep one (a door panel over an opening).
		local kept = {}
		for _, d in doors do
			local lo, hi = extent(o, d.side)
			local pos = d.pos or (lo + hi) / 2
			local clash = nil
			for _, k in kept do
				local klo, khi = extent(o, k.side)
				if k.side == d.side and math.abs((k.pos or (klo + khi) / 2) - pos) < DOOR_W then
					clash = k
				end
			end
			if clash then
				clash.panel = clash.panel or d.panel
				changed = true
			else
				table.insert(kept, d)
			end
		end
		doors = kept
		if changed then
			o.src.doors = DoorRules.format(doors)
		end
	end
end

return DoorRules
