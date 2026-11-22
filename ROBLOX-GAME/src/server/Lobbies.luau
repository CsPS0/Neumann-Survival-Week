-- Private lobbies by code. "Create private lobby" makes a reserved server (a developer GUID in
-- TeleportOptions.ReservedServerId), stores code -> GUID in a MemoryStore hash map for 6 hours and teleports the
-- creator there; "Join by code" looks the code up and teleports the player to the same server. The lobby server
-- learns its code from the teleport data and shows it (ReplicatedStorage attribute LobbyCode). An invite sent from a
-- private lobby carries the code as launch data, so the friend lands in the same lobby.
-- Reserved servers only exist in the published game: in Studio the buttons explain that instead.
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Settings = require(ReplicatedStorage.Shared.Settings)

local LIFETIME = 6 * 3600 -- seconds a code stays valid (renewed while the lobby runs)

local Lobbies = {}

local remotes: Folder
local codes = nil :: MemoryStoreHashMap?
local busy: { [Player]: boolean } = {}

local function banner(player: Player, text: string)
	local remote = remotes:FindFirstChild("Banner") :: RemoteEvent
	remote:FireClient(player, text, 6)
end

local function map(): MemoryStoreHashMap?
	if not codes then
		local ok, result = pcall(function()
			return MemoryStoreService:GetHashMap("LobbyCodes")
		end)
		codes = if ok then result else nil
	end
	return codes
end

local function inRound(player: Player): boolean
	local state = player:GetAttribute("State")
	return state == "alive" or state == "downed"
end

local function teleport(player: Player, serverId: string, code: string): boolean
	local options = Instance.new("TeleportOptions")
	options.ReservedServerId = serverId
	options:SetTeleportData({ lobbyCode = code })
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not ok then
		warn("[lobbies] teleport failed: " .. tostring(err))
		banner(player, "Could not move you to that lobby. Try again in a moment.")
	end
	return ok
end

local function create(player: Player)
	if RunService:IsStudio() then
		banner(player, "Private lobbies only work in the published game, not in Studio.")
		return
	end
	if inRound(player) then
		banner(player, "Finish the round first.")
		return
	end
	local store = map()
	if not store then
		banner(player, "Private lobbies are not available right now.")
		return
	end
	local code, serverId = nil, HttpService:GenerateGUID(false)
	for _ = 1, 5 do
		local candidate = Settings.newCode(math.random)
		local ok, existing = pcall(function()
			return store:GetAsync(candidate)
		end)
		if ok and existing == nil then
			code = candidate
			break
		end
	end
	if not code then
		banner(player, "Could not make a lobby code. Try again.")
		return
	end
	local ok = pcall(function()
		store:SetAsync(code, serverId, LIFETIME)
	end)
	if not ok then
		banner(player, "Could not make a lobby. Try again.")
		return
	end
	banner(player, `Making lobby {code}...`)
	teleport(player, serverId, code)
end

local function join(player: Player, raw: any)
	local code = Settings.cleanCode(raw)
	if not code then
		banner(player, "A lobby code has 5 letters or numbers.")
		return
	end
	if code == ReplicatedStorage:GetAttribute("LobbyCode") then
		banner(player, "You are already in that lobby.")
		return
	end
	if RunService:IsStudio() then
		banner(player, "Joining by code only works in the published game, not in Studio.")
		return
	end
	if inRound(player) then
		banner(player, "Finish the round first.")
		return
	end
	local store = map()
	local ok, serverId = false, nil
	if store then
		ok, serverId = pcall(function()
			return store:GetAsync(code)
		end)
	end
	if not ok or type(serverId) ~= "string" then
		banner(player, `No lobby with the code {code}.`)
		return
	end
	banner(player, `Joining lobby {code}...`)
	teleport(player, serverId, code)
end

local function onJoined(player: Player)
	local data = player:GetJoinData()
	-- Arrived through a lobby teleport: this server is that lobby.
	local teleportData = data.TeleportData
	if type(teleportData) == "table" and ReplicatedStorage:GetAttribute("LobbyCode") == nil then
		local code = Settings.cleanCode(teleportData.lobbyCode)
		if code and game.PrivateServerId ~= "" then
			ReplicatedStorage:SetAttribute("LobbyCode", code)
		end
	end
	-- Arrived through an invite from a private lobby: go to it.
	local launch = data.LaunchData
	if type(launch) == "string" and launch ~= "" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, launch)
		local code = ok and type(decoded) == "table" and Settings.cleanCode(decoded.lobby)
		if code and code ~= ReplicatedStorage:GetAttribute("LobbyCode") then
			task.delay(2, join, player, code)
		end
	end
end

function Lobbies.init(remoteFolder: Folder)
	remotes = remoteFolder
	local function guarded(fn: (Player, any) -> ())
		return function(player: Player, arg: any)
			if busy[player] then
				return
			end
			busy[player] = true
			local ok, err = pcall(fn, player, arg)
			if not ok then
				warn("[lobbies] " .. tostring(err))
			end
			task.delay(3, function()
				busy[player] = nil
			end)
		end
	end
	local createRemote = remotes:WaitForChild("CreateLobby") :: RemoteEvent
	createRemote.OnServerEvent:Connect(guarded(create))
	local joinRemote = remotes:WaitForChild("JoinLobby") :: RemoteEvent
	joinRemote.OnServerEvent:Connect(guarded(join))

	Players.PlayerAdded:Connect(onJoined)
	for _, p in Players:GetPlayers() do
		task.spawn(onJoined, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		busy[p] = nil
	end)

	TeleportService.TeleportInitFailed:Connect(function(player, result, message)
		if player.Parent then
			banner(player, `The move failed ({result.Name}). Try again.`)
		end
		warn("[lobbies] teleport init failed: " .. tostring(message))
	end)

	-- A lobby keeps its code alive while it runs and frees it when it closes.
	task.spawn(function()
		while true do
			task.wait(1800)
			local code = ReplicatedStorage:GetAttribute("LobbyCode")
			local store = map()
			if code and store and game.PrivateServerId ~= "" then
				pcall(function()
					store:UpdateAsync(code, function(old)
						return old
					end, LIFETIME)
				end)
			end
		end
	end)
	game:BindToClose(function()
		local code = ReplicatedStorage:GetAttribute("LobbyCode")
		local store = map()
		if code and store and not RunService:IsStudio() then
			pcall(function()
				store:RemoveAsync(code)
			end)
		end
	end)
end

return Lobbies
