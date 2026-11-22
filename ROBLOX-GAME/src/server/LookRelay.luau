-- Relays each player's head pitch to the other players (UnreliableRemoteEvent "Look"). The server only checks and
-- forwards: a finite number, clamped to +-80 degrees, at most 25 updates a second per player. It never moves joints;
-- every client animates the others itself.
local Players = game:GetService("Players")

local MAX_PITCH = math.rad(80)
local MIN_INTERVAL = 1 / 25

local LookRelay = {}

function LookRelay.init(remotes: Folder)
	local look = remotes:WaitForChild("Look") :: UnreliableRemoteEvent
	local last: { [Player]: number } = {}
	look.OnServerEvent:Connect(function(player, pitch)
		if type(pitch) ~= "number" or pitch ~= pitch or math.abs(pitch) == math.huge then
			return
		end
		local now = os.clock()
		if now - (last[player] or 0) < MIN_INTERVAL then
			return
		end
		last[player] = now
		local clamped = math.clamp(pitch, -MAX_PITCH, MAX_PITCH)
		for _, other in Players:GetPlayers() do
			if other ~= player then
				look:FireClient(other, player, clamped)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		last[player] = nil
	end)
end

return LookRelay
