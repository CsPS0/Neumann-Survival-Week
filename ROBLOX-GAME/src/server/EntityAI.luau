-- The computer-controlled entity (HORROR-GAME/scripts/horror_entity.gd), server only.
-- IDLE / PATROL between patrol points / CHASE a seen target / ATTACK in range. It hears sprinting on its floor,
-- senses its target's rough position every `hintInterval`, checks occupied lockers whose occupant breathes, never
-- catches a hidden player, and a torch flash stuns it, then leaves it blind for a while.
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Doors = require(script.Parent.Doors)
local EntityModel = require(script.Parent.EntityModel)

local E = Config.Entity
local S = Config.studs
local TICK = 0.1
local SIGHT_HALF_ANGLE = math.rad(60)
local LOCKER_COOLDOWN = 10
local FLOOR_TOLERANCE = S(2)

export type Options = {
	targets: () -> { Player },
	isHidden: (Player) -> boolean,
	holdingBreath: (Player) -> boolean,
	lockers: () -> { [Model]: Player },
	onCatch: (Player) -> (),
	-- Overrides of Config.Entity for this entity (the campaign difficulty: chaseSpeed, sight, hintInterval).
	params: { [string]: number }?,
}

local EntityAI = {}
EntityAI.__index = EntityAI

function EntityAI.new(model: Model, school, opts: Options)
	local self = setmetatable({}, EntityAI)
	self.model = model
	self.humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	self.root = model.PrimaryPart :: BasePart
	self.school = school
	self.opts = opts
	local tuning: any = table.clone(E)
	for key, value in opts.params or {} do
		tuning[key] = value
	end
	self.E = tuning
	self.state = "idle"
	self.running = false
	self.now = 0
	self.stateUntil = 0
	self.target = nil :: Player?
	self.lastSeenAt = 0
	self.lastSeenPos = nil :: Vector3?
	self.goal = nil :: Vector3?
	self.waypoints = {} :: { PathWaypoint }
	self.wp = 0
	self.stunUntil = 0
	self.blindUntil = 0
	self.nextHint = 0
	self.lockerChecked = {} :: { [Model]: number }
	self.lastPos = self.root.Position
	self.stuckTime = 0
	self.path = PathfindingService:CreatePath({
		AgentRadius = 1.5,
		AgentHeight = 5.5,
		AgentCanJump = false,
		WaypointSpacing = 6,
	})
	self.rayParams = RaycastParams.new()
	self.rayParams.FilterType = Enum.RaycastFilterType.Exclude
	self.rayParams.FilterDescendantsInstances = { model }
	return self
end

function EntityAI:placeAt(position: Vector3)
	self.model:PivotTo(CFrame.new(position + Vector3.new(0, S(1), 0)))
	self.waypoints = {}
	self.goal = nil
end

function EntityAI:stun(seconds: number)
	local now = os.clock()
	self.stunUntil = now + seconds
	self.blindUntil = self.stunUntil + self.E.blindAfterStun
	self.humanoid:MoveTo(self.root.Position)
	self.waypoints = {}
	self.goal = nil
	self.state = "idle"
	EntityModel.setAggressive(self.model, false)
end

local function rootOf(player: Player): BasePart?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function EntityAI:candidates(): { Player }
	local list = {}
	for _, p in self.opts.targets() do
		if p:GetAttribute("State") == "alive" and not self.opts.isHidden(p) and rootOf(p) then
			table.insert(list, p)
		end
	end
	return list
end

function EntityAI:canSee(player: Player): boolean
	if os.clock() < self.blindUntil then
		return false
	end
	local root = rootOf(player)
	if not root then
		return false
	end
	local eye = self.root.Position + Vector3.new(0, S(1.1), 0)
	local to = root.Position + Vector3.new(0, S(0.4), 0) - eye
	local dist = to.Magnitude
	if dist > S(self.E.sight) then
		return false
	end
	if dist > S(self.E.proximity) then
		local forward = self.root.CFrame.LookVector
		if math.acos(math.clamp(forward:Dot(to.Unit), -1, 1)) > SIGHT_HALF_ANGLE then
			return false
		end
	end
	local hit = workspace:Raycast(eye, to, self.rayParams)
	return hit ~= nil and hit.Instance:IsDescendantOf(player.Character :: Model)
end

function EntityAI:hears(player: Player): boolean
	if os.clock() < self.blindUntil or not player:GetAttribute("Sprinting") then
		return false
	end
	local root = rootOf(player)
	return root ~= nil and math.abs(root.Position.Y - self.root.Position.Y) < FLOOR_TOLERANCE
		and (root.Position - self.root.Position).Magnitude <= S(self.E.hearing)
end

function EntityAI:setGoal(position: Vector3)
	self.goal = position
	self.waypoints = {}
	self.wp = 0
	local ok = pcall(function()
		self.path:ComputeAsync(self.root.Position, position)
	end)
	if ok and self.path.Status == Enum.PathStatus.Success then
		self.waypoints = self.path:GetWaypoints()
		self.wp = math.min(2, #self.waypoints)
		if self.wp > 0 then
			self.humanoid:MoveTo(self.waypoints[self.wp].Position)
		end
	else
		self.humanoid:MoveTo(position)
	end
end

function EntityAI:followPath(): boolean -- true when the goal is reached
	if not self.goal then
		return true
	end
	local here = self.root.Position
	local wp = self.waypoints[self.wp]
	if not wp then
		return (Vector3.new(here.X, 0, here.Z) - Vector3.new(self.goal.X, 0, self.goal.Z)).Magnitude < 3
	end
	local flat = Vector3.new(wp.Position.X - here.X, 0, wp.Position.Z - here.Z)
	if flat.Magnitude < 2.5 then
		self.wp += 1
		local nextWp = self.waypoints[self.wp]
		if not nextWp then
			self.goal = nil
			return true
		end
		self.humanoid:MoveTo(nextWp.Position)
	end
	return false
end

function EntityAI:randomGoal(): Vector3
	local patrol = self.school.patrol
	local here = self.root.Position
	for _ = 1, 8 do
		local p
		if math.random() < self.E.waypointBias then
			p = patrol[math.random(#patrol)]
		else
			local lamp = self.school.lamps[math.random(#self.school.lamps)]
			local part = lamp.Parent :: BasePart
			p = Vector3.new(part.Position.X, part.Position.Y - S(Config.WALL_HEIGHT) + S(0.1), part.Position.Z)
		end
		if (p - here).Magnitude >= S(self.E.roamMin) then
			return p
		end
	end
	return patrol[math.random(#patrol)]
end

function EntityAI:openNearbyDoors()
	for _, door in CollectionService:GetTagged("Door") do
		local panel = (door :: Model).PrimaryPart
		if panel and not door:GetAttribute("Open") and not door:GetAttribute("Locked")
			and (panel.Position - self.root.Position).Magnitude < 5 then
			Doors.setOpen(door :: Model, true)
		end
	end
end

function EntityAI:checkLockers()
	local now = os.clock()
	for locker, occupant in self.opts.lockers() do
		local body = locker.PrimaryPart
		if body and not self.opts.holdingBreath(occupant) and now >= (self.lockerChecked[locker] or 0)
			and (body.Position - self.root.Position).Magnitude <= S(self.E.lockerCheck) + 2 then
			self.lockerChecked[locker] = now + LOCKER_COOLDOWN
			self.state = "check"
			self.stateUntil = now + self.E.idleTime + 2
			self.humanoid.WalkSpeed = S(self.E.patrolSpeed)
			self:setGoal((body.CFrame * CFrame.new(0, 0, S(0.9))).Position)
			return true
		end
	end
	return false
end

function EntityAI:tick()
	local now = os.clock()
	local h = self.humanoid
	if now < self.stunUntil then
		h:MoveTo(self.root.Position)
		return
	end
	self:openNearbyDoors()

	-- Sight beats everything else.
	local seen: Player? = nil
	local best = math.huge
	for _, p in self:candidates() do
		if self:canSee(p) then
			local d = ((rootOf(p) :: BasePart).Position - self.root.Position).Magnitude
			if d < best then
				best, seen = d, p
			end
		end
	end
	if seen then
		self.target = seen
		self.lastSeenAt = now
		self.lastSeenPos = (rootOf(seen) :: BasePart).Position
		if self.state ~= "chase" then
			self.state = "chase"
			EntityModel.setAggressive(self.model, true)
		end
		h.WalkSpeed = S(self.E.chaseSpeed)
		if best <= S(self.E.attackRange) + 1.5 then
			self.opts.onCatch(seen)
			self.state = "idle"
			self.stateUntil = now + self.E.attackDuration
			self.target = nil
			self.goal = nil
			EntityModel.setAggressive(self.model, false)
			h:MoveTo(self.root.Position)
			return
		end
		-- In sight: walk straight at it.
		self.goal = nil
		h:MoveTo(self.lastSeenPos :: Vector3)
		return
	end

	if self.state == "chase" then
		if now - self.lastSeenAt > self.E.loseSight or not self.lastSeenPos then
			self.state = "patrol"
			EntityModel.setAggressive(self.model, false)
			self.goal = nil
		elseif not self.goal and self.lastSeenPos then
			self:setGoal(self.lastSeenPos)
		elseif self:followPath() then
			self.lastSeenPos = nil
		end
		return
	end

	-- Hearing a sprint on its floor, or the periodic hint, sends it to look.
	for _, p in self:candidates() do
		if self:hears(p) then
			self.state = "investigate"
			h.WalkSpeed = S(self.E.chaseSpeed)
			self:setGoal((rootOf(p) :: BasePart).Position)
			break
		end
	end
	if self.E.hintInterval > 0 and now >= self.nextHint then
		self.nextHint = now + self.E.hintInterval
		local list = self:candidates()
		local nearest, nd = nil, math.huge
		for _, p in list do
			local d = ((rootOf(p) :: BasePart).Position - self.root.Position).Magnitude
			if d < nd then
				nearest, nd = p, d
			end
		end
		if nearest then
			local offset = Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)) * S(1)
			self.state = "investigate"
			h.WalkSpeed = S(self.E.patrolSpeed) * 1.4
			self:setGoal((rootOf(nearest) :: BasePart).Position + offset)
		end
	end

	if self.state ~= "check" and self:checkLockers() then
		return
	end

	if self.state == "idle" then
		if now >= self.stateUntil then
			self.state = "patrol"
			h.WalkSpeed = S(self.E.patrolSpeed)
			self:setGoal(self:randomGoal())
		end
	elseif self.state == "patrol" or self.state == "investigate" or self.state == "check" then
		if self:followPath() then
			if self.state == "check" then
				-- Linger at the locker, then move on.
				if now >= self.stateUntil then
					self.state = "idle"
					self.stateUntil = now + math.random() * self.E.idleTime
				end
			else
				self.state = "idle"
				self.stateUntil = now + math.random() * self.E.idleTime
			end
		end
	end

	-- Stuck: barely moved for a second while it should walk.
	if self.state ~= "idle" and self.goal then
		self.stuckTime = if (self.root.Position - self.lastPos).Magnitude < 0.3 then self.stuckTime + TICK else 0
		if self.stuckTime >= 1 then
			self.stuckTime = 0
			self:setGoal(if self.state == "patrol" then self:randomGoal() else self.goal :: Vector3)
		end
	end
	self.lastPos = self.root.Position
end

function EntityAI:start()
	if self.running then
		return
	end
	self.running = true
	self.state = "idle"
	self.stateUntil = os.clock() + 1
	self.nextHint = os.clock() + self.E.hintInterval
	pcall(function()
		self.root:SetNetworkOwner(nil)
	end)
	task.spawn(function()
		while self.running and self.model.Parent do
			local ok, err = pcall(self.tick, self)
			if not ok then
				warn("[entity] " .. tostring(err))
			end
			task.wait(TICK)
		end
	end)
end

function EntityAI:stop()
	self.running = false
	if self.humanoid.Parent then
		self.humanoid:MoveTo(self.root.Position)
	end
end

return EntityAI
