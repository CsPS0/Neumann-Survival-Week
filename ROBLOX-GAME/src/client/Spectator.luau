-- While you are out or watching, the camera follows a living player; Left/Right (or the touch buttons) switch.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local State = require(script.Parent.State)

local player = Players.LocalPlayer
local Spectator = {}

local function targets(): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p ~= player and p:GetAttribute("State") == "alive" and p.Character
			and p.Character:FindFirstChildOfClass("Humanoid") then
			table.insert(list, p)
		end
	end
	return list
end

function Spectator.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Spectator"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -70)
	label.Size = UDim2.fromOffset(420, 28)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.TextSize = 18
	label.Font = Enum.Font.GothamMedium
	label.Visible = false
	label.Parent = gui

	local index = 1
	local watching = false

	local function show()
		local list = targets()
		if #list == 0 then
			label.Text = "Nobody left to watch"
			return
		end
		index = (index - 1) % #list + 1
		local target = list[index]
		local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			workspace.CurrentCamera.CameraSubject = humanoid
		end
		local name = target:GetAttribute("Tag") or target.DisplayName
		label.Text = `Watching {name}   (Left / Right to switch)`
	end

	local function step(delta: number)
		return function(_, state)
			if state == Enum.UserInputState.Begin and watching then
				index += delta
				show()
			end
			return Enum.ContextActionResult.Sink
		end
	end

	local function refresh()
		local mine = State.mine()
		local should = (mine == "out" or mine == "spectator") and State.phase() ~= "lobby" and State.phase() ~= "result"
		if should == watching then
			if watching then
				show()
			end
			return
		end
		watching = should
		label.Visible = should
		-- Watching others is easier from behind them; playing is first person.
		player.CameraMode = if should then Enum.CameraMode.Classic else game:GetService("StarterPlayer").CameraMode
		if should then
			ContextActionService:BindAction("SpectatePrev", step(-1), true, Enum.KeyCode.Left, Enum.KeyCode.Q)
			ContextActionService:SetTitle("SpectatePrev", "<")
			ContextActionService:BindAction("SpectateNext", step(1), true, Enum.KeyCode.Right, Enum.KeyCode.E)
			ContextActionService:SetTitle("SpectateNext", ">")
			show()
		else
			ContextActionService:UnbindAction("SpectatePrev")
			ContextActionService:UnbindAction("SpectateNext")
			local own = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if own then
				workspace.CurrentCamera.CameraSubject = own
			end
		end
	end
	State.changed:Connect(refresh)
	-- Someone else going out may take away the player being watched.
	Players.PlayerRemoving:Connect(refresh)
	task.spawn(function()
		while true do
			task.wait(2)
			if watching then
				local subject = workspace.CurrentCamera.CameraSubject
				local owner = subject and subject.Parent and Players:GetPlayerFromCharacter(subject.Parent)
				if not owner or owner:GetAttribute("State") ~= "alive" then
					show()
				end
			end
		end
	end)
	player.CharacterAdded:Connect(function()
		task.wait()
		refresh()
	end)
	-- A late joiner is already a spectator before this script runs.
	refresh()
end

return Spectator
