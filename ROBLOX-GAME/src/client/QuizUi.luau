-- The lesson test at your desk. Sitting down, the view lowers to the paper in front of you and the task appears:
--   choice  - a printed question with boxes to tick (click or keys 1-4)
--   written - a lined sheet: write the answer on the line, Enter hands it in
--   code    - the PC: a small editor (Python), Run shows what it prints, Hand in sends it
--   network - a small "packet tracer": click a device, then another to lay a cable; click a cable to remove it
-- Standing up puts the test away until you sit again. The server marks every answer (src/shared/LessonSheet.luau).
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CodeCheck = require(ReplicatedStorage.Shared.CodeCheck)
local NetCheck = require(ReplicatedStorage.Shared.NetCheck)
local StoryUi = require(script.Parent.StoryUi)

local player = Players.LocalPlayer
local QuizUi = {}

local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
local PAPER = Color3.fromRGB(246, 242, 230)
local INK = Color3.fromRGB(28, 38, 92)
local PRINT = Color3.fromRGB(30, 30, 34)
local RULE = Color3.fromRGB(170, 196, 226)
local MARGIN = Color3.fromRGB(220, 120, 120)
local HAND = Enum.Font.IndieFlower
local SCREEN = Color3.fromRGB(22, 24, 30)
local GREEN = Color3.fromRGB(140, 230, 150)
local RED = Color3.fromRGB(240, 120, 110)

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function text(parent: Instance, value: string, size: number, color: Color3, font: Enum.Font, height: number?):
	TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0, height or size + 8)
	t.AutomaticSize = if height then Enum.AutomaticSize.None else Enum.AutomaticSize.Y
	t.TextWrapped = true
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Top
	t.Text = value
	t.TextSize = size
	t.TextColor3 = color
	t.Font = font
	t.Parent = parent
	return t
end

local function list(parent: Instance, padding: number)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
end

local function pad(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop, p.PaddingBottom = UDim.new(0, px), UDim.new(0, px)
	p.PaddingLeft, p.PaddingRight = UDim.new(0, px + 16), UDim.new(0, px)
	p.Parent = parent
end

local function button(parent: Instance, value: string, color: Color3, order: number): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(130, 34)
	b.LayoutOrder = order
	b.BackgroundColor3 = color
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = value
	b.TextSize = 16
	b.Font = Enum.Font.GothamMedium
	corner(b, 6)
	b.Parent = parent
	return b
end

function QuizUi.init(remotes: Folder)
	local answerRemote = remotes:WaitForChild("QuizAnswer") :: RemoteEvent
	local gui = StoryUi.gui("Quiz", 6)
	gui.IgnoreGuiInset = true
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.52)
	holder.Size = UDim2.new(0, 620, 0.78, 0)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = gui
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(620, 640)
	sizeLimit.Parent = holder
	StoryUi.freeMouseWhile(gui, holder)
	local note = text(gui, "", 18, StoryUi.GOLD, Enum.Font.GothamMedium, 26)
	note.AnchorPoint = Vector2.new(0.5, 1)
	note.Position = UDim2.new(0.5, 0, 1, -170)
	note.Size = UDim2.fromOffset(600, 26)
	note.TextXAlignment = Enum.TextXAlignment.Center
	note.TextStrokeTransparency = 0.5

	local quiz = nil :: any -- { lesson, subject, mode, questions, paper, seated }
	local current = 0
	local waiting = false
	local hideToken = 0
	local deskView = false

	local function unbindKeys()
		for i = 1, #KEYS do
			ContextActionService:UnbindAction("Quiz" .. i)
		end
	end

	-- The view lowers to the paper on the desk while you write (a scripted camera; back to normal after).
	local function setDeskView(on: boolean)
		local camera = workspace.CurrentCamera
		if on == deskView then
			return
		end
		if on and quiz and not (quiz.paper and quiz.paper.Parent) then
			for _, p in CollectionService:GetTagged("TestPaper") do
				if p:GetAttribute("Owner") == player.UserId then
					quiz.paper = p
				end
			end
		end
		if on and quiz and not (quiz.paper and quiz.paper.Parent) then
			-- The paper on the desk has not reached this client yet: look again shortly.
			local mine = quiz
			task.delay(0.3, function()
				if quiz == mine then
					setDeskView(true)
				end
			end)
			return
		end
		deskView = on
		if on and quiz and quiz.paper and quiz.paper.Parent then
			local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
			if not head then
				deskView = false
				return
			end
			local paper = quiz.paper :: BasePart
			local eye = head.Position + Vector3.new(0, 0.3, 0)
			local target = paper.Position + (if quiz.mode == "code" then Vector3.new(0, 1.0, 0) else Vector3.zero)
			camera.CameraType = Enum.CameraType.Scriptable
			TweenService:Create(camera, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
				CFrame = CFrame.lookAt(eye:Lerp(target, 0.25), target),
			}):Play()
		else
			camera.CameraType = Enum.CameraType.Custom
		end
	end

	local function clear()
		for _, c in holder:GetChildren() do
			if not c:IsA("UISizeConstraint") then
				c:Destroy()
			end
		end
	end

	local function hideLater(seconds: number)
		hideToken += 1
		local token = hideToken
		task.delay(seconds, function()
			if token == hideToken then
				holder.Visible = false
				setDeskView(false)
			end
		end)
	end

	local function send(answer: any)
		if waiting or not quiz then
			return
		end
		waiting = true
		unbindKeys()
		answerRemote:FireServer(quiz.lesson, current, answer)
	end

	-- A sheet of paper (lined for writing) or a PC screen, filling the holder.
	local function sheet(kind: string): Frame
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = if kind == "screen" then SCREEN else PAPER
		f.ClipsDescendants = true -- the ruled lines stop at the paper's edge
		f.Parent = holder
		corner(f, if kind == "screen" then 10 else 3)
		local stroke = Instance.new("UIStroke")
		stroke.Color = if kind == "screen" then Color3.fromRGB(60, 64, 72) else Color3.fromRGB(200, 194, 178)
		stroke.Thickness = if kind == "screen" then 8 else 1
		stroke.Parent = f
		if kind == "lined" then
			for y = 96, 900, 30 do
				local line = Instance.new("Frame")
				line.BorderSizePixel = 0
				line.BackgroundColor3 = RULE
				line.Position = UDim2.fromOffset(0, y)
				line.Size = UDim2.new(1, 0, 0, 1)
				line.Parent = f
			end
			local margin = Instance.new("Frame")
			margin.BorderSizePixel = 0
			margin.BackgroundColor3 = MARGIN
			margin.Position = UDim2.fromOffset(28, 0) -- left of the writing (the text starts at 38 px)
			margin.Size = UDim2.new(0, 2, 1, 0)
			margin.Parent = f
		end
		local body = Instance.new("Frame")
		body.Name = "Body"
		body.BackgroundTransparency = 1
		body.Size = UDim2.fromScale(1, 1)
		body.Parent = f
		pad(body, 22)
		list(body, 10)
		return body
	end

	local showQuestion: () -> ()

	local function header(body: Frame, ink: Color3, font: Enum.Font)
		text(body, `{quiz.subject} test  ·  {current} / {#quiz.questions}`, 18, ink, font).LayoutOrder = 1
	end

	local function choicePaper(q: any)
		local body = sheet("plain")
		header(body, PRINT, Enum.Font.Merriweather)
		text(body, q.text, 22, PRINT, Enum.Font.Merriweather).LayoutOrder = 2
		for i, option in q.options do
			local b = Instance.new("TextButton")
			b.LayoutOrder = 2 + i
			b.Size = UDim2.new(1, 0, 0, 40)
			b.BackgroundTransparency = 1
			b.Text = `☐   {option}`
			b.TextXAlignment = Enum.TextXAlignment.Left
			b.TextSize = 22
			b.Font = Enum.Font.Merriweather
			b.TextColor3 = PRINT
			b.Parent = body
			b.MouseEnter:Connect(function()
				b.TextColor3 = INK
			end)
			b.MouseLeave:Connect(function()
				b.TextColor3 = PRINT
			end)
			local function pick()
				b.Text = `☒   {option}`
				b.TextColor3 = INK
				send(i)
			end
			b.Activated:Connect(pick)
			ContextActionService:BindAction("Quiz" .. i, function(_, state)
				if state == Enum.UserInputState.Begin then
					pick()
				end
				return Enum.ContextActionResult.Sink
			end, false, KEYS[i])
		end
		text(body, "Tick one box (click, or keys 1-4).", 14, Color3.fromRGB(110, 106, 96), Enum.Font.Gotham)
			.LayoutOrder = 20
	end

	local function writtenPaper(q: any)
		local body = sheet("lined")
		header(body, INK, HAND)
		text(body, q.text, 24, PRINT, Enum.Font.Merriweather).LayoutOrder = 2
		local box = Instance.new("TextBox")
		box.LayoutOrder = 3
		box.Size = UDim2.new(1, 0, 0, 44)
		box.BackgroundTransparency = 1
		box.TextColor3 = INK
		box.PlaceholderText = "write your answer here..."
		box.PlaceholderColor3 = Color3.fromRGB(150, 160, 190)
		box.TextSize = 30
		box.Font = HAND
		box.TextXAlignment = Enum.TextXAlignment.Left
		box.ClearTextOnFocus = false
		box.Text = ""
		box.Parent = body
		local row = Instance.new("Frame")
		row.LayoutOrder = 4
		row.Size = UDim2.new(1, 0, 0, 34)
		row.BackgroundTransparency = 1
		row.Parent = body
		local ok = button(row, "Hand in", INK, 1)
		ok.Activated:Connect(function()
			if box.Text ~= "" then
				send(box.Text)
			end
		end)
		box.FocusLost:Connect(function(enter)
			if enter and box.Text ~= "" then
				send(box.Text)
			end
		end)
		task.defer(function()
			if box.Parent then
				box:CaptureFocus()
			end
		end)
	end

	local function codeScreen(q: any)
		local body = sheet("screen")
		header(body, Color3.fromRGB(150, 160, 175), Enum.Font.Code)
		text(body, q.text, 18, Color3.fromRGB(230, 232, 240), Enum.Font.GothamMedium).LayoutOrder = 2
		text(body, `It should print:\n{q.expect}`, 14, Color3.fromRGB(150, 200, 150), Enum.Font.Code).LayoutOrder = 3
		local editor = Instance.new("TextBox")
		editor.LayoutOrder = 4
		editor.Size = UDim2.new(1, 0, 0, 170)
		editor.BackgroundColor3 = Color3.fromRGB(12, 13, 17)
		editor.TextColor3 = Color3.fromRGB(220, 225, 235)
		editor.Font = Enum.Font.Code
		editor.TextSize = 17
		editor.MultiLine = true
		editor.ClearTextOnFocus = false
		editor.TextXAlignment = Enum.TextXAlignment.Left
		editor.TextYAlignment = Enum.TextYAlignment.Top
		editor.Text = q.starter or ""
		editor.PlaceholderText = '# Python\nprint("...")'
		editor.Parent = body
		corner(editor, 4)
		local edPad = Instance.new("UIPadding")
		edPad.PaddingLeft, edPad.PaddingTop = UDim.new(0, 8), UDim.new(0, 6)
		edPad.Parent = editor
		-- After a line ending in ":" a new line starts indented (the loop's body).
		local last = editor.Text
		editor:GetPropertyChangedSignal("Text"):Connect(function()
			local t = editor.Text
			if #t == #last + 1 and string.sub(t, -2) == ":\n" then
				last = t .. "    "
				editor.Text = last
				editor.CursorPosition = #last + 1
				return
			end
			last = t
		end)
		local output = text(body, "", 15, Color3.fromRGB(200, 205, 215), Enum.Font.Code, 70)
		output.LayoutOrder = 6
		output.BackgroundColor3 = Color3.fromRGB(8, 9, 12)
		output.BackgroundTransparency = 0
		corner(output, 4)
		local row = Instance.new("Frame")
		row.LayoutOrder = 5
		row.Size = UDim2.new(1, 0, 0, 34)
		row.BackgroundTransparency = 1
		row.Parent = body
		local rowList = Instance.new("UIListLayout")
		rowList.FillDirection = Enum.FillDirection.Horizontal
		rowList.Padding = UDim.new(0, 10)
		rowList.Parent = row
		button(row, "▶ Run", Color3.fromRGB(46, 120, 70), 1).Activated:Connect(function()
			local out, err = CodeCheck.run(editor.Text)
			if out then
				output.Text = "> " .. (if #out > 0 then table.concat(out, "\n") else "(nothing printed)")
				output.TextColor3 = Color3.fromRGB(200, 205, 215)
			else
				output.Text = "Error: " .. tostring(err)
				output.TextColor3 = RED
			end
		end)
		button(row, "Hand in", Color3.fromRGB(60, 80, 150), 2).Activated:Connect(function()
			if editor.Text ~= "" then
				send(editor.Text)
			end
		end)
		task.defer(function()
			if editor.Parent then
				editor:CaptureFocus()
				editor.CursorPosition = #editor.Text + 1
			end
		end)
	end

	local GLYPH = { pc = "PC", server = "SRV", switch = "SW", router = "R", cloud = "WAN" }
	local COLOR = { pc = Color3.fromRGB(70, 110, 170), server = Color3.fromRGB(110, 80, 160),
		switch = Color3.fromRGB(50, 140, 120), router = Color3.fromRGB(180, 110, 50), cloud = Color3.fromRGB(120, 130, 140) }

	local function networkDesk(q: any)
		local body = sheet("screen")
		header(body, Color3.fromRGB(150, 160, 175), Enum.Font.Code)
		text(body, q.text, 18, Color3.fromRGB(230, 232, 240), Enum.Font.GothamMedium).LayoutOrder = 2
		local canvas = Instance.new("Frame")
		canvas.LayoutOrder = 3
		canvas.Size = UDim2.new(1, 0, 0, 260)
		canvas.BackgroundColor3 = Color3.fromRGB(30, 34, 42)
		canvas.ClipsDescendants = true
		canvas.Parent = body
		corner(canvas, 6)
		local status = text(body, "Click a device, then another, to lay a cable. Click a cable to remove it.", 14,
			Color3.fromRGB(170, 175, 185), Enum.Font.Gotham)
		status.LayoutOrder = 4
		local devices = q.devices :: { { id: string, kind: string } }
		local links: { { string } } = {}
		local pos: { [string]: Vector2 } = {}
		-- End devices on the bottom row, switches in the middle, routers and the internet on top.
		local rows = { {}, {}, {} } :: { { any } }
		for _, d in devices do
			local r = if d.kind == "pc" or d.kind == "server" then 3 elseif d.kind == "switch" then 2 else 1
			table.insert(rows[r], d)
		end
		local W = 560
		for r, row in rows do
			for k, d in row do
				pos[d.id] = Vector2.new(W * k / (#row + 1), 40 + (r - 1) * 85)
			end
		end
		local cableLayer = Instance.new("Frame")
		cableLayer.BackgroundTransparency = 1
		cableLayer.Size = UDim2.fromScale(1, 1)
		cableLayer.Parent = canvas
		local picked: string? = nil
		local nodes: { [string]: TextButton } = {}
		local redraw: () -> ()
		redraw = function()
			for _, c in cableLayer:GetChildren() do
				c:Destroy()
			end
			for k, l in links do
				local a, b = pos[l[1]], pos[l[2]]
				local mid = (a + b) / 2
				local len = (b - a).Magnitude
				local cable = Instance.new("TextButton")
				cable.Text = ""
				cable.AutoButtonColor = false
				cable.AnchorPoint = Vector2.new(0.5, 0.5)
				cable.Position = UDim2.fromOffset(mid.X, mid.Y)
				cable.Size = UDim2.fromOffset(len, 4)
				cable.Rotation = math.deg(math.atan2(b.Y - a.Y, b.X - a.X))
				cable.BackgroundColor3 = Color3.fromRGB(240, 200, 80)
				cable.BorderSizePixel = 0
				cable.Parent = cableLayer
				cable.Activated:Connect(function()
					table.remove(links, k)
					redraw()
				end)
			end
			for id, node in nodes do
				local stroke = node:FindFirstChildOfClass("UIStroke") :: UIStroke
				stroke.Color = if id == picked then Color3.fromRGB(255, 230, 120) else Color3.fromRGB(20, 20, 24)
				stroke.Thickness = if id == picked then 3 else 1
			end
		end
		for _, d in devices do
			local node = Instance.new("TextButton")
			node.AnchorPoint = Vector2.new(0.5, 0.5)
			node.Position = UDim2.fromOffset(pos[d.id].X, pos[d.id].Y)
			node.Size = UDim2.fromOffset(78, 46)
			node.BackgroundColor3 = COLOR[d.kind] or Color3.fromRGB(90, 90, 90)
			node.TextColor3 = Color3.new(1, 1, 1)
			node.Font = Enum.Font.GothamBold
			node.TextSize = 13
			node.Text = `{GLYPH[d.kind] or "?"}\n{d.id}`
			node.ZIndex = 3
			node.Parent = canvas
			corner(node, 8)
			local stroke = Instance.new("UIStroke")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = node
			nodes[d.id] = node
			node.Activated:Connect(function()
				if not picked then
					picked = d.id
				elseif picked == d.id then
					picked = nil
				else
					local ok, why = NetCheck.canLink(devices, links, picked, d.id)
					if ok then
						table.insert(links, { picked, d.id })
						status.Text = `Cable: {picked} - {d.id}`
					else
						status.Text = `Can't: {why}`
					end
					picked = nil
				end
				redraw()
			end)
		end
		redraw()
		local row = Instance.new("Frame")
		row.LayoutOrder = 5
		row.Size = UDim2.new(1, 0, 0, 34)
		row.BackgroundTransparency = 1
		row.Parent = body
		button(row, "Hand in", Color3.fromRGB(60, 80, 150), 1).Activated:Connect(function()
			send(links)
		end)
	end

	showQuestion = function()
		clear()
		unbindKeys()
		local q = quiz.questions[current]
		if not q then
			return
		end
		if quiz.mode == "choice" then
			choicePaper(q)
		elseif quiz.mode == "written" then
			writtenPaper(q)
		elseif quiz.mode == "code" then
			codeScreen(q)
		else
			networkDesk(q)
		end
	end

	local function seated(): boolean
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		return humanoid ~= nil and humanoid.SeatPart ~= nil
	end

	-- Sitting shows the test; standing up puts it away (the server keeps your answers).
	local function refresh()
		if not quiz then
			return
		end
		local show = seated() or not quiz.seated
		holder.Visible = show
		note.Text = if show then "" else "Sit back down at your desk to go on with the test."
		setDeskView(show and quiz.seated)
	end
	local seatConnection: RBXScriptConnection? = nil
	local function watchSeat()
		if seatConnection then
			seatConnection:Disconnect()
			seatConnection = nil
		end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			seatConnection = humanoid:GetPropertyChangedSignal("SeatPart"):Connect(refresh)
		end
	end

	local function abort()
		unbindKeys()
		quiz = nil
		hideToken += 1
		holder.Visible = false
		note.Text = ""
		setDeskView(false)
	end
	(remotes:WaitForChild("CampaignState") :: RemoteEvent).OnClientEvent:Connect(function(state)
		if state == nil then
			abort()
		end
	end)
	player:GetAttributeChangedSignal("State"):Connect(function()
		if player:GetAttribute("State") ~= "alive" then
			abort()
		end
	end);

	(remotes:WaitForChild("QuizStart") :: RemoteEvent).OnClientEvent:Connect(function(info)
		quiz = info
		current = 1
		waiting = false
		hideToken += 1
		watchSeat()
		showQuestion()
		refresh()
	end);

	(remotes:WaitForChild("QuizResult") :: RemoteEvent).OnClientEvent:Connect(function(result)
		if not quiz or result.lesson ~= quiz.lesson then
			return
		end
		clear()
		local body = sheet(if quiz.mode == "code" or quiz.mode == "network" then "screen" else "plain")
		local ink = if quiz.mode == "code" or quiz.mode == "network" then Color3.fromRGB(230, 232, 240) else PRINT
		if result.closed then
			unbindKeys()
			text(body, `The bell. Pens down.\nYour score: {result.right}/{result.total}.`, 24, ink, HAND).LayoutOrder = 1
			quiz = nil
			note.Text = ""
			hideLater(2.5)
			return
		end
		text(body, if result.correct then "Correct!" else "Wrong.", 30, if result.correct then GREEN else RED, HAND)
			.LayoutOrder = 1
		waiting = false
		if result.done then
			text(body, `All done: {result.right}/{result.total}. Wait for the bell.`, 20, ink, HAND).LayoutOrder = 2
			quiz = nil
			hideLater(2.5)
		else
			current = result.questionIndex + 1
			task.delay(0.8, function()
				if quiz then
					showQuestion()
				end
			end)
		end
	end)
end

return QuizUi
