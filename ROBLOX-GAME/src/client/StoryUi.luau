-- Small widget helpers for the story screens (phone, quiz, votes, keypad, ending), in the menu's colours.
local Players = game:GetService("Players")

local MouseLock = require(script.Parent.MouseLock)

local player = Players.LocalPlayer
local StoryUi = {}

StoryUi.BG = Color3.fromRGB(14, 12, 16)
StoryUi.BUTTON = Color3.fromRGB(44, 38, 48)
StoryUi.ACCENT = Color3.fromRGB(120, 40, 36)
StoryUi.TEXT = Color3.new(1, 1, 1)
StoryUi.MUTED = Color3.fromRGB(200, 190, 170)
StoryUi.GOLD = Color3.fromRGB(255, 226, 170)

function StoryUi.corner(parent: Instance)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = parent
end

function StoryUi.gui(name: string, order: number): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.DisplayOrder = order
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

-- A centred, scrolling panel with padding and a vertical list. `maxWidth` in pixels.
function StoryUi.panel(parent: Instance, maxWidth: number, heightScale: number): ScrollingFrame
	local panel = Instance.new("ScrollingFrame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.92, 0, heightScale, 0)
	panel.BackgroundColor3 = StoryUi.BG
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.ScrollBarThickness = 6
	panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
	panel.CanvasSize = UDim2.new()
	panel.Visible = false
	panel.Parent = parent
	StoryUi.corner(panel)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(maxWidth, 10000)
	constraint.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 14)
	pad.PaddingBottom = UDim.new(0, 14)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = panel
	return panel
end

function StoryUi.text(parent: Instance, value: string, size: number, order: number, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.LayoutOrder = order
	l.BackgroundTransparency = 1
	l.TextColor3 = color or StoryUi.TEXT
	l.TextSize = size
	l.Font = Enum.Font.GothamMedium
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.Text = value
	l.Parent = parent
	return l
end

function StoryUi.button(parent: Instance, value: string, order: number, color: Color3?): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 38)
	b.LayoutOrder = order
	b.BackgroundColor3 = color or StoryUi.BUTTON
	b.TextColor3 = StoryUi.TEXT
	b.TextSize = 16
	b.Font = Enum.Font.GothamMedium
	b.TextWrapped = true
	b.Text = value
	b.AutoButtonColor = true
	StoryUi.corner(b)
	b.Parent = parent
	return b
end

-- Removes every widget from a panel (keeps the layout, padding and size constraint).
function StoryUi.clear(panel: Instance)
	for _, c in panel:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

-- The game is first person: a visible modal button frees the mouse while `panel` is visible.
function StoryUi.freeMouseWhile(_gui: ScreenGui, panel: GuiObject)
	MouseLock.track(panel) -- the one Modal button lives there (see MouseLock.luau)
end

-- A short message for you only, low in the middle of the screen.
local toastLabel: TextLabel? = nil
local toastToken = 0
function StoryUi.toast(text: string, seconds: number?)
	if not toastLabel then
		local gui = StoryUi.gui("Toast", 9)
		local l = Instance.new("TextLabel")
		l.AnchorPoint = Vector2.new(0.5, 1)
		l.Position = UDim2.new(0.5, 0, 1, -190)
		l.Size = UDim2.fromOffset(560, 30)
		l.BackgroundTransparency = 1
		l.TextColor3 = Color3.fromRGB(255, 226, 170)
		l.TextStrokeTransparency = 0.4
		l.TextSize = 19
		l.Font = Enum.Font.GothamMedium
		l.Parent = gui
		toastLabel = l
	end
	local l = toastLabel :: TextLabel
	toastToken += 1
	local mine = toastToken
	l.Text = text
	l.Visible = true
	task.delay(seconds or 3.5, function()
		if mine == toastToken then
			l.Visible = false
		end
	end)
end

return StoryUi
