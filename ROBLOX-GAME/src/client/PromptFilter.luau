-- Shows each ProximityPrompt only to the players it is meant for (attribute `For`), and never a prompt on your own
-- character (attribute `Owner` = UserId). The change is local; the server checks every trigger again.
--   all       anyone
--   living    anyone alive in a round (Social Deduction body reports)
--   survivor  alive Hide and Seek survivors (revive)
--   entity    an alive entity (catch, takedown)
-- Prompts are kept in a set (added/removed events), so a state change touches only the prompts, not the whole map.
local Players = game:GetService("Players")

local State = require(script.Parent.State)

local player = Players.LocalPlayer
local PromptFilter = {}

local prompts: { [ProximityPrompt]: boolean } = {}

local function allowed(prompt: ProximityPrompt): boolean
	if prompt:GetAttribute("Owner") == player.UserId then
		return false
	end
	local only = prompt:GetAttribute("OnlyUser")
	if only and only ~= player.UserId then
		return false -- e.g. "Put on" on someone else's bag
	end
	if player:GetAttribute("Hidden") then
		return false -- In a locker: E leaves it (Controls), no other prompt.
	end
	local kind = prompt:GetAttribute("For") or "all"
	if kind == "all" then
		return true
	end
	if not State.alive() then
		return false
	end
	if kind == "living" then
		return true
	end
	if kind == "survivor" then
		return State.role == "survivor"
	end
	if kind == "entity" then
		return State.role == "entity"
	end
	return false
end

local function apply(prompt: ProximityPrompt)
	prompt.Enabled = allowed(prompt)
end

local function track(d: Instance)
	if d:IsA("ProximityPrompt") and not prompts[d] then
		prompts[d] = true
		apply(d)
	end
end

function PromptFilter.init()
	for _, d in workspace:GetDescendants() do
		track(d)
	end
	workspace.DescendantAdded:Connect(track)
	workspace.DescendantRemoving:Connect(function(d)
		if d:IsA("ProximityPrompt") then
			prompts[d] = nil
		end
	end)
	State.changed:Connect(function()
		for prompt in prompts do
			apply(prompt)
		end
	end)
end

return PromptFilter
