-- What this client knows about the round: the phase and mode (ReplicatedStorage attributes), its own state (player
-- attribute) and its secret role (the Role remote). `State.changed` fires when any of them changes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local State = {
	role = nil :: string?, -- "survivor" | "entity" | "crew" | nil
	partner = nil :: string?, -- the other entity's tag in Social Deduction with two entities
}

local changedEvent = Instance.new("BindableEvent")
State.changed = changedEvent.Event

function State.phase(): string
	return ReplicatedStorage:GetAttribute("Phase") or "lobby"
end

function State.mode(): string
	return ReplicatedStorage:GetAttribute("Mode") or "none"
end

function State.mine(): string
	return player:GetAttribute("State") or "lobby"
end

function State.alive(): boolean
	return State.mine() == "alive"
end

function State.init(remotes: Folder)
	(remotes:WaitForChild("Role") :: RemoteEvent).OnClientEvent:Connect(function(role, partner)
		State.role = role
		State.partner = partner
		changedEvent:Fire()
	end)
	for _, name in { "Phase", "Mode" } do
		ReplicatedStorage:GetAttributeChangedSignal(name):Connect(function()
			if State.phase() == "lobby" then
				State.role = nil
				State.partner = nil
			end
			changedEvent:Fire()
		end)
	end
	for _, name in { "State", "Hidden", "TorchAllowed" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			changedEvent:Fire()
		end)
	end
end

return State
