-- Lobby, rounds and spawning. The only module that spawns characters. Rounds repeat RESTART_DELAY seconds after a
-- result with the same options until someone presses "Back to lobby" (match.gd). Late joiners spectate.
-- Shared state: ReplicatedStorage attributes Mode, Phase, PhaseEndsAt, Cycle; player attribute State.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Rules = require(ReplicatedStorage.Shared.Rules)
local Characters = require(script.Parent.Characters)
local Lockers = require(script.Parent.Lockers)
local Torch = require(script.Parent.Torch)

export type Options = { mode: string, entity: string, difficulty: string? }
export type RoundContext = {
	players: { Player },
	-- Adds a player who joined mid-round (modes with playerJoined): they count as playing from now on.
	addPlayer: (player: Player) -> (),
	options: Options,
	school: any,
	remotes: Folder,
	timeScale: number,
	-- Starts a phase; `onDone` runs when its time is up unless another phase started meanwhile.
	setPhase: (phase: string, seconds: number, onDone: (() -> ())?) -> (),
	remaining: () -> number,
	finish: (summary: string) -> (),
	isPlaying: (player: Player) -> boolean,
	banner: (text: string, seconds: number?, to: Player?) -> (),
	spawnAt: (index: number) -> CFrame,
}
export type Mode = {
	start: (ctx: RoundContext) -> (),
	playerLeft: (player: Player) -> (),
	playerDied: (player: Player) -> (),
	stop: () -> (),
	-- Optional: a player joined mid-round. Without it they spectate until the next round.
	playerJoined: ((player: Player) -> ())?,
}

local RoundManager = {}

local school
local remotes: Folder
local modes: { [string]: Mode } = {}
local active: Mode? = nil
local ctx: RoundContext? = nil
local options: Options? = nil
local phaseToken = 0
local timeScale = 1

local function setAttr(name: string, value: any)
	ReplicatedStorage:SetAttribute(name, value)
end

local function banner(text: string, seconds: number?, to: Player?)
	local remote = remotes:FindFirstChild("Banner") :: RemoteEvent
	if to then
		remote:FireClient(to, text, seconds or 5)
	else
		remote:FireAllClients(text, seconds or 5)
	end
end

-- Spawn points in the Aula: a small grid around the entrance spawn, 1.1 m apart (match_world.gd SPREAD).
local function spawnAt(index: number): CFrame
	local col = (index - 1) % 5
	local row = math.floor((index - 1) / 5)
	return school.spawn * CFrame.new(Config.studs((col - 2) * 1.1), 0, Config.studs(-row * 1.1))
end

local function setState(player: Player, state: string)
	player:SetAttribute("State", state)
end

-- Phase timer: writes the attributes and calls `onDone` when the time is up, unless a newer phase replaced it.
local function setPhase(phase: string, seconds: number, onDone: (() -> ())?)
	phaseToken += 1
	local token = phaseToken
	local scaled = seconds * timeScale
	setAttr("Phase", phase)
	setAttr("PhaseEndsAt", workspace:GetServerTimeNow() + scaled)
	if onDone then
		task.delay(scaled, function()
			if token == phaseToken then
				onDone()
			end
		end)
	end
end

local function remaining(): number
	return math.max(0, ((ReplicatedStorage:GetAttribute("PhaseEndsAt") or 0) - workspace:GetServerTimeNow()) / timeScale)
end

local function spawnLobby(player: Player, index: number)
	Characters.spawn(player, spawnAt(index))
	Torch.setAllowed(player, true)
	Torch.reset(player)
	player:SetAttribute("Tag", nil)
	player:SetAttribute("Seeker", nil)
	player:SetAttribute("Hidden", false)
	player:SetAttribute("Sprinting", false)
	setState(player, "lobby")
end

local function toLobby()
	active = nil
	ctx = nil
	setAttr("Mode", "none")
	setAttr("Cycle", false)
	setPhase("lobby", 0)
end

local startRound: (opts: Options) -> (boolean, string?)

local function finish(summary: string)
	if not ctx or not active then
		return
	end
	local mode = active
	active = nil
	mode.stop()
	Lockers.releaseAll()
	Lockers.canHide = function()
		return true
	end
	banner(summary, Config.RESTART_DELAY)
	-- The phase first: respawning yields, and nothing may see "no mode, but still hunting" meanwhile.
	setPhase("result", Config.RESTART_DELAY, function()
		ctx = nil
		if ReplicatedStorage:GetAttribute("Cycle") and options then
			setAttr("Phase", "lobby")
			local ok, reason = startRound(options)
			if not ok then
				banner(reason or "The next round could not start.", 6)
				toLobby()
			end
		else
			toLobby()
		end
	end)
	for i, p in Players:GetPlayers() do
		task.spawn(spawnLobby, p, i)
	end
end

startRound = function(opts: Options): (boolean, string?)
	if ReplicatedStorage:GetAttribute("Phase") ~= "lobby" then
		return false, "A round is already running."
	end
	local mode = modes[opts.mode]
	if not mode then
		return false, "Unknown mode."
	end
	local ok, reason = Rules.canStart(opts.mode :: any, opts.entity :: any, #Players:GetPlayers())
	if not ok then
		return false, reason
	end
	-- Claim the start before anything yields, so a second click or the restart timer cannot start a second round.
	setAttr("Phase", "starting")
	options = opts
	setAttr("Mode", opts.mode)
	setAttr("Cycle", opts.mode ~= "campaign") -- A story run ends in the lobby; the short modes repeat.
	local spawned = {}
	for i, p in Players:GetPlayers() do
		table.insert(spawned, p)
		task.spawn(function()
			Characters.spawn(p, spawnAt(i))
		end)
	end
	-- Wait for the characters (they load in parallel), at most 10 seconds.
	local deadline = os.clock() + 10
	repeat
		task.wait(0.1)
		local waiting = false
		for _, p in spawned do
			if p.Parent and not (p.Character and p.Character:FindFirstChild("HumanoidRootPart")) then
				waiting = true
			end
		end
	until not waiting or os.clock() > deadline
	-- Only players still here and with a character take part; check the player count again.
	local players = {}
	for _, p in spawned do
		if p.Parent and p.Character then
			table.insert(players, p)
		end
	end
	ok, reason = Rules.canStart(opts.mode :: any, opts.entity :: any, #players)
	if not ok then
		toLobby()
		for i, p in Players:GetPlayers() do
			task.spawn(spawnLobby, p, i)
		end
		return false, reason
	end
	for _, p in players do
		Torch.setAllowed(p, true)
		Torch.reset(p)
		p:SetAttribute("Hidden", false)
		setState(p, "alive")
	end
	local playing: { [Player]: boolean } = {}
	for _, p in players do
		playing[p] = true
	end
	ctx = {
		players = players,
		addPlayer = function(p: Player)
			if not playing[p] then
				playing[p] = true
				table.insert(players, p)
			end
		end,
		options = opts,
		school = school,
		remotes = remotes,
		timeScale = timeScale,
		setPhase = setPhase,
		remaining = remaining,
		finish = finish,
		isPlaying = function(p: Player): boolean
			return playing[p] == true and p.Parent ~= nil
		end,
		banner = banner,
		spawnAt = spawnAt,
	}
	active = mode
	mode.start(ctx :: RoundContext)
	return true, nil
end

-- Server-side entry for tests (Studio command bar or MCP): RoundManager.start({mode = "hideseek", entity =
-- "computer"}, {timeScale = 0.1}) runs a round with every timer ten times faster.
function RoundManager.start(opts: Options, testOptions: { timeScale: number? }?): (boolean, string?)
	timeScale = if testOptions and testOptions.timeScale then testOptions.timeScale else 1
	return startRound(opts)
end

function RoundManager.isRunning(): boolean
	return active ~= nil
end

function RoundManager.init(schoolData, remoteFolder: Folder, modeTable: { [string]: Mode })
	school = schoolData
	remotes = remoteFolder
	modes = modeTable
	toLobby()

	local startRemote = remotes:WaitForChild("StartRound") :: RemoteEvent
	startRemote.OnServerEvent:Connect(function(player, mode, entity, difficulty)
		if type(mode) ~= "string" or type(entity) ~= "string" then
			return
		end
		timeScale = 1
		local level = if type(difficulty) == "string" then difficulty else nil
		local ok, reason = startRound({ mode = mode, entity = entity, difficulty = level })
		if not ok then
			banner(reason or "Cannot start.", 5, player)
		end
	end)

	local backRemote = remotes:WaitForChild("BackToLobby") :: RemoteEvent
	backRemote.OnServerEvent:Connect(function(player)
		if active and options and options.mode == "freeroam" then
			finish(`{player.DisplayName} ended free roam.`)
			return
		end
		if ReplicatedStorage:GetAttribute("Cycle") then
			setAttr("Cycle", false)
			banner(`{player.DisplayName} stopped the rounds. Back to the lobby after this one.`, 5)
		end
	end)

	local function onCharacter(player: Player, character: Model)
		local humanoid = character:WaitForChild("Humanoid", 5)
		if not humanoid or not humanoid:IsA("Humanoid") then
			return
		end
		humanoid.Died:Connect(function()
			if active and ctx and ctx.isPlaying(player) and player.Character == character then
				active.playerDied(player)
			elseif not active then
				task.wait(3)
				if player.Parent and not active and player.Character == character then
					spawnLobby(player, 1)
				end
			end
		end)
	end

	local function join(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		local phase = ReplicatedStorage:GetAttribute("Phase")
		if active and active.playerJoined and phase ~= "starting" then
			active.playerJoined(player)
		elseif phase ~= "lobby" and phase ~= "result" then
			setState(player, "spectator")
			Torch.setAllowed(player, false)
			banner("A round is running. You watch until the next one.", 6, player)
		else
			spawnLobby(player, #Players:GetPlayers())
		end
	end
	Players.PlayerAdded:Connect(join)
	for _, p in Players:GetPlayers() do
		task.spawn(join, p)
	end

	Players.PlayerRemoving:Connect(function(player)
		if active and ctx and ctx.isPlaying(player) then
			active.playerLeft(player)
		end
	end)
end

return RoundManager
