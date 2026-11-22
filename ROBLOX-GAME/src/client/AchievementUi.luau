-- Achievements on screen: a toast slides in at the top right when one unlocks (with a chime), and the menu's
-- "Achievements" button opens the full list (unlocked ones in gold).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Achievements = require(ReplicatedStorage.Shared.Achievements)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local StoryUi = require(script.Parent.StoryUi)

local AchievementUi = {}

local GOLD = Color3.fromRGB(255, 214, 120)
local have: { [string]: boolean } = {}
local gui: ScreenGui
local listPanel: ScrollingFrame

local function toast(id: string)
	local info = Achievements.LIST[id]
	if not info then
		return
	end
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(1, 0)
	card.Position = UDim2.new(1, 340, 0, 70)
	card.Size = UDim2.fromOffset(320, 70)
	card.BackgroundColor3 = Color3.fromRGB(16, 15, 18)
	card.BackgroundTransparency = 0.1
	card.Parent = gui
	StoryUi.corner(card)
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 1.5
	stroke.Parent = card
	local icon = Instance.new("TextLabel")
	icon.BackgroundTransparency = 1
	icon.Position = UDim2.fromOffset(10, 0)
	icon.Size = UDim2.fromOffset(44, 70)
	icon.Text = "★"
	icon.TextSize = 34
	icon.TextColor3 = GOLD
	icon.Font = Enum.Font.GothamBold
	icon.Parent = card
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(60, 8)
	title.Size = UDim2.new(1, -70, 0, 18)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = `Achievement unlocked: {info.name}`
	title.TextSize = 15
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = GOLD
	title.Parent = card
	local about = Instance.new("TextLabel")
	about.BackgroundTransparency = 1
	about.Position = UDim2.fromOffset(60, 30)
	about.Size = UDim2.new(1, -70, 0, 34)
	about.TextXAlignment = Enum.TextXAlignment.Left
	about.TextYAlignment = Enum.TextYAlignment.Top
	about.TextWrapped = true
	about.Text = info.about
	about.TextSize = 13
	about.Font = Enum.Font.Gotham
	about.TextColor3 = StoryUi.MUTED
	about.Parent = card
	local id2 = Sounds.IDS.achievement
	if id2 and id2 ~= "" then
		local s = Instance.new("Sound")
		s.SoundId = id2
		s.Volume = Sounds.VOLUME.achievement or 0.5
		s.Parent = SoundService
		s:Play()
		s.Ended:Once(function()
			s:Destroy()
		end)
	end
	TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Position = UDim2.new(1, -16, 0, 70) }):Play()
	task.delay(5, function()
		TweenService:Create(card, TweenInfo.new(0.4), { Position = UDim2.new(1, 340, 0, 70) }):Play()
		task.wait(0.5)
		card:Destroy()
	end)
end

local function renderList()
	StoryUi.clear(listPanel)
	local n = 0
	for _ in have do
		n += 1
	end
	StoryUi.text(listPanel, `Achievements  {n} / {#Achievements.ORDER}`, 20, 1, GOLD)
	for i, id in Achievements.ORDER do
		local info = Achievements.LIST[id]
		local got = have[id] == true
		StoryUi.text(listPanel, `{if got then "★" else "☆"}  {info.name}  -  {info.about}`, 15, 1 + i,
			if got then GOLD else StoryUi.MUTED)
	end
	StoryUi.button(listPanel, "Close", 100, StoryUi.ACCENT).Activated:Connect(function()
		listPanel.Visible = false
	end)
end

-- Opens the list (the menu's button).
function AchievementUi.open()
	renderList()
	listPanel.Visible = true
end

function AchievementUi.init(remotes: Folder)
	gui = StoryUi.gui("Achievements", 12)
	listPanel = StoryUi.panel(gui, 520, 0.75)
	listPanel.Visible = false
	StoryUi.freeMouseWhile(gui, listPanel)
	local remote = remotes:WaitForChild("Achievements") :: RemoteEvent
	remote.OnClientEvent:Connect(function(list, new)
		have = {}
		for _, id in list do
			have[id] = true
		end
		if new then
			toast(new)
		end
		if listPanel.Visible then
			renderList()
		end
	end)
end

return AchievementUi
