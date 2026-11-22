-- The story's full-screen moments (remote "StoryScene", docs/2026-11-22-campaign-story-design.md):
--   intro  the title card at 06:30
--   slip   Lab 14's white flash, black, "Twenty minutes later...", then waking up blurred on the Aula floor
--   home   a fade out and in: you are taken home
--   back   a fade out and in: you climb back into the school
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local StoryScenes = {}

local GOLD = Color3.fromRGB(255, 220, 120)

function StoryScenes.init(remotes: Folder)
	local gui = Instance.new("ScreenGui")
	gui.Name = "StoryScenes"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 30
	gui.Parent = player:WaitForChild("PlayerGui")

	local cover = Instance.new("Frame")
	cover.Size = UDim2.fromScale(1, 1)
	cover.BackgroundColor3 = Color3.new(0, 0, 0)
	cover.BackgroundTransparency = 1
	cover.BorderSizePixel = 0
	cover.Parent = gui

	local function label(size: number, font: Enum.Font, y: number): TextLabel
		local t = Instance.new("TextLabel")
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = UDim2.fromScale(0.5, y)
		t.Size = UDim2.new(0.9, 0, 0, size + 10)
		t.BackgroundTransparency = 1
		t.Font = font
		t.TextSize = size
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextTransparency = 1
		t.Text = ""
		t.Parent = gui
		return t
	end
	local big = label(54, Enum.Font.GothamBlack, 0.44)
	local small = label(22, Enum.Font.Gotham, 0.53)
	local tiny = label(18, Enum.Font.Gotham, 0.6)

	local blur = Instance.new("BlurEffect")
	blur.Name = "StoryBlur"
	blur.Size = 0
	blur.Parent = Lighting

	local busy = 0 -- a newer scene cancels the fades of an older one
	local function tween(obj: Instance, seconds: number, goal: { [string]: any })
		TweenService:Create(obj, TweenInfo.new(seconds, Enum.EasingStyle.Quad), goal):Play()
	end
	local function texts(t: number, seconds: number)
		for _, l in { big, small, tiny } do
			tween(l, seconds, { TextTransparency = t })
		end
	end
	local function show(a: string, b: string?, c: string?, color: Color3?)
		big.Text, small.Text, tiny.Text = a, b or "", c or ""
		big.TextColor3 = color or Color3.new(1, 1, 1)
		texts(0, 0.8)
	end

	local function intro(data: any)
		busy += 1
		local mine = busy
		cover.BackgroundColor3 = Color3.new(0, 0, 0)
		cover.BackgroundTransparency = 0
		show("THE EMPTY SCHOOL", "Neumann Survival Week: day one", `06:30. {data and data.difficulty or ""}`, GOLD)
		task.wait(3.6)
		if busy ~= mine then
			return
		end
		texts(1, 1)
		tween(cover, 1.6, { BackgroundTransparency = 1 })
	end

	local function slip(data: any)
		busy += 1
		local mine = busy
		-- The flash of the explosion.
		cover.BackgroundColor3 = Color3.new(1, 1, 1)
		cover.BackgroundTransparency = 0
		texts(1, 0)
		task.wait(0.5)
		tween(cover, 0.9, { BackgroundColor3 = Color3.new(0, 0, 0) })
		task.wait(1.0)
		if busy ~= mine then
			return
		end
		show(`{data and data.minutes or 20} minutes later...`, "You don't remember any of it.")
		blur.Size = 28
		task.wait(2.6)
		if busy ~= mine then
			return
		end
		texts(1, 0.6)
		-- Waking up: the black lifts, the blur clears slowly, a blink or two.
		tween(cover, 1.4, { BackgroundTransparency = 0.2 })
		task.wait(1.4)
		tween(cover, 0.25, { BackgroundTransparency = 0.85 })
		task.wait(0.4)
		tween(cover, 0.2, { BackgroundTransparency = 0.1 })
		task.wait(0.3)
		tween(cover, 1.2, { BackgroundTransparency = 1 })
		tween(blur, 5, { Size = 0 })
	end

	local function fade(a: string, b: string?)
		busy += 1
		local mine = busy
		cover.BackgroundColor3 = Color3.new(0, 0, 0)
		tween(cover, 0.6, { BackgroundTransparency = 0 })
		task.wait(0.6)
		show(a, b)
		task.wait(2.0)
		if busy ~= mine then
			return
		end
		texts(1, 0.6)
		tween(cover, 1.0, { BackgroundTransparency = 1 })
	end

	local remote = remotes:WaitForChild("StoryScene") :: RemoteEvent
	remote.OnClientEvent:Connect(function(kind, data)
		if kind == "intro" then
			task.spawn(intro, data)
		elseif kind == "slip" then
			task.spawn(slip, data)
		elseif kind == "home" then
			task.spawn(fade, "Home", "Your room. The school feels far away.")
		elseif kind == "back" then
			task.spawn(fade, "Back to school", "In through a broken window at the far end.")
		end
	end)
end

return StoryScenes
