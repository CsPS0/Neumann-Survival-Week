-- Server entry: creates the remotes, builds the school and starts the lobby.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ChatControl = require(script.Parent.ChatControl)
local Lockers = require(script.Parent.Lockers)
local RoundManager = require(script.Parent.RoundManager)
local SchoolBuilder = require(script.Parent.SchoolBuilder)
local Torch = require(script.Parent.Torch)

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in Remotes.NAMES do
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remotes
end
for _, name in Remotes.UNRELIABLE do
	local event = Instance.new("UnreliableRemoteEvent")
	event.Name = name
	event.Parent = remotes
end
remotes.Parent = ReplicatedStorage

-- A place made from the Baseplate template has a baseplate and a spawn pad at floor level; the school replaces them.
for _, name in { "Baseplate", "SpawnLocation" } do
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

local started = os.clock()
local folder = Instance.new("Folder")
folder.Name = "School"
folder.Parent = workspace
local school = SchoolBuilder.build(folder)
local parts = 0
for _, d in folder:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end
-- Outside the windows, and the time of day (sun in the lobby and the story's day, night in the other modes).
local Lighting = game:GetService("Lighting")
local DayNight = require(script.Parent.DayNight)
local Outdoors = require(script.Parent.Outdoors)
local streetLights = Outdoors.build(workspace)
DayNight.init()
task.spawn(function()
	while true do
		Outdoors.setDaylight(streetLights, DayNight.daylight(Lighting.ClockTime))
		task.wait(2)
	end
end)

print(string.format("[server] school built: %d parts, %d lamps, %d lockers in %.2f s", parts, #school.lamps,
	#school.lockers, os.clock() - started))

-- Sprinting is reported by the client (stamina runs there); the entity hears it.
local sprintRemote = remotes:WaitForChild("Sprint") :: RemoteEvent
sprintRemote.OnServerEvent:Connect(function(player, sprinting)
	if type(sprinting) == "boolean" then
		player:SetAttribute("Sprinting", sprinting)
	end
end)

Torch.init(remotes)
require(script.Parent.People).init(school)
Lockers.init(school.lockers, remotes)
ChatControl.init()
require(script.Parent.Lobbies).init(remotes)
require(script.Parent.PlayerSettings).init(remotes)
require(script.Parent.AchievementService).init(remotes)
require(script.Parent.Csoki).init(school, remotes, workspace)
require(script.Parent.SchoolGames).init(school, remotes, folder)
require(script.Parent.NpcReactions).init()
require(script.Parent.TestBots).init(remotes)
require(script.Parent.Grab).init(remotes)
require(script.Parent.LookRelay).init(remotes)
require(script.Parent.Campaign.Votes).init(remotes)
require(script.Parent.Campaign.Inventories).init(remotes)
RoundManager.init(school, remotes, {
	hideseek = require(script.Parent.HideAndSeek),
	deduction = require(script.Parent.SocialDeduction),
	campaign = require(script.Parent.Campaign.CampaignMode),
	freeroam = require(script.Parent.FreeRoam),
})

-- For tests from the Studio command bar or the MCP (a separate script VM, so a BindableFunction, not _G):
-- game.ServerStorage.TestHooks.StartRound:Invoke({mode = "hideseek", entity = "computer"}, {timeScale = 0.1})
local hooks = Instance.new("Folder")
hooks.Name = "TestHooks"
local startHook = Instance.new("BindableFunction")
startHook.Name = "StartRound"
startHook.OnInvoke = function(opts, testOptions)
	return RoundManager.start(opts, testOptions)
end
startHook.Parent = hooks
-- The four test players and the entity's attack (TestBots), in front of the first player.
local demoHook = Instance.new("BindableFunction")
demoHook.Name = "AttackDemo"
demoHook.OnInvoke = function()
	local p = game:GetService("Players"):GetPlayers()[1]
	local r = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not r then
		return false
	end
	return require(script.Parent.TestBots).run(r.CFrame, workspace)
end
demoHook.Parent = hooks
-- The entity attacks you, in your own view (TestBots.attackMe).
local attackHook = Instance.new("BindableFunction")
attackHook.Name = "AttackMe"
attackHook.OnInvoke = function()
	local p = game:GetService("Players"):GetPlayers()[1]
	return p ~= nil and require(script.Parent.TestBots).attackMe(p, workspace)
end
attackHook.Parent = hooks
hooks.Parent = game:GetService("ServerStorage")
