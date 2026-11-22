-- Dry run of SchoolBuilder outside Roblox: real Instances from @lune/roblox, stubbed services and Doors.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

-- Run from ROBLOX-GAME/: `lune run tools/school-dryrun`. Optional argument: a .rbxm path to save the school to.
local root = "."
local function load(path: string, env: { [string]: any })
	return luau.load(fs.readFile(root .. "/" .. path), { debugName = path, environment = env })()
end

local base = {
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	UDim2 = roblox.UDim2,
	Enum = roblox.Enum,
	Font = roblox.Font,
	TweenInfo = { new = function() return {} end },
}

local Config = load("src/shared/Config.luau", {})
local FloorData = load("src/shared/FloorData.luau", {})
local Rooms = load("src/shared/Rooms.luau", {})
local CampaignData = load("src/shared/CampaignData.luau", {})

local tags = 0
local doorsCreated, lockedDoors = 0, 0
local services = {
	CollectionService = { AddTag = function(_, _inst, _tag) tags += 1 end },
	ReplicatedStorage = { Shared = { Config = "Config", FloorData = "FloorData", Rooms = "Rooms",
		CampaignData = "CampaignData" } },
	TweenService = {},
}
local modules = { Config = Config, FloorData = FloorData, Rooms = Rooms, CampaignData = CampaignData }

-- Doors without events: builds the same panel geometry, counts doors.
local DoorsStub = {
	create = function(parent, hinge, width, height, sign, locked)
		doorsCreated += 1
		if locked then
			lockedDoors += 1
		end
		assert(sign == 1 or sign == -1, "swing sign")
		assert(width > 0 and height > 0, "door size")
		local model = roblox.Instance.new("Model")
		model:SetAttribute("Locked", locked)
		local panel = roblox.Instance.new("Part")
		panel.Size = roblox.Vector3.new(width, height, 0.18)
		panel.CFrame = hinge * roblox.CFrame.new(width / 2, height / 2, 0)
		panel.Parent = model
		model.Parent = parent
		return model
	end,
}
modules.Doors = DoorsStub

local env = table.clone(base)
env.game = { GetService = function(_, name) return services[name] end }
env.script = { Parent = { Doors = "Doors", Furniture = "Furniture" } }
env.require = function(key)
	return modules[key]
end
env.typeof = typeof
-- The real furniture module, with Seat available as an Instance class.
local furnitureEnv = table.clone(env)
modules.Furniture = load("src/server/Furniture.luau", furnitureEnv)

local SchoolBuilder = load("src/server/SchoolBuilder.luau", env)
local folder = roblox.Instance.new("Folder")
local school = SchoolBuilder.build(folder)

local parts, minY, maxY = 0, math.huge, -math.huge
local names = {}
for _, d in folder:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
		names[d.Name] = (names[d.Name] or 0) + 1
		local p = d.CFrame.Position
		minY, maxY = math.min(minY, p.Y), math.max(maxY, p.Y)
		assert(d.Size.X > 0 and d.Size.Y > 0 and d.Size.Z > 0, "non-positive size on " .. d.Name)
	end
end
print(`parts={parts} doors={doorsCreated} locked={lockedDoors} tags={tags} lamps={#school.lamps} lockers={#school.lockers} patrol={#school.patrol}`)
print(`y range {math.floor(minY)}..{math.floor(maxY)} studs; spawn {school.spawn.Position}; far {school.farPoint}`)
local list = {}
for name, n in names do
	table.insert(list, `{name}={n}`)
end
table.sort(list)
print(table.concat(list, " "))

-- Collidable parts containing a point (studs), other than `except`.
local solids = {}
for _, d in folder:GetDescendants() do
	if d:IsA("BasePart") and d.CanCollide then
		table.insert(solids, d)
	end
end
local function blockers(point, except)
	local hits = {}
	for _, p in solids do
		if p ~= except then
			local l = p.CFrame:PointToObjectSpace(point)
			if math.abs(l.X) < p.Size.X / 2 and math.abs(l.Y) < p.Size.Y / 2 and math.abs(l.Z) < p.Size.Z / 2 then
				table.insert(hits, `{p.Parent.Name}.{p.Name}`)
			end
		end
	end
	return hits
end
print("spawn blocked by: " .. table.concat(blockers(school.spawn.Position), ", "))

-- Every doorway, 1 m up: at 20%, 50% and 80% of its width, in the gap and 0.6 m to each side, must be free.
local blocked, blockedOpen = 0, 0
for _, model in folder:GetDescendants() do
	if model:IsA("Model") and model:FindFirstChild("Part") and model.Name == "Model" then
		local panel = model:FindFirstChild("Part")
		local hinge = panel.CFrame * roblox.CFrame.new(-panel.Size.X / 2, -panel.Size.Y / 2, 0)
		local hit = nil
		for _, along in { 0.2, 0.5, 0.8 } do
			for _, off in { 0, 1.8, -1.8 } do
				local p = (hinge * roblox.CFrame.new(panel.Size.X * along, 3, off)).Position
				local hits = blockers(p, panel)
				if #hits > 0 then
					hit = `{p} blocked by {table.concat(hits, ", ")}`
					break
				end
			end
			if hit then
				break
			end
		end
		if hit then
			blocked += 1
			local locked = model:GetAttribute("Locked")
			if not locked then
				blockedOpen += 1
			end
			print(`{if locked then "closed-room" else "OPEN"} door at {hit}`)
		end
	end
end
print(`blocked doors: {blocked} (open rooms: {blockedOpen})`)
for i, p in school.patrol do
	local hits = blockers(p + roblox.Vector3.new(0, 3, 0))
	if #hits > 0 then
		print(`patrol {i} inside {table.concat(hits, ", ")}`)
	end
end

-- Every lesson room needs chairs for a class (People.luau seats the story's class there).
local fewSeats = {}
for subject, info in CampaignData.SUBJECTS do
	local n = #(school.seats[`{info.floor}:{info.room}`] or {})
	if n < 6 then
		table.insert(fewSeats, `{subject} ({info.floor}:{info.room}) {n}`)
	end
end
-- `lune run tools/school-dryrun -- --room GT2,WC`: what these rooms' furniture is.
local roomArg = table.find(process.args, "--room")
if roomArg and process.args[roomArg + 1] then
	local wanted = string.split(process.args[roomArg + 1], ",")
	for _, d in folder:GetDescendants() do
		if d:IsA("Model") and d.Name == "Furniture" and table.find(wanted, d:GetAttribute("Room")) then
			local names = {}
			for _, c in d:GetChildren() do
				names[c.Name] = (names[c.Name] or 0) + 1
			end
			local list = {}
			for k, v in names do
				table.insert(list, `{k}={v}`)
			end
			table.sort(list)
			print(`{d.Parent.Name} {d:GetAttribute("Room")}: {table.concat(list, " ")}`)
		end
	end
end
print("lesson rooms with fewer than 6 chairs: " .. (if #fewSeats > 0 then table.concat(fewSeats, ", ") else "none"))

-- Every open room is finished: it has some furniture (corridors and closed rooms have none).
local pieces = {}
for _, d in folder:GetDescendants() do
	if d:IsA("Model") and d.Name == "Furniture" then
		local key = `{d.Parent.Name}:{d:GetAttribute("Room")}`
		pieces[key] = (pieces[key] or 0) + #d:GetChildren()
	end
end
local bare = {}
for _, r in school.rooms do
	if r.kind ~= "corridor" and r.kind ~= "other" then
		local n = 0
		for key, count in pieces do
			if string.sub(key, -#r.label - 1) == ":" .. r.label then
				n += count
			end
		end
		if n == 0 then
			table.insert(bare, `{r.floor}:{r.label} ({r.kind})`)
		end
	end
end
print("open rooms without furniture: " .. (if #bare > 0 then table.concat(bare, ", ") else "none"))

-- `lune run tools/school-dryrun -- --obstacles out.json`: world boxes (metres) of everything a walker meets, for
-- tools/map-editor/reach.py (where the school is cut off). Kinds: "block" (collidable, at body height; door panels
-- are left out, people walk through doors), "floor" (something to stand on), "door" (door panels, open or closed).
local obsArg = table.find(process.args, "--obstacles")
if obsArg and process.args[obsArg + 1] then
	local out = {}
	local M = Config.STUDS_PER_METRE
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			local cf, size = d.CFrame, d.Size
			local rx, ry, rz = cf.RightVector, cf.UpVector, cf.LookVector
			local ex = math.abs(rx.X) * size.X + math.abs(ry.X) * size.Y + math.abs(rz.X) * size.Z
			local ey = math.abs(rx.Y) * size.X + math.abs(ry.Y) * size.Y + math.abs(rz.Y) * size.Z
			local ez = math.abs(rx.Z) * size.X + math.abs(ry.Z) * size.Y + math.abs(rz.Z) * size.Z
			local p = cf.Position
			local isDoor = d.Parent and d.Parent:IsA("Model") and d.Parent:GetAttribute("Locked") ~= nil
			local kind = if isDoor then "door" elseif d.CanCollide then "block" else nil
			if kind then
				table.insert(out, { k = kind, n = d.Name,
					x0 = (p.X - ex / 2) / M, x1 = (p.X + ex / 2) / M, y0 = (p.Y - ey / 2) / M, y1 = (p.Y + ey / 2) / M,
					z0 = (p.Z - ez / 2) / M, z1 = (p.Z + ez / 2) / M, locked = if isDoor then d.Parent:GetAttribute("Locked") else nil,
					room = if isDoor then d.Parent:GetAttribute("Room") else nil,
					floor = if isDoor then d.Parent:GetAttribute("Floor") else nil })
			end
		end
	end
	local serde = require("@lune/serde")
	fs.writeFile(process.args[obsArg + 1], serde.encode("json", {
		parts = out,
		spawn = { x = school.spawn.Position.X / M, y = school.spawn.Position.Y / M, z = school.spawn.Position.Z / M },
		stairs = FloorData.STAIRS,
		patrol = (function()
			local list = {}
			for _, p in school.patrol do
				table.insert(list, { x = p.X / M, y = p.Y / M, z = p.Z / M })
			end
			return list
		end)(),
		floorHeight = Config.FLOOR_HEIGHT,
	}))
	print(`obstacles: {#out} boxes written`)
end

-- Save the built school as a model file for a look in Studio if needed.
if process.args[1] and string.sub(process.args[1], 1, 2) ~= "--" then
	fs.writeFile(process.args[1], roblox.serializeModel({ folder }))
end
