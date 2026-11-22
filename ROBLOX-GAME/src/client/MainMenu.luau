-- The main menu, laid out like the Godot game's title screen: the school blurred behind, the title and a column of
-- buttons on the left (Play, Free roam, Achievements, Settings, How to play, Friends), and pages that open beside
-- it. During a round the same menu is the pause menu (Resume first). It opens when you join and with the menu key
-- (` by default); moving (W A S D, Space) or clicking outside it closes it, like any other game.
-- Settings (saved per player on the server): Graphics (quality, field of view, head bob, FPS counter), Audio
-- (master and ambience volume) and Controls (mouse sensitivity and every key, click a key to change it).
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Keybinds = require(ReplicatedStorage.Shared.Keybinds)
local Settings = require(ReplicatedStorage.Shared.Settings)
local ClientSettings = require(script.Parent.ClientSettings)
local MouseLock = require(script.Parent.MouseLock)
local State = require(script.Parent.State)

local player = Players.LocalPlayer
local MainMenu = {}

local MODES = {
	{ text = "Hide and Seek (computer entity)", mode = "hideseek", entity = "computer" },
	{ text = "Hide and Seek (player entity)", mode = "hideseek", entity = "player" },
	{ text = "Social Deduction (3+ players)", mode = "deduction", entity = "player" },
}
local STORY = {
	{ text = "Story: Easy (up to ~45 min, shows where to go)", difficulty = "easy" },
	{ text = "Story: Normal (~45-60 min)", difficulty = "normal" },
	{ text = "Story: Hard (1-2 hours, typed answers, no hints)", difficulty = "hard" },
}

local PANEL = Color3.fromRGB(12, 10, 14)
local BUTTON = Color3.fromRGB(34, 30, 38)
local HOVER = Color3.fromRGB(60, 50, 62)
local ACCENT = Color3.fromRGB(120, 40, 36)
local GOLD = Color3.fromRGB(242, 209, 115)
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(200, 190, 170)

local values: Settings.Values = Settings.clean(nil)

local function corner(parent: Instance, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 6)
	c.Parent = parent
end

local function list(parent: Instance, gap: number)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, gap)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
end

local function label(parent: Instance, text: string, size: number, order: number, color: Color3?, font: Enum.Font?):
	TextLabel
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, size + 10)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.LayoutOrder = order
	l.BackgroundTransparency = 1
	l.TextColor3 = color or TEXT
	l.TextSize = size
	l.Font = font or Enum.Font.GothamMedium
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = parent
	return l
end

-- A menu button: dark, a gold bar slides in on the left when the mouse is over it (as in the Godot menu).
local function button(parent: Instance, text: string, order: number, color: Color3?, height: number?): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, height or 42)
	b.LayoutOrder = order
	b.BackgroundColor3 = color or BUTTON
	b.BackgroundTransparency = 0.1
	b.TextColor3 = TEXT
	b.TextSize = 17
	b.Font = Enum.Font.GothamMedium
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.Text = "    " .. text
	b.AutoButtonColor = false
	corner(b)
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = GOLD
	bar.BorderSizePixel = 0
	bar.Size = UDim2.new(0, 0, 1, 0)
	bar.Parent = b
	corner(bar, 3)
	local base = b.BackgroundColor3
	b.MouseEnter:Connect(function()
		TweenService:Create(bar, TweenInfo.new(0.12), { Size = UDim2.new(0, 4, 1, 0) }):Play()
		b.BackgroundColor3 = if color then base:Lerp(Color3.new(1, 1, 1), 0.12) else HOVER
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(bar, TweenInfo.new(0.12), { Size = UDim2.new(0, 0, 1, 0) }):Play()
		b.BackgroundColor3 = base
	end)
	b.Parent = parent
	return b
end

local function applySettings()
	ClientSettings.set(values)
	values = ClientSettings.values
end

function MainMenu.init(remotes: Folder)
	local startRemote = remotes:WaitForChild("StartRound") :: RemoteEvent
	local backRemote = remotes:WaitForChild("BackToLobby") :: RemoteEvent
	local createRemote = remotes:WaitForChild("CreateLobby") :: RemoteEvent
	local joinRemote = remotes:WaitForChild("JoinLobby") :: RemoteEvent
	local saveRemote = remotes:WaitForChild("SaveSettings") :: RemoteEvent
	local settingsRemote = remotes:WaitForChild("Settings") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "Menu"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Parent = player:WaitForChild("PlayerGui")

	-- The whole screen is a button: a click outside the menu closes it.
	local dim = Instance.new("TextButton")
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.BorderSizePixel = 0
	dim.Parent = gui
	local shade = Instance.new("UIGradient")
	shade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0.6),
		NumberSequenceKeypoint.new(1, 1) })
	shade.Parent = dim
	MouseLock.track(dim)
	local blur = Instance.new("BlurEffect")
	blur.Name = "MenuBlur"
	blur.Size = 0
	blur.Parent = Lighting

	-- Left column: title and the main buttons.
	local column = Instance.new("Frame")
	column.Position = UDim2.new(0, 56, 0, 0)
	column.Size = UDim2.new(0, 340, 1, 0)
	column.BackgroundTransparency = 1
	column.Parent = dim
	local colList = Instance.new("UIListLayout")
	colList.Padding = UDim.new(0, 8)
	colList.SortOrder = Enum.SortOrder.LayoutOrder
	colList.VerticalAlignment = Enum.VerticalAlignment.Center
	colList.Parent = column
	local title = label(column, "THE EMPTY SCHOOL", 38, 1, GOLD, Enum.Font.GothamBlack)
	title.TextStrokeTransparency = 0.6
	label(column, "Neumann Survival Week", 16, 2, MUTED)
	local where = label(column, "", 13, 3, MUTED)
	local message = label(column, "", 14, 4, Color3.fromRGB(255, 226, 170))
	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.new(1, 0, 0, 10)
	spacer.LayoutOrder = 5
	spacer.BackgroundTransparency = 1
	spacer.Parent = column

	-- Right side: the open page.
	local pageArea = Instance.new("Frame")
	pageArea.AnchorPoint = Vector2.new(0, 0.5)
	pageArea.Position = UDim2.new(0, 430, 0.5, 0)
	pageArea.Size = UDim2.new(1, -480, 0.82, 0)
	pageArea.BackgroundTransparency = 1
	pageArea.Parent = dim
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(560, 760)
	sizeLimit.Parent = pageArea

	local pages: { [string]: ScrollingFrame } = {}
	local current: string? = nil
	local function page(name: string): ScrollingFrame
		local p = Instance.new("ScrollingFrame")
		p.Name = name
		p.Size = UDim2.fromScale(1, 1)
		p.BackgroundColor3 = PANEL
		p.BackgroundTransparency = 0.12
		p.BorderSizePixel = 0
		p.ScrollBarThickness = 5
		p.AutomaticCanvasSize = Enum.AutomaticSize.Y
		p.CanvasSize = UDim2.new()
		p.Visible = false
		p.Parent = pageArea
		corner(p, 10)
		local pad = Instance.new("UIPadding")
		for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
			(pad :: any)[side] = UDim.new(0, 18)
		end
		pad.Parent = p
		list(p, 8)
		pages[name] = p
		return p
	end
	local function openPage(name: string?)
		current = if current == name then nil else name
		for n, p in pages do
			p.Visible = n == current
		end
	end

	local render: () -> ()

	-- Play ---------------------------------------------------------------------------------------------------------
	local play = page("play")
	label(play, "Play", 24, 1, GOLD, Enum.Font.GothamBold)
	local order = 1
	local function nextOrder(): number
		order += 1
		return order
	end
	label(play, "The night school (2-10 players)", 15, nextOrder(), MUTED)
	for _, m in MODES do
		button(play, m.text, nextOrder(), ACCENT).Activated:Connect(function()
			startRemote:FireServer(m.mode, m.entity)
		end)
	end
	label(play, "The story day (solo or co-op, one shared ending)", 15, nextOrder(), MUTED)
	for _, s in STORY do
		button(play, s.text, nextOrder(), Color3.fromRGB(46, 70, 96)).Activated:Connect(function()
			startRemote:FireServer("campaign", "none", s.difficulty)
		end)
	end

	-- Settings -----------------------------------------------------------------------------------------------------
	local settings = page("settings")
	label(settings, "Settings", 24, 1, GOLD, Enum.Font.GothamBold)
	local tabsRow = Instance.new("Frame")
	tabsRow.Size = UDim2.new(1, 0, 0, 36)
	tabsRow.LayoutOrder = 2
	tabsRow.BackgroundTransparency = 1
	tabsRow.Parent = settings
	local tabsList = Instance.new("UIListLayout")
	tabsList.FillDirection = Enum.FillDirection.Horizontal
	tabsList.Padding = UDim.new(0, 6)
	tabsList.Parent = tabsRow
	local tabBody = Instance.new("Frame")
	tabBody.Size = UDim2.new(1, 0, 0, 0)
	tabBody.AutomaticSize = Enum.AutomaticSize.Y
	tabBody.LayoutOrder = 3
	tabBody.BackgroundTransparency = 1
	tabBody.Parent = settings
	list(tabBody, 8)
	local tab = "Graphics"
	local capturing: string? = nil -- the action waiting for a key

	local saveToken = 0
	local function changed()
		applySettings()
		render()
		saveToken += 1
		local mine = saveToken
		task.delay(1, function()
			if mine == saveToken then
				saveRemote:FireServer(values)
			end
		end)
	end

	-- A row: a name on the left, a control on the right.
	local function row(order2: number, name: string, valueText: string, onMinus: (() -> ())?, onPlus: (() -> ())?,
		onClick: (() -> ())?)
		local r = Instance.new("Frame")
		r.Size = UDim2.new(1, 0, 0, 38)
		r.LayoutOrder = order2
		r.BackgroundColor3 = BUTTON
		r.BackgroundTransparency = 0.3
		r.Parent = tabBody
		corner(r)
		local n = label(r, name, 15, 0)
		n.AutomaticSize = Enum.AutomaticSize.None
		n.Position = UDim2.fromOffset(12, 0)
		n.Size = UDim2.new(0.55, -12, 1, 0)
		local v = Instance.new("TextButton")
		v.AnchorPoint = Vector2.new(1, 0.5)
		v.Position = UDim2.new(1, -(if onMinus then 50 else 8), 0.5, 0)
		v.Size = UDim2.fromOffset(if onMinus then 110 else 150, 30)
		v.BackgroundColor3 = Color3.fromRGB(24, 22, 28)
		v.TextColor3 = GOLD
		v.TextSize = 15
		v.Font = Enum.Font.GothamBold
		v.Text = valueText
		v.AutoButtonColor = onClick ~= nil
		v.Parent = r
		corner(v)
		if onClick then
			v.Activated:Connect(onClick)
		end
		if onMinus and onPlus then
			for i, f in { onMinus, onPlus } do
				local b = Instance.new("TextButton")
				b.AnchorPoint = Vector2.new(1, 0.5)
				b.Position = UDim2.new(1, if i == 1 then -164 else -8, 0.5, 0)
				b.Size = UDim2.fromOffset(36, 30)
				b.BackgroundColor3 = Color3.fromRGB(50, 44, 56)
				b.TextColor3 = TEXT
				b.TextSize = 20
				b.Font = Enum.Font.GothamBold
				b.Text = if i == 1 then "-" else "+"
				b.Parent = r
				corner(b)
				b.Activated:Connect(f)
			end
		end
	end

	local function stepper(order2: number, name: string, key: string, fmt: (number) -> string)
		row(order2, name, fmt((values :: any)[key]), function()
			(values :: any)[key] = Settings.step(key, (values :: any)[key], -1)
			changed()
		end, function()
			(values :: any)[key] = Settings.step(key, (values :: any)[key], 1)
			changed()
		end)
	end

	local function renderSettings()
		for _, c in tabsRow:GetChildren() do
			if c:IsA("GuiButton") then
				c:Destroy()
			end
		end
		for _, name in { "Graphics", "Audio", "Controls" } do
			local b = Instance.new("TextButton")
			b.Size = UDim2.fromOffset(120, 34)
			b.BackgroundColor3 = if name == tab then Color3.fromRGB(90, 72, 40) else BUTTON
			b.TextColor3 = if name == tab then GOLD else TEXT
			b.TextSize = 16
			b.Font = Enum.Font.GothamBold
			b.Text = name
			b.Parent = tabsRow
			corner(b)
			b.Activated:Connect(function()
				tab = name
				capturing = nil
				render()
			end)
		end
		for _, c in tabBody:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		if tab == "Graphics" then
			label(tabBody, "DISPLAY", 14, 1, GOLD)
			local presets = { low = "Low", medium = "Medium", high = "High" }
			row(2, "Quality (shadows and screen effects)", presets[values.graphics], nil, nil, function()
				local i = table.find(Settings.GRAPHICS, values.graphics) or 3
				values.graphics = Settings.GRAPHICS[i % #Settings.GRAPHICS + 1]
				changed()
			end)
			stepper(3, "Field of view", "fov", function(v)
				return `{v}°`
			end)
			row(4, "Head bob while walking", if values.bobbing then "On" else "Off", nil, nil, function()
				values.bobbing = not values.bobbing
				changed()
			end)
			row(5, "FPS counter", if values.showFps then "On" else "Off", nil, nil, function()
				values.showFps = not values.showFps
				changed()
			end)
			label(tabBody, "Roblox's own graphics level (Esc > Settings) sets how far you see and texture detail.",
				12, 6, MUTED)
		elseif tab == "Audio" then
			label(tabBody, "VOLUME", 14, 1, GOLD)
			stepper(2, "Master volume", "volume", function(v)
				return `{math.round(v * 100)}%`
			end)
			stepper(3, "Ambience (hum, birds, wind)", "ambience", function(v)
				return `{math.round(v * 100)}%`
			end)
		else
			label(tabBody, "MOUSE", 14, 1, GOLD)
			stepper(2, "Mouse sensitivity", "sensitivity", function(v)
				return string.format("%.1f", v)
			end)
			label(tabBody, "KEYS  (click one, then press the new key; Esc cancels)", 14, 3, GOLD)
			label(tabBody, "Fixed: W A S D move, Space jump, E interact, 2 / 3 pocket to hand, mouse look, left click "
				.. "hit / throw.", 12, 4, MUTED)
			for i, a in Keybinds.ACTIONS do
				local key = values.keys[a.id] or a.default
				row(10 + i, a.label, if capturing == a.id then "press a key..." else Keybinds.label(key), nil, nil,
					function()
						capturing = a.id
						render()
					end)
			end
			button(tabBody, "Reset all keys", 100, nil, 34).Activated:Connect(function()
				values.keys = Keybinds.clean(nil)
				capturing = nil
				changed()
			end)
		end
	end
	-- The next key press goes to the action being changed.
	UserInputService.InputBegan:Connect(function(input)
		if not capturing or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		local id = capturing :: string
		capturing = nil
		if input.KeyCode ~= Enum.KeyCode.Escape then
			local name = input.KeyCode.Name
			local before = values.keys[id]
			values.keys = Keybinds.assign(values.keys, id, name)
			if values.keys[id] == before and name ~= before then
				message.Text = `{Keybinds.label(name)} can't be used for that (it moves you or is fixed).`
			end
		end
		changed()
	end)

	-- How to play --------------------------------------------------------------------------------------------------
	local how = page("how")
	local howText: TextLabel
	label(how, "How to play", 24, 1, GOLD, Enum.Font.GothamBold)
	howText = label(how, "", 15, 2)
	local function renderHow()
		local k = function(id: string): string
			return Keybinds.label(values.keys[id] or Keybinds.default(id))
		end
		howText.Text = table.concat({
			"W A S D  move,  Space  jump,  mouse  look,  E  use / talk / open",
			`{k("sprint")}  sprint,  {k("crouch")}  crouch (while running: slide)`,
			`{k("phone")}  phone up (browse it with the cursor),  {k("phoneHands")}  hold it in both hands`,
			`{k("torch")}  phone flashlight,  {k("flash")}  flash burst (stuns the entity)`,
			`{k("bag")}  bag and items,  {k("dropBag")}  drop the bag,  {k("useItem")}  use a power bank`,
			`{k("menu")}  this menu,  {k("meeting")}  call a meeting (Social Deduction)`,
			"",
			"Hide and Seek: hide in lockers, flash the entity, free a caught friend: hit the entity from behind or "
				.. "pull them free (it hurts). Too slow and the entity starts eating them.",
			"The story: go to your lessons, sit at a desk for the test, find clues, borrow keys from the porter, name "
				.. "the entity.",
			"Using the phone while walking makes you dizzy. Keep it up too long and you fall over.",
		}, "\n")
	end

	-- Friends ------------------------------------------------------------------------------------------------------
	local friends = page("friends")
	label(friends, "Friends and lobbies", 24, 1, GOLD, Enum.Font.GothamBold)
	button(friends, "Invite friends", 2).Activated:Connect(function()
		local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if not ok or not can then
			message.Text = "Invites are not available here (they work in the published game)."
			return
		end
		local options = Instance.new("ExperienceInviteOptions")
		options.PromptMessage = "Come play The Empty School with me!"
		local code = ReplicatedStorage:GetAttribute("LobbyCode")
		if code then
			options.LaunchData = HttpService:JSONEncode({ lobby = code })
		end
		pcall(SocialService.PromptGameInvite, SocialService, player, options)
	end)
	button(friends, "Create private lobby", 3).Activated:Connect(function()
		message.Text = "Making a private lobby..."
		createRemote:FireServer()
	end)
	local codeRow = Instance.new("Frame")
	codeRow.Size = UDim2.new(1, 0, 0, 40)
	codeRow.LayoutOrder = 4
	codeRow.BackgroundTransparency = 1
	codeRow.Parent = friends
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0.62, -6, 1, 0)
	box.BackgroundColor3 = Color3.fromRGB(30, 26, 34)
	box.TextColor3 = TEXT
	box.PlaceholderText = "Lobby code"
	box.PlaceholderColor3 = Color3.fromRGB(130, 120, 130)
	box.Text = ""
	box.TextSize = 18
	box.Font = Enum.Font.GothamMedium
	box.ClearTextOnFocus = false
	corner(box)
	box.Parent = codeRow
	local joinButton = Instance.new("TextButton")
	joinButton.AnchorPoint = Vector2.new(1, 0)
	joinButton.Position = UDim2.fromScale(1, 0)
	joinButton.Size = UDim2.new(0.38, 0, 1, 0)
	joinButton.BackgroundColor3 = BUTTON
	joinButton.TextColor3 = TEXT
	joinButton.TextSize = 17
	joinButton.Font = Enum.Font.GothamMedium
	joinButton.Text = "Join by code"
	corner(joinButton)
	joinButton.Parent = codeRow
	local function joinCode()
		local code = Settings.cleanCode(box.Text)
		if not code then
			message.Text = "A lobby code has 5 letters or numbers."
			return
		end
		message.Text = `Looking for lobby {code}...`
		joinRemote:FireServer(code)
	end
	joinButton.Activated:Connect(joinCode)
	box.FocusLost:Connect(function(enter)
		if enter then
			joinCode()
		end
	end)

	-- The main column's buttons ------------------------------------------------------------------------------------
	local setOpen: (boolean) -> ()
	local resume = button(column, "Resume", 10, Color3.fromRGB(46, 96, 70))
	resume.Activated:Connect(function()
		setOpen(false)
	end)
	local playButton = button(column, "Play", 11, ACCENT)
	playButton.Activated:Connect(function()
		openPage("play")
	end)
	local freeRoam = button(column, "Free roam", 12, Color3.fromRGB(46, 96, 70))
	freeRoam.Activated:Connect(function()
		startRemote:FireServer("freeroam", "none")
	end)
	local stopButton = button(column, "Stop after this round", 13)
	stopButton.Activated:Connect(function()
		backRemote:FireServer()
	end)
	local adminButton = button(column, "Admin panel", 14, Color3.fromRGB(70, 60, 110))
	adminButton.Activated:Connect(function()
		setOpen(false)
		require(script.Parent.AdminUi).open()
	end)
	button(column, "Achievements", 15, Color3.fromRGB(110, 86, 40)).Activated:Connect(function()
		setOpen(false)
		require(script.Parent.AchievementUi).open()
	end)
	button(column, "Settings", 16).Activated:Connect(function()
		openPage("settings")
	end)
	button(column, "How to play", 17).Activated:Connect(function()
		openPage("how")
	end)
	button(column, "Friends and lobbies", 18).Activated:Connect(function()
		openPage("friends")
	end)
	local hint = label(column, "", 12, 30, MUTED)

	-- FPS counter.
	local fpsGui = Instance.new("ScreenGui")
	fpsGui.Name = "Fps"
	fpsGui.ResetOnSpawn = false
	fpsGui.Parent = player:WaitForChild("PlayerGui")
	local fpsLabel = Instance.new("TextLabel")
	fpsLabel.AnchorPoint = Vector2.new(1, 0)
	fpsLabel.Position = UDim2.new(1, -10, 0, 90)
	fpsLabel.Size = UDim2.fromOffset(90, 22)
	fpsLabel.BackgroundTransparency = 0.5
	fpsLabel.BackgroundColor3 = Color3.new(0, 0, 0)
	fpsLabel.TextColor3 = TEXT
	fpsLabel.TextSize = 14
	fpsLabel.Font = Enum.Font.Code
	fpsLabel.Parent = fpsGui
	local frames, elapsed = 0, 0
	RunService.RenderStepped:Connect(function(dt)
		fpsLabel.Visible = values.showFps
		frames += 1
		elapsed += dt
		if elapsed >= 0.5 then
			fpsLabel.Text = `{math.round(frames / elapsed)} FPS`
			frames, elapsed = 0, 0
		end
	end)

	render = function()
		local phase = State.phase()
		local lobby = phase == "lobby"
		local roaming = ReplicatedStorage:GetAttribute("Mode") == "freeroam"
		resume.Visible = not lobby
		playButton.Visible = lobby
		freeRoam.Visible = lobby
		stopButton.Visible = not lobby and (roaming or ReplicatedStorage:GetAttribute("Cycle") == true)
		stopButton.Text = "    " .. (if roaming then "End free roam" else "Stop after this round")
		adminButton.Visible = roaming and player:GetAttribute("Admin") == true
		if not lobby and current == "play" then
			openPage(nil)
		end
		local code = ReplicatedStorage:GetAttribute("LobbyCode")
		where.Text = if code then `Private lobby. Code: {code}` else "Public server"
		hint.Text = `Start walking or click outside to play. {Keybinds.label(values.keys.menu or "Backquote")} opens `
			.. "this menu again."
		renderSettings()
		renderHow()
	end

	setOpen = function(open: boolean)
		dim.Visible = open
		capturing = nil
		TweenService:Create(blur, TweenInfo.new(0.25), { Size = if open then 16 else 0 }):Play()
		if open then
			message.Text = ""
			render()
		end
	end
	dim.Activated:Connect(function()
		setOpen(false)
	end)
	-- Starting to move closes the menu (not while typing in a box or choosing a key).
	local MOVE = { [Enum.KeyCode.W] = true, [Enum.KeyCode.A] = true, [Enum.KeyCode.S] = true, [Enum.KeyCode.D] = true,
		[Enum.KeyCode.Up] = true, [Enum.KeyCode.Down] = true, [Enum.KeyCode.Left] = true, [Enum.KeyCode.Right] = true,
		[Enum.KeyCode.Space] = true, [Enum.KeyCode.Thumbstick1] = true }
	UserInputService.InputBegan:Connect(function(input)
		if dim.Visible and not capturing and MOVE[input.KeyCode] and not UserInputService:GetFocusedTextBox() then
			setOpen(false)
		end
	end)
	ClientSettings.bind("Menu", "menu", function(_, state)
		if state == Enum.UserInputState.Begin and not capturing then
			setOpen(not dim.Visible)
		end
		return Enum.ContextActionResult.Sink
	end, true, { Enum.KeyCode.ButtonStart })

	local lastPhase = State.phase()
	State.changed:Connect(function()
		local phase = State.phase()
		if phase == "starting" and lastPhase ~= "starting" then
			setOpen(false) -- A round begins: get out of the way.
		end
		lastPhase = phase
		render()
	end)
	ReplicatedStorage:GetAttributeChangedSignal("Cycle"):Connect(render)
	ReplicatedStorage:GetAttributeChangedSignal("LobbyCode"):Connect(render)
	ReplicatedStorage:GetAttributeChangedSignal("Mode"):Connect(render)
	player:GetAttributeChangedSignal("Admin"):Connect(render)
	local banner = remotes:WaitForChild("Banner") :: RemoteEvent
	banner.OnClientEvent:Connect(function(text)
		if dim.Visible then
			message.Text = tostring(text)
		end
	end)
	settingsRemote.OnClientEvent:Connect(function(saved)
		values = Settings.clean(saved)
		applySettings()
		render()
	end)

	applySettings()
	setOpen(true)
end

return MainMenu
