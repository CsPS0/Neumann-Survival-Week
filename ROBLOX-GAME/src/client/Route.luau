-- The phone's route planner (like the school's map app's "Útvonaltervező"): pick a room on the phone and a trail of
-- small glowing dots on the floor leads you there, up and down the stairs too. It recalculates every 1.5 s while
-- you walk, says how far it is (bottom left), and ends when you step into the room. Only you see the dots.
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local FloorData = require(ReplicatedStorage.Shared.FloorData)
local StoryUi = require(script.Parent.StoryUi)

local player = Players.LocalPlayer
local Route = {}

local S = Config.studs
local SPACING = 3 -- studs between dots
local MAX_DOTS = 90
local REFRESH = 1.5
local DOT = Color3.fromRGB(255, 214, 90)

local target: { floor: number, label: string }? = nil
local token = 0
local dots: { Part } = {}
local folder: Folder
local hint: TextLabel
local changed = Instance.new("BindableEvent")
Route.changed = changed.Event

function Route.target(): { floor: number, label: string }?
	return target
end

local function root(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- The centre (studs, at walking height) of the room with this label on this floor nearest to you (WCs repeat).
-- Where to walk in the nearest room with this label: its middle first, then spots 1 m inside its walls (desks can
-- wall in the middle of a small IT room; any spot inside the room counts as arrived).
local function goals(floor: number, label: string, from: Vector3): { Vector3 }
	local best, bestD, doors = nil, math.huge, ""
	for _, r in FloorData.FLOORS[floor + 1].rooms do
		if r.label == label then
			local ax, az = FloorData.toWorld(floor, r.x0, r.y0)
			local bx, bz = FloorData.toWorld(floor, r.x1, r.y1)
			local d = (Vector3.new(S((ax + bx) / 2), from.Y, S((az + bz) / 2)) - from).Magnitude
			if d < bestD then
				best, bestD = { x0 = math.min(ax, bx), z0 = math.min(az, bz), x1 = math.max(ax, bx), z1 = math.max(az, bz) }, d
				doors = r.doors
			end
		end
	end
	if not best then
		return {}
	end
	local y = S(floor * Config.FLOOR_HEIGHT) + 3
	local function at(x: number, z: number): Vector3
		return Vector3.new(S(x), y, S(z))
	end
	local list = { at((best.x0 + best.x1) / 2, (best.z0 + best.z1) / 2) }
	-- Just inside each door ("S10.8": side, then the position along the wall in plan metres; none = the middle).
	for side, pos in string.gmatch(doors, "(%a)([%d%.]*)") do
		side = string.upper(side)
		local p = tonumber(pos)
		local wx, wz = 0, 0
		if p then
			wx, wz = FloorData.toWorld(floor, p, p)
		end
		if side == "N" or side == "S" then
			local x = if p then wx else (best.x0 + best.x1) / 2
			table.insert(list, 2, at(x, if side == "N" then best.z0 + 0.8 else best.z1 - 0.8))
		elseif side == "W" or side == "E" then
			local z = if p then wz else (best.z0 + best.z1) / 2
			table.insert(list, 2, at(if side == "W" then best.x0 + 0.8 else best.x1 - 0.8, z))
		end
	end
	for _, f in { 0.5, 0.25, 0.75 } do
		local x = best.x0 + (best.x1 - best.x0) * f
		local z = best.z0 + (best.z1 - best.z0) * f
		table.insert(list, at(x, best.z0 + 1))
		table.insert(list, at(x, best.z1 - 1))
		table.insert(list, at(best.x0 + 1, z))
		table.insert(list, at(best.x1 - 1, z))
	end
	return list
end

-- A story room locked until someone brings its key from the Porta (Keys.luau).
local function isLocked(floor: number, label: string): boolean
	for _, door in CollectionService:GetTagged("Door") do
		if door:GetAttribute("Room") == label and door:GetAttribute("Floor") == floor and door:GetAttribute("Locked") then
			return true
		end
	end
	return false
end

local function dot(i: number): Part
	local p = dots[i]
	if not p then
		p = Instance.new("Part")
		p.Name = "RouteDot"
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(0.55, 0.55, 0.55)
		p.Material = Enum.Material.Neon
		p.Color = DOT
		p.Transparency = 0.2
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = folder
		dots[i] = p
	end
	return p
end

local function hideFrom(n: number)
	for i = n, #dots do
		dots[i].Transparency = 1
	end
end

-- Lays dots along the waypoints, starting a few studs ahead of you.
local function draw(points: { Vector3 })
	local n = 0
	local carry = 2
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local seg = (b - a).Magnitude
		local d = carry
		while d < seg and n < MAX_DOTS do
			n += 1
			local p = dot(n)
			p.Position = a:Lerp(b, d / seg) + Vector3.new(0, -2.4, 0)
			p.Transparency = 0.2
			d += SPACING
		end
		carry = d - seg
	end
	hideFrom(n + 1)
end

function Route.stop()
	target = nil
	token += 1
	hideFrom(1)
	hint.Text = ""
	changed:Fire()
end

local function arrived(r: BasePart, t: { floor: number, label: string }): boolean
	local m = r.Position / Config.STUDS_PER_METRE
	return FloorData.floorAt(m.Y) == t.floor and FloorData.roomLabelAt(t.floor, m.X, m.Z) == t.label
end

function Route.set(floor: number, label: string)
	target = { floor = floor, label = label }
	token += 1
	local mine = token
	changed:Fire()
	local path = PathfindingService:CreatePath({ AgentRadius = 1.5, AgentHeight = 5.5, AgentCanJump = false,
		WaypointSpacing = 4 })
	local preferred: number? = nil
	task.spawn(function()
		while token == mine and target do
			local t = target :: { floor: number, label: string }
			local r = root()
			if r then
				if arrived(r, t) then
					hint.Text = `You are in {t.label}.`
					hideFrom(1)
					task.delay(3, function()
						if token == mine then
							Route.stop()
						end
					end)
					return
				end
				-- The spot that worked last time first, then the others in order.
				local list = goals(t.floor, t.label, r.Position)
				local order = {}
				if preferred and list[preferred] then
					table.insert(order, preferred)
				end
				for i = 1, #list do
					if i ~= preferred then
						table.insert(order, i)
					end
				end
				local ok = false
				for _, i in order do
					ok = pcall(function()
						path:ComputeAsync(r.Position, list[i])
					end) and path.Status == Enum.PathStatus.Success
					if token ~= mine then
						return
					end
					if ok then
						preferred = i
						break
					end
				end
				if ok then
					local points = {}
					local length = 0
					for i, w in path:GetWaypoints() do
						points[i] = w.Position + Vector3.new(0, 3, 0)
						if i > 1 then
							length += (points[i] - points[i - 1]).Magnitude
						end
					end
					draw(points)
					local floorWord = if t.floor == FloorData.floorAt(r.Position.Y / Config.STUDS_PER_METRE) then ""
						else `, {FloorData.FLOOR_NAMES[t.floor + 1]}`
					hint.Text = `Route: {t.label}{floorWord}  {math.round(length / Config.STUDS_PER_METRE)} m`
				else
					hideFrom(1)
					hint.Text = if isLocked(t.floor, t.label) then `Route: {t.label} is locked. The porter at the Porta has the key.`
						else `Route: {t.label}: no way in right now (locked?)`
				end
			end
			task.wait(REFRESH)
		end
	end)
end

function Route.init()
	folder = Instance.new("Folder")
	folder.Name = "RouteGuide"
	folder.Parent = workspace
	local gui = StoryUi.gui("Route", 2)
	hint = Instance.new("TextLabel")
	hint.AnchorPoint = Vector2.new(0, 1)
	hint.Position = UDim2.new(0, 14, 1, -14)
	hint.Size = UDim2.fromOffset(360, 24)
	hint.BackgroundTransparency = 1
	hint.TextColor3 = DOT
	hint.TextStrokeTransparency = 0.4
	hint.TextSize = 17
	hint.Font = Enum.Font.GothamMedium
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Text = ""
	hint.Parent = gui
	-- A new round respawns everyone: drop the route when you leave play or go out.
	player:GetAttributeChangedSignal("State"):Connect(function()
		local s = player:GetAttribute("State")
		if target and s ~= "alive" and s ~= "lobby" then
			Route.stop()
		end
	end)
end

return Route
