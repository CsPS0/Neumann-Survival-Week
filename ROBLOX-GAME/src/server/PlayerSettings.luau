-- Saves each player's menu settings (field of view, mouse sensitivity, volume, FPS counter) in a DataStore and sends
-- them back when they join. Values are re-checked with Settings.clean, whatever the client sends. In Studio this
-- needs "Enable Studio Access to API Services"; without it the settings simply do not persist.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Settings)
Settings.useKeybinds(require(ReplicatedStorage.Shared.Keybinds))

local PlayerSettings = {}

local store = nil :: DataStore?
local current: { [Player]: Settings.Values } = {}
local dirty: { [Player]: boolean } = {}

local function key(player: Player): string
	return "u" .. player.UserId
end

local function save(player: Player)
	local values = current[player]
	if not store or not values or not dirty[player] then
		return
	end
	dirty[player] = nil
	local ok, err = pcall(function()
		(store :: DataStore):SetAsync(key(player), values, { player.UserId })
	end)
	if not ok then
		warn("[settings] save failed: " .. tostring(err))
	end
end

function PlayerSettings.init(remotes: Folder)
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("PlayerSettings")
	end)
	store = if ok then result else nil
	local settingsRemote = remotes:WaitForChild("Settings") :: RemoteEvent
	local saveRemote = remotes:WaitForChild("SaveSettings") :: RemoteEvent

	local function load(player: Player)
		local raw = nil
		if store then
			local good, data = pcall(function()
				return (store :: DataStore):GetAsync(key(player))
			end)
			raw = if good then data else nil
		end
		local values = Settings.clean(raw)
		current[player] = values
		if player.Parent then
			settingsRemote:FireClient(player, values)
		end
	end
	Players.PlayerAdded:Connect(load)
	for _, p in Players:GetPlayers() do
		task.spawn(load, p)
	end

	saveRemote.OnServerEvent:Connect(function(player, raw)
		current[player] = Settings.clean(raw)
		dirty[player] = true
	end)

	Players.PlayerRemoving:Connect(function(player)
		save(player)
		current[player] = nil
		dirty[player] = nil
	end)
	game:BindToClose(function()
		for player in current do
			save(player)
		end
	end)
end

return PlayerSettings
