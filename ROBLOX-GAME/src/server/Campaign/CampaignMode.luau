-- The story campaign as one team day (docs/2026-11-20-campaign-design.md): arrive, lessons with quizzes, clues and
-- teachers in the breaks, Lab 14 explodes after the last lesson, the afternoon investigation, the accusation vote at
-- dusk, then the night hunt with the exorcism quest. One clock, one culprit and one shared ending for the server.
-- The difficulty (Difficulty.luau) sets how long and how demanding the run is.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CampaignData = require(ReplicatedStorage.Shared.CampaignData)
local CampaignRules = require(ReplicatedStorage.Shared.CampaignRules)
local Config = require(ReplicatedStorage.Shared.Config)
local Difficulty = require(ReplicatedStorage.Shared.Difficulty)
local FloorData = require(ReplicatedStorage.Shared.FloorData)
local Rules = require(ReplicatedStorage.Shared.Rules)
local Schedule = require(ReplicatedStorage.Shared.Schedule)
local Characters = require(script.Parent.Parent.Characters)
local Doors = require(script.Parent.Parent.Doors)
local EntityAI = require(script.Parent.Parent.EntityAI)
local EntityModel = require(script.Parent.Parent.EntityModel)
local Lockers = require(script.Parent.Parent.Lockers)
local Torch = require(script.Parent.Parent.Torch)
local Caretaker = require(script.Parent.Caretaker)
local Clues = require(script.Parent.Clues)
local Glimpses = require(script.Parent.Glimpses)
local Inventories = require(script.Parent.Inventories)
local Lessons = require(script.Parent.Lessons)
local Npc = require(script.Parent.Npc)
local Pickups = require(script.Parent.Pickups)
local Porter = require(script.Parent.Porter)
local Keys = require(script.Parent.Keys)
local AchievementService = require(script.Parent.Parent.AchievementService)
local Quest = require(script.Parent.Quest)
local Teachers = require(script.Parent.Teachers)
local Votes = require(script.Parent.Votes)

local S = Config.studs
local TICK = 0.1
local ACCUSE_SECONDS = 60
local CHOICE_SECONDS = 45
local REVIVE_WINDOW = 30
local REVIVE_HOLD = 3
local SOLO_PENALTY = 20 -- game minutes lost when a solo Easy player is caught
local ENTITY_HEAD_START = 10 -- seconds between nightfall and the entity waking
local DEAL_COOLDOWN = 60 -- seconds after a refused deal before the altar offers it again
local POWER_BANKS = 3 -- per run, in empty rooms

local CampaignMode = {}

local WAY_NAMES = { caught = "caught", expelled = "expelled", ranaway = "ran away" }

local ctx = nil
local run = nil

local function remote(name: string): RemoteEvent
	return ctx.remotes:FindFirstChild(name) :: RemoteEvent
end

-- Players still in the run and alive (not downed, not out).
local function alive(): { Player }
	local list = {}
	if not run then
		return list
	end
	for p in run.students do
		if p.Parent and p:GetAttribute("State") == "alive" then
			table.insert(list, p)
		end
	end
	return list
end

-- Alive or downed: everyone who has not gone out yet.
local function standing(): { Player }
	local list = {}
	if not run then
		return list
	end
	for p in run.students do
		local state = p:GetAttribute("State")
		if p.Parent and (state == "alive" or state == "downed") then
			table.insert(list, p)
		end
	end
	return list
end

local function changed()
	if run then
		run.dirty = true
	end
end

local function sound(name: string, at: Vector3?)
	remote("Sound"):FireAllClients(name, at)
end

local function setPhase(phase: string)
	if run.phase ~= phase then
		run.phase = phase
		ctx.setPhase(phase, 0)
		changed()
	end
end

-- The ending card for everyone, then the result phase and the lobby.
local function finishRun(id: number)
	if not run or run.over then
		return
	end
	run.over = true
	-- Everyone who took part in the run gets the ending's achievement.
	local took = {}
	for p in run.students do
		took[p] = true
	end
	for p in run.out do
		took[p] = true
	end
	for p in took do
		AchievementService.award(p, `ending_{id}`)
	end
	local ending = CampaignData.ENDINGS[id]
	local out = {}
	for p, way in run.out do
		table.insert(out, `{p.DisplayName} ({WAY_NAMES[way] or way})`)
	end
	remote("Ending"):FireAllClients({
		id = id,
		title = ending.title,
		color = ending.color,
		text = ending.text,
		stats = {
			difficulty = run.level.label,
			quiz = `{run.quizRight}/{run.quizTotal}`,
			clues = `{#run.clues}/{run.level.clues}`,
			time = Schedule.format(run.minutes),
			out = out,
		},
	})
	ctx.finish(`Ending {id}: {ending.title}`)
end

local function checkAllOut()
	if run and not run.over and #standing() == 0 then
		finishRun(CampaignRules.allOutEnding(run.lastWay))
	end
end

-- `way`: "caught", "expelled" or "ranaway".
local function markOut(player: Player, way: string, message: string?)
	if not run or run.out[player] or not run.students[player] then
		return
	end
	run.out[player] = way
	run.outIds[player.UserId] = true -- rejoining does not make you a student again
	run.lastWay = way
	run.downedAt[player] = nil
	for _, prompt in run.revivePrompts[player] or {} do
		prompt:Destroy()
	end
	run.revivePrompts[player] = nil
	Lockers.release(player)
	Inventories.spill(player, ctx.school.spawn.Position - Vector3.new(0, 3, 0)) -- nothing needed is lost
	if player.Parent then
		Characters.setSpeed(player, nil)
		player:SetAttribute("State", "out")
		Characters.despawn(player)
		ctx.banner(message or "You are out. Watch the others.", 6, player)
	end
	Votes.recheck()
	changed()
	checkAllOut()
end

-- Lessons ---------------------------------------------------------------------------------------------------------

local function lessonInfo(i: number): { subject: string, room: string, floor: number }?
	local subject = run.subjects[i + 1]
	if not subject then
		return nil
	end
	local info = CampaignData.SUBJECTS[subject]
	return { subject = subject, room = info.room, floor = info.floor }
end

local function onSkip(player: Player)
	if not Characters.root(player) then
		return -- joined a moment ago and is still loading
	end
	local n, expelled = CampaignRules.skip(run.skips[player.UserId] or 0, run.level.skipLimit)
	run.skips[player.UserId] = n
	if expelled then
		ctx.banner(`{player.DisplayName} skipped too many lessons and was expelled.`, 6)
		markOut(player, "expelled", "You skipped too many lessons: expelled. Watch the others.")
	else
		local limit = run.level.skipLimit
		local left = if limit == math.huge then "" else ` ({limit - n} more and you are expelled)`
		ctx.banner(`You skipped the lesson{left}.`, 5, player)
	end
	changed()
end

local function explode()
	run.exploded = true
	run.minutes = math.max(run.minutes, Schedule.AFTERNOON)
	local lab = Doors.find(CampaignData.STORY.lab.room, CampaignData.STORY.lab.floor)
	if lab then
		Doors.setLocked(lab, false)
		Doors.setOpen(lab, true)
	end
	local labPos = Pickups.spot(CampaignData.STORY.lab.floor, CampaignData.STORY.lab.room)
	sound("sting", labPos)
	remote("Sound"):FireAllClients("bell")
	ctx.banner("BOOM! Lab 14 exploded. Lessons are over; the teachers leave the building.", 8)
	if run.teachers then
		run.teachers:dismiss(ctx.school.spawn.Position)
	end
	run.clueSpawner:wave(3)
	if run.level.caretaker ~= "off" then
		local myRun = run
		local caretaker = Caretaker.new({
			folder = run.folder,
			patrol = ctx.school.patrol,
			alive = alive,
			speed = 2.6,
			onCatch = function(player)
				ctx.banner(`The caretaker caught {player.DisplayName}: expelled.`, 6)
				markOut(player, "expelled", "The caretaker caught you: expelled. Watch the others.")
			end,
		}, ctx.school.patrol[1] + Vector3.new(0, 3, 0))
		if run ~= myRun then
			caretaker:destroy() -- the run ended while the caretaker was built
			return
		end
		run.caretaker = caretaker
	end
	run.glimpses = Glimpses.new({
		folder = run.folder,
		alive = alive,
		look = run.look,
		minutes = function()
			return if run then run.minutes else 0
		end,
		patrol = ctx.school.patrol,
		sound = sound,
	})
	changed()
end

local function tickLessons()
	local count = #run.subjects
	local i = run.lessonIndex
	if run.exploded or i >= count then
		return
	end
	local start = Schedule.lessonStart(i)
	if run.lessonStage == "wait" then
		if run.minutes >= start then
			run.lessonStage = "grace"
			local info = lessonInfo(i) :: any
			remote("Sound"):FireAllClients("bell")
			ctx.banner(`The bell rings: {info.subject} in room {info.room}. Get in now!`, 6)
			changed()
		end
	end
	if run.lessonStage == "grace" then
		run.lessons:checkAttendance(i)
		if run.minutes >= start + Schedule.GRACE then
			local attending = run.lessons:closeAttendance(i)
			if not run or run.over then
				return -- the last player was expelled for skipping
			end
			run.attending = attending
			run.lessonStage = "lesson"
			if run.attending == 0 then
				run.minutes = math.max(run.minutes, Schedule.lessonEnd(i)) -- nobody in class: skip ahead
			end
			changed()
		end
	end
	if run.lessonStage == "lesson" then
		run.lessons:checkStanding(i)
		if run.attending > 0 and run.lessons:allDone(i) then
			run.minutes = math.max(run.minutes, Schedule.lessonEnd(i)) -- every attendee finished the quiz
		end
		if run.minutes >= Schedule.lessonEnd(i) then
			run.lessons:closeQuiz(i)
			run.breaks += 1
			run.lessonIndex = i + 1
			run.lessonStage = "wait"
			if run.lessonIndex >= count then
				explode()
				return
			end
			if run.lessonIndex == math.ceil(count / 2) then
				run.clueSpawner:wave(2)
			end
			run.teachers:sendFor(run.subjects[run.lessonIndex + 1])
			ctx.banner("Break. Look for clues and talk to the teachers (E).", 5)
			changed()
		end
	end
end

-- Night -----------------------------------------------------------------------------------------------------------

local function revive(player: Player, by: Player)
	if player:GetAttribute("State") ~= "downed" or by:GetAttribute("State") ~= "alive" then
		return
	end
	run.downedAt[player] = nil
	for _, prompt in run.revivePrompts[player] or {} do
		prompt:Destroy()
	end
	run.revivePrompts[player] = nil
	Characters.setSpeed(player, nil)
	player:SetAttribute("State", "alive")
	ctx.banner(`{by.DisplayName} got you up!`, 3, player)
	changed()
end

local function caught(player: Player)
	if not run or run.over or player:GetAttribute("State") ~= "alive" or Lockers.isHidden(player) then
		return
	end
	local root = Characters.root(player)
	sound("sting", root and root.Position)
	if not run.level.revive then
		ctx.banner(`The entity took {player.DisplayName}.`, 5)
		markOut(player, "caught", "The entity caught you. You are out; watch the others.")
		return
	end
	if #alive() <= 1 then
		-- Nobody left to revive you (solo, or the others are down): wake up at the entrance and lose some time.
		run.minutes = math.min(run.minutes + SOLO_PENALTY, Schedule.END - 1)
		Characters.place(player, ctx.spawnAt(1))
		ctx.banner("Everything went black... You wake up at the entrance. Time has passed.", 6, player)
		changed()
		return
	end
	player:SetAttribute("State", "downed")
	Characters.setSpeed(player, 0)
	Torch.off(player)
	ctx.banner(`The entity caught you! A teammate can get you up in {REVIVE_WINDOW} seconds.`, 6, player)
	if root then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Revive"
		prompt.ActionText = "Revive"
		prompt.ObjectText = player.DisplayName
		prompt.HoldDuration = REVIVE_HOLD
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = S(2.5) + 2
		prompt:SetAttribute("For", "living")
		prompt:SetAttribute("Owner", player.UserId)
		prompt.Triggered:Connect(function(by)
			local a, b = Characters.root(by), Characters.root(player)
			if a and b and (a.Position - b.Position).Magnitude < S(3) + 3 then
				revive(player, by)
			end
		end)
		prompt.Parent = root
		run.revivePrompts[player] = { prompt }
	end
	local stamp = os.clock()
	run.downedAt[player] = stamp
	local myRun = run
	task.delay(REVIVE_WINDOW * ctx.timeScale, function()
		if run == myRun and run.downedAt[player] == stamp and player:GetAttribute("State") == "downed" then
			markOut(player, "caught", "Nobody came. The entity took you; watch the others.")
		end
	end)
	changed()
	checkAllOut()
end

local function onFlash(player: Player, origin: Vector3, look: Vector3)
	if not run or not run.ai or player:GetAttribute("State") ~= "alive" then
		return
	end
	local target = run.ai.root.Position
	if not Rules.flashHits(origin, look, target, S(Config.Torch.range), Config.Torch.coneDeg) then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Model }
	local hit = workspace:Raycast(origin, target - origin, params)
	if hit and not hit.Instance:IsDescendantOf(run.entityModel) then
		return
	end
	run.ai:stun(Config.Torch.stun)
	ctx.banner(`{player.DisplayName} stunned the entity!`, 3)
end

local startNight: () -> ()

local function askCureOrDestroy()
	Votes.ask("The teacher lies at the altar. Cure them, or destroy the demon with them?",
		{ "Cure the teacher", "Destroy the demon" }, CHOICE_SECONDS * ctx.timeScale, alive, function(pick)
			if not run or run.over then
				return
			end
			local destroy = pick == 2 -- no votes: cure
			local ratio = CampaignRules.ratio(run.quizRight, run.quizTotal)
			finishRun(CampaignRules.ritualEnding(destroy, ratio, #run.clues, run.level.clues))
		end)
end

local function onRitualDone()
	run.ritualDone = true -- the clock stops for the last choice
	if run.caretaker then
		run.caretaker:destroy()
		run.caretaker = nil
	end
	if run.ai then
		run.ai:stop()
	end
	if run.entityModel then
		run.entityModel:Destroy()
		run.entityModel = nil
	end
	run.ai = nil
	sound("bell")
	ctx.banner("The bell rings once. The whispers stop.", 6)
	local myRun = run
	run.quest:showHost(CampaignData.TEACHERS[run.culprit])
	if run == myRun and not run.over then -- building the body yields
		askCureOrDestroy()
	end
end

local function onDeal()
	if Votes.isOpen() or os.clock() < run.dealBlockedUntil then
		return
	end
	ctx.banner("A voice from the altar offers a deal...", 5)
	Votes.ask("Make a deal with the demon? It leaves you alone, you leave it the school.", { "Yes", "No" },
		CHOICE_SECONDS * ctx.timeScale, alive, function(pick)
			if not run or run.over then
				return
			end
			if pick == 1 then
				finishRun(6)
			else
				run.dealBlockedUntil = os.clock() + DEAL_COOLDOWN * ctx.timeScale
				ctx.banner("The team refused the deal.", 4)
			end
		end, true) -- more than half of the living must say yes
end

startNight = function()
	run.accused = true
	setPhase("night")
	if run.caretaker and run.level.caretaker ~= "night" then
		run.caretaker:destroy()
		run.caretaker = nil
	elseif run.caretaker then
		run.caretaker:setPaused(false)
	end
	ctx.banner("Correct. Night falls and the doors lock behind you. Banish it before 05:00!", 8)
	run.quest = Quest.new({
		level = run.level,
		folder = run.folder,
		remotes = ctx.remotes,
		school = ctx.school,
		usedRooms = run.usedRooms,
		timeScale = ctx.timeScale,
		alive = alive,
		banner = ctx.banner,
		porterTopic = Keys.addTopic,
		changed = changed,
		sound = sound,
		onRitualStart = function(altar: Vector3)
			if run.ai then
				run.ai.state = "investigate"
				run.ai:setGoal(altar)
			end
		end,
		onRitualDone = onRitualDone,
		onDeal = onDeal,
	})
	run.quest:start(run.porter)
	local model = EntityModel.build(run.look)
	model.Parent = run.folder
	EntityModel.setTrail(model, run.folder)
	run.entityModel = model
	run.ai = EntityAI.new(model, ctx.school, {
		targets = alive,
		isHidden = Lockers.isHidden,
		holdingBreath = Lockers.holdingBreath,
		lockers = Lockers.occupied,
		onCatch = caught,
		params = { chaseSpeed = run.level.chaseSpeed, sight = run.level.sight, hintInterval = run.level.hintInterval },
	})
	run.ai:placeAt(ctx.school.farPoint)
	local myRun = run
	task.delay(ENTITY_HEAD_START * ctx.timeScale, function()
		if run == myRun and run.ai and not run.over then
			run.ai:start()
			sound("sting")
			ctx.banner("Something is awake in the building.", 5)
		end
	end)
	changed()
end

local function startAccusation()
	if run.voting then
		return
	end
	run.voting = true
	local names = {}
	for i, id in CampaignData.SUSPECTS do
		names[i] = CampaignData.TEACHERS[id]
	end
	ctx.banner("Dusk. Who is the entity? Vote together.", 6)
	Votes.ask("Who is the entity?", names, ACCUSE_SECONDS * ctx.timeScale, alive, function(pick)
		if not run or run.over then
			return
		end
		run.voting = false
		if not pick then
			ctx.banner("Nobody voted. Vote again.", 4)
			return -- the tick re-opens the vote
		end
		if CampaignData.SUSPECTS[pick] == run.culprit then
			for _, p in alive() do
				AchievementService.award(p, "right_suspect")
			end
			startNight()
		else
			finishRun(8)
		end
	end)
end

-- State for the phone and the HUD ---------------------------------------------------------------------------------

local function guidePosition(): Vector3?
	if run.level.guidance ~= "exact" then
		return nil
	end
	if run.phase == "night" and run.quest then
		local _, pos = run.quest:stepPlace(CampaignRules.questStep(run.quest.state))
		return pos
	end
	if run.phase == "accusation" then
		return nil
	end
	local info = lessonInfo(run.lessonIndex)
	if info and not run.exploded and (run.phase == "grace" or run.minutes >= Schedule.lessonStart(run.lessonIndex) - 12) then
		return Npc.roomPoint(FloorData, info.floor, info.room)
	end
	return run.clueSpawner:nextPosition() or (info and not run.exploded and Npc.roomPoint(FloorData, info.floor, info.room))
end

local function snapshot(player: Player)
	local info = lessonInfo(run.lessonIndex)
	local step, questRoom = nil, nil
	if run.quest then
		step = CampaignRules.questStep(run.quest.state)
		local place = run.quest:stepPlace(step)
		questRoom = place and place.room
	end
	local objective = CampaignRules.objective({
		phase = run.phase,
		nextLesson = if info and not run.exploded then { subject = info.subject, room = info.room } else nil,
		clueRoom = run.clueSpawner:nextRoom(),
		cluesFound = #run.clues,
		cluesNeeded = run.level.clues,
		accused = run.accused,
		questStep = step,
		questRoom = questRoom,
	}, run.level.guidance)
	local timetable = {}
	for i, subject in run.subjects do
		local data = CampaignData.SUBJECTS[subject]
		timetable[i] = { subject = subject, room = data.room, time = Schedule.format(Schedule.lessonStart(i - 1)),
			teacher = CampaignData.TEACHERS[CampaignData.teacherOf(subject, run.row)],
			done = i - 1 < run.lessonIndex }
	end
	local out = {}
	for p, way in run.out do
		table.insert(out, `{p.DisplayName}: {WAY_NAMES[way] or way}`)
	end
	return {
		difficulty = run.level.label,
		minutes = run.minutes,
		clock = Schedule.format(run.minutes),
		phase = run.phase,
		objective = objective,
		timetable = timetable,
		clues = run.clues,
		altar = if run.quest then run.quest.state.altar else nil,
		quiz = { right = run.quizRight, total = run.quizTotal },
		skips = run.skips[player.UserId] or 0,
		skipLimit = if run.level.skipLimit == math.huge then 0 else run.level.skipLimit,
		out = out,
		guide = guidePosition(),
	}
end

local function broadcast()
	run.dirty = false
	run.lastSent = os.clock()
	local state = remote("CampaignState")
	ReplicatedStorage:SetAttribute("CampaignMinutes", run.minutes)
	-- For the people in the school (People.luau): which room the class sits in, and whether everyone has left.
	local lesson = lessonInfo(run.lessonIndex)
	ReplicatedStorage:SetAttribute("CampaignLessonRoom",
		if lesson and not run.exploded then `{lesson.floor}:{lesson.room}` else nil)
	ReplicatedStorage:SetAttribute("CampaignExploded", run.exploded)
	for _, p in Players:GetPlayers() do
		state:FireClient(p, snapshot(p))
	end
end

-- The clock -------------------------------------------------------------------------------------------------------

local function tick(dt: number)
	if run.over then
		return
	end
	local count = #run.subjects
	local phase = Schedule.phaseAt(run.minutes, count, run.exploded, run.accused)
	-- The pace comes from the phase. Test scripts can hold the clock with the ServerStorage attribute CampaignFreeze.
	if not run.adopted then
		-- Players who joined while the run was starting were made spectators: they play too.
		run.adopted = true
		for _, p in Players:GetPlayers() do
			if not run.students[p] and p:GetAttribute("State") == "spectator" then
				CampaignMode.playerJoined(p)
			end
		end
	end
	if not ServerStorage:GetAttribute("CampaignFreeze") and not run.ritualDone then
		run.minutes += Schedule.pace(phase, run.level.paceScale) / ctx.timeScale * dt
	end
	-- Test scripts can also set the clock (minutes after midnight) with CampaignSetMinutes; it is cleared once used.
	local setTo = ServerStorage:GetAttribute("CampaignSetMinutes")
	if type(setTo) == "number" then
		ServerStorage:SetAttribute("CampaignSetMinutes", nil)
		run.minutes = setTo
	end
	tickLessons()
	if not run or run.over then
		return
	end
	phase = Schedule.phaseAt(run.minutes, count, run.exploded, run.accused)
	if phase == "accusation" then
		run.minutes = Schedule.DUSK
		if run.caretaker and run.level.caretaker == "afternoon" then
			run.caretaker:destroy()
			run.caretaker = nil
		elseif run.caretaker then
			run.caretaker:setPaused(true) -- nobody gets expelled while the vote covers the screen
		end
		setPhase("accusation")
		startAccusation()
	elseif phase == "over" then
		run.minutes = Schedule.END
		ctx.banner("05:00. The night is over without an answer.", 6)
		finishRun(7)
		return
	else
		setPhase(phase)
	end
	if run.dirty or os.clock() - run.lastSent >= 1 then
		broadcast()
	end
end

-- Mode ------------------------------------------------------------------------------------------------------------

local function spawnStudent(player: Player)
	run.students[player] = true
	player:SetAttribute("State", "alive")
	player:SetAttribute("Hidden", false)
	Torch.setAllowed(player, true)
	remote("Role"):FireClient(player, "student")
end

function CampaignMode.start(c)
	ctx = c
	local level = Difficulty.get(c.options.difficulty or "normal")
	local rowIndex = math.random(#CampaignData.TIMETABLES)
	local folder = Instance.new("Folder")
	folder.Name = "Campaign"
	folder.Parent = workspace
	run = {
		level = level,
		row = rowIndex,
		subjects = Schedule.pickLessons(CampaignData.TIMETABLES[rowIndex], level.lessons),
		culprit = CampaignData.SUSPECTS[math.random(#CampaignData.SUSPECTS)],
		minutes = Schedule.OPEN,
		phase = "",
		exploded = false,
		accused = false,
		voting = false,
		over = false,
		breaks = 0,
		lessonIndex = 0,
		lessonStage = "wait",
		attending = 0,
		students = {} :: { [Player]: boolean },
		skips = {} :: { [number]: number }, -- by UserId
		out = {} :: { [Player]: string },
		outIds = {} :: { [number]: boolean },
		ritualDone = false,
		adopted = false,
		dealBlockedUntil = 0,
		downedAt = {} :: { [Player]: number },
		revivePrompts = {} :: { [Player]: { Instance } },
		lastWay = "ranaway",
		quizRight = 0,
		quizTotal = 0,
		clues = {} :: { string },
		usedRooms = {} :: { [string]: boolean },
		folder = folder,
		dirty = true,
		lastSent = 0,
		connections = {} :: { RBXScriptConnection },
	}
	local looks = CampaignData.LOOKS[run.culprit]
	run.look = {
		jacket = Color3.fromRGB(looks.jacket[1], looks.jacket[2], looks.jacket[3]),
		trousers = Color3.fromRGB(looks.trousers[1], looks.trousers[2], looks.trousers[3]),
		mark = CampaignData.ENTITY_MARKS[run.culprit],
	}
	for _, p in c.players do
		spawnStudent(p)
	end
	ReplicatedStorage:SetAttribute("CampaignDifficulty", level.name)
	-- For test scripts (ServerStorage never replicates, so clients cannot read it).
	ServerStorage:SetAttribute("CampaignCulprit", run.culprit)

	-- Lab 14 is sealed until it explodes.
	local lab = Doors.find(CampaignData.STORY.lab.room, CampaignData.STORY.lab.floor)
	if lab then
		Doors.setLocked(lab, true, "Lab 14: sealed. Chemistry in progress.")
	end

	local myRun = run
	local teachers = Teachers.new(folder, {
		row = rowIndex,
		culprit = run.culprit,
		breaks = function()
			return if run then run.breaks else 0
		end,
		dialogue = remote("Dialogue"),
		isAlive = function(p)
			return p:GetAttribute("State") == "alive"
		end,
	})
	if run ~= myRun then
		return -- everybody left while the NPCs were built (they yield); stop() destroyed the folder
	end
	run.teachers = teachers
	run.teachers:sendFor(run.subjects[1])
	local porter = Porter.build(folder)
	if run ~= myRun then
		return
	end
	run.porter = porter
	-- Classrooms are locked; the porter lends the keys. The rooms the story sends everyone to stay open.
	local exempt = {}
	for _, place in CampaignData.STORY do
		exempt[`{place.floor}:{place.room}`] = true
	end
	for _, place in CampaignData.AFTER_ROOMS do
		exempt[`{place.floor}:{place.room}`] = true
	end
	for _, subject in run.subjects do
		local info = CampaignData.SUBJECTS[subject]
		if info then
			exempt[`{info.floor}:{info.room}`] = true
		end
	end
	Keys.start({
		exempt = exempt,
		banner = ctx.banner,
		isNight = function()
			return run ~= nil and run.phase == "night"
		end,
	}, porter)
	run.lessons = Lessons.new({
		level = level,
		subjects = run.subjects,
		remotes = c.remotes,
		seats = c.school.seats,
		folder = folder,
		alive = alive,
		onSkip = onSkip,
		onScore = function(right, total)
			run.quizRight += right
			run.quizTotal += total
			changed()
		end,
		onAllDone = function() end, -- the tick jumps the clock once every attendee is done
	})
	run.clueSpawner = Clues.new({
		culprit = run.culprit,
		count = level.clues,
		folder = folder,
		usedRooms = run.usedRooms,
		onFound = function(player, text)
			table.insert(run.clues, text)
			if #run.clues >= level.clues then
				for p in run.students do
					AchievementService.award(p, "detective")
				end
			end
			ctx.banner(`{player.DisplayName} found a clue: {text}`, 8)
			changed()
		end,
		takePaper = function(player, text)
			return Inventories.give(player, { id = "papers", texts = { text } })
		end,
	})
	run.clueSpawner:wave(1)
	Inventories.enable(folder)
	-- Power banks for the phone in a few empty rooms.
	local banks = 0
	for _, place in CampaignData.CLUE_ROOMS do
		if banks >= POWER_BANKS then
			break
		end
		if not run.usedRooms[place.room] and math.random() < 0.4 then
			local at = Pickups.spot(place.floor, place.room, -1, 1)
			if at then
				banks += 1
				Inventories.dropItem({ id = "battery" }, at)
			end
		end
	end

	-- Leaving through the front door: out for the rest of the run.
	local spawn = c.school.spawn
	local doorAt = spawn.Position - spawn.LookVector * S(1.6) - Vector3.new(0, 3, 0)
	local exitPart = Pickups.part(folder, "FrontDoor", doorAt, Vector3.new(1.2, 2.1, 0.15), Color3.fromRGB(90, 70, 50),
		Enum.Material.Wood)
	exitPart.CanCollide = false
	exitPart.Transparency = 0.3
	Pickups.prompt(exitPart, "Leave the school (you are out)", "Front door", 2, function(player)
		if run and not run.over then
			ctx.banner(`{player.DisplayName} left the school.`, 5)
			markOut(player, "ranaway", "You walked out of the school. Watch the others.")
		end
	end)

	local keypad = remote("KeypadEnter")
	table.insert(run.connections, keypad.OnServerEvent:Connect(function(player, code)
		if run and run.quest and player:GetAttribute("State") == "alive" then
			run.quest:enterCode(player, code)
		end
	end))

	Lockers.canHide = function(p: Player): boolean
		return run ~= nil and run.students[p] == true and p:GetAttribute("State") == "alive"
	end
	Torch.onFlash = onFlash

	local subject = lessonInfo(0) :: any
	ctx.banner(`{level.label} story. First lesson at 07:30: {subject.subject} in room {subject.room}. Press P for the phone.`, 10)
	task.spawn(function()
		local last = os.clock()
		while run == myRun and not myRun.over do
			task.wait(TICK)
			if run ~= myRun or myRun.over then
				break -- the run ended while waiting
			end
			local now = os.clock()
			local ok, err = pcall(tick, now - last)
			last = now
			if not ok then
				warn("[campaign] " .. tostring(err))
			end
		end
	end)
end

function CampaignMode.playerJoined(player: Player)
	if not run or run.over then
		return
	end
	if not run.accused and run.phase ~= "accusation" and not run.outIds[player.UserId] then
		ctx.addPlayer(player)
		local index = #Players:GetPlayers()
		spawnStudent(player)
		Inventories.join(player)
		local myRun = run
		task.spawn(function()
			Characters.spawn(player, ctx.spawnAt(index))
			if run == myRun and not run.over and player.Parent and not run.out[player] then
				player:SetAttribute("State", "alive")
			end
		end)
		ctx.banner(`{player.DisplayName} joined the class.`, 4)
	else
		player:SetAttribute("State", "spectator")
		Torch.setAllowed(player, false)
		ctx.banner("You cannot join the story now. You watch until the next run.", 6, player)
	end
	changed()
end

function CampaignMode.playerLeft(player: Player)
	if not run then
		return
	end
	if run.students[player] and not run.out[player] then
		Inventories.spill(player, ctx.school.spawn.Position - Vector3.new(0, 3, 0))
	end
	run.students[player] = nil
	run.downedAt[player] = nil
	Votes.recheck()
	changed()
	if #standing() == 0 and not run.over then
		local anyoneLeft = false
		for p in run.out do
			if p.Parent then
				anyoneLeft = true
			end
		end
		if anyoneLeft then
			finishRun(CampaignRules.allOutEnding(run.lastWay))
		else
			run.over = true
			ctx.finish("Everybody left the story.")
		end
	end
end

function CampaignMode.playerDied(player: Player)
	if not run or run.over then
		return
	end
	if run.accused then
		local state = player:GetAttribute("State")
		if state == "alive" or state == "downed" then
			markOut(player, "caught", "You died in the dark. Watch the others.")
		end
		return
	end
	-- By day nothing kills: put them back at the entrance.
	local myRun = run
	task.delay(2, function()
		if run == myRun and player.Parent and run.students[player] and not run.out[player] then
			Characters.spawn(player, ctx.spawnAt(1))
			player:SetAttribute("State", "alive")
		end
	end)
end

function CampaignMode.stop()
	local old = run
	run = nil
	if not old then
		return
	end
	old.over = true
	Votes.cancel()
	for _, connection in old.connections do
		connection:Disconnect()
	end
	if old.ai then
		old.ai:stop()
	end
	if old.caretaker then
		old.caretaker:destroy()
	end
	if old.glimpses then
		old.glimpses:destroy()
	end
	if old.quest then
		old.quest:destroy()
	end
	if old.teachers then
		old.teachers:destroy()
	end
	if old.lessons then
		old.lessons:destroy()
	end
	local lab = Doors.find(CampaignData.STORY.lab.room, CampaignData.STORY.lab.floor)
	if lab then
		Doors.setLocked(lab, false)
	end
	Keys.stop()
	old.folder:Destroy()
	Torch.onFlash = nil
	Inventories.disable()
	for p in old.students do
		if p.Parent then
			Characters.setSpeed(p, nil)
		end
	end
	ReplicatedStorage:SetAttribute("CampaignMinutes", nil)
	ReplicatedStorage:SetAttribute("CampaignLessonRoom", nil)
	ReplicatedStorage:SetAttribute("CampaignExploded", nil)
	ReplicatedStorage:SetAttribute("CampaignDifficulty", nil)
	ServerStorage:SetAttribute("CampaignCulprit", nil)
	remote("CampaignState"):FireAllClients(nil)
	ctx = nil
end

return CampaignMode
