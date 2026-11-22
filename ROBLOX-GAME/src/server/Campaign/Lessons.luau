-- Lessons: a player inside the lesson's room within the grace after the bell attends; missing the grace is a skip.
-- An attending player sits down at a desk (E on any chair in the room; a classmate sitting there gets up) and gets
-- the test there: a paper on the desk in front of them, which everyone can see being written. How it is answered
-- depends on the subject (src/shared/LessonSheet.luau): ticking an option, writing the answer, a small program on
-- the PC or cabling a network. Standing up puts the pen down; sitting again goes on. Anyone in class still without
-- a paper after a short wait (no free chair, or they never sat) gets it standing, so nobody skips the test. The test closes at the lesson's end and
-- everyone gets up; unanswered tasks count as wrong. Every answer counts towards the team's quiz score.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CampaignData = require(ReplicatedStorage.Shared.CampaignData)
local Config = require(ReplicatedStorage.Shared.Config)
local FloorData = require(ReplicatedStorage.Shared.FloorData)
local LessonSheet = require(ReplicatedStorage.Shared.LessonSheet)
LessonSheet.init(require(ReplicatedStorage.Shared.Answers) :: any, require(ReplicatedStorage.Shared.CodeCheck) :: any,
	require(ReplicatedStorage.Shared.NetCheck) :: any)
local Characters = require(script.Parent.Parent.Characters)
local AchievementService = require(script.Parent.Parent.AchievementService)

local S = Config.studs
local STANDING_WAIT = 15 -- seconds before a player without a free chair gets the paper standing

local Lessons = {}
Lessons.__index = Lessons

export type Run = {
	level: any,
	subjects: { string },
	remotes: Folder,
	seats: { [string]: { Seat } }, -- "floor:room" -> the room's chairs (SchoolBuilder)
	folder: Instance,
	alive: () -> { Player },
	onSkip: (Player) -> (),
	onScore: (right: number, total: number) -> (),
	onAllDone: (lesson: number) -> (),
}

type Sheet = { kind: string, tasks: { any }, answered: { [number]: boolean }, written: { string }, right: number,
	paper: Part?, seat: Seat? }

function Lessons.new(run: Run)
	local self = setmetatable({}, Lessons)
	self.run = run
	self.open = nil :: number? -- the lesson whose test is open
	self.sheets = {} :: { [Player]: Sheet }
	self.attended = {} :: { [number]: { [Player]: boolean } }
	self.since = {} :: { [Player]: number } -- when an attending player without a paper came in
	self.prompts = {} :: { ProximityPrompt }
	local answerRemote = run.remotes:FindFirstChild("QuizAnswer") :: RemoteEvent
	self.connection = answerRemote.OnServerEvent:Connect(function(player, lesson, index, answer)
		self:answer(player, lesson, index, answer)
	end)
	return self
end

function Lessons:subject(i: number): string
	return self.run.subjects[i + 1]
end

local function inRoom(player: Player, room: string, floor: number): boolean
	local root = Characters.root(player)
	if not root then
		return false
	end
	local m = root.Position / Config.STUDS_PER_METRE
	return FloorData.floorAt(m.Y) == floor and FloorData.roomLabelAt(floor, m.X, m.Z) == room
end

local function seatedOn(player: Player): Seat?
	local humanoid = Characters.humanoid(player)
	local seat = humanoid and humanoid.SeatPart
	return if seat and seat:IsA("Seat") then seat else nil
end

local function standUp(player: Player)
	local humanoid = Characters.humanoid(player)
	if humanoid and humanoid.SeatPart then
		humanoid.Sit = false
		humanoid.Jump = true
	end
end

function Lessons:roomSeats(i: number): { Seat }
	local info = CampaignData.SUBJECTS[self:subject(i)]
	return self.run.seats[`{info.floor}:{info.room}`] or {}
end

-- "Sit down" on every chair of the lesson's room while its test is open.
function Lessons:addPrompts(i: number)
	self:removePrompts()
	for _, seat in self:roomSeats(i) do
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SitPrompt"
		prompt.ActionText = "Sit down"
		prompt.ObjectText = "Desk"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = 7
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("For", "living")
		prompt.Triggered:Connect(function(player)
			self:sit(player, seat)
		end)
		prompt.Parent = seat
		table.insert(self.prompts, prompt)
	end
end

function Lessons:removePrompts()
	for _, prompt in self.prompts do
		prompt:Destroy()
	end
	self.prompts = {}
end

function Lessons:sit(player: Player, seat: Seat)
	local i = self.open
	local humanoid = Characters.humanoid(player)
	local root = Characters.root(player)
	if not i or not humanoid or not root or player:GetAttribute("State") ~= "alive"
		or not (self.attended[i] and self.attended[i][player]) or (root.Position - seat.Position).Magnitude > S(4) then
		return
	end
	local occupant = seat.Occupant
	if occupant and Players:GetPlayerFromCharacter(occupant.Parent) then
		return -- a friend sits there
	end
	task.spawn(function()
		-- A classmate there (or one arriving just now) makes room; a few tries, they may be mid-step.
		for _ = 1, 4 do
			local other = seat.Occupant
			if other == humanoid or not humanoid.Parent then
				break
			end
			if other then
				if Players:GetPlayerFromCharacter(other.Parent) then
					return
				end
				other.Sit = false
				other.Jump = true
				task.wait(0.25)
			end
			if seat.Occupant == nil then
				seat:SetAttribute("Claimed", true) -- People's classmates leave it alone
				seat:Sit(humanoid)
			end
			task.wait(0.15)
		end
		if seat.Occupant == humanoid and humanoid.Parent then
			local sheet = self.sheets[player]
			if sheet and sheet.seat and sheet.seat ~= seat then
				sheet.seat:SetAttribute("Claimed", nil) -- moved to another chair
				sheet.seat = seat
			end
			task.wait(0.2)
			if seatedOn(player) == seat and not self.sheets[player] and self.open == i then
				self:startQuiz(player, i, self:subject(i), seat)
			end
		end
	end)
end

-- Called every tick during the grace and the lesson: players who walk in during the grace attend; attending players
-- without a free chair get the paper standing after a while.
function Lessons:checkAttendance(i: number)
	local subject = self:subject(i)
	local info = CampaignData.SUBJECTS[subject]
	local list = self.attended[i] or {}
	self.attended[i] = list
	if self.open ~= i then
		self.open = i
		self:addPrompts(i)
	end
	for _, player in self.run.alive() do
		if not list[player] and inRoom(player, info.room, info.floor) then
			list[player] = true
			self.since[player] = os.clock()
			local hint = self.run.remotes:FindFirstChild("Banner") :: RemoteEvent?
			if hint then
				hint:FireClient(player, "Sit down at a desk (E on a chair) to get your test.", 5)
			end
		end
	end
	self:checkStanding(i)
end

function Lessons:checkStanding(i: number)
	for player in self.attended[i] or {} do
		if player:GetAttribute("State") ~= "alive" and seatedOn(player) then
			standUp(player) -- downed or out: off the chair
		end
		if not self.sheets[player] and player.Parent and player:GetAttribute("State") == "alive" then
			local seat = seatedOn(player)
			if seat then
				self:startQuiz(player, i, self:subject(i), seat)
			elseif os.clock() - (self.since[player] or 0) > STANDING_WAIT then
				self:startQuiz(player, i, self:subject(i), nil)
			end
		end
	end
end

-- The paper on the desk in front of a chair (or in the player's hand), with what they write on it.
local function makePaper(folder: Instance, seat: Seat?, player: Player, subject: string): Part?
	local root = Characters.root(player)
	if not root then
		return nil
	end
	local base = seat and seat.CFrame or root.CFrame
	local look = base.LookVector
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance, seat :: Instance }
	-- The desk top: straight down from a point ahead of the chair.
	local from = base.Position + look * S(0.55) + Vector3.new(0, S(0.8), 0)
	local hit = workspace:Raycast(from, Vector3.new(0, -S(1.2), 0), params)
	local top = if hit then hit.Position else base.Position + look * S(0.45) + Vector3.new(0, S(0.3), 0)
	local paper = Instance.new("Part")
	paper.Name = "TestPaper"
	paper.Anchored = true
	paper.CanCollide = false
	paper.CanTouch = false
	paper.CanQuery = false
	paper.Size = Vector3.new(S(0.21), S(0.004), S(0.297))
	paper.Color = Color3.fromRGB(244, 241, 232)
	paper.Material = Enum.Material.SmoothPlastic
	paper.CFrame = CFrame.lookAt(top + Vector3.new(0, S(0.003), 0), top + Vector3.new(look.X, 0, look.Z) * 10)
		* CFrame.Angles(0, math.rad(math.random(-6, 6)), 0)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.CanvasSize = Vector2.new(210, 297)
	gui.LightInfluence = 1
	gui.Parent = paper
	local text = Instance.new("TextLabel")
	text.Name = "Writing"
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(1, -16, 1, -12)
	text.Position = UDim2.fromOffset(8, 6)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.TextWrapped = true
	text.TextSize = 14
	text.Font = Enum.Font.IndieFlower
	text.TextColor3 = Color3.fromRGB(30, 40, 90)
	text.Text = `{subject} test\n{player.DisplayName}\n`
	text.Parent = gui
	paper:SetAttribute("Owner", player.UserId)
	paper.Parent = folder
	CollectionService:AddTag(paper, "TestPaper") -- the owner's client finds it by this (QuizUi)
	return paper
end

local function rewrite(sheet: Sheet, subject: string, player: Player)
	local paper = sheet.paper
	local label = paper and paper:FindFirstChild("SurfaceGui") and (paper :: any).SurfaceGui:FindFirstChild("Writing")
	if label then
		local lines = { `{subject} test`, player.DisplayName, "" }
		for k = 1, #sheet.tasks do
			table.insert(lines, `{k}. {sheet.written[k] or ""}`)
		end
		label.Text = table.concat(lines, "\n")
	end
end

function Lessons:startQuiz(player: Player, i: number, subject: string, seat: Seat?)
	if self.sheets[player] then
		return
	end
	local level = self.run.level
	local kind, tasks = LessonSheet.build(CampaignData.SUBJECTS[subject], level.quizMode, level.quizCount, math.random)
	local shown = {}
	for k, task in tasks do
		shown[k] = LessonSheet.shown(kind, task)
	end
	local sheet: Sheet = { kind = kind, tasks = tasks, answered = {}, written = {}, right = 0, seat = seat,
		paper = makePaper(self.run.folder, seat, player, subject) }
	self.sheets[player] = sheet
	self.run.onScore(0, #tasks) -- Every task counts; unanswered ones stay wrong.
	AchievementService.award(player, "first_lesson")
	local remote = self.run.remotes:FindFirstChild("QuizStart") :: RemoteEvent
	remote:FireClient(player, { lesson = i, subject = subject, mode = kind, questions = shown, paper = sheet.paper,
		seated = seat ~= nil })
end

function Lessons:answer(player: Player, lesson: any, index: any, answer: any)
	local sheet = self.sheets[player]
	if self.open ~= lesson or not sheet or type(index) ~= "number" or sheet.answered[index] then
		return
	end
	local task = sheet.tasks[index]
	if not task then
		return
	end
	local correct = LessonSheet.check(sheet.kind, task, answer)
	sheet.answered[index] = true
	sheet.written[index] = LessonSheet.written(sheet.kind, task, answer)
	rewrite(sheet, self:subject(lesson), player)
	if correct then
		sheet.right += 1
		self.run.onScore(1, 0)
		if sheet.kind == "code" then
			AchievementService.award(player, "hello_world")
		elseif sheet.kind == "network" then
			AchievementService.award(player, "net_admin")
		end
	end
	local done = true
	for k = 1, #sheet.tasks do
		if not sheet.answered[k] then
			done = false
		end
	end
	if done and sheet.right == #sheet.tasks then
		AchievementService.award(player, "straight_a")
	end
	local result = self.run.remotes:FindFirstChild("QuizResult") :: RemoteEvent
	result:FireClient(player, { lesson = lesson, questionIndex = index, correct = correct, done = done,
		right = sheet.right, total = #sheet.tasks })
	if done and self:allDone(lesson) then
		self.run.onAllDone(lesson)
	end
end

-- Every attending player (alive) has finished their paper; one still without a paper is not done.
function Lessons:allDone(i: number): boolean
	for player in self.attended[i] or {} do
		if player.Parent and player:GetAttribute("State") == "alive" then
			local sheet = self.sheets[player]
			if not sheet then
				return false
			end
			for k = 1, #sheet.tasks do
				if not sheet.answered[k] then
					return false
				end
			end
		end
	end
	return true
end

-- The grace is over: everyone alive who did not come in skipped. Returns how many attend.
function Lessons:closeAttendance(i: number): number
	local list = self.attended[i] or {}
	self.attended[i] = list
	local count = 0
	for _, player in self.run.alive() do
		if list[player] then
			count += 1
		else
			self.run.onSkip(player)
		end
	end
	return count
end

-- The lesson is over: close every paper and everyone gets up.
function Lessons:closeQuiz(i: number)
	local result = self.run.remotes:FindFirstChild("QuizResult") :: RemoteEvent
	for player in self.attended[i] or {} do
		local sheet = self.sheets[player]
		if sheet and player.Parent then
			result:FireClient(player, { lesson = i, done = true, closed = true, right = sheet.right,
				total = #sheet.tasks })
		end
		if sheet and sheet.seat then
			sheet.seat:SetAttribute("Claimed", nil)
		end
		if sheet and sheet.paper then
			sheet.paper:Destroy()
		end
		if seatedOn(player) then
			standUp(player)
		end
		self.sheets[player] = nil
		self.since[player] = nil
	end
	self:removePrompts()
	if self.open == i then
		self.open = nil
	end
end

function Lessons:destroy()
	self.connection:Disconnect()
	if self.open then
		self:closeQuiz(self.open)
	end
	self:removePrompts()
end

return Lessons
