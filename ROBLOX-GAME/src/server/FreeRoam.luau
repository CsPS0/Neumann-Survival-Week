-- Free roam: the school by day with nothing chasing you. Walk anywhere (every door opens), play ping pong and
-- basketball, meet Csoki, carry things in your bag. Admins (src/shared/AdminRules.luau) get a panel (F2 / the menu):
-- time of day, walking speed, teleport to a room, items, the room lights, call Csoki, the crowd, end free roam.
-- Every request is checked here, whatever a client sends. Ends when an admin ends it or everyone left.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AdminRules = require(ReplicatedStorage.Shared.AdminRules)
local Config = require(ReplicatedStorage.Shared.Config)
local FloorData = require(ReplicatedStorage.Shared.FloorData)
local AchievementService = require(script.Parent.AchievementService)
local Characters = require(script.Parent.Characters)
local Inventories = require(script.Parent.Campaign.Inventories)

local S = Config.studs

local FreeRoam = {}

local ctx = nil :: any
local folder: Folder? = nil
local connection: RBXScriptConnection? = nil

local function isAdmin(player: Player): boolean
	local creatorIsGroup = game.CreatorType == Enum.CreatorType.Group
	local rank = 0
	if creatorIsGroup then
		local ok, r = pcall(player.GetRankInGroup, player, game.CreatorId)
		rank = if ok then r else 0
	end
	return AdminRules.isAdmin({
		userId = player.UserId,
		creatorId = game.CreatorId,
		creatorIsGroup = creatorIsGroup,
		groupRank = rank,
		privateOwnerId = game.PrivateServerOwnerId,
		studio = RunService:IsStudio(),
	})
end

-- Marks who sees the panel (the client shows it only with this attribute; the server checks again anyway).
local function mark(player: Player)
	player:SetAttribute("Admin", isAdmin(player))
end

local function play(player: Player)
	ctx.addPlayer(player)
	player:SetAttribute("State", "alive")
	ReplicatedStorage:SetAttribute("FreeRoamPlayers", #Players:GetPlayers())
	player:SetAttribute("Hidden", false)
	AchievementService.award(player, "free_spirit")
	Inventories.join(player)
	mark(player)
end

local function act(player: Player, op: any, args: any)
	if not ctx or not player:GetAttribute("Admin") or not isAdmin(player) then
		return
	end
	local a = AdminRules.check(op, args)
	if not a then
		return
	end
	if op == "time" then
		ReplicatedStorage:SetAttribute("FreeRoamClock", a.hour)
		ctx.banner(`Admin: the time is now {string.format("%02d:%02d", math.floor(a.hour), (a.hour % 1) * 60)}.`, 3)
	elseif op == "speed" then
		Characters.setSpeed(player, if a.times == 1 then nil else Config.Player.walk * a.times)
		ctx.banner(`Walking speed x{a.times}.`, 3, player)
	elseif op == "give" then
		Inventories.give(player, { id = a.item })
	elseif op == "teleport" then
		local r = FloorData.roomRect(a.floor, a.room)
		if r then
			Characters.place(player, CFrame.new(S((r.x0 + r.x1) / 2), S(a.floor * Config.FLOOR_HEIGHT) + 3,
				S((r.z0 + r.z1) / 2)))
		else
			ctx.banner(`There is no room {a.room} on that floor.`, 3, player)
		end
	elseif op == "lights" then
		local on = not ReplicatedStorage:GetAttribute("RoomLightsOff")
		ReplicatedStorage:SetAttribute("RoomLightsOff", on)
		ctx.banner(if on then "Admin: the room lights are off." else "Admin: the room lights are on.", 3)
	elseif op == "csoki" then
		local csoki = (require :: any)(script.Parent.Csoki)
		csoki.callTo(player)
	elseif op == "people" then
		local off = not ReplicatedStorage:GetAttribute("CrowdOff")
		ReplicatedStorage:SetAttribute("CrowdOff", off)
		ctx.banner(if off then "Admin: the school empties." else "Admin: the people are back.", 3)
	elseif op == "attackMe" then
		require(script.Parent.TestBots).attackMe(player, workspace)
	elseif op == "demo" then
		local r = Characters.root(player)
		if r and not require(script.Parent.TestBots).run(r.CFrame, workspace) then
			ctx.banner("The attack demo is already running.", 3, player)
		end
	elseif op == "end" then
		ctx.finish("Free roam ended.")
	end
end

function FreeRoam.start(c)
	ctx = c
	local f = Instance.new("Folder")
	f.Name = "FreeRoam"
	f.Parent = workspace
	folder = f
	Inventories.enable(f)
	for _, p in c.players do
		play(p)
	end
	local remote = c.remotes:FindFirstChild("AdminAction") :: RemoteEvent
	connection = remote.OnServerEvent:Connect(act)
	-- A few dog biscuits in the Büfé and the kitchen: Csoki follows whoever brings one.
	for _, room in { "Büfé", "Konyha" } do
		local r = FloorData.roomRect(0, room)
		if r then
			Inventories.dropItem({ id = "biscuit" }, Vector3.new(S((r.x0 + r.x1) / 2), 1.5, S((r.z0 + r.z1) / 2)))
		end
	end
	c.setPhase("freeroam", 0)
	c.banner("Free roam: the school is yours. Ping pong in the Aula, basketball in the gym, Csoki is around.", 7)
end

function FreeRoam.playerJoined(player: Player)
	if ctx then
		task.spawn(function()
			Characters.spawn(player, ctx.spawnAt(1))
			play(player)
		end)
	end
end

function FreeRoam.playerLeft(_player: Player)
	if ctx and #Players:GetPlayers() <= 1 then
		ctx.finish("Everyone left.")
	end
end

function FreeRoam.playerDied(player: Player)
	if ctx then
		task.delay(3, function()
			if ctx and player.Parent then
				Characters.spawn(player, ctx.spawnAt(1))
				player:SetAttribute("State", "alive")
			end
		end)
	end
end

function FreeRoam.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	for _, p in Players:GetPlayers() do
		Characters.setSpeed(p, nil)
		p:SetAttribute("Admin", nil)
	end
	ReplicatedStorage:SetAttribute("FreeRoamClock", nil)
	ReplicatedStorage:SetAttribute("RoomLightsOff", nil)
	ReplicatedStorage:SetAttribute("CrowdOff", nil)
	Inventories.disable()
	if folder then
		folder:Destroy()
		folder = nil
	end
	ctx = nil
end

return FreeRoam
