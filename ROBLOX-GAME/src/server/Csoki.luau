-- Csoki, the caretaker's dog (HORROR-GAME/scripts/csoki.gd). Wanders the ground floor near the Aula, barks when the
-- entity or the caretaker is within 20 m (a warning), can be petted (E), and follows whoever gives it a dog biscuit
-- for 3 minutes. It is moved by the server along pathfinding waypoints (no physics, it never blocks anyone) and is
-- away during Hide and Seek and Social Deduction, where a bark would give the hider or the entity away.
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local AchievementService = require(script.Parent.AchievementService)
local Characters = require(script.Parent.Characters)
local Inventories = require(script.Parent.Campaign.Inventories)

local S = Config.studs
local WALK = S(1.4) -- studs per second
local RUN = S(3.2)
local WARN = S(20)
local BARK_EVERY = 6
local FOLLOW_SECONDS = 180
local WANDER_RADIUS = S(25)

local Csoki = {}

local model: Model
local root: Part
local legs: { { part: Part, offset: CFrame, phase: number } } = {}
local tail: Part
local tailOffset: CFrame
local home: Vector3
local points: { Vector3 } = {}
local path: { Vector3 } = {}
local following: Player? = nil
local followUntil = 0
local lastBark = 0
local walkPhase = 0
local present = true
local remotes: Folder

local FUR = Color3.fromRGB(140, 97, 56)
local DARK = Color3.fromRGB(50, 36, 26)

local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = name == "Body" -- the prompt's part is the only one rays may find
	p.CastShadow = true
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Fabric
	if shape then
		p.Shape = shape
	end
	p:SetAttribute("Offset", true)
	p.Parent = model
	return p
end

local offsets: { [Part]: CFrame } = {}

local function build(parent: Instance, at: Vector3)
	model = Instance.new("Model")
	model.Name = "Csoki"
	-- Sizes in metres from csoki.gd, studs here.
	root = piece("Body", Vector3.new(S(0.22), S(0.2), S(0.55)), CFrame.new(0, S(0.36), 0), FUR)
	offsets[root] = CFrame.new(0, S(0.36), 0)
	local function add(name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?): Part
		local p = piece(name, size, offset, color, shape)
		offsets[p] = offset
		return p
	end
	add("Head", Vector3.new(S(0.22), S(0.22), S(0.22)), CFrame.new(0, S(0.46), S(-0.34)), FUR, Enum.PartType.Ball)
	add("Snout", Vector3.new(S(0.09), S(0.09), S(0.12)), CFrame.new(0, S(0.43), S(-0.46)), DARK)
	add("Nose", Vector3.new(S(0.04), S(0.04), S(0.03)), CFrame.new(0, S(0.45), S(-0.525)), Color3.new(0.05, 0.05, 0.05))
	for _, x in { -0.07, 0.07 } do
		add("Ear", Vector3.new(S(0.04), S(0.1), S(0.06)), CFrame.new(S(x), S(0.58), S(-0.31)) * CFrame.Angles(0, 0,
			math.rad(x * 300)), DARK)
		add("Eye", Vector3.new(S(0.03), S(0.03), S(0.02)), CFrame.new(S(x * 0.7), S(0.5), S(-0.44)),
			Color3.new(0.05, 0.05, 0.05), Enum.PartType.Ball)
	end
	for i, corner in { Vector2.new(-0.08, -0.2), Vector2.new(0.08, -0.2), Vector2.new(-0.08, 0.2), Vector2.new(0.08, 0.2) } do
		local offset = CFrame.new(S(corner.X), S(0.14), S(corner.Y))
		local leg = add("Leg", Vector3.new(S(0.05), S(0.28), S(0.05)), offset, DARK)
		table.insert(legs, { part = leg, offset = offset, phase = if i == 1 or i == 4 then 0 else math.pi })
	end
	tailOffset = CFrame.new(0, S(0.46), S(0.32)) * CFrame.Angles(math.rad(40), 0, 0)
	tail = add("Tail", Vector3.new(S(0.03), S(0.2), S(0.03)), tailOffset, FUR)
	model.PrimaryPart = root
	model:PivotTo(CFrame.new(at))
	model.Parent = parent
	-- Pet it, or give it a biscuit.
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pet"
	prompt.ObjectText = "Csoki"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("For", "all")
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		Csoki.interact(player)
	end)
end

local function banner(player: Player, text: string)
	local r = remotes:FindFirstChild("Banner") :: RemoteEvent?
	if r then
		r:FireClient(player, text, 3)
	end
end

function Csoki.interact(player: Player)
	if not present then
		return
	end
	if Inventories.isEnabled() and Inventories.reachable(player, "biscuit") then
		if following == player then
			banner(player, "Csoki is already with you.")
			return
		end
		Inventories.take(player, "biscuit")
		following = player
		followUntil = os.clock() + FOLLOW_SECONDS
		path = {}
		banner(player, "Csoki gobbles the biscuit and trots after you.")
		AchievementService.award(player, "dog_walker")
		return
	end
	banner(player, "Csoki wags its tail.")
	AchievementService.award(player, "good_boy")
end

-- The admin panel: Csoki runs to this player (and follows for a while).
function Csoki.callTo(player: Player)
	following = player
	followUntil = os.clock() + 60
	path = {}
end

local function ground(at: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { model }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(at + Vector3.new(0, 3, 0), Vector3.new(0, -8, 0), params)
	return if hit then hit.Position.Y else at.Y
end

local function planTo(goal: Vector3)
	local p = PathfindingService:CreatePath({ AgentRadius = 1, AgentHeight = 2.5, AgentCanJump = false,
		WaypointSpacing = 4 })
	local ok = pcall(function()
		p:ComputeAsync(root.Position, goal)
	end)
	path = {}
	if ok and p.Status == Enum.PathStatus.Success then
		for i, w in p:GetWaypoints() do
			if i > 1 then
				table.insert(path, w.Position)
			end
		end
	end
end

-- The entity and the caretaker live in a mode's folder in the workspace (two levels down at most; the school's
-- thousands of parts are not searched).
local function danger(): boolean
	local function near(m: Instance): boolean
		if m:IsA("Model") and (m.Name == "Entity" or m.Name == "Caretaker") then
			local pivot = m:GetPivot().Position
			return (pivot - root.Position).Magnitude < WARN
		end
		return false
	end
	for _, a in workspace:GetChildren() do
		if a.Name ~= "School" then
			if near(a) then
				return true
			end
			if a:IsA("Folder") then
				for _, b in a:GetChildren() do
					if near(b) then
						return true
					end
				end
			end
		end
	end
	return false
end

local function wanted(): boolean
	local mode = ReplicatedStorage:GetAttribute("Mode")
	return mode ~= "hideseek" and mode ~= "deduction"
end

function Csoki.init(school: any, remoteFolder: Folder, parent: Instance)
	remotes = remoteFolder
	home = school.spawn.Position - Vector3.new(0, 3, 0) + Vector3.new(S(3), 0, S(2))
	for _, p in school.patrol do
		if math.abs(p.Y - home.Y) < 3 and (p - home).Magnitude < WANDER_RADIUS then
			table.insert(points, p)
		end
	end
	table.insert(points, home)
	build(parent, home)

	-- Planning (yields) runs here; moving runs every frame.
	task.spawn(function()
		while true do
			if present then
				if following and (not following.Parent or os.clock() > followUntil
					or following:GetAttribute("State") == "out") then
					following = nil
				end
				local target = following and Characters.root(following)
				if target then
					local behind = target.Position - target.CFrame.LookVector * S(1.2)
					if (behind - root.Position).Magnitude > S(1.5) then
						planTo(Vector3.new(behind.X, ground(behind), behind.Z))
					else
						path = {}
					end
					task.wait(0.5)
				else
					if #path == 0 then
						task.wait(3 + math.random() * 6)
						local goal = points[math.random(#points)] + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
						planTo(goal)
					end
					task.wait(0.5)
				end
				if os.clock() - lastBark > BARK_EVERY and danger() then
					lastBark = os.clock()
					local sound = remotes:FindFirstChild("Sound") :: RemoteEvent?
					if sound then
						sound:FireAllClients("bark", root.Position)
					end
				end
			else
				task.wait(1)
			end
		end
	end)

	local facing = CFrame.new()
	local feet = home -- where its paws are (the body parts sit above it)
	RunService.Heartbeat:Connect(function(dt)
		-- Away during the night modes, back afterwards.
		local want = wanted()
		if want ~= present then
			present = want
			model.Parent = if want then parent else nil
			following = nil
			path = {}
			if want then
				feet = home
			end
		end
		if not present then
			return
		end
		local here = feet
		local moving = false
		local nextPoint = path[1]
		if nextPoint then
			local flat = Vector3.new(nextPoint.X - here.X, 0, nextPoint.Z - here.Z)
			local speed = if following then RUN else WALK
			if flat.Magnitude < 0.6 then
				table.remove(path, 1)
			else
				moving = true
				local step = flat.Unit * math.min(speed * dt, flat.Magnitude)
				local pos = here + step
				local y = ground(pos)
				here = Vector3.new(pos.X, here.Y + (y - here.Y) * math.min(1, dt * 10), pos.Z)
				facing = CFrame.lookAt(Vector3.zero, flat.Unit)
				feet = here
			end
		end
		if moving then
			walkPhase += dt * (if following then 14 else 9)
		end
		local base = CFrame.new(here) * facing
		for part, offset in offsets do
			part.CFrame = base * offset
		end
		for _, leg in legs do
			local swing = if moving then math.sin(walkPhase + leg.phase) * 0.6 else 0
			leg.part.CFrame = base * leg.offset * CFrame.new(0, S(0.14), 0) * CFrame.Angles(swing, 0, 0)
				* CFrame.new(0, -S(0.14), 0)
		end
		tail.CFrame = base * tailOffset * CFrame.Angles(0, 0, math.sin(os.clock() * (if following then 14 else 6)) * 0.5)
	end)
end

return Csoki
