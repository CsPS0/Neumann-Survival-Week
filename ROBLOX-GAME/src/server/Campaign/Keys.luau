-- Room keys in the story (src/shared/KeyRules.luau has the rules). When a story starts, every classroom, computer
-- room and the gym with a single way in is locked, except the rooms the story needs open (the day's lessons, the
-- story rooms and the night's rooms). E on a locked door: with its key on you (hand, pockets or the worn bag) it
-- opens for good; without it the porter remembers which room you wanted. The porter has one prompt: he lends the
-- key you asked for, gives the storage key at night (Quest adds that as a topic), and otherwise takes back every room
-- key you carry.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FloorData = require(ReplicatedStorage.Shared.FloorData)
local KeyRules = require(ReplicatedStorage.Shared.KeyRules)
local Rooms = require(ReplicatedStorage.Shared.Rooms)
local Characters = require(script.Parent.Parent.Characters)
local Doors = require(script.Parent.Parent.Doors)
local Inventories = require(script.Parent.Inventories)
local Pickups = require(script.Parent.Pickups)
local AchievementService = require(script.Parent.Parent.AchievementService)
local Achievements = require(ReplicatedStorage.Shared.Achievements)

local WANT_FOR = 180 -- seconds the porter remembers which locked door you tried

export type Opts = {
	exempt: { [string]: boolean }, -- "floor:label" rooms that stay open
	banner: (text: string, seconds: number?, to: Player?) -> (),
	isNight: () -> boolean,
}

type Active = {
	opts: Opts,
	ledgers: { [number]: KeyRules.Ledger },
	borrowed: { [number]: { [string]: boolean } }, -- every room key a player got this run (Key Collector)
	wanted: { [number]: { room: string, floor: number, at: number } },
	locked: { [Model]: boolean },
	topics: { (Player) -> boolean },
	prompt: ProximityPrompt?,
	left: RBXScriptConnection,
}

local Keys = {}
local active: Active? = nil

local function say(player: Player, line: string)
	if active then
		active.opts.banner(`Porter: {line}`, 6, player)
	end
end

local function ledgerOf(a: Active, player: Player): KeyRules.Ledger
	local ledger = a.ledgers[player.UserId]
	if not ledger then
		ledger = KeyRules.newLedger()
		a.ledgers[player.UserId] = ledger
	end
	return ledger
end

local function carriedRooms(player: Player): { string }
	local rooms = {}
	for _, id in Inventories.carried(player, KeyRules.isKey) do
		table.insert(rooms, KeyRules.roomOf(id) :: string)
	end
	return rooms
end

-- E on a locked door.
local function tryDoor(player: Player, door: Model, room: string, floor: number)
	local a = active
	local panel = door.PrimaryPart
	local root = Characters.root(player)
	if not a or not panel or not root or player:GetAttribute("State") ~= "alive"
		or (root.Position - panel.Position).Magnitude > 16 then
		return
	end
	if table.find(carriedRooms(player), room) then
		for _, d in Doors.ofRoom(room, floor) do
			a.locked[d] = nil
			Doors.setLocked(d, false)
		end
		Doors.setOpen(door, true)
		a.opts.banner(`You unlock {room}.`, 3, player)
		return
	end
	a.wanted[player.UserId] = { room = room, floor = floor, at = os.clock() }
	a.opts.banner(`Locked. The porter at the Porta lends the key to {room}.`, 4, player)
end

local function talk(player: Player)
	local a = active
	if not a then
		return
	end
	local ledger = ledgerOf(a, player)
	local carried = carriedRooms(player)
	-- 1. The room you just tried.
	local want = a.wanted[player.UserId]
	if want and os.clock() - want.at < WANT_FOR and not table.find(carried, want.room) then
		a.wanted[player.UserId] = nil
		local before = table.clone(ledger.out)
		local ok, line = KeyRules.ask(ledger, want.room, carried, os.clock(), a.opts.isNight(), math.random)
		if ok and not Inventories.give(player, { id = KeyRules.itemId(want.room) }) then
			ledger.out = before -- no room for it: "No room" was shown
			return
		end
		if ok then
			local got = a.borrowed[player.UserId] or {}
			a.borrowed[player.UserId] = got
			got[want.room] = true
			local n = 0
			for _ in got do
				n += 1
			end
			if n >= Achievements.KEYS then
				AchievementService.award(player, "key_collector")
			end
		end
		say(player, line)
		return
	end
	-- 2. Whatever the story adds (the storage key at night).
	for _, topic in a.topics do
		if topic(player) then
			return
		end
	end
	-- 3. Give every room key back.
	local returned = {}
	for _, id in Inventories.takeAll(player, KeyRules.isKey) do
		table.insert(returned, KeyRules.roomOf(id) :: string)
	end
	say(player, KeyRules.giveBack(ledger, returned))
end

-- Locks the keyed rooms and gives the porter his prompt.
function Keys.start(opts: Opts, porter: Model?)
	Keys.stop()
	local a: Active = {
		opts = opts,
		ledgers = {},
		borrowed = {},
		wanted = {},
		locked = {},
		topics = {},
		prompt = nil,
		left = Players.PlayerRemoving:Connect(function(player)
			if active then
				active.ledgers[player.UserId] = nil
				active.wanted[player.UserId] = nil
			end
		end),
	}
	active = a
	for f, fl in FloorData.FLOORS do
		local floor = f - 1
		for _, r in fl.rooms do
			if r.label ~= "" and not opts.exempt[`{floor}:{r.label}`]
				and KeyRules.isKeyed(Rooms.typeOf(r.label), KeyRules.doorCount(r.doors)) then
				for _, door in Doors.ofRoom(r.label, floor) do
					a.locked[door] = true
					local room = r.label
					Doors.setLocked(door, true, `{room}: locked. The key is at the Porta.`, function(player)
						tryDoor(player, door, room, floor)
					end, "Unlock")
				end
			end
		end
	end
	local root = porter and porter:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		a.prompt = Pickups.prompt(root, "Talk", "Porter (keys)", 0.3, talk)
	end
end

-- Something else the porter can be asked (checked after the room you tried, before giving keys back). The topic
-- returns true when it answered.
function Keys.addTopic(topic: (Player) -> boolean)
	if active then
		table.insert(active.topics, topic)
	end
end

-- Story over: every door it locked opens up again.
function Keys.stop()
	local a = active
	if not a then
		return
	end
	active = nil
	a.left:Disconnect()
	if a.prompt then
		a.prompt:Destroy()
	end
	for door in a.locked do
		if door.Parent and door:GetAttribute("Locked") then
			Doors.setLocked(door, false)
		end
	end
end

return Keys
