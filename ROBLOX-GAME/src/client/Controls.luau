-- Actions: F torch, T flash, Space hold breath and E leave inside a locker, G call a meeting. Each also gets a touch
-- button on phones. Shows the stamina and battery bars. (Sprint, crouch and slide: MovementController.)
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config)
local MovementController = require(script.Parent.MovementController)
local State = require(script.Parent.State)

local player = Players.LocalPlayer
local Controls = {}

local function bar(parent: Instance, y: number, color: Color3): (Frame, Frame, TextLabel)
	local back = Instance.new("Frame")
	back.AnchorPoint = Vector2.new(0.5, 1)
	back.Position = UDim2.new(0.5, 0, 1, y)
	back.Size = UDim2.fromOffset(220, 10)
	back.BackgroundColor3 = Color3.new(0, 0, 0)
	back.BackgroundTransparency = 0.4
	back.BorderSizePixel = 0
	back.Parent = parent
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(1, 0.5)
	label.Position = UDim2.new(0, -8, 0.5, 0)
	label.Size = UDim2.fromOffset(120, 16)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.Font = Enum.Font.GothamMedium
	label.Parent = back
	return back, fill, label
end

local function disableReset()
	task.spawn(function()
		for _ = 1, 30 do
			if pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", false) then
				return
			end
			task.wait(1)
		end
	end)
end

function Controls.init(remotes: Folder)
	local torchRemote = remotes:WaitForChild("Torch") :: RemoteEvent
	local flashRemote = remotes:WaitForChild("Flash") :: RemoteEvent
	local breathRemote = remotes:WaitForChild("Breath") :: RemoteEvent
	local meetingRemote = remotes:WaitForChild("CallMeeting") :: RemoteEvent
	local leaveRemote = remotes:WaitForChild("LeaveLocker") :: RemoteEvent

	disableReset()

	local ClientSettings = require(script.Parent.ClientSettings)
	ClientSettings.bind("Torch", "torch", function(_, state)
		if state == Enum.UserInputState.Begin then
			torchRemote:FireServer(not player:GetAttribute("TorchOn"))
		end
		return Enum.ContextActionResult.Sink
	end, true, { Enum.KeyCode.ButtonY })
	ContextActionService:SetTitle("Torch", "Light")
	ContextActionService:SetPosition("Torch", UDim2.new(1, -230, 1, -90))

	ClientSettings.bind("Flash", "flash", function(_, state)
		if state == Enum.UserInputState.Begin then
			flashRemote:FireServer(workspace.CurrentCamera.CFrame.LookVector)
		end
		return Enum.ContextActionResult.Sink
	end, true, { Enum.KeyCode.ButtonX })
	ContextActionService:SetTitle("Flash", "Flash")
	ContextActionService:SetPosition("Flash", UDim2.new(1, -230, 1, -150))

	-- Breath only exists while hidden in a locker; the meeting key only during a Social Deduction night.
	local breathBound, meetingBound = false, false
	local function rebind()
		local hidden = player:GetAttribute("Hidden") == true
		if hidden ~= breathBound then
			breathBound = hidden
			if hidden then
				ContextActionService:BindAction("Breath", function(_, state)
					if state == Enum.UserInputState.Begin then
						breathRemote:FireServer(true)
					elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
						breathRemote:FireServer(false)
					end
					return Enum.ContextActionResult.Sink
				end, true, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
				ContextActionService:SetTitle("Breath", "Hold breath")
				ContextActionService:BindAction("LeaveLocker", function(_, state)
					if state == Enum.UserInputState.Begin then
						leaveRemote:FireServer()
					end
					return Enum.ContextActionResult.Sink
				end, true, Enum.KeyCode.E, Enum.KeyCode.ButtonB)
				ContextActionService:SetTitle("LeaveLocker", "Leave")
			else
				ContextActionService:UnbindAction("Breath")
				ContextActionService:UnbindAction("LeaveLocker")
				breathRemote:FireServer(false)
			end
		end
		local meeting = State.mode() == "deduction" and State.phase() == "night" and State.alive()
		if meeting ~= meetingBound then
			meetingBound = meeting
			if meeting then
				ContextActionService:BindAction("Meeting", function(_, state)
					if state == Enum.UserInputState.Begin then
						meetingRemote:FireServer()
					end
					return Enum.ContextActionResult.Sink
				end, true, require(script.Parent.ClientSettings).key("meeting"), Enum.KeyCode.ButtonB)
				ContextActionService:SetTitle("Meeting", "Meeting")
				ContextActionService:SetPosition("Meeting", UDim2.new(1, -110, 1, -210))
			else
				ContextActionService:UnbindAction("Meeting")
			end
		end
	end
	State.changed:Connect(rebind)
	rebind()

	-- Meters.
	local gui = Instance.new("ScreenGui")
	gui.Name = "Meters"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local staminaBack, staminaFill, staminaLabel = bar(gui, -24, Color3.fromRGB(120, 200, 140))
	staminaLabel.Text = "Stamina"
	local batteryBack, batteryFill, batteryLabel = bar(gui, -42, Color3.fromRGB(240, 220, 140))

	-- The bars change slowly: twenty updates a second.
	local nextUpdate = 0
	RunService.Heartbeat:Connect(function()
		if os.clock() < nextUpdate then
			return
		end
		nextUpdate = os.clock() + 0.05
		local stamina = MovementController.stamina
		local lock = player:GetAttribute("SpeedLock")
		staminaBack.Visible = stamina.value < Config.Player.staminaMax and lock == nil
		staminaFill.Size = UDim2.fromScale(stamina.value / Config.Player.staminaMax, 1)
		staminaFill.BackgroundColor3 = if stamina.exhausted then Color3.fromRGB(200, 90, 80) else Color3.fromRGB(120, 200, 140)

		local allowedTorch = player:GetAttribute("TorchAllowed") ~= false
		batteryBack.Visible = allowedTorch
		local battery = player:GetAttribute("Battery") or 0
		batteryFill.Size = UDim2.fromScale(battery / Config.Torch.batteryMax, 1)
		local wait = (player:GetAttribute("FlashReadyAt") or 0) - workspace:GetServerTimeNow()
		batteryLabel.Text = if wait > 0 then string.format("Flash in %d s", math.ceil(wait)) else "Phone battery"
	end)
end

return Controls
