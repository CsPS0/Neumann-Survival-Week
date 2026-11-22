-- Screen and world effects: the black curtain for a player entity while survivors hide, the white-out when the
-- torch stuns you, lamp flicker near a takedown, seeing out of your locker, and sounds (src/shared/Sounds.luau).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local ClientSettings = require(script.Parent.ClientSettings)
local State = require(script.Parent.State)

local player = Players.LocalPlayer
local Effects = {}

-- Plays a named sound once; skipped when its asset id is empty. With `at`, it plays from that point in the world.
function Effects.play(name: string, at: Vector3?)
	local id = Sounds.IDS[name]
	if not id or id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = Sounds.VOLUME[name] or 0.6
	sound.SoundGroup = ClientSettings.group() -- The menu's volume setting.
	if at then
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.one
		holder.Position = at
		holder.Parent = workspace
		sound.RollOffMaxDistance = Config.studs(Sounds.RANGE[name] or 30)
		sound.RollOffMinDistance = Config.studs(2)
		sound.Parent = holder
		sound.Ended:Connect(function()
			holder:Destroy()
		end)
		task.delay(15, function()
			holder:Destroy()
		end)
	else
		sound.Parent = SoundService
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
	end
	sound:Play()
	local cut = Sounds.LENGTH[name]
	if cut then
		task.delay(cut, function()
			sound:Stop()
			sound:Destroy()
		end)
	end
end

-- The school's ceiling lamps, found once (the school is built before players join and never changes).
local lampCache: { SpotLight }? = nil
local function lamps(): { SpotLight }
	if lampCache and #lampCache > 0 then
		return lampCache
	end
	local list = {}
	local school = workspace:FindFirstChild("School")
	if school then
		for _, d in school:GetDescendants() do
			if d:IsA("SpotLight") then
				table.insert(list, d)
			end
		end
	end
	lampCache = list
	return list
end

function Effects.init(remotes: Folder)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Effects"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = -1
	gui.Parent = player:WaitForChild("PlayerGui")

	local curtain = Instance.new("Frame")
	curtain.Size = UDim2.fromScale(1, 1)
	curtain.BackgroundColor3 = Color3.new(0, 0, 0)
	curtain.BorderSizePixel = 0
	curtain.Visible = false
	curtain.Parent = gui
	local curtainText = Instance.new("TextLabel")
	curtainText.Size = UDim2.fromScale(1, 1)
	curtainText.BackgroundTransparency = 1
	curtainText.TextColor3 = Color3.fromRGB(200, 60, 50)
	curtainText.TextSize = 28
	curtainText.Font = Enum.Font.GothamBold
	curtainText.Text = "You are the entity. They are hiding..."
	curtainText.Parent = curtain

	local white = Instance.new("Frame")
	white.Size = UDim2.fromScale(1, 1)
	white.BackgroundColor3 = Color3.new(1, 1, 1)
	white.BackgroundTransparency = 1
	white.BorderSizePixel = 0
	white.Parent = gui

	local function refresh()
		curtain.Visible = State.mode() == "hideseek" and State.phase() == "hiding" and State.role == "entity"
	end
	State.changed:Connect(refresh)

	local stunned = remotes:WaitForChild("Stunned") :: RemoteEvent
	stunned.OnClientEvent:Connect(function(seconds)
		white.BackgroundTransparency = 0.05
		TweenService:Create(white, TweenInfo.new(tonumber(seconds) or 3), { BackgroundTransparency = 1 }):Play()
	end);

	(remotes:WaitForChild("Flicker") :: RemoteEvent).OnClientEvent:Connect(function(position, seconds)
		if typeof(position) ~= "Vector3" then
			return
		end
		local near = {}
		for _, l in lamps() do
			local part = l.Parent
			if part and part:IsA("BasePart") and (part.Position - position).Magnitude <= Config.studs(Config.Deduction.flickerRange) then
				table.insert(near, l)
			end
		end
		local stop = os.clock() + (tonumber(seconds) or 1.6)
		task.spawn(function()
			while os.clock() < stop do
				for _, l in near do
					l.Enabled = math.random() < 0.35
				end
				task.wait(0.07)
			end
			for _, l in near do
				l.Enabled = true
			end
		end)
	end);

	-- A lost eye (Hide and Seek): the left side of your view is dark until the next round.
	do
		local gui = Instance.new("ScreenGui")
		gui.Name = "LostEye"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 0
		gui.Parent = player:WaitForChild("PlayerGui")
		local shade = Instance.new("Frame")
		shade.Size = UDim2.fromScale(0.62, 1)
		shade.BackgroundColor3 = Color3.new(0, 0, 0)
		shade.BorderSizePixel = 0
		shade.Visible = false
		shade.Parent = gui
		local fade = Instance.new("UIGradient")
		fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.02), NumberSequenceKeypoint.new(0.6, 0.15),
			NumberSequenceKeypoint.new(1, 1) })
		fade.Parent = shade
		local function update()
			shade.Visible = player:GetAttribute("LostEye") == true
		end
		player:GetAttributeChangedSignal("LostEye"):Connect(update)
		update()
	end

	(remotes:WaitForChild("Sound") :: RemoteEvent).OnClientEvent:Connect(function(name, at)
		if type(name) == "string" then
			Effects.play(name, if typeof(at) == "Vector3" then at else nil)
		end
	end)

	-- Inside a locker you see out through its door; the heartbeat runs while the entity is close.
	local seeThrough: BasePart? = nil
	local heartbeatAt = 0
	RunService.Heartbeat:Connect(function()
		local hiddenIn: BasePart? = nil
		if player:GetAttribute("Hidden") then
			local lockers = workspace:FindFirstChild("School") and workspace.School:FindFirstChild("Lockers")
			if lockers then
				for _, locker in lockers:GetChildren() do
					if locker:GetAttribute("Occupant") == player.UserId then
						hiddenIn = locker:FindFirstChild("Front") :: BasePart?
						break
					end
				end
			end
		end
		if hiddenIn ~= seeThrough then
			if seeThrough then
				seeThrough.LocalTransparencyModifier = 0
			end
			if hiddenIn then
				hiddenIn.LocalTransparencyModifier = 0.75
			end
			seeThrough = hiddenIn
		end

		local entity = workspace:FindFirstChild("Entity")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if entity and entity.PrimaryPart and root and State.alive() and os.clock() >= heartbeatAt
			and (entity.PrimaryPart.Position - (root :: BasePart).Position).Magnitude < Config.studs(12) then
			heartbeatAt = os.clock() + 1.1
			Effects.play("heartbeat")
		end
	end)
end

return Effects
