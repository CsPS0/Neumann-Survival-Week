-- Spider webs after the time slip (docs/2026-11-22-campaign-story-design.md): they hang from the ceilings of the
-- corridors and rooms, more every game hour, and at night thick webs seal the exits. Built from thin parts (spokes
-- and rings), no images. Each web finds its own wall and ceiling with raycasts, so it hangs where it should.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local S = Config.studs
local THREAD = 0.08
local COLOR = Color3.fromRGB(232, 232, 226)
local LIMIT = 70 -- webs at most (about 20 parts each)

local Webs = {}
Webs.__index = Webs

local function thread(parent: Instance, a: Vector3, b: Vector3, thick: number?)
	local length = (b - a).Magnitude
	if length < 0.05 then
		return
	end
	local p = Instance.new("Part")
	p.Name = "Thread"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = COLOR
	p.Transparency = 0.12
	local t = thick or THREAD
	p.Size = Vector3.new(t, t, length)
	p.CFrame = CFrame.lookAt((a + b) / 2, b)
	p.Parent = parent
end

-- A web in the plane of `frame` (its RightVector and UpVector), centred on its position. `from`..`to` are the
-- angles (radians, 0 = right) the web covers: a full circle, or a half hanging from a ceiling line.
local function web(parent: Instance, frame: CFrame, radius: number, from: number, to: number, spokes: number,
	rings: number, thick: number?): Model
	local model = Instance.new("Model")
	model.Name = "Web"
	local centre = frame.Position
	local function at(angle: number, r: number): Vector3
		return centre + frame.RightVector * math.cos(angle) * r + frame.UpVector * math.sin(angle) * r
	end
	local full = math.abs(to - from) >= math.pi * 2 - 1e-3
	local count = if full then spokes else spokes - 1
	local angles = {}
	for i = 0, count do
		local wobble = (math.random() - 0.5) * 0.12
		angles[i + 1] = from + (to - from) * (i / spokes) + wobble
	end
	if full then
		angles[#angles] = nil -- the last spoke would sit on the first
	end
	for _, angle in angles do
		thread(model, centre, at(angle, radius * (0.9 + math.random() * 0.15)), thick)
	end
	for ring = 1, rings do
		local r = radius * ring / (rings + 0.6)
		for i = 1, #angles - (if full then 0 else 1) do
			local a1 = angles[i]
			local a2 = angles[i % #angles + 1]
			-- A sagging chord between two spokes.
			local p1, p2 = at(a1, r), at(a2, r)
			local mid = (p1 + p2) / 2 + (centre - (p1 + p2) / 2).Unit * r * 0.08
			thread(model, p1, mid, thick)
			thread(model, mid, p2, thick)
		end
	end
	model.Parent = parent
	return model
end

export type Opts = {
	folder: Instance,
	points: { Vector3 }, -- floor-level points in corridors and rooms (studs)
}

function Webs.new(opts: Opts)
	local self = setmetatable({}, Webs)
	self.folder = Instance.new("Folder")
	self.folder.Name = "Webs"
	self.folder.Parent = opts.folder
	self.points = table.clone(opts.points)
	self.count = 0
	self.seals = {} :: { Model }
	self.params = RaycastParams.new()
	self.params.FilterType = Enum.RaycastFilterType.Include
	local school = workspace:FindFirstChild("School")
	self.params.FilterDescendantsInstances = { school or workspace }
	-- Shuffle once so the webs spread over the whole school, not one corridor first.
	for i = #self.points, 2, -1 do
		local j = math.random(i)
		self.points[i], self.points[j] = self.points[j], self.points[i]
	end
	self.next = 1
	return self
end

-- One web near `point`: under the ceiling, flat against the nearest wall (a half web hanging down), or in the
-- corner between two walls. Returns false when no wall is near.
function Webs:hangNear(point: Vector3): boolean
	local up = workspace:Raycast(point + Vector3.new(0, 2, 0), Vector3.new(0, S(6), 0), self.params)
	if not up then
		return false
	end
	local ceiling = up.Position.Y - 0.08
	local from = Vector3.new(point.X, ceiling - 0.4, point.Z)
	local best = nil
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local hit = workspace:Raycast(from, dir * S(6), self.params)
		if hit and (not best or hit.Distance < best.Distance) then
			best = hit
		end
	end
	if not best then
		return false
	end
	local normal = best.Normal
	local along = normal:Cross(Vector3.yAxis).Unit
	local slide = (math.random() - 0.5) * S(2)
	local centre = Vector3.new(best.Position.X, ceiling, best.Position.Z) + normal * 0.06 + along * slide
	-- The web's plane is the wall: right = along the wall, up = up. A half web hangs below the ceiling line.
	local frame = CFrame.fromMatrix(centre, along, Vector3.yAxis)
	local radius = S(0.5 + math.random() * 0.6)
	web(self.folder, frame, radius, math.pi, math.pi * 2, 6, 3)
	self.count += 1
	return true
end

-- `n` more webs (fewer if the school is full).
function Webs:grow(n: number)
	local tries = 0
	while n > 0 and self.count < LIMIT and tries < n * 4 do
		tries += 1
		local point = self.points[self.next]
		self.next = self.next % #self.points + 1
		if point and self:hangNear(point + Vector3.new((math.random() - 0.5) * 6, 0, (math.random() - 0.5) * 6)) then
			n -= 1
		end
	end
end

-- A thick web over a doorway: `frame` faces out of the door, `size` is the opening (studs).
function Webs:seal(frame: CFrame, size: Vector2): Model
	local radius = math.max(size.X, size.Y) * 0.62
	local model = web(self.folder, frame, radius, 0, math.pi * 2, 12, 6, 0.14)
	-- A few loose strands across the corners.
	for _ = 1, 6 do
		local a = frame * Vector3.new((math.random() - 0.5) * size.X, (math.random() - 0.5) * size.Y, 0)
		local b = frame * Vector3.new((math.random() - 0.5) * size.X, (math.random() - 0.5) * size.Y, 0)
		thread(model, a, b, 0.11)
	end
	table.insert(self.seals, model)
	return model
end

-- The ritual is done: the seals fall away.
function Webs:unseal()
	for _, model in self.seals do
		model:Destroy()
	end
	self.seals = {}
end

function Webs:destroy()
	self.folder:Destroy()
end

return Webs
