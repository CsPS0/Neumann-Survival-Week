-- The story's small screens: what a teacher says (E on a teacher), the safe's keypad, and the ending card.
local Players = game:GetService("Players")

local StoryUi = require(script.Parent.StoryUi)

local StoryDialogs = {}

function StoryDialogs.init(remotes: Folder)
	-- Teacher talk: a box at the bottom that fades after a few seconds.
	local talkGui = StoryUi.gui("Dialogue", 4)
	local talk = Instance.new("Frame")
	talk.AnchorPoint = Vector2.new(0.5, 1)
	talk.Position = UDim2.new(0.5, 0, 1, -70)
	talk.Size = UDim2.new(0.9, 0, 0, 0)
	talk.AutomaticSize = Enum.AutomaticSize.Y
	talk.BackgroundColor3 = StoryUi.BG
	talk.BackgroundTransparency = 0.15
	talk.Visible = false
	talk.Parent = talkGui
	StoryUi.corner(talk)
	local talkSize = Instance.new("UISizeConstraint")
	talkSize.MaxSize = Vector2.new(620, 10000)
	talkSize.Parent = talk
	local talkPad = Instance.new("UIPadding")
	talkPad.PaddingTop = UDim.new(0, 10)
	talkPad.PaddingBottom = UDim.new(0, 10)
	talkPad.PaddingLeft = UDim.new(0, 12)
	talkPad.PaddingRight = UDim.new(0, 12)
	talkPad.Parent = talk
	local talkList = Instance.new("UIListLayout")
	talkList.Padding = UDim.new(0, 4)
	talkList.SortOrder = Enum.SortOrder.LayoutOrder
	talkList.Parent = talk
	local talkToken = 0
	(remotes:WaitForChild("Dialogue") :: RemoteEvent).OnClientEvent:Connect(function(info)
		StoryUi.clear(talk)
		StoryUi.text(talk, info.name, 17, 1, StoryUi.GOLD)
		for i, line in info.lines do
			StoryUi.text(talk, `"{line}"`, 16, 1 + i)
		end
		talk.Visible = true
		talkToken += 1
		local token = talkToken
		task.delay(5 + 3 * #info.lines, function()
			if token == talkToken then
				talk.Visible = false
			end
		end)
	end)

	-- The safe's keypad.
	local padGui = StoryUi.gui("Keypad", 8)
	local pad = StoryUi.panel(padGui, 340, 0.4)
	StoryUi.freeMouseWhile(padGui, pad)
	local enterRemote = remotes:WaitForChild("KeypadEnter") :: RemoteEvent
	StoryUi.text(pad, "Old safe: enter the 4-digit code", 18, 1, StoryUi.GOLD)
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, 0, 0, 44)
	box.LayoutOrder = 2
	box.BackgroundColor3 = Color3.fromRGB(30, 28, 34)
	box.TextColor3 = StoryUi.TEXT
	box.PlaceholderText = "0000"
	box.TextSize = 26
	box.Font = Enum.Font.Code
	box.ClearTextOnFocus = true
	box.Text = ""
	StoryUi.corner(box)
	box.Parent = pad
	box:GetPropertyChangedSignal("Text"):Connect(function()
		local digits = string.sub(string.gsub(box.Text, "%D", ""), 1, 4)
		if digits ~= box.Text then
			box.Text = digits
		end
	end)
	local function submit()
		if #box.Text == 4 then
			enterRemote:FireServer(box.Text)
			pad.Visible = false
		end
	end
	StoryUi.button(pad, "Open", 3, StoryUi.ACCENT).Activated:Connect(submit)
	StoryUi.button(pad, "Cancel", 4).Activated:Connect(function()
		pad.Visible = false
	end)
	box.FocusLost:Connect(function(enter)
		if enter then
			submit()
		end
	end);
	-- Close the keypad when the run ends or you are caught.
	(remotes:WaitForChild("CampaignState") :: RemoteEvent).OnClientEvent:Connect(function(state)
		if state == nil then
			pad.Visible = false
		end
	end)
	Players.LocalPlayer:GetAttributeChangedSignal("State"):Connect(function()
		if Players.LocalPlayer:GetAttribute("State") ~= "alive" then
			pad.Visible = false
		end
	end);
	(remotes:WaitForChild("Keypad") :: RemoteEvent).OnClientEvent:Connect(function()
		box.Text = ""
		pad.Visible = true
		task.defer(function()
			box:CaptureFocus()
		end)
	end)

	-- The ending card: stays until closed.
	local endGui = StoryUi.gui("Ending", 9)
	local card = StoryUi.panel(endGui, 600, 0.8)
	StoryUi.freeMouseWhile(endGui, card);
	(remotes:WaitForChild("Ending") :: RemoteEvent).OnClientEvent:Connect(function(info)
		StoryUi.clear(card)
		local c = info.color or { 1, 1, 1 }
		local title = StoryUi.text(card, `Ending {info.id}: {info.title}`, 30, 1, Color3.new(c[1], c[2], c[3]))
		title.Font = Enum.Font.GothamBold
		title.TextXAlignment = Enum.TextXAlignment.Center
		local body = StoryUi.text(card, info.text, 18, 2)
		body.TextXAlignment = Enum.TextXAlignment.Center
		local s = info.stats or {}
		StoryUi.text(card, `Difficulty: {s.difficulty}   |   Team quiz: {s.quiz}   |   Clues: {s.clues}   |   Clock: {s.time}`,
			15, 3, StoryUi.MUTED)
		if s.out and #s.out > 0 then
			StoryUi.text(card, "Out: " .. table.concat(s.out, ", "), 15, 4, StoryUi.MUTED)
		end
		StoryUi.button(card, "Close", 5, StoryUi.ACCENT).Activated:Connect(function()
			card.Visible = false
		end)
		card.Visible = true
	end)
end

return StoryDialogs
