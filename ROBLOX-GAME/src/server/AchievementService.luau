-- Achievements (the list: src/shared/Achievements.luau). AchievementService.award(player, id) from anywhere on the
-- server; each player's unlocked set is kept in a DataStore (saved right away, and when they leave) and sent to them
-- with the new one, which their client shows as a toast. Also counts the rooms each player walks into (Explorer).
-- In Studio saving needs "Enable Studio Access to API Services"; without it achievements last for the session.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Achievements = require(ReplicatedStorage.Shared.Achievements)
local Config = require(ReplicatedStorage.Shared.Config)
local FloorData = require(ReplicatedStorage.Shared.FloorData)

local AchievementService = {}

local store = nil :: DataStore?
local have: { [Player]: { [string]: boolean } } = {}
local rooms: { [Player]: { [string]: boolean } } = {}
local remote: RemoteEvent

local function key(player: Player): string
	return "u" .. player.UserId
end

local function save(player: Player)
	local set = have[player]
	if not store or not set then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			(store :: DataStore):SetAsync(key(player), set, { player.UserId })
		end)
		if not ok then
			warn("[achievements] save failed: " .. tostring(err))
		end
	end)
end

local function send(player: Player, new: string?)
	local list = {}
	for id in have[player] or {} do
		table.insert(list, id)
	end
	remote:FireClient(player, list, new)
end

function AchievementService.award(player: Player, id: string)
	local set = have[player]
	if not set or not player.Parent then
		return
	end
	local new, extra = Achievements.add(set, id)
	if not new then
		return
	end
	send(player, id)
	if extra then
		task.delay(3, function()
			if player.Parent then
				send(player, extra)
			end
		end)
	end
	save(player)
end

function AchievementService.has(player: Player, id: string): boolean
	return have[player] ~= nil and have[player][id] == true
end

function AchievementService.init(remotes: Folder)
	remote = remotes:WaitForChild("Achievements") :: RemoteEvent
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("Achievements")
	end)
	store = if ok then result else nil
	local function load(player: Player)
		local raw = nil
		if store then
			local good, data = pcall(function()
				return (store :: DataStore):GetAsync(key(player))
			end)
			raw = if good then data else nil
		end
		if not player.Parent then
			return
		end
		have[player] = Achievements.clean(raw)
		rooms[player] = {}
		send(player, nil)
	end
	Players.PlayerAdded:Connect(load)
	for _, p in Players:GetPlayers() do
		task.spawn(load, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		have[player] = nil
		rooms[player] = nil
	end)
	-- Explorer: the rooms each player has walked into this visit.
	task.spawn(function()
		while true do
			task.wait(2)
			for player, seen in rooms do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and not AchievementService.has(player, "explorer") then
					local m = root.Position / Config.STUDS_PER_METRE
					local floor = FloorData.floorAt(m.Y)
					local label = FloorData.roomLabelAt(floor, m.X, m.Z)
					if label and label ~= "" then
						seen[`{floor}:{label}`] = true
						local n = 0
						for _ in seen do
							n += 1
						end
						if n >= Achievements.EXPLORER_ROOMS then
							AchievementService.award(player, "explorer")
						end
					end
				end
			end
		end
	end)
end

return AchievementService
