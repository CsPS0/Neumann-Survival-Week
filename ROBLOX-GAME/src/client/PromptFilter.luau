-- Shows each ProximityPrompt only to the players it is meant for (attribute `For`), and never a prompt on your own
-- character (attribute `Owner` = UserId). The change is local; the server checks every trigger again.
--   all       anyone
--   living    anyone alive in a round (Social Deduction body reports)
--   survivor  alive Hide and Seek survivors (revive)
--   entity    an alive entity (catch, takedown)
-- Prompts are kept in a set (added/removed events), so a state change touches only the prompts, not the whole map.
-- Rescues come first: while you are in reach of a held teammate's "Pull free" or the entity's "Hit it from behind",
-- every other prompt (a door, a locker) steps aside, so E never closes a door instead of saving someone.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local State = require(script.Parent.State)

local player = Players.LocalPlayer
local PromptFilter = {}

local prompts: { [ProximityPrompt]: boolean } = {}
local RESCUE = { Revive = true, HitEntity = true }
local rescuing = false -- a rescue prompt is in reach: the others are off
local someoneHeld = false -- the entity holds a player (attribute Grabbed): only then can you hit it from behind

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
	prompt.Enabled = allowed(prompt) and (not rescuing or RESCUE[prompt.Name] == true)
		and (prompt.Name ~= "HitEntity" or someoneHeld)
end

-- Is a rescue prompt you may use within its reach of you?
local function rescueInReach(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	for prompt in prompts do
		local part = prompt.Parent
		if RESCUE[prompt.Name] and part and part:IsA("BasePart") and allowed(prompt)
			and (prompt.Name ~= "HitEntity" or someoneHeld)
			and (part.Position - root.Position).Magnitude <= prompt.MaxActivationDistance then
			return true
		end
	end
	return false
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
	local function applyAll()
		for prompt in prompts do
			apply(prompt)
		end
	end
	State.changed:Connect(applyAll)
	local nextCheck = 0
	local heldShown = false
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now < nextCheck then
			return
		end
		nextCheck = now + 0.2
		local held = false
		for _, p in Players:GetPlayers() do
			if p:GetAttribute("Grabbed") then
				held = true
				break
			end
		end
		someoneHeld = held
		local near = rescueInReach()
		if near ~= rescuing or held ~= heldShown then
			rescuing = near
			heldShown = held
			applyAll()
		end
	end)
end

return PromptFilter
