-- The Social Deduction meeting panel: who called it, the room log of the last minute per tag, and the vote list
-- (buttons or keys 1-9, plus Skip). Also points the chat box at the "Out" channel while you are out.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local State = require(script.Parent.State)

local player = Players.LocalPlayer
local MeetingUi = {}

local KEYS = {
	Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five,
	Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine,
}

local function text(parent: Instance, value: string, size: number, order: number, height: number?): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, height or (size + 8))
	l.LayoutOrder = order
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextSize = size
	l.Font = Enum.Font.GothamMedium
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.Text = value
	l.Parent = parent
	return l
end

local function describe(entries: { { label: string, ago: number } }): string
	if #entries == 0 then
		return "no rooms recorded"
	end
	local parts = {}
	for _, e in entries do
		table.insert(parts, `{e.label} ({e.ago} s ago)`)
	end
	return table.concat(parts, "  >  ")
end

function MeetingUi.init(remotes: Folder)
	local voteRemote = remotes:WaitForChild("Vote") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "Meeting"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("ScrollingFrame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.52)
	panel.Size = UDim2.new(0.9, 0, 0.72, 0)
	panel.BackgroundColor3 = Color3.fromRGB(14, 12, 16)
	panel.BackgroundTransparency = 0.12
	panel.ScrollBarThickness = 6
	panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
	panel.CanvasSize = UDim2.new()
	panel.Visible = false
	panel.Parent = gui
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(720, 10000)
	constraint.Parent = panel
	local pad = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(pad :: any)[side] = UDim.new(0, 14)
	end
	pad.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = panel

	-- The game is first person: the cursor is free while the meeting panel is open.
	require(script.Parent.MouseLock).track(panel)

	local voted = false
	local options: { string } = {}

	local function clear()
		for _, c in panel:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for i = 1, #KEYS do
			ContextActionService:UnbindAction("Vote" .. i)
		end
	end

	local resultLabel: TextLabel? = nil

	local function vote(target: string)
		if voted or not State.alive() then
			return
		end
		voted = true
		voteRemote:FireServer(target)
		if resultLabel then
			resultLabel.Text = if target == "skip" then "You skipped. Waiting for the others..."
				else `You voted for {target}. Waiting for the others...`
		end
	end

	(remotes:WaitForChild("MeetingStarted") :: RemoteEvent).OnClientEvent:Connect(function(info)
		clear()
		voted = false
		panel.Visible = true
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end
		local heading = if info.victim then `{info.caller} found {info.victim}'s body.` else `{info.caller} called a meeting.`
		text(panel, "MEETING", 26, nextOrder()).Font = Enum.Font.GothamBold
		text(panel, heading, 18, nextOrder())
		text(panel, "Where everyone was in the last minute:", 16, nextOrder()).TextColor3 = Color3.fromRGB(200, 190, 170)
		local tags = table.clone(info.living)
		if info.victim then
			table.insert(tags, info.victim)
		end
		for _, tag in tags do
			local suffix = if tag == info.victim then " (body)" else ""
			text(panel, `{tag}{suffix}: {describe(info.log[tag] or {})}`, 15, nextOrder(), 40)
		end
		local canVote = State.alive()
		text(panel, if canVote then "Vote (click, or press the number):" else "You are out and cannot vote.", 16, nextOrder())
			.TextColor3 = Color3.fromRGB(200, 190, 170)
		options = {}
		for _, tag in info.living do
			if tag ~= player:GetAttribute("Tag") then
				table.insert(options, tag)
			end
		end
		table.insert(options, "skip")
		for i, target in options do
			local b = Instance.new("TextButton")
			b.Size = UDim2.new(1, 0, 0, 36)
			b.LayoutOrder = nextOrder()
			b.BackgroundColor3 = Color3.fromRGB(46, 40, 50)
			b.TextColor3 = Color3.new(1, 1, 1)
			b.TextSize = 17
			b.Font = Enum.Font.GothamMedium
			b.Text = `{if i <= #KEYS then i .. ". " else ""}{if target == "skip" then "Skip vote" else target}`
			b.AutoButtonColor = canVote
			b.Parent = panel
			if canVote then
				b.Activated:Connect(function()
					vote(target)
				end)
				if i <= #KEYS then
					ContextActionService:BindAction("Vote" .. i, function(_, state)
						if state == Enum.UserInputState.Begin then
							vote(target)
						end
						return Enum.ContextActionResult.Sink
					end, false, KEYS[i])
				end
			end
		end
		resultLabel = text(panel, "", 18, nextOrder(), 48)
	end);

	(remotes:WaitForChild("MeetingResult") :: RemoteEvent).OnClientEvent:Connect(function(ejected, wasEntity, counts)
		local lines = {}
		if ejected then
			table.insert(lines, `{ejected} was ejected. {if wasEntity then "They were the entity!" else "They were not the entity."}`)
		else
			table.insert(lines, "Nobody was ejected.")
		end
		local tally = {}
		for target, n in counts or {} do
			table.insert(tally, `{if target == "skip" then "skip" else target}: {n}`)
		end
		table.sort(tally)
		if #tally > 0 then
			table.insert(lines, "Votes: " .. table.concat(tally, ", "))
		end
		if resultLabel then
			resultLabel.Text = table.concat(lines, "\n")
			resultLabel.TextColor3 = Color3.fromRGB(255, 226, 170)
		end
		for i = 1, #KEYS do
			ContextActionService:UnbindAction("Vote" .. i)
		end
	end)

	-- Hide the panel when the meeting is over; send chat to the right channel.
	local function refresh()
		if State.phase() ~= "meeting" and panel.Visible then
			panel.Visible = false
			clear()
		end
		local config = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
		local channels = TextChatService:FindFirstChild("TextChannels")
		if config and channels then
			local out = channels:FindFirstChild("Out")
			local useOut = State.mode() == "deduction" and State.mine() == "out" and out ~= nil
			config.TargetTextChannel = (if useOut then out else channels:FindFirstChild("RBXGeneral")) :: TextChannel?
		end
	end
	State.changed:Connect(refresh)

	-- In Social Deduction chat shows the speaker's tag instead of their Roblox name, to match the vote list.
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local source = message.TextSource
		local sender = source and Players:GetPlayerByUserId(source.UserId)
		local tag = sender and sender:GetAttribute("Tag")
		if tag then
			local props = Instance.new("TextChatMessageProperties")
			props.PrefixText = `{tag}:`
			return props
		end
		return nil
	end
end

return MeetingUi
