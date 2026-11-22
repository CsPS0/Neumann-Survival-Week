-- The people in the school (docs/2026-11-21-life-design.md).
--
-- By day (the lobby, and the story until Lab 14 explodes) students, teachers, cleaners and kitchen staff fill the
-- school near the players: at most CROWD people, the ones far from every player are taken away and new ones appear
-- out of sight near someone. In a lesson the students sit in the classrooms (the story's lesson room gets a class),
-- in a break they walk the corridors and stand in groups. When Lab 14 explodes everyone walks out. The story's own
-- teachers are not here (Campaign/Teachers.luau); the crowd has no teachers in the story so nobody mixes them up.
--
-- At night (Hide and Seek, Social Deduction) a few students stayed late: the mode calls People.startVictims with its
-- hooks. They wander, run from the entity, and the entity can take them (the computer entity by reaching one, a
-- player entity with E). A take is a scream everyone hears; in Social Deduction the body stays and can be reported.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local FloorData = require(ReplicatedStorage.Shared.FloorData)
local Npc = require(script.Parent.Campaign.Npc)

local S = Config.studs

local People = {}

local CROWD = 24
local NEAR = S(50) -- new people appear within this distance of a player...
local NOT_TOO_NEAR = S(12) -- ...but not right in front of them
local FAR = S(80) -- people farther than this from every player are taken away
local LOBBY_BREAK = 60 -- seconds of the lobby's break and lesson cycle
local LOBBY_LESSON = 120
local FLEE_RANGE = S(12)

type Person = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	role: string, -- student, classmate, teacher, cleaner, cook, victim
	seat: Seat?,
	scene: string?, -- the scene the person last acted on
	taken: boolean?,
	name: string?,
}

export type VictimHooks = {
	count: number,
	threats: () -> { Vector3 }, -- where the entity (or entities) are, in studs
	computer: () -> BasePart?, -- the computer entity's root: it takes a student by reaching them
	canTake: (by: Player) -> boolean, -- may this player take a student now (the player entity)
	active: () -> boolean, -- the hunt or the night is on: students run and can be taken
	onTaken: ((by: Player?, name: string, at: Vector3) -> ())?,
	bodies: boolean, -- leave a body that can be reported (Social Deduction)
	report: ((by: Player, name: string) -> ())?,
}

local school: any
local folder: Folder
local people: { [Model]: Person } = {}
local victimHooks: VictimHooks? = nil
local bodies: { Model } = {}
local corridor: { Vector3 } = {} -- walking points (studs, root height)
local classrooms: { { key: string, floor: number, centre: Vector3, seats: { Seat } } } = {}
local kitchens: { Vector3 } = {}
local offices: { Vector3 } = {}
local exit: Vector3 = Vector3.zero

local scene = "empty"
local lobbyLesson = false
local lobbyFlipAt = 0

-- Looks ---------------------------------------------------------------------------------------------------------

local SKINS = {
	Color3.fromRGB(241, 205, 178), Color3.fromRGB(226, 182, 150), Color3.fromRGB(205, 160, 125),
	Color3.fromRGB(176, 128, 96), Color3.fromRGB(128, 88, 62), Color3.fromRGB(92, 62, 44),
}
local CASUAL = {
	Color3.fromRGB(40, 60, 110), Color3.fromRGB(150, 40, 45), Color3.fromRGB(60, 110, 70), Color3.fromRGB(230, 230, 230),
	Color3.fromRGB(30, 30, 34), Color3.fromRGB(200, 160, 60), Color3.fromRGB(110, 70, 130), Color3.fromRGB(90, 140, 170),
	Color3.fromRGB(180, 90, 60), Color3.fromRGB(120, 120, 126),
}
local JEANS = { Color3.fromRGB(46, 62, 98), Color3.fromRGB(30, 34, 44), Color3.fromRGB(70, 84, 110),
	Color3.fromRGB(84, 70, 56) }
local ROLE = {
	student = { name = "Student", speed = 1.35 },
	classmate = { name = "Student", speed = 1.35 }, -- the class of the story's lesson room (always there)
	teacher = { name = "Teacher", speed = 1.2, torso = { Color3.fromRGB(90, 80, 70), Color3.fromRGB(60, 70, 90),
		Color3.fromRGB(120, 110, 100), Color3.fromRGB(140, 60, 60) }, legs = { Color3.fromRGB(40, 40, 46),
		Color3.fromRGB(70, 66, 60) } },
	cleaner = { name = "Cleaner", speed = 1.0, torso = { Color3.fromRGB(60, 100, 160) },
		legs = { Color3.fromRGB(40, 70, 120) } },
	cook = { name = "Cook", speed = 1.0, torso = { Color3.fromRGB(235, 235, 232) },
		legs = { Color3.fromRGB(60, 60, 64) } },
}

local function pick<T>(list: { T }): T
	return list[math.random(#list)]
end

-- Helpers -------------------------------------------------------------------------------------------------------

local function remote(name: string): RemoteEvent?
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	return remotes and remotes:FindFirstChild(name) :: RemoteEvent?
end

local function playerRoots(): { BasePart }
	local list = {}
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local root = c and c:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			table.insert(list, root)
		end
	end
	return list
end

local function sameFloor(a: Vector3, b: Vector3): boolean
	return math.abs(a.Y - b.Y) < S(Config.FLOOR_HEIGHT * 0.6)
end

-- Is `at` a good place for someone new to appear: near a player, not right next to one.
local function goodSpot(at: Vector3, roots: { BasePart }): boolean
	local near = false
	for _, r in roots do
		local d = (r.Position - at).Magnitude
		if d < NOT_TOO_NEAR then
			return false
		end
		if d < NEAR then
			near = true
		end
	end
	return near
end

local function nearestPlayerDistance(at: Vector3, roots: { BasePart }): number
	local best = math.huge
	for _, r in roots do
		best = math.min(best, (r.Position - at).Magnitude)
	end
	return best
end

local function freeSeat(seats: { Seat }): Seat?
	local free = {}
	for _, seat in seats do
		if not seat.Occupant and not seat:GetAttribute("Claimed") then
			table.insert(free, seat)
		end
	end
	return if #free > 0 then pick(free) else nil
end

local function standUp(person: Person)
	local seat = person.seat
	if seat then
		seat:SetAttribute("Claimed", nil)
		person.seat = nil
	end
	if person.humanoid.Sit then
		person.humanoid.Sit = false
		person.humanoid.Jump = true
		task.wait(0.3)
	end
end

local function sitOn(person: Person, seat: Seat)
	person.seat = seat
	seat:SetAttribute("Claimed", true)
	seat:Sit(person.humanoid)
end

local function remove(person: Person)
	if person.seat then
		person.seat:SetAttribute("Claimed", nil)
	end
	people[person.model] = nil
	Npc.remove(person.model)
end

local function spawnPerson(role: string, at: CFrame, name: string?): Person
	local info = ROLE[role] or ROLE.student
	local torso = if info.torso then pick(info.torso) else pick(CASUAL)
	local legs = if info.legs then pick(info.legs) else pick(JEANS)
	local young = role == "student" or role == "classmate" or role == "victim"
	local model = Npc.build(name or info.name, torso, legs, at, folder, {
		skin = pick(SKINS),
		height = if young then 0.9 + math.random() * 0.15 else 1 + math.random() * 0.08,
		width = 0.9 + math.random() * 0.15,
		nameless = true,
	})
	model:SetAttribute("Role", role)
	if role == "teacher" then
		CollectionService:AddTag(model, "Teacher")
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "People"
		end
	end
	local person: Person = {
		model = model,
		humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid,
		root = model:FindFirstChild("HumanoidRootPart") :: BasePart,
		role = role,
		name = name,
	}
	people[model] = person
	return person
end

local function pointsNear(from: Vector3, minD: number, maxD: number, list: { Vector3 }): { Vector3 }
	local out = {}
	for _, p in list do
		local d = (p - from).Magnitude
		if d >= minD and d <= maxD and sameFloor(p, from) then
			table.insert(out, p)
		end
	end
	return out
end

local function nearestClassroomWithSeat(from: Vector3): ({ Seat }?, Vector3?)
	local best, bestD, bestCentre = nil, math.huge, nil
	for _, room in classrooms do
		local d = (room.centre - from).Magnitude + (if sameFloor(room.centre, from) then 0 else S(40))
		if d < bestD and freeSeat(room.seats) then
			best, bestD, bestCentre = room.seats, d, room.centre
		end
	end
	return best, bestCentre
end

-- Day behaviour -------------------------------------------------------------------------------------------------

local function lessonOn(): boolean
	return scene == "lesson" or (scene == "lobby" and lobbyLesson)
end

local function lessonRoomSeats(): { Seat }?
	local key = ReplicatedStorage:GetAttribute("CampaignLessonRoom")
	return if type(key) == "string" then school.seats[key] else nil
end

local function wanderTo(person: Person, list: { Vector3 }, minD: number, maxD: number, speed: number): boolean
	local options = pointsNear(person.root.Position, minD, maxD, list)
	if #options == 0 then
		return false
	end
	return Npc.walkTo(person.model, pick(options) + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)), speed)
end

local function idle(seconds: number, person: Person, sceneAtStart: string)
	local stop = os.clock() + seconds
	while os.clock() < stop and person.model.Parent and scene == sceneAtStart
		and lessonOn() == (person.scene == "lesson") do
		task.wait(0.5)
	end
end

local function studentStep(person: Person)
	local now = scene
	if lessonOn() then
		person.scene = "lesson"
		if person.seat and person.humanoid.Sit then
			idle(5, person, now)
			return
		end
		-- The story's lesson room fills first, then the nearest classroom with a free chair.
		local seats = lessonRoomSeats()
		local seat = seats and freeSeat(seats)
		if not seat or (seat.Position - person.root.Position).Magnitude > S(45) then
			local near = nearestClassroomWithSeat(person.root.Position)
			seat = near and freeSeat(near)
		end
		if not seat then
			idle(4, person, now)
			return
		end
		seat:SetAttribute("Claimed", true)
		person.seat = seat
		Npc.walkTo(person.model, seat.Position + Vector3.new(0, 2, 0), 1.6)
		-- A player may have sat down there while the classmate was walking over.
		if person.model.Parent and lessonOn() and person.seat == seat and not seat.Occupant then
			sitOn(person, seat)
		elseif person.seat == seat and seat.Occupant ~= person.humanoid then
			person.seat = nil
		end
		return
	end
	person.scene = "break"
	if person.role == "classmate" then
		person.role = "student" -- after the lesson the class mixes with everyone else
		person.model:SetAttribute("Role", "student")
	end
	standUp(person)
	local r = math.random()
	if r < 0.5 then
		wanderTo(person, corridor, S(4), S(30), 1.35)
	elseif r < 0.75 then
		-- Join someone else for a chat.
		local other: Person? = nil
		for _, p in people do
			if p ~= person and p.role == "student" and sameFloor(p.root.Position, person.root.Position)
				and (p.root.Position - person.root.Position).Magnitude < S(20) then
				other = p
				break
			end
		end
		if other then
			local offset = (person.root.Position - other.root.Position).Unit * S(0.9)
			if offset ~= offset then
				offset = Vector3.new(S(0.9), 0, 0)
			end
			Npc.walkTo(person.model, other.root.Position + offset, 1.3)
			person.root.CFrame = CFrame.lookAt(person.root.Position,
				Vector3.new(other.root.Position.X, person.root.Position.Y, other.root.Position.Z))
		end
	end
	idle(5 + math.random() * 12, person, now)
end

local function teacherStep(person: Person)
	local now = scene
	standUp(person)
	if lessonOn() then
		person.scene = "lesson"
		-- Stand at the front of a classroom near them.
		local _, centre = nearestClassroomWithSeat(person.root.Position)
		if centre then
			Npc.walkTo(person.model, centre + Vector3.new(math.random(-4, 4), 0, math.random(-4, 4)), 1.2)
		end
		idle(30 + math.random() * 30, person, now)
		return
	end
	person.scene = "break"
	if #offices > 0 and math.random() < 0.4 then
		local options = pointsNear(person.root.Position, S(4), S(40), offices)
		if #options > 0 then
			Npc.walkTo(person.model, pick(options), 1.2)
		end
	else
		wanderTo(person, corridor, S(4), S(25), 1.2)
	end
	idle(8 + math.random() * 14, person, now)
end

local function cleanerStep(person: Person)
	local now = scene
	person.scene = if lessonOn() then "lesson" else "break"
	wanderTo(person, corridor, S(3), S(14), 0.9)
	idle(8 + math.random() * 12, person, now) -- mopping
end

local function cookStep(person: Person)
	local now = scene
	person.scene = if lessonOn() then "lesson" else "break"
	local options = pointsNear(person.root.Position, 0, S(15), kitchens)
	if #options > 0 then
		Npc.walkTo(person.model, pick(options) + Vector3.new(math.random(-4, 4), 0, math.random(-4, 4)), 0.9)
	end
	idle(6 + math.random() * 10, person, now)
end

local STEPS = {
	student = studentStep,
	classmate = studentStep,
	teacher = teacherStep,
	cleaner = cleanerStep,
	cook = cookStep,
}

local function leave(person: Person)
	-- Out of the door, or gone after 40 s whatever happens (nobody stays behind in the empty school).
	task.delay(40, function()
		if person.model.Parent then
			remove(person)
		end
	end)
	standUp(person)
	Npc.walkTo(person.model, exit, 1.7)
	if person.model.Parent then
		remove(person)
	end
end

local function run(person: Person)
	task.spawn(function()
		while person.model.Parent and people[person.model] do
			if scene == "leave" then
				leave(person)
				return
			end
			local step = STEPS[person.role]
			if not step then
				return
			end
			local ok, err = pcall(step, person)
			if not ok then
				warn("[people] " .. tostring(err))
				task.wait(2)
			end
			task.wait()
		end
	end)
end

-- Who should be in the school now, and where a new one appears.
local function wanted(): { [string]: number }
	if scene == "lobby" then
		return { student = 16, teacher = 3, cleaner = 2, cook = if #kitchens > 0 then 2 else 0 }
	elseif scene == "lesson" or scene == "break" then
		return { student = 14, classmate = if scene == "lesson" and lessonRoomSeats() then 8 else 0, teacher = 0,
			cleaner = 2, cook = if #kitchens > 0 then 2 else 0 }
	end
	return {}
end

local function spawnSpot(role: string, roots: { BasePart }): (CFrame?, Seat?)
	if role == "cook" then
		return if #kitchens > 0 then CFrame.new(pick(kitchens)) else nil, nil
	end
	if role == "classmate" then
		local lessonSeats = lessonRoomSeats()
		local seat = lessonSeats and freeSeat(lessonSeats)
		return if seat then seat.CFrame + Vector3.new(0, 2, 0) else nil, seat
	end
	if role == "student" and lessonOn() then
		local options = {}
		-- A class sits together: fill the fullest classroom near a player before starting another one.
		for _, room in classrooms do
			if goodSpot(room.centre, roots) and freeSeat(room.seats) then
				table.insert(options, room)
			end
		end
		local function taken(room): number
			local n = 0
			for _, seat in room.seats do
				if seat.Occupant or seat:GetAttribute("Claimed") then
					n += 1
				end
			end
			return n
		end
		table.sort(options, function(a, b)
			return taken(a) > taken(b)
		end)
		local room = options[1]
		if room and math.random() < 0.3 then
			room = pick(options)
		end
		local seat = room and freeSeat(room.seats)
		if seat then
			return seat.CFrame + Vector3.new(0, 2, 0), seat
		end
		return nil, nil
	end
	local options = {}
	for _, p in corridor do
		if goodSpot(p, roots) then
			table.insert(options, p)
		end
	end
	if #options == 0 then
		return nil, nil
	end
	return CFrame.new(pick(options) + Vector3.new(math.random(-2, 2), 0, math.random(-2, 2)))
		* CFrame.Angles(0, math.random() * math.pi * 2, 0), nil
end

local function keepCrowd()
	local roots = playerRoots()
	local counts: { [string]: number } = {}
	for _, person in people do
		if person.role ~= "victim" then
			-- Far from everyone: take them away (the kitchen staff and the lesson's class stay where they are).
			local stays = person.role == "cook" or person.role == "classmate"
			if #roots == 0 or (not stays and nearestPlayerDistance(person.root.Position, roots) > FAR) then
				remove(person)
			else
				counts[person.role] = (counts[person.role] or 0) + 1
			end
		end
	end
	if #roots == 0 then
		return
	end
	local made = 0
	for role, n in wanted() do
		while (counts[role] or 0) < n and made < 4 do
			local at, seat = spawnSpot(role, roots)
			if not at then
				break
			end
			local person = spawnPerson(role, at)
			if seat then
				sitOn(person, seat)
				person.scene = "lesson"
			end
			run(person)
			counts[role] = (counts[role] or 0) + 1
			made += 1
		end
	end
end

local function clearCrowd()
	for _, person in people do
		if person.role ~= "victim" then
			remove(person)
		end
	end
end

-- Victims -------------------------------------------------------------------------------------------------------

local function dropBody(person: Person)
	local model = person.model
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		elseif d:IsA("ProximityPrompt") then
			d:Destroy()
		end
	end
	model:PivotTo(model:GetPivot() * CFrame.new(0, -S(0.75), 0) * CFrame.Angles(-math.pi / 2, 0, 0))
	model.Name = "Body"
	local hooks = victimHooks
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Report"
	prompt.ActionText = "Report body"
	prompt.ObjectText = person.name or "Student"
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = S(3) + 2
	prompt:SetAttribute("For", "living")
	prompt.Triggered:Connect(function(by)
		local root = by.Character and by.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hooks and hooks.report and root and (root.Position - person.root.Position).Magnitude < S(3) + 8 then
			hooks.report(by, person.name or "Student")
		end
	end)
	prompt.Parent = person.root
	people[model] = nil
	table.insert(bodies, model)
end

local function take(person: Person, by: Player?)
	local hooks = victimHooks
	if person.taken or not hooks then
		return
	end
	person.taken = true
	Npc.stop(person.model)
	local at = person.root.Position
	local sound = remote("Sound")
	if sound then
		sound:FireAllClients("scream", at)
	end
	local flicker = remote("Flicker")
	if flicker then
		flicker:FireAllClients(at, 1.6)
	end
	if hooks.onTaken then
		hooks.onTaken(by, person.name or "Student", at)
	end
	if hooks.bodies then
		dropBody(person)
	else
		task.delay(0.25, function()
			remove(person)
		end)
	end
end

local function fleePoint(from: Vector3, threat: Vector3): Vector3?
	local best, bestScore = nil, -math.huge
	local candidates = pointsNear(from, S(6), S(30), corridor)
	for _, room in classrooms do
		if sameFloor(room.centre, from) and (room.centre - from).Magnitude < S(30) then
			table.insert(candidates, room.centre)
		end
	end
	for _, p in candidates do
		local away = (p - threat).Magnitude
		-- Never run towards the entity: the point must be farther from it than from here.
		if away > (from - threat).Magnitude then
			local score = away - (p - from).Magnitude * 0.3
			if score > bestScore then
				best, bestScore = p, score
			end
		end
	end
	return best
end

local function runVictim(person: Person)
	local root = person.root
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Take"
	prompt.ActionText = "Take"
	prompt.ObjectText = person.name or "Student"
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = S(2.5) + 2
	prompt:SetAttribute("For", "entity")
	prompt.Triggered:Connect(function(by)
		local hooks = victimHooks
		local from = by.Character and by.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hooks and hooks.active() and hooks.canTake(by) and from
			and (from.Position - root.Position).Magnitude < S(2.5) + 4 then
			take(person, by)
		end
	end)
	prompt.Parent = root

	task.spawn(function()
		local nextPlan = 0
		local nextWander = os.clock() + math.random() * 5
		local wasActive = false
		while person.model.Parent and not person.taken and people[person.model] do
			local hooks = victimHooks
			if not hooks then
				break
			end
			local now = os.clock()
			local active = hooks.active()
			if not active then
				if wasActive then
					Npc.stop(person.model)
				end
			else
				local computer = hooks.computer()
				if computer and (computer.Position - root.Position).Magnitude < S(2.2) then
					take(person, nil)
					break
				end
				-- The nearest threat on this floor.
				local threat, threatD = nil, math.huge
				for _, t in hooks.threats() do
					local d = (t - root.Position).Magnitude
					if d < threatD and sameFloor(t, root.Position) then
						threat, threatD = t, d
					end
				end
				if threat and threatD < FLEE_RANGE then
					if now >= nextPlan then
						nextPlan = now + 1.5
						local to = fleePoint(root.Position, threat)
						if to then
							Npc.goTo(person.model, to, 3.6)
						end
					end
				elseif now >= nextWander then
					nextWander = now + 8 + math.random() * 10
					local options = pointsNear(root.Position, S(4), S(20), corridor)
					if #options > 0 then
						Npc.goTo(person.model, pick(options), 1.1)
					end
				end
			end
			wasActive = active
			task.wait(0.25)
		end
	end)
end

local victimRound = 0

-- Building characters yields, so the students appear in the background (the mode's start goes on at once).
function People.startVictims(hooks: VictimHooks)
	People.stopVictims()
	clearCrowd()
	victimHooks = hooks
	victimRound += 1
	local myRound = victimRound
	task.spawn(function()
		local spots = table.clone(corridor)
		for i = 1, hooks.count do
			if #spots == 0 or victimRound ~= myRound then
				break
			end
			local at = table.remove(spots, math.random(#spots)) :: Vector3
			local person = spawnPerson("victim", CFrame.new(at) * CFrame.Angles(0, math.random() * math.pi * 2, 0),
				"Classmate " .. string.char(64 + i))
			if victimRound ~= myRound then
				remove(person) -- the round ended while this one was being built
				break
			end
			person.model:SetAttribute("Victim", true)
			runVictim(person)
		end
	end)
end

function People.clearBodies()
	for _, b in bodies do
		b:Destroy()
	end
	bodies = {}
end

function People.stopVictims()
	victimRound += 1
	victimHooks = nil
	for _, person in people do
		if person.role == "victim" then
			remove(person)
		end
	end
	People.clearBodies()
end

-- Is (x, z) (world metres) inside a room (named or not, other than a corridor piece) or a courtyard of a floor?
local function inRoomOrSolid(floor: number, x: number, z: number): boolean
	local f = FloorData.FLOORS[floor + 1]
	local function inside(x0: number, y0: number, x1: number, y1: number): boolean
		local ax, az = FloorData.toWorld(floor, x0, y0)
		local bx, bz = FloorData.toWorld(floor, x1, y1)
		return x >= math.min(ax, bx) and x <= math.max(ax, bx) and z >= math.min(az, bz) and z <= math.max(az, bz)
	end
	for _, r in f.rooms do
		if r.kind ~= "corridor" and inside(r.x0, r.y0, r.x1, r.y1) then
			return true
		end
	end
	for _, b in f.solids do
		if inside(b.x0, b.y0, b.x1, b.y1) then
			return true
		end
	end
	return false
end

-- Walking points: every 3 m of corridor floor (not in a room, a courtyard or a stairwell) with nothing standing
-- there, checked against the built school.
local function sampleCorridors(): { Vector3 }
	local list = {}
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { folder }
	local boxParams = OverlapParams.new()
	boxParams.FilterType = Enum.RaycastFilterType.Exclude
	boxParams.FilterDescendantsInstances = { folder }
	for i, f in FloorData.FLOORS do
		local floor = i - 1
		local ax, az = FloorData.toWorld(floor, f.rect.x0, f.rect.y0)
		local bx, bz = FloorData.toWorld(floor, f.rect.x1, f.rect.y1)
		local y = floor * Config.FLOOR_HEIGHT
		for x = math.min(ax, bx) + 1, math.max(ax, bx) - 1, 3 do
			for z = math.min(az, bz) + 1, math.max(az, bz) - 1, 3 do
				if not inRoomOrSolid(floor, x, z) then
					local hit = workspace:Raycast(Vector3.new(S(x), S(y + 1.5), S(z)), Vector3.new(0, -S(2), 0), rayParams)
					if hit and hit.Instance.Name == "Floor" then
						local clear = true
						for _, part in workspace:GetPartBoundsInBox(CFrame.new(S(x), hit.Position.Y + S(1.1), S(z)),
							Vector3.new(S(1.4), S(1.6), S(1.4)), boxParams) do
							if part.CanCollide then
								clear = false
								break
							end
						end
						if clear then
							table.insert(list, Vector3.new(S(x), hit.Position.Y + 3, S(z)))
						end
					end
				end
			end
		end
	end
	return list
end

-- Scenes --------------------------------------------------------------------------------------------------------

local function sceneNow(): string
	local mode = ReplicatedStorage:GetAttribute("Mode")
	local phase = ReplicatedStorage:GetAttribute("Phase")
	if mode == nil or mode == "none" or mode == "freeroam" then
		return if ReplicatedStorage:GetAttribute("CrowdOff") then "night" else "lobby"
	elseif mode == "campaign" then
		if ReplicatedStorage:GetAttribute("CampaignExploded") then
			return "leave"
		elseif phase == "grace" or phase == "lesson" then
			return "lesson"
		elseif phase == "arrive" or phase == "break" then
			return "break"
		end
		return "leave"
	end
	return "night"
end

function People.init(schoolData)
	school = schoolData
	folder = Instance.new("Folder")
	folder.Name = "People"
	folder.Parent = workspace
	exit = school.spawn.Position

	-- People walk through each other (a crowd never jams a doorway), but players bump into them (NpcReactions).
	pcall(function()
		PhysicsService:RegisterCollisionGroup("People")
		PhysicsService:RegisterCollisionGroup("PlayerChars")
		PhysicsService:CollisionGroupSetCollidable("People", "People", false)
		PhysicsService:CollisionGroupSetCollidable("People", "PlayerChars", true)
	end)
	local function mark(character: Model)
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") then
				d.CollisionGroup = "PlayerChars"
			end
		end
		character.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") then
				d.CollisionGroup = "PlayerChars"
			end
		end)
	end
	local function watch(player: Player)
		player.CharacterAdded:Connect(mark)
		if player.Character then
			mark(player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end

	corridor = sampleCorridors()
	local perFloor = { 0, 0, 0 }
	for _, p in corridor do
		local f = FloorData.floorAt(p.Y / Config.STUDS_PER_METRE) + 1
		perFloor[f] = (perFloor[f] or 0) + 1
	end
	print(`[people] walking points per floor: {table.concat(perFloor, ", ")}`)
	for _, p in school.patrol do
		table.insert(corridor, p + Vector3.new(0, 3, 0))
	end
	for _, room in school.rooms do
		local key = `{room.floor}:{room.label}`
		local seats = school.seats[key]
		if (room.kind == "normal" or room.kind == "computer" or room.kind == "lab") and seats and #seats > 0 then
			table.insert(classrooms, { key = key, floor = room.floor, centre = room.centre, seats = seats })
		elseif room.kind == "kitchen" or room.kind == "dining" then
			table.insert(kitchens, room.centre)
		elseif room.kind == "office" then
			table.insert(offices, room.centre)
		end
	end

	task.spawn(function()
		local lastCrowd = 0
		while true do
			local before = scene
			scene = sceneNow()
			if scene == "lobby" and os.clock() >= lobbyFlipAt then
				lobbyLesson = not lobbyLesson
				lobbyFlipAt = os.clock() + (if lobbyLesson then LOBBY_LESSON else LOBBY_BREAK)
				local sound = remote("Sound")
				if lobbyLesson and sound and #Players:GetPlayers() > 0 and before == "lobby" then
					sound:FireAllClients("bell")
				end
				for _, person in people do
					if person.role ~= "victim" then
						Npc.stop(person.model)
					end
				end
			end
			if scene ~= before then
				if scene == "night" or before == "night" then
					clearCrowd()
				end
				if before == "night" and scene ~= "night" then
					People.stopVictims()
				end
				-- Everyone reconsiders what to do now.
				for _, person in people do
					if person.role ~= "victim" then
						Npc.stop(person.model)
					end
				end
			end
			if (scene == "lobby" or scene == "lesson" or scene == "break") and os.clock() - lastCrowd >= 2 then
				lastCrowd = os.clock()
				keepCrowd()
			end
			task.wait(0.5)
		end
	end)
end

return People
