-- Who has the mouse. The game is first person: the mouse turns the view (locked in the middle, a crosshair dot) unless
-- a panel that needs the cursor is on screen (the menu, the bag, a test paper, the phone held in both hands...).
-- Panels register here with MouseLock.track(panel). One button gets Modal = true only while a tracked panel is really
-- on screen (itself, every ancestor and its ScreenGui). Roblox frees the mouse for ANY button with Modal = true, even
-- an invisible one inside a hidden frame (checked in Studio), so no other script may set Modal: that was why the
-- mouse needed a held right click to turn the view.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MouseLock = {}

local tracked: { GuiObject } = {}
local free = false
local modal: TextButton
local dot: Frame

local function onScreen(g: GuiObject): boolean
	local node: Instance? = g
	while node and node:IsA("GuiObject") do
		if not node.Visible then
			return false
		end
		node = node.Parent
	end
	local layer = g:FindFirstAncestorWhichIsA("LayerCollector")
	return layer ~= nil and (layer :: any).Enabled ~= false and layer.Parent ~= nil
end

-- The cursor is free while `panel` is on screen.
function MouseLock.track(panel: GuiObject)
	table.insert(tracked, panel)
end

function MouseLock.isFree(): boolean
	return free
end

function MouseLock.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MouseLock"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	modal = Instance.new("TextButton")
	modal.Name = "FreeMouse"
	modal.Size = UDim2.fromOffset(1, 1)
	modal.BackgroundTransparency = 1
	modal.Text = ""
	modal.Modal = false
	modal.Visible = true
	modal.Parent = gui
	-- The crosshair: a small dot while the mouse turns the view.
	dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(5, 5)
	dot.BackgroundColor3 = Color3.new(1, 1, 1)
	dot.BackgroundTransparency = 0.2
	dot.BorderSizePixel = 0
	dot.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = dot
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.new(0, 0, 0)
	edge.Transparency = 0.5
	edge.Parent = dot

	-- After a panel closes Roblox does not take the mouse back by itself (in Studio it waited for a click, which is why
	-- the view only turned with a held right click): for two frames the mouse is set free, then locked again.
	local relock = 0
	RunService:BindToRenderStep("MouseLock", Enum.RenderPriority.Camera.Value + 5, function()
		if relock > 0 then
			relock -= 1
			UserInputService.MouseBehavior = if relock > 0 then Enum.MouseBehavior.Default
				else Enum.MouseBehavior.LockCenter
		end
	end)
	RunService.RenderStepped:Connect(function()
		local wasFree = free
		local open = false
		for i = #tracked, 1, -1 do
			local panel = tracked[i]
			if not panel.Parent then
				table.remove(tracked, i)
			elseif onScreen(panel) then
				open = true
			end
		end
		free = open
		if modal.Modal ~= open then
			modal.Modal = open
		end
		if wasFree and not open and Players.LocalPlayer.CameraMode == Enum.CameraMode.LockFirstPerson then
			relock = 2
		end
		local locked = not open and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
		dot.Visible = locked and workspace.CurrentCamera.CameraType == Enum.CameraType.Custom
		UserInputService.MouseIconEnabled = not locked
	end)
end

return MouseLock
