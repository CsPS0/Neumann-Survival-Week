-- Social Deduction (HORROR-GAME/docs/multiplayer-modes.md, match.gd): one secret entity (two at 8+ players) among
-- the crew. Everyone looks the same and shows a tag ("Student 1", "Teacher 2"). The entity takes people down with E
-- (20 s into the night, then every 30 s). A body report or the meeting key starts a meeting with the room log of the
-- last minute and a vote; more than half of the living players' votes ejects someone.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local FloorData = require(ReplicatedStorage.Shared.FloorData)
local RoomLog = require(ReplicatedStorage.Shared.RoomLog)
local Rules = require(ReplicatedStorage.Shared.Rules)
local Characters = require(script.Parent.Characters)
local ChatControl = require(script.Parent.ChatControl)
local Lockers = require(script.Parent.Lockers)
local People = require(script.Parent.People)

local D = Config.Deduction
local S = Config.studs

local SocialDeduction = {}

local ctx = nil
local round = 0
local roles: { [Player]: string } = {}
local alive: { [Player]: boolean } = {}
local tagOf: { [Player]: string } = {}
local playerOf: { [string]: Player } = {}
local readyAt: { [Player]: number } = {}
local meetingUsed: { [Player]: boolean } = {}
local prompts: { Instance } = {}
local bodies: { Model } = {}
local log = RoomLog.new()
local votes: { [string]: string } = {}
local nightStart = 0
local nightLeft = 0
local meetingOpen = false
local resolved = false -- the open meeting's vote is counted; no more votes until the next meeting
local lastVictim: string? = nil
local connections: { RBXScriptConnection } = {}

local function remote(name: string): RemoteEvent
	return ctx.remotes:FindFirstChild(name) :: RemoteEvent
end

local function now(): number
	return os.clock()
end

local function counts(): (number, number)
	local entities, crew = 0, 0
	for p, isAlive in alive do
		if isAlive then
			if roles[p] == "entity" then
				entities += 1
			else
				crew += 1
			end
		end
	end
	return entities, crew
end

local function livingTags(): { string }
	local list = {}
	for p, isAlive in alive do
		if isAlive then
			table.insert(list, tagOf[p])
		end
	end
	table.sort(list)
	return list
end

local function entityTags(): string
	local list = {}
	for p, role in roles do
		if role == "entity" then
			table.insert(list, tagOf[p])
		end
	end
	table.sort(list)
	return table.concat(list, " and ")
end

local function check(timeUp: boolean): boolean
	local entities, crew = counts()
	local result = Rules.deductionResult(entities, crew, timeUp)
	if not result then
		return false
	end
	local reveal = entityTags()
	local many = #string.split(reveal, " and ") > 1
	local summary = if result == "crew"
		then `The crew wins! {if many then "The entities were" else "The entity was"} {reveal}.`
		else `{if many then "The entities win" else "The entity wins"}. It was {reveal}.`
	ctx.finish(summary)
	return true
end

-- Out of the round: no character, spectating, chatting only with the other players who are out.
local function eliminate(player: Player)
	if not alive[player] then
		return
	end
	alive[player] = false
	Lockers.release(player)
	if player.Parent then
		player:SetAttribute("State", "out")
		task.spawn(ChatControl.setOut, player, true) -- Joining the channel yields; nothing waits for it.
	end
	for i = #prompts, 1, -1 do
		if prompts[i]:GetAttribute("Owner") == player.UserId then
			prompts[i]:Destroy()
			table.remove(prompts, i)
		end
	end
	Characters.despawn(player)
end

local function tagBillboard(player: Player)
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not head then
		return
	end
	local board = Instance.new("BillboardGui")
	board.Name = "Tag"
	board.Size = UDim2.fromOffset(140, 26)
	board.StudsOffset = Vector3.new(0, 2, 0)
	board.MaxDistance = S(14)
	board.Parent = head
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.3
	text.TextScaled = true
	text.Font = Enum.Font.GothamMedium
	text.Text = tagOf[player]
	text.Parent = board
	local humanoid = Characters.humanoid(player)
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

-- Only the votes of players still alive count (a voter who left or was taken out no longer does).
local function livingVotes(): { [string]: string }
	local out = {}
	for voter, target in votes do
		local p = playerOf[voter]
		if p and alive[p] and p.Parent then
			out[voter] = target
		end
	end
	return out
end

local function allVoted(): boolean
	local n = 0
	for _ in livingVotes() do
		n += 1
	end
	return n >= #livingTags()
end

local startMeeting: (callerTag: string, victimTag: string?) -> ()

local function dropBody(victim: Player): Model?
	local character = victim.Character
	if not character then
		return nil
	end
	character.Archivable = true
	local body = character:Clone()
	body.Name = "Body"
	for _, d in body:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ProximityPrompt") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	local humanoid = body:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	-- Lying on the floor.
	body:PivotTo(character:GetPivot() * CFrame.new(0, -S(0.75), 0) * CFrame.Angles(-math.pi / 2, 0, 0))
	body:SetAttribute("Victim", tagOf[victim])
	local root = body:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Report"
		prompt.ActionText = "Report body"
		prompt.ObjectText = tagOf[victim]
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = S(3) + 2
		prompt:SetAttribute("For", "living")
		prompt.Triggered:Connect(function(by)
			local from = Characters.root(by)
			if alive[by] and not meetingOpen and ReplicatedStorage:GetAttribute("Phase") == "night"
				and from and (from.Position - (root :: BasePart).Position).Magnitude < S(3) + 8 then
				startMeeting(tagOf[by], tagOf[victim])
			end
		end)
		prompt.Parent = root
	end
	body.Parent = workspace
	table.insert(bodies, body)
	return body
end

local function takedown(by: Player, victim: Player)
	local t = now()
	if not alive[by] or roles[by] ~= "entity" or not alive[victim] or roles[victim] == "entity" or meetingOpen
		or ReplicatedStorage:GetAttribute("Phase") ~= "night" or t < (readyAt[by] or math.huge)
		or Lockers.isHidden(victim) then
		return
	end
	local a, b = Characters.root(by), Characters.root(victim)
	if not a or not b or (a.Position - b.Position).Magnitude > S(2.5) + 4 then
		return
	end
	readyAt[by] = Rules.takedownReadyAt(nightStart, t, D.firstTakedown, D.takedownCooldown)
	local where = b.Position
	lastVictim = tagOf[victim]
	dropBody(victim)
	eliminate(victim)
	remote("Flicker"):FireAllClients(where, D.flickerTime)
	remote("Sound"):FireAllClients("sting", where)
	if victim.Parent then
		ctx.banner("You were taken down. You are out; you can chat with the others who are out.", 6, victim)
	end
	check(false)
end

local function addTakedownPrompt(player: Player)
	local root = Characters.root(player)
	if not root then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Takedown"
	prompt.ActionText = "Take down"
	prompt.ObjectText = tagOf[player]
	prompt.RequiresLineOfSight = false -- The target's own body would block the test; the server checks distance.
	prompt.MaxActivationDistance = S(2.5) + 2
	prompt:SetAttribute("For", "entity")
	prompt:SetAttribute("Owner", player.UserId)
	prompt.Triggered:Connect(function(by)
		takedown(by, player)
	end)
	prompt.Parent = root
	table.insert(prompts, prompt)
end

local function placeEveryone()
	local i = 0
	for _, p in ctx.players do
		if alive[p] then
			i += 1
			Characters.place(p, ctx.spawnAt(i))
		end
	end
end

local function freezeAll(on: boolean)
	for p, isAlive in alive do
		if isAlive and p.Parent then
			Characters.freeze(p, on)
		end
	end
end

local function night(seconds: number)
	freezeAll(false)
	ctx.setPhase("night", seconds, function()
		check(true)
	end)
end

local endMeeting: () -> ()

startMeeting = function(callerTag: string, victimTag: string?)
	if meetingOpen or not ctx then
		return
	end
	meetingOpen = true
	resolved = false
	nightLeft = ctx.remaining()
	Lockers.releaseAll()
	freezeAll(true)
	for _, b in bodies do
		b:Destroy()
	end
	bodies = {}
	People.clearBodies()
	votes = {}
	ChatControl.setMeeting(true)
	local t = now()
	local entries = {}
	local function addLog(tag: string)
		local list = {}
		for _, e in log:recent(tag, t, D.logAge) do
			table.insert(list, { label = e.label, ago = math.max(0, math.round(t - e.t)) })
		end
		entries[tag] = list
	end
	local living = livingTags()
	for _, tag in living do
		addLog(tag)
	end
	if victimTag then
		addLog(victimTag)
	end
	remote("MeetingStarted"):FireAllClients({
		caller = callerTag,
		victim = victimTag,
		living = living,
		log = entries,
		seconds = D.meeting,
	})
	ctx.setPhase("meeting", D.meeting, endMeeting)
end

endMeeting = function()
	if not meetingOpen or resolved or not ctx then
		return
	end
	resolved = true
	local living = #livingTags()
	local ejectedTag, tally = Rules.tallyVotes(livingVotes(), living)
	local wasEntity = nil
	if ejectedTag then
		local p = playerOf[ejectedTag]
		wasEntity = p ~= nil and roles[p] == "entity"
		if p then
			eliminate(p)
		end
	end
	remote("MeetingResult"):FireAllClients(ejectedTag, wasEntity, tally)
	local myRound = round
	ctx.setPhase("meeting", D.meetingResult, function()
		if myRound ~= round or not ctx then
			return
		end
		meetingOpen = false
		ChatControl.setMeeting(false)
		if check(false) then
			return
		end
		placeEveryone()
		night(math.max(nightLeft, 5))
	end)
end

local function trackRooms()
	local myRound = round
	task.spawn(function()
		while myRound == round and ctx do
			task.wait(1)
			if myRound ~= round or not ctx then
				break
			end
			if ReplicatedStorage:GetAttribute("Phase") == "night" then
				local t = now()
				for p, isAlive in alive do
					local root = isAlive and Characters.root(p)
					if root then
						local m = root.Position / Config.STUDS_PER_METRE
						local floor = FloorData.floorAt(m.Y)
						log:record(tagOf[p], FloorData.logLabel(floor, m.X, m.Z), t)
					end
				end
			end
		end
	end)
end

function SocialDeduction.start(c)
	ctx = c
	round += 1
	roles, alive, tagOf, playerOf, readyAt, meetingUsed = {}, {}, {}, {}, {}, {}
	prompts, bodies, votes = {}, {}, {}
	log:clear()
	meetingOpen = false
	lastVictim = nil

	local order = table.clone(c.players)
	for i = #order, 2, -1 do
		local j = math.random(i)
		order[i], order[j] = order[j], order[i]
	end
	local entityCount = Rules.entityCount(#order, D.secondEntityAt)
	local students, teachers = 0, 0
	for i, p in order do
		roles[p] = if i <= entityCount then "entity" else "crew"
		alive[p] = true
	end
	-- Tags in a fresh random order, so the entities are not always "Student 1".
	for i = #order, 2, -1 do
		local j = math.random(i)
		order[i], order[j] = order[j], order[i]
	end
	for i, p in order do
		local tag
		if i % 2 == 1 then
			students += 1
			tag = `Student {students}`
		else
			teachers += 1
			tag = `Teacher {teachers}`
		end
		tagOf[p] = tag
		playerOf[tag] = p
		p:SetAttribute("Tag", tag)
		tagBillboard(p)
	end
	for p, role in roles do
		local partner = nil
		if role == "entity" then
			for q, r in roles do
				if q ~= p and r == "entity" then
					partner = tagOf[q]
				end
			end
		end
		remote("Role"):FireClient(p, role, partner)
		-- On everyone, entities too: a character without one would give the entity away. The server rejects.
		addTakedownPrompt(p)
	end
	Lockers.canHide = function(p: Player): boolean
		return alive[p] == true and not meetingOpen
	end
	ChatControl.setRound(true)

	table.insert(connections, remote("CallMeeting").OnServerEvent:Connect(function(player)
		if not ctx or not alive[player] or meetingOpen or ReplicatedStorage:GetAttribute("Phase") ~= "night" then
			return
		end
		if not Rules.canCallMeeting(now(), nightStart, meetingUsed[player] == true, D.meetingLockout) then
			ctx.banner(if meetingUsed[player] then "You already called a meeting this round."
				else "Too early for a meeting.", 3, player)
			return
		end
		meetingUsed[player] = true
		startMeeting(tagOf[player], nil)
	end))
	table.insert(connections, remote("Vote").OnServerEvent:Connect(function(player, target)
		if not ctx or not meetingOpen or resolved or not alive[player] or type(target) ~= "string" then
			return
		end
		local tag = tagOf[player]
		if votes[tag] then
			return
		end
		local target_ = target :: string
		if target_ ~= "skip" and not (playerOf[target_] and alive[playerOf[target_]]) then
			return
		end
		votes[tag] = target_
		if allVoted() then
			endMeeting()
		end
	end))

	-- A few students stayed late. They do not know who the entity is (running from one player would give it away),
	-- so they just wander; the entity can take one with E, which counts as its takedown, and leaves a body.
	People.startVictims({
		count = 4,
		threats = function(): { Vector3 }
			return {}
		end,
		computer = function(): BasePart?
			return nil
		end,
		canTake = function(by: Player): boolean
			return ctx ~= nil and alive[by] == true and roles[by] == "entity" and not meetingOpen
				and now() >= (readyAt[by] or math.huge)
		end,
		active = function(): boolean
			return ReplicatedStorage:GetAttribute("Phase") == "night" and not meetingOpen
		end,
		onTaken = function(by: Player?, name: string, _at: Vector3)
			if by then
				readyAt[by] = Rules.takedownReadyAt(nightStart, now(), D.firstTakedown, D.takedownCooldown)
			end
			lastVictim = name
		end,
		bodies = true,
		report = function(by: Player, name: string)
			if ctx and alive[by] and not meetingOpen and ReplicatedStorage:GetAttribute("Phase") == "night" then
				startMeeting(tagOf[by], name)
			end
		end,
	})

	freezeAll(true)
	c.banner(if entityCount > 1 then "Two entities hide among you. Watch the others." else "One of you is the entity. Watch the others.", 6)
	trackRooms()
	c.setPhase("brief", D.brief, function()
		nightStart = now()
		for p, role in roles do
			if role == "entity" then
				readyAt[p] = Rules.takedownReadyAt(nightStart, nil, D.firstTakedown, D.takedownCooldown)
			end
		end
		night(D.night)
	end)
end

local function gone(player: Player)
	if not ctx or alive[player] == nil then
		return
	end
	local wasAlive = alive[player]
	alive[player] = false
	if wasAlive and meetingOpen and not resolved then
		-- Their vote no longer counts; the meeting ends now if everyone left has voted.
		if allVoted() then
			endMeeting()
			return
		end
	end
	if not (meetingOpen and resolved) then
		check(false) -- During the result screen the win check runs when it ends.
	end
end

function SocialDeduction.playerLeft(player: Player)
	gone(player)
end

function SocialDeduction.playerDied(player: Player)
	if alive[player] then
		eliminate(player)
		check(false)
	else
		gone(player)
	end
end

function SocialDeduction.stop()
	round += 1
	People.stopVictims()
	for _, c in connections do
		c:Disconnect()
	end
	connections = {}
	for _, p in prompts do
		p:Destroy()
	end
	for _, b in bodies do
		b:Destroy()
	end
	prompts, bodies = {}, {}
	meetingOpen = false
	ChatControl.setRound(false)
	log:clear()
	ctx = nil
end

return SocialDeduction
