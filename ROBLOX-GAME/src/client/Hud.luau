-- The top line (phase, timer, role, players still up) and banner messages from the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Schedule = require(ReplicatedStorage.Shared.Schedule)
local State = require(script.Parent.State)

local player = Players.LocalPlayer
local Hud = {}

-- How the chosen key for an action is shown ("`" for the menu).
local function keyName(id: string): string
	local Keybinds = require(ReplicatedStorage.Shared.Keybinds)
	local ClientSettings = require(script.Parent.ClientSettings)
	return Keybinds.label(ClientSettings.values.keys[id] or Keybinds.default(id))
end

local PHASE_NAMES = {
	lobby = "Lobby",
	starting = "Starting",
	hiding = "Hiding",
	hunt = "Hunt",
	brief = "Get ready",
	night = "Night",
	meeting = "Meeting",
	result = "Result",
	-- The story day.
	arrive = "Arrival",
	grace = "Bell",
	lesson = "Lesson",
	["break"] = "Break",
	afternoon = "Afternoon",
	accusation = "Accusation",
}

local ROLE_NAMES = {
	survivor = "Survivor",
	entity = "The entity",
	crew = "Crew",
	student = "Student",
}

local function label(parent: Instance, y: number, size: number): TextLabel
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.new(0.5, 0, 0, y)
	l.Size = UDim2.new(0.9, 0, 0, size + 8)
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.4
	l.TextSize = size
	l.Font = Enum.Font.GothamMedium
	l.TextWrapped = true
	l.Text = ""
	l.Parent = parent
	return l
end

local function upCount(): number
	local n = 0
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("State") == "alive" and not p:GetAttribute("Seeker") then
			n += 1
		end
	end
	return n
end

function Hud.init(remotes: Folder)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local top = label(gui, 6, 20)
	local bannerLabel = label(gui, 40, 24)
	bannerLabel.TextColor3 = Color3.fromRGB(255, 226, 170)

	local bannerUntil = 0
	(remotes:WaitForChild("Banner") :: RemoteEvent).OnClientEvent:Connect(function(text, seconds)
		bannerLabel.Text = tostring(text)
		bannerUntil = os.clock() + (tonumber(seconds) or 5)
	end)

	-- Ten updates a second are plenty for a clock and a few words.
	local nextUpdate = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now < nextUpdate then
			return
		end
		nextUpdate = now + 0.1
		if bannerLabel.Text ~= "" and os.clock() > bannerUntil then
			bannerLabel.Text = ""
		end
		local phase = State.phase()
		if phase == "lobby" then
			local code = ReplicatedStorage:GetAttribute("LobbyCode")
			top.Text = `Lobby: press {keyName("menu")} for the menu to start a round`
				.. (if code then `   |   private lobby {code}` else "")
			return
		end
		local left = math.max(0, (ReplicatedStorage:GetAttribute("PhaseEndsAt") or 0) - workspace:GetServerTimeNow())
		local minutes = ReplicatedStorage:GetAttribute("CampaignMinutes")
		local parts = { if State.mode() == "campaign" and minutes
			then `{Schedule.format(minutes)}  {PHASE_NAMES[phase] or phase}`
			elseif phase == "freeroam" then `Free roam: {keyName("menu")} for the menu`
				.. (if Players.LocalPlayer:GetAttribute("Admin") then `, {keyName("admin")} admin panel`
				else "")
			else string.format("%s %d:%02d", PHASE_NAMES[phase] or phase, left // 60, math.floor(left % 60)) }
		local mine = State.mine()
		if mine == "out" then
			table.insert(parts, "You are out")
		elseif mine == "spectator" then
			table.insert(parts, "Watching")
		elseif State.role then
			local role = ROLE_NAMES[State.role] or State.role
			if State.partner then
				role ..= ` (with {State.partner})`
			end
			table.insert(parts, role)
		end
		local humanoid = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health < humanoid.MaxHealth and mine ~= "out" then
			table.insert(parts, `Health {math.ceil(humanoid.Health)}`)
		end
		if mine == "downed" then
			table.insert(parts, "DOWNED: wait for a teammate")
		end
		if phase ~= "result" then
			table.insert(parts, `{upCount()} up`)
		end
		local tag = player:GetAttribute("Tag")
		if tag then
			table.insert(parts, `you are {tag}`)
		end
		top.Text = table.concat(parts, "   |   ")
	end)
end

return Hud
