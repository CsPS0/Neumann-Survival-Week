-- When the entity has you (Grab.luau): your view is locked on its face, it shakes with every bite, the edges of the
-- screen bleed red as time runs out, and a big prompt shows the key to mash (the defend key, X by default) with the
-- meter you have to fill before the timer runs out. Both hands push at it (Viewmodel) and shove on every press.
-- It takes your arm, then an eye (a flash and a scream); fill the meter and you throw it off; too slow and it eats
-- you (the screen goes black). Everything here is your own screen; the server keeps the meter.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Keybinds = require(ReplicatedStorage.Shared.Keybinds)
local ClientSettings = require(script.Parent.ClientSettings)
local Effects = require(script.Parent.Effects)
local Viewmodel = require(script.Parent.Viewmodel)

local player = Players.LocalPlayer
local StruggleUi = {}

local RED = Color3.fromRGB(200, 20, 20)
local GOLD = Color3.fromRGB(255, 220, 120)

function StruggleUi.init(remotes: Folder)
	local grabRemote = remotes:WaitForChild("Grab") :: RemoteEvent
	local struggleRemote = remotes:WaitForChild("Struggle") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "Struggle"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Red edges (a vignette) that close in as time runs out.
	local edges: { Frame } = {}
	for i, spec in { { UDim2.fromScale(1, 0.35), UDim2.fromScale(0, 0), 90 }, { UDim2.fromScale(1, 0.35), UDim2.fromScale(0, 0.65), -90 },
		{ UDim2.fromScale(0.3, 1), UDim2.fromScale(0, 0), 0 }, { UDim2.fromScale(0.3, 1), UDim2.fromScale(0.7, 0), 180 } } do
		local f = Instance.new("Frame")
		f.Size = spec[1]
		f.Position = spec[2]
		f.BackgroundColor3 = RED
		f.BorderSizePixel = 0
		f.Parent = gui
		local g = Instance.new("UIGradient")
		g.Rotation = spec[3]
		g.Transparency = NumberSequence.new(0.2, 1)
		g.Parent = f
		edges[i] = f
	end
	-- A full-screen flash (bites, the arm, the eye) and the black of being eaten.
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = gui

	-- The prompt: the key, the meter, the time left.
	local box = Instance.new("Frame")
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.new(0.5, 0, 1, -110)
	box.Size = UDim2.fromOffset(460, 130)
	box.BackgroundTransparency = 1
	box.Parent = gui
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 34)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 30
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.2
	title.Text = "FIGHT IT OFF!"
	title.Parent = box
	local keyCap = Instance.new("TextLabel")
	keyCap.AnchorPoint = Vector2.new(0.5, 0)
	keyCap.Position = UDim2.new(0.5, 0, 0, 40)
	keyCap.Size = UDim2.fromOffset(58, 58)
	keyCap.BackgroundColor3 = Color3.fromRGB(240, 236, 226)
	keyCap.TextColor3 = Color3.fromRGB(20, 20, 24)
	keyCap.Font = Enum.Font.GothamBlack
	keyCap.TextSize = 32
	keyCap.Parent = box
	local capCorner = Instance.new("UICorner")
	capCorner.CornerRadius = UDim.new(0, 8)
	capCorner.Parent = keyCap
	local capStroke = Instance.new("UIStroke")
	capStroke.Color = GOLD
	capStroke.Thickness = 3
	capStroke.Parent = keyCap
	local mash = Instance.new("TextLabel")
	mash.AnchorPoint = Vector2.new(0, 0)
	mash.Position = UDim2.new(0.5, 40, 0, 52)
	mash.Size = UDim2.fromOffset(180, 34)
	mash.BackgroundTransparency = 1
	mash.Font = Enum.Font.GothamBold
	mash.TextSize = 22
	mash.TextColor3 = GOLD
	mash.TextXAlignment = Enum.TextXAlignment.Left
	mash.TextStrokeTransparency = 0.3
	mash.Text = "MASH IT!"
	mash.Parent = box
	local meterBack = Instance.new("Frame")
	meterBack.Position = UDim2.new(0, 30, 0, 106)
	meterBack.Size = UDim2.new(1, -60, 0, 12)
	meterBack.BackgroundColor3 = Color3.fromRGB(30, 10, 10)
	meterBack.Parent = box
	local meterFill = Instance.new("Frame")
	meterFill.Size = UDim2.fromScale(0, 1)
	meterFill.BackgroundColor3 = GOLD
	meterFill.BorderSizePixel = 0
	meterFill.Parent = meterBack
	local timeBack = Instance.new("Frame")
	timeBack.Position = UDim2.new(0, 30, 0, 122)
	timeBack.Size = UDim2.new(1, -60, 0, 4)
	timeBack.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
	timeBack.BorderSizePixel = 0
	timeBack.Parent = box
	local timeFill = Instance.new("Frame")
	timeFill.Size = UDim2.fromScale(1, 1)
	timeFill.BackgroundColor3 = RED
	timeFill.BorderSizePixel = 0
	timeFill.Parent = timeBack
	local result = Instance.new("TextLabel")
	result.AnchorPoint = Vector2.new(0.5, 0.5)
	result.Position = UDim2.fromScale(0.5, 0.42)
	result.Size = UDim2.fromOffset(700, 60)
	result.BackgroundTransparency = 1
	result.Font = Enum.Font.GothamBlack
	result.TextSize = 40
	result.TextColor3 = Color3.new(1, 1, 1)
	result.TextStrokeTransparency = 0.2
	result.Text = ""
	result.Parent = gui

	local entity: Model? = nil
	local endsAt, hold = 0, 25
	local meter, shown = 0, 0
	local shake, capPop = 0, 0
	local holding = false

	local function flashOf(color: Color3, strength: number)
		flash.BackgroundColor3 = color
		flash.BackgroundTransparency = 1 - strength
		TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	end

	local function press()
		if not holding then
			return
		end
		struggleRemote:FireServer()
		Viewmodel.shove()
		shake = math.max(shake, 0.35)
		capPop = 1
		meter = math.min(1, meter + 0.03) -- a little at once on screen; the server's value follows
	end

	local function bindKey(on: boolean)
		if on then
			ContextActionService:BindActionAtPriority("Struggle", function(_, state)
				if state == Enum.UserInputState.Begin then
					press()
				end
				return Enum.ContextActionResult.Sink
			end, true, Enum.ContextActionPriority.High.Value + 10, ClientSettings.key("defend"), Enum.KeyCode.ButtonA)
			ContextActionService:SetTitle("Struggle", "FIGHT")
			ContextActionService:SetPosition("Struggle", UDim2.new(1, -170, 1, -210))
		else
			ContextActionService:UnbindAction("Struggle")
		end
	end

	-- The view: from your eyes straight at its face, shaking.
	RunService:BindToRenderStep("StruggleView", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if not holding and result.Text == "" then
			return
		end
		local camera = workspace.CurrentCamera
		local character = player.Character
		local head = character and character:FindFirstChild("Head") :: BasePart?
		local face = entity and (entity:FindFirstChild("Head", true) :: BasePart?)
		shake = math.max(0, shake - dt * 1.6)
		capPop = math.max(0, capPop - dt * 6)
		if head and face and holding then
			local eye = head.Position + Vector3.new(0, 0.3, 0)
			local s = shake * shake
			local jitter = CFrame.Angles((math.random() - 0.5) * s * 0.25, (math.random() - 0.5) * s * 0.25,
				(math.random() - 0.5) * s * 0.4)
			camera.CFrame = CFrame.lookAt(eye, face.Position) * jitter
			camera.FieldOfView = 62 - s * 6
		end
		-- The prompt.
		local left = math.max(0, endsAt - workspace:GetServerTimeNow())
		timeFill.Size = UDim2.fromScale(left / hold, 1)
		shown += (meter - shown) * math.min(1, dt * 14)
		meterFill.Size = UDim2.fromScale(shown, 1)
		keyCap.Size = UDim2.fromOffset(58 + capPop * 12, 58 + capPop * 12)
		capStroke.Thickness = 3 + capPop * 3
		local urgency = 1 - left / hold
		for _, e in edges do
			e.BackgroundTransparency = 0.55 - urgency * 0.45 + math.sin(os.clock() * (4 + urgency * 8)) * 0.08
		end
	end)

	local function begin(data: any)
		entity = data.entity
		hold = data.hold or 25
		endsAt = data.endsAt or (workspace:GetServerTimeNow() + hold)
		meter, shown = 0, 0
		holding = true
		result.Text = ""
		keyCap.Text = Keybinds.label(ClientSettings.values.keys.defend or "X")
		box.Visible = true
		gui.Enabled = true
		Viewmodel.setStruggle(true)
		bindKey(true)
		shake = 1
		flashOf(RED, 0.6)
		Effects.play("scream")
	end

	local function stop(kind: string)
		holding = false
		bindKey(false)
		box.Visible = false
		Viewmodel.setStruggle(false)
		if kind == "self" then
			result.Text = "YOU THREW IT OFF!"
			result.TextColor3 = GOLD
			Viewmodel.shove()
			flashOf(Color3.new(1, 1, 1), 0.4)
		elseif kind == "rescued" then
			result.Text = "SOMEONE PULLED YOU FREE!"
			result.TextColor3 = GOLD
			flashOf(Color3.new(1, 1, 1), 0.3)
		elseif kind == "eaten" then
			result.Text = "IT ATE YOU."
			result.TextColor3 = RED
			flash.BackgroundColor3 = Color3.new(0, 0, 0)
			flash.BackgroundTransparency = 1
			TweenService:Create(flash, TweenInfo.new(1.2), { BackgroundTransparency = 0 }):Play()
			Effects.play("scream")
		end
		task.delay(if kind == "eaten" then 3.5 else 1.8, function()
			if not holding then
				result.Text = ""
				gui.Enabled = false
				flash.BackgroundTransparency = 1
				workspace.CurrentCamera.FieldOfView = ClientSettings.values.fov
			end
		end)
	end

	grabRemote.OnClientEvent:Connect(function(kind, data)
		if kind == "start" then
			begin(data)
		elseif kind == "meter" then
			meter = data -- the server's meter
		elseif kind == "bite" then
			shake = math.max(shake, 0.9)
			flashOf(RED, 0.35)
		elseif kind == "maim" then
			shake = 1.2
			flashOf(Color3.new(1, 1, 1), 0.8)
			Effects.play("scream")
			result.Text = if data == "LostArm" then "YOUR ARM!" else "YOUR EYE!"
			result.TextColor3 = RED
			task.delay(1.2, function()
				if holding then
					result.Text = ""
				end
			end)
		elseif kind == "end" then
			stop(data)
		end
	end)
end

return StruggleUi
