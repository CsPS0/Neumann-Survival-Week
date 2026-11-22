-- The story run on screen: the objective line under the top bar and, on Easy, a marker over where to go next.
-- (The phone with the timetable, clues and team is Phone.luau.)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local StoryUi = require(script.Parent.StoryUi)

local player = Players.LocalPlayer
local StoryHud = {}

local function marker(): (Part, TextLabel)
	local part = Instance.new("Part")
	part.Name = "StoryGuide"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	local billboard = Instance.new("BillboardGui")
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(120, 44)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.Parent = part
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.fromRGB(255, 226, 120)
	l.TextStrokeTransparency = 0.3
	l.TextSize = 16
	l.Font = Enum.Font.GothamBold
	l.Text = "Here"
	l.Parent = billboard
	return part, l
end

function StoryHud.init(remotes: Folder)
	local gui = StoryUi.gui("Story", 3)
	local objective = Instance.new("TextLabel")
	objective.AnchorPoint = Vector2.new(0.5, 0)
	objective.Position = UDim2.new(0.5, 0, 0, 74)
	objective.Size = UDim2.new(0.9, 0, 0, 22)
	objective.BackgroundTransparency = 1
	objective.TextColor3 = Color3.fromRGB(190, 230, 255)
	objective.TextStrokeTransparency = 0.4
	objective.TextSize = 17
	objective.Font = Enum.Font.GothamMedium
	objective.TextWrapped = true
	objective.Text = ""
	objective.Parent = gui

	local guide, guideLabel = marker()
	local state = nil :: any;

	(remotes:WaitForChild("CampaignState") :: RemoteEvent).OnClientEvent:Connect(function(newState)
		state = newState
		if not state then
			objective.Text = ""
			guide.Parent = nil
			return
		end
		local mine = player:GetAttribute("State")
		objective.Text = if mine == "alive" or mine == "downed" then state.objective else ""
		if state.guide and mine == "alive" then
			guide.Position = state.guide
			guide.Parent = workspace
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				guideLabel.Text = string.format("Here  %d m", math.floor((root.Position - state.guide).Magnitude / Config.STUDS_PER_METRE + 0.5))
			end
		else
			guide.Parent = nil
		end
	end)
end

return StoryHud
