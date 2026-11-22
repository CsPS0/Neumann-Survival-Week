-- The free roam admin panel (the admin key, 5 by default, or the menu's button), only for admins (the server sets the Admin attribute and checks
-- every request again: src/server/FreeRoam.luau). Time of day, walking speed, teleport to a room, items, the room
-- lights, call Csoki, the crowd, end free roam.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminRules = require(ReplicatedStorage.Shared.AdminRules)
local FloorData = require(ReplicatedStorage.Shared.FloorData)
local Inventory = require(ReplicatedStorage.Shared.Inventory)
local StoryUi = require(script.Parent.StoryUi)

local player = Players.LocalPlayer
local AdminUi = {}

local panel: ScrollingFrame
local action: RemoteEvent
local floor = 0

local function allowed(): boolean
	return ReplicatedStorage:GetAttribute("Mode") == "freeroam" and player:GetAttribute("Admin") == true
end

local function row(order: number): Frame
	local f = Instance.new("Frame")
	f.LayoutOrder = order
	f.Size = UDim2.new(1, 0, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.BackgroundTransparency = 1
	f.Parent = panel
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.fromOffset(110, 34)
	g.CellPadding = UDim2.fromOffset(6, 6)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = f
	return f
end

local function small(parent: Instance, text: string, order: number, onClick: () -> ())
	local b = StoryUi.button(parent, text, order)
	b.TextSize = 14
	b.Activated:Connect(onClick)
end

local render: () -> ()

render = function()
	StoryUi.clear(panel)
	StoryUi.text(panel, "Admin panel", 20, 1, StoryUi.GOLD)
	StoryUi.text(panel, "Time of day", 15, 2, StoryUi.MUTED)
	local times = row(3)
	for i, h in AdminRules.HOURS do
		small(times, string.format("%02d:%02d", math.floor(h), (h % 1) * 60), i, function()
			action:FireServer("time", { hour = h })
		end)
	end
	StoryUi.text(panel, "Walking speed", 15, 4, StoryUi.MUTED)
	local speeds = row(5)
	for i, m in AdminRules.SPEEDS do
		small(speeds, `x{m}`, i, function()
			action:FireServer("speed", { times = m })
		end)
	end
	StoryUi.text(panel, "Give me", 15, 6, StoryUi.MUTED)
	local items = row(7)
	for i, id in AdminRules.ITEMS do
		small(items, Inventory.nameOf(id), i, function()
			action:FireServer("give", { item = id })
		end)
	end
	StoryUi.text(panel, "School", 15, 8, StoryUi.MUTED)
	local school = row(9)
	small(school, "Room lights", 1, function()
		action:FireServer("lights", {})
	end)
	small(school, "Call Csoki", 2, function()
		action:FireServer("csoki", {})
	end)
	small(school, "People on/off", 3, function()
		action:FireServer("people", {})
	end)
	StoryUi.text(panel, `Teleport: {FloorData.FLOOR_NAMES[floor + 1]}`, 15, 10, StoryUi.MUTED)
	local floors = row(11)
	for f = 0, #FloorData.FLOORS - 1 do
		small(floors, FloorData.FLOOR_NAMES[f + 1], f + 1, function()
			floor = f
			render()
		end)
	end
	local rooms = row(12)
	local labels = {}
	for _, r in FloorData.FLOORS[floor + 1].rooms do
		if r.label ~= "" and not table.find(labels, r.label) then
			table.insert(labels, r.label)
		end
	end
	table.sort(labels)
	for i, label in labels do
		small(rooms, label, i, function()
			action:FireServer("teleport", { room = label, floor = floor })
		end)
	end
	StoryUi.button(panel, "End free roam (back to the lobby)", 20, StoryUi.ACCENT).Activated:Connect(function()
		action:FireServer("end", {})
		panel.Visible = false
	end)
	StoryUi.button(panel, "Close", 21).Activated:Connect(function()
		panel.Visible = false
	end)
end

function AdminUi.open()
	if allowed() then
		render()
		panel.Visible = true
	end
end

function AdminUi.allowed(): boolean
	return allowed()
end

function AdminUi.init(remotes: Folder)
	action = remotes:WaitForChild("AdminAction") :: RemoteEvent
	local gui = StoryUi.gui("Admin", 11)
	panel = StoryUi.panel(gui, 560, 0.8)
	panel.Visible = false
	StoryUi.freeMouseWhile(gui, panel)
	require(script.Parent.ClientSettings).bind("AdminPanel", "admin", function(_, state)
		if state == Enum.UserInputState.Begin and allowed() then
			if panel.Visible then
				panel.Visible = false
			else
				AdminUi.open()
			end
		end
		return Enum.ContextActionResult.Pass
	end, false)
	-- Free roam over or no longer admin: the panel goes.
	local function check()
		if not allowed() then
			panel.Visible = false
		end
	end
	ReplicatedStorage:GetAttributeChangedSignal("Mode"):Connect(check)
	player:GetAttributeChangedSignal("Admin"):Connect(check)
end

return AdminUi
