-- Hiding in lockers (HORROR-GAME/scripts/hiding_spot.gd). E on a free locker hides you inside: your character is
-- anchored in it and invisible to others, the camera goes first person and your torch goes out. E again leaves.
-- Space (the Breath remote) holds your breath; the computer entity skips lockers whose occupant holds it.
local Players = game:GetService("Players")

local Characters = require(script.Parent.Characters)
local Torch = require(script.Parent.Torch)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local Lockers = {}

local occupantOf: { [Model]: Player } = {}
local lockerOf: { [Player]: Model } = {}
local breath: { [Player]: boolean } = {}
local saved: { [Player]: { [Instance]: number } } = {}
local enabled = true

-- Who may hide right now; the active mode can narrow it (e.g. only alive survivors). Lobby: everyone.
Lockers.canHide = function(_player: Player): boolean
	return true
end

local function promptOf(locker: Model): ProximityPrompt?
	return locker:FindFirstChild("HidePrompt", true) :: ProximityPrompt?
end

local function setVisible(player: Player, visible: boolean)
	local character = player.Character
	if not character then
		return
	end
	if not visible then
		local store = {}
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				store[d] = d.Transparency
				d.Transparency = 1
			elseif d:IsA("BillboardGui") then -- The Social Deduction tag would float above the locker.
				store[d] = if d.Enabled then 1 else 0
				d.Enabled = false
			end
		end
		saved[player] = store
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	else
		for d, t in saved[player] or {} do
			if d.Parent then
				if d:IsA("BillboardGui") then
					d.Enabled = t == 1
				else
					(d :: any).Transparency = t
				end
			end
		end
		saved[player] = nil
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and player:GetAttribute("Tag") == nil then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		end
	end
end

-- The locker door's clang for everyone near it.
local function clang(locker: Model)
	local body = locker.PrimaryPart
	local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	local sound = remotes and remotes:FindFirstChild("Sound")
	if body and sound then
		(sound :: RemoteEvent):FireAllClients("locker", body.Position)
	end
end

local function hide(player: Player, locker: Model)
	local body = locker.PrimaryPart
	local root = Characters.root(player)
	if not body or not root then
		return
	end
	occupantOf[locker] = player
	lockerOf[player] = locker
	breath[player] = false
	Torch.off(player)
	root.Anchored = true
	player.Character:PivotTo(body.CFrame * CFrame.Angles(0, math.pi, 0)) -- Facing the door, to look out.
	setVisible(player, false)
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player:SetAttribute("Hidden", true)
	locker:SetAttribute("Occupant", player.UserId)
	clang(locker)
end

-- Frees the player's locker. `place` puts the character in front of it (false when the character is gone).
local function free(player: Player, place: boolean)
	local locker = lockerOf[player]
	if not locker then
		return
	end
	occupantOf[locker] = nil
	lockerOf[player] = nil
	breath[player] = nil
	locker:SetAttribute("Occupant", 0)
	clang(locker)
	if player.Parent then
		player:SetAttribute("Hidden", false)
		player.CameraMode = game:GetService("StarterPlayer").CameraMode -- First person, the game's default.
	end
	if place and player.Character and locker.PrimaryPart then
		setVisible(player, true)
		-- In front of the door (Godot exit position: 0.95 m along the locker's +Z), standing height.
		local front = locker.PrimaryPart.CFrame * CFrame.new(0, 0, Config.studs(0.95))
		player.Character:PivotTo(front * CFrame.Angles(0, math.pi, 0)) -- Facing out of the locker.
		local root = Characters.root(player)
		if root then
			root.Anchored = false
		end
	else
		saved[player] = nil
	end
end

function Lockers.release(player: Player)
	free(player, true)
end

function Lockers.releaseAll()
	for player in lockerOf do
		free(player, true)
	end
end

function Lockers.isHidden(player: Player): boolean
	return lockerOf[player] ~= nil
end

function Lockers.holdingBreath(player: Player): boolean
	return breath[player] == true
end

function Lockers.occupied(): { [Model]: Player }
	return occupantOf
end

function Lockers.lockerOf(player: Player): Model?
	return lockerOf[player]
end

function Lockers.setEnabled(on: boolean)
	enabled = on
	if not on then
		Lockers.releaseAll()
	end
end

function Lockers.init(lockers: { Model }, remotes: Folder)
	for _, locker in lockers do
		local prompt = promptOf(locker)
		if not prompt then
			continue
		end
		-- The prompt always says "Hide": an occupied locker looks like any other (nothing happens on it).
		prompt.Triggered:Connect(function(player)
			local root = Characters.root(player)
			local near = root and locker.PrimaryPart and (root.Position - locker.PrimaryPart.Position).Magnitude < 14
			if near and enabled and occupantOf[locker] == nil and lockerOf[player] == nil and Lockers.canHide(player) then
				hide(player, locker)
			end
		end)
	end
	local breathRemote = remotes:WaitForChild("Breath") :: RemoteEvent
	breathRemote.OnServerEvent:Connect(function(player, holding)
		if type(holding) == "boolean" and lockerOf[player] then
			breath[player] = holding
		end
	end)
	local leaveRemote = remotes:WaitForChild("LeaveLocker") :: RemoteEvent
	leaveRemote.OnServerEvent:Connect(function(player)
		free(player, true)
	end)
	Players.PlayerRemoving:Connect(function(player)
		free(player, false)
	end)
	local function watch(player: Player)
		player.CharacterRemoving:Connect(function()
			free(player, false)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
end

return Lockers
