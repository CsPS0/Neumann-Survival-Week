-- The torch (HORROR-GAME/scripts/player.gd): F switches a head spotlight, T flashes it. The server owns the battery
-- (drains while lit, 15 per flash) and the 12 s flash cooldown, kept in player attributes for the HUD.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local T = Config.Torch
local S = Config.studs

local Torch = {}

-- Set by the active mode: called after a successful flash with the head position and the look direction.
Torch.onFlash = nil :: ((player: Player, origin: Vector3, look: Vector3) -> ())?

local function light(player: Player): SpotLight?
	local head = player.Character and player.Character:FindFirstChild("Head")
	return head and head:FindFirstChild("Torch") :: SpotLight?
end

local function apply(player: Player)
	local l = light(player)
	if l then
		l.Enabled = player:GetAttribute("TorchOn") == true
	end
end

local function setOn(player: Player, on: boolean)
	-- Never in a locker, downed or out.
	local state = player:GetAttribute("State")
	local usable = not player:GetAttribute("Hidden") and (state == "alive" or state == "lobby")
	player:SetAttribute("TorchOn", on and usable and player:GetAttribute("TorchAllowed") ~= false
		and (player:GetAttribute("Battery") or 0) > 0)
	apply(player)
end

function Torch.reset(player: Player)
	player:SetAttribute("Battery", T.batteryMax)
	player:SetAttribute("FlashReadyAt", 0)
	setOn(player, false)
end

function Torch.off(player: Player)
	setOn(player, false)
end

function Torch.setAllowed(player: Player, allowed: boolean)
	player:SetAttribute("TorchAllowed", allowed)
	if not allowed then
		setOn(player, false)
	end
end

local function addLight(player: Player, character: Model)
	local head = character:WaitForChild("Head", 5)
	if not head then
		return
	end
	local l = Instance.new("SpotLight")
	l.Name = "Torch"
	l.Face = Enum.NormalId.Front
	l.Angle = T.coneDeg * 2
	l.Range = S(T.range)
	l.Brightness = 3
	l.Color = Color3.fromRGB(255, 244, 220)
	l.Shadows = true
	l.Parent = head
	apply(player)
end

function Torch.init(remotes: Folder)
	local function setup(player: Player)
		player:SetAttribute("TorchAllowed", true)
		Torch.reset(player)
		player.CharacterAdded:Connect(function(character)
			addLight(player, character)
		end)
		if player.Character then
			addLight(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(setup)
	for _, p in Players:GetPlayers() do
		setup(p)
	end

	(remotes:WaitForChild("Torch") :: RemoteEvent).OnServerEvent:Connect(function(player, on)
		if type(on) == "boolean" then
			setOn(player, on)
		end
	end);

	(remotes:WaitForChild("Flash") :: RemoteEvent).OnServerEvent:Connect(function(player, look)
		local head = player.Character and player.Character:FindFirstChild("Head")
		if typeof(look) ~= "Vector3" or look.Magnitude < 0.5 or not head or not head:IsA("BasePart") then
			return
		end
		local now = workspace:GetServerTimeNow()
		local battery = player:GetAttribute("Battery") or 0
		local state = player:GetAttribute("State")
		if player:GetAttribute("TorchAllowed") == false or player:GetAttribute("Hidden")
			or (state ~= "alive" and state ~= "lobby") or battery < T.cost
			or now < (player:GetAttribute("FlashReadyAt") or 0) then
			return
		end
		player:SetAttribute("Battery", battery - T.cost)
		player:SetAttribute("FlashReadyAt", now + T.cooldown)
		local l = light(player)
		if l then
			-- A short bright burst everyone sees, then back to the normal beam (on or off).
			l.Brightness = 12
			l.Enabled = true
			task.delay(0.2, function()
				l.Brightness = 3
				apply(player)
			end)
		end
		if Torch.onFlash then
			Torch.onFlash(player, head.Position, look.Unit)
		end
	end)

	-- Battery drain while lit, written four times a second so the attribute does not flood the network.
	local pending = 0
	RunService.Heartbeat:Connect(function(dt)
		pending += dt
		if pending < 0.25 then
			return
		end
		local step = pending
		pending = 0
		for _, p in Players:GetPlayers() do
			if p:GetAttribute("TorchOn") then
				local battery = math.max(0, (p:GetAttribute("Battery") or 0) - T.drainPerSec * step)
				p:SetAttribute("Battery", battery)
				if battery <= 0 then
					setOn(p, false)
				end
			end
		end
	end)
end

return Torch
