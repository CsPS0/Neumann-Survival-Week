-- The night's exorcism quest (quest.gd). Items go into the hand, pockets or bag of the player who takes them
-- (Inventories); using one needs it in the user's hand or a pocket:
--   1. the porter hands over the storage key; it opens the red room (salt and fuse inside)
--   2. the fuse goes in the fuse box in room 24; the Lab 14 cabinet then gives the holy water
--   3. notes in other rooms carry the safe code; the old safe in room 229 holds the silver bell
--   4. the three items go on the altar in the Aula; the ritual lasts the difficulty's seconds while a living player
--      stays within 6 m of the altar. Then the team votes to cure or destroy the possessed teacher.
-- The altar also offers a deal with the demon (team vote).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CampaignData = require(ReplicatedStorage.Shared.CampaignData)
local Config = require(ReplicatedStorage.Shared.Config)
local FloorData = require(ReplicatedStorage.Shared.FloorData)
local Characters = require(script.Parent.Parent.Characters)
local Doors = require(script.Parent.Parent.Doors)
local Inventories = require(script.Parent.Inventories)
local Npc = require(script.Parent.Npc)
local Pickups = require(script.Parent.Pickups)

local S = Config.studs
local RITUAL_RANGE = 6

local Quest = {}
Quest.__index = Quest

export type Run = {
	level: any,
	folder: Instance,
	remotes: Folder,
	school: any,
	usedRooms: { [string]: boolean },
	timeScale: number,
	alive: () -> { Player },
	banner: (text: string, seconds: number?, to: Player?) -> (),
	porterTopic: ((topic: (Player) -> boolean) -> ())?, -- one prompt on the porter (Keys.addTopic)
	changed: () -> (),
	onRitualStart: (altar: Vector3) -> (),
	beforeRitual: ((start: () -> ()) -> ())?, -- the team names the entity first (CampaignMode)
	onRitualDone: () -> (),
	onDeal: () -> (),
	sound: (name: string, at: Vector3?) -> (),
}

local ITEM_NAMES = { key = "Storage key", salt = "Salt", fuse = "Fuse", vial = "Holy water", bell = "Silver bell" }

function Quest.new(run: Run)
	local self = setmetatable({}, Quest)
	self.run = run
	self.state = { haveKey = false, redOpened = false, fusePlaced = false, vialTaken = false, notes = 0,
		notesNeeded = run.level.notes, safeOpen = false, altar = { salt = false, vial = false, bell = false } }
	self.code = string.format("%04d", math.random(0, 9999))
	self.started = false
	self.ritualActive = false
	self.ritualDone = false
	-- The red room: a free open room for the storage.
	local rooms = table.clone(CampaignData.CLUE_ROOMS)
	for k = #rooms, 2, -1 do
		local j = math.random(k)
		rooms[k], rooms[j] = rooms[j], rooms[k]
	end
	-- Not a room someone stands in: the red door locks at nightfall and the key is at the Porta.
	local function occupied(place): boolean
		for _, player in run.alive() do
			local root = Characters.root(player)
			if root then
				local m = root.Position / Config.STUDS_PER_METRE
				if FloorData.floorAt(m.Y) == place.floor and FloorData.roomLabelAt(place.floor, m.X, m.Z) == place.room then
					return true
				end
			end
		end
		return false
	end
	for _, place in rooms do
		if not run.usedRooms[place.room] and not occupied(place) then
			self.red = place
			run.usedRooms[place.room] = true
			break
		end
	end
	self.noteRooms = {}
	for _, place in rooms do
		if #self.noteRooms >= run.level.notes then
			break
		end
		if not run.usedRooms[place.room] then
			table.insert(self.noteRooms, place)
			run.usedRooms[place.room] = true
		end
	end
	return self
end

-- Where the current step happens, for the objective and Easy's guide marker.
function Quest:stepPlace(step: string): ({ room: string, floor: number }?, Vector3?)
	if step == "redkey" then
		return { room = "Porta", floor = 0 }, self.porterPos
	elseif step == "redroom" and self.red then
		return self.red, self.redDoorPos
	elseif step == "fuse" then
		return CampaignData.STORY.fuse, self.fuseBoxPos
	elseif step == "vial" then
		return CampaignData.STORY.lab, self.cabinetPos
	elseif step == "notes" then
		for i, place in self.noteRooms do
			if not self.notesRead[i] then
				return place, self.notePos[i]
			end
		end
	elseif step == "safe" then
		return CampaignData.STORY.safe, self.safePos
	elseif step == "altar" or step == "ritual" then
		return { room = "Aula", floor = 0 }, self.altarPos
	end
	return nil, nil
end

-- Builds the night's objects (called when the hunt starts).
function Quest:start(porter: Model?)
	if self.started then
		return
	end
	self.started = true
	local run = self.run
	local folder = run.folder
	-- 1. The porter hands over the storage key.
	if porter then
		local root = porter:FindFirstChild("HumanoidRootPart") :: BasePart
		self.porterPos = root.Position
		-- True when he answered (false once the team has it, so the porter's other talk goes on).
		local function storageKey(player: Player): boolean
			if self.state.haveKey then
				return false
			end
			if Inventories.give(player, { id = "key" }) then
				self.state.haveKey = true
				run.banner(`{player.DisplayName} got the storage key from the porter.`, 5)
				run.changed()
			end
			return true
		end
		if run.porterTopic then
			run.porterTopic(storageKey) -- one prompt on the porter (Keys.luau)
		else
			Pickups.prompt(root, "Ask for the storage key", "Porter", 0.5, function(player)
				if not storageKey(player) then
					run.banner("The porter: I already gave you the storage key.", 4, player)
				end
			end)
		end
	end
	-- The red room's door.
	local door = self.red and Doors.find(self.red.room, self.red.floor)
	if door then
		local panel = door.PrimaryPart :: BasePart
		self.redColor = panel.Color
		panel.Color = Color3.fromRGB(150, 30, 30)
		self.redDoorPos = panel.Position
		Doors.setLocked(door, true, "Red room: STORAGE", function(player)
			local root = Characters.root(player)
			if self.state.redOpened or player:GetAttribute("State") ~= "alive" or not root
				or (root.Position - panel.Position).Magnitude > 16 then
				return
			end
			if not Inventories.take(player, "key") then
				run.banner(if self.state.haveKey then "You need the storage key in your hand or a pocket."
					else "Locked. The porter keeps the storage key.", 4, player)
				return
			end
			self.state.redOpened = true
			Doors.setLocked(door, false)
			Doors.setOpen(door, true)
			run.banner("The red room is open.", 4)
			run.changed()
		end, "Unlock (storage key)")
	end
	if self.red then
		for i, item in { "salt", "fuse" } do
			local at = Pickups.spot(self.red.floor, self.red.room, (i - 1.5) * 1.2, 0)
			if at then
				local box = Pickups.part(folder, ITEM_NAMES[item], at, Vector3.new(0.35, 0.3, 0.35),
					if item == "salt" then Color3.fromRGB(235, 235, 235) else Color3.fromRGB(200, 160, 60))
				Pickups.prompt(box, "Take", ITEM_NAMES[item], 0.3, function(player)
					if box.Parent and self.state.redOpened -- not through the locked door's wall
						and Inventories.give(player, { id = item }) then
						box:Destroy()
						run.banner(`{player.DisplayName} took the {string.lower(ITEM_NAMES[item])}.`, 4)
						run.changed()
					end
				end)
			end
		end
	end
	-- 2. The fuse box in room 24 and the cabinet in Lab 14.
	local fuseAt = Pickups.spot(CampaignData.STORY.fuse.floor, CampaignData.STORY.fuse.room, 0, -2)
	if fuseAt then
		local box = Pickups.part(folder, "FuseBox", fuseAt + Vector3.new(0, S(1.2), 0), Vector3.new(0.5, 0.6, 0.2),
			Color3.fromRGB(110, 110, 100), Enum.Material.Metal)
		self.fuseBoxPos = box.Position
		Pickups.prompt(box, "Put the fuse in", "Fuse box", 0.6, function(player)
			if self.state.fusePlaced then
				return
			end
			if not Inventories.take(player, "fuse") then
				run.banner("The fuse box is missing a fuse. Hold one in your hand.", 4, player)
				return
			end
			self.state.fusePlaced = true
			run.sound("door", box.Position)
			run.banner("The fuse clicks in. Somewhere a cabinet hums.", 5)
			run.changed()
		end)
	end
	local labAt = Pickups.spot(CampaignData.STORY.lab.floor, CampaignData.STORY.lab.room, -2.5, 0)
	if labAt then
		local cabinet = Pickups.part(folder, "Cabinet", labAt, Vector3.new(0.9, 1.8, 0.5), Color3.fromRGB(90, 100, 110),
			Enum.Material.Metal)
		self.cabinetPos = cabinet.Position
		Pickups.prompt(cabinet, "Open the cabinet", "Lab cabinet", 0.5, function(player)
			if self.state.vialTaken then
				return
			end
			if not self.state.fusePlaced then
				run.banner("The cabinet's lock has no power.", 4, player)
				return
			end
			if not Inventories.give(player, { id = "vial" }) then
				return
			end
			self.state.vialTaken = true
			run.banner(`{player.DisplayName} took the holy water.`, 4)
			run.changed()
		end)
	end
	-- 3. Notes with the code, and the safe.
	self.notesRead = {}
	self.notePos = {}
	local perNote = 4 // math.max(1, #self.noteRooms)
	for i, place in self.noteRooms do
		local at = Pickups.spot(place.floor, place.room, 0.5, 0.5)
		if at then
			local first = (i - 1) * perNote + 1
			local digits = string.sub(self.code, first, first + perNote - 1)
			local text = if perNote == 1 then `Safe code: digit {first} is {digits}.`
				else `Safe code: digits {first}-{first + perNote - 1} are {digits}.`
			local note = Pickups.paper(folder, "Note", at, "Note", function(player, model)
				if self.notesRead[i] then
					return
				end
				-- The code is only on the paper: no room, no note.
				if not Inventories.give(player, { id = "papers", texts = { text } }) then
					return
				end
				self.notesRead[i] = text
				self.state.notes += 1
				model:Destroy()
				run.banner(`{player.DisplayName} found a note.`, 5)
				run.banner(`Note: {text} (it is in your papers)`, 8, player)
				run.changed()
			end)
			local paper = note:FindFirstChild("Paper") :: BasePart
			self.notePos[i] = paper.Position
		end
	end
	local safeAt = Pickups.spot(CampaignData.STORY.safe.floor, CampaignData.STORY.safe.room, 2, 2)
	if safeAt then
		local safe = Pickups.part(folder, "Safe", safeAt, Vector3.new(0.7, 0.8, 0.6), Color3.fromRGB(60, 62, 66),
			Enum.Material.DiamondPlate)
		self.safePos = safe.Position
		Pickups.prompt(safe, "Enter the code", "Old safe", 0, function(player)
			if self.state.safeOpen then
				return
			end
			(run.remotes:FindFirstChild("Keypad") :: RemoteEvent):FireClient(player, true)
		end)
	end
	-- 4. The altar in the Aula.
	local spawnPos = run.school.spawn.Position
	local altarAt = Vector3.new(spawnPos.X, S(0), spawnPos.Z - S(7))
	local altar = Pickups.part(folder, "Altar", altarAt, Vector3.new(1.6, 0.9, 0.8), Color3.fromRGB(70, 58, 50),
		Enum.Material.Slate)
	self.altarPos = altar.Position
	self.altar = altar
	Pickups.prompt(altar, "Place the items / start the ritual", "Altar", 0.6, function(player)
		self:useAltar(player)
	end)
	local dealPrompt = Pickups.prompt(altar, "Make a deal", "Altar", 1.5, function(player)
		if not self.ritualActive and not self.ritualDone then
			run.onDeal()
		end
	end)
	dealPrompt.KeyboardKeyCode = Enum.KeyCode.R
	dealPrompt.UIOffset = Vector2.new(0, 70)
	run.changed()
end

function Quest:enterCode(player: Player, code: any)
	if self.state.safeOpen or type(code) ~= "string" or not string.match(code, "^%d%d%d%d$") or not self.safePos then
		return
	end
	-- At the safe, and one try a second: no guessing all 10,000 codes from across the school.
	local root = Characters.root(player)
	if not root or (root.Position - self.safePos).Magnitude > 16 then
		return
	end
	self.lastTry = self.lastTry or {}
	local now = os.clock()
	if now - (self.lastTry[player] or 0) < 1 then
		return
	end
	self.lastTry[player] = now
	if code == self.code then
		if not Inventories.give(player, { id = "bell" }) then
			return -- "No room": make space and enter the code again
		end
		self.state.safeOpen = true
		self.run.banner(`{player.DisplayName} opened the safe: a silver bell.`, 5)
		self.run.changed()
	else
		self.run.banner("Wrong code.", 3, player)
	end
end

function Quest:useAltar(player: Player)
	local run = self.run
	if self.ritualActive or self.ritualDone then
		return
	end
	local placed = 0
	for _, item in { "salt", "vial", "bell" } do
		if not self.state.altar[item] and Inventories.take(player, item) then
			self.state.altar[item] = true
			placed += 1
		end
	end
	if placed > 0 then
		run.banner(`{player.DisplayName} placed {placed} item(s) on the altar.`, 4)
		run.changed()
	end
	local a = self.state.altar
	if not (a.salt and a.vial and a.bell) then
		if placed == 0 then
			run.banner("The altar needs salt, holy water and a silver bell, in your hand or pockets.", 4, player)
		end
		return
	end
	if run.beforeRitual then
		run.beforeRitual(function()
			if not self.ritualActive and not self.ritualDone then
				self:startRitual()
			end
		end)
	else
		self:startRitual()
	end
end

function Quest:startRitual()
	local run = self.run
	self.ritualActive = true
	local seconds = run.level.ritual * run.timeScale
	run.banner(`The ritual begins. Stay near the altar for {run.level.ritual} seconds!`, 6)
	run.sound("sting", self.altarPos)
	run.onRitualStart(self.altarPos)
	local started = os.clock()
	task.spawn(function()
		while self.ritualActive and os.clock() - started < seconds do
			task.wait(0.5)
			if not self.ritualActive then
				return -- the run ended meanwhile
			end
			local anyone = false
			for _, player in run.alive() do
				local root = Characters.root(player)
				if root and (root.Position - self.altarPos).Magnitude <= S(RITUAL_RANGE) then
					anyone = true
				end
			end
			if not anyone then
				self.ritualActive = false
				run.banner("Nobody stayed at the altar. The ritual broke off. Start it again.", 6)
				run.changed()
				return
			end
		end
		if self.ritualActive then
			self.ritualActive = false
			self.ritualDone = true
			run.changed()
			run.onRitualDone()
		end
	end)
	run.changed()
end

-- The possessed teacher lying at the altar after the ritual.
function Quest:showHost(name: string)
	local at = CFrame.new(self.altarPos + Vector3.new(0, 0, S(2))) * CFrame.Angles(-math.pi / 2, 0, 0)
	local body = Npc.build(name, Color3.fromRGB(60, 60, 64), Color3.fromRGB(40, 40, 44), at, self.run.folder)
	for _, d in body:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
end

function Quest:destroy()
	self.ritualActive = false
	if self.red then
		local door = Doors.find(self.red.room, self.red.floor)
		if door and self.redColor then
			Doors.setLocked(door, false)
			local panel = door.PrimaryPart :: BasePart
			panel.Color = self.redColor
		end
	end
end

return Quest
