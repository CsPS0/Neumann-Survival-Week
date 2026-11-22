-- Hand, pockets and bag on screen (story only), in the style of current horror games (DOORS, Lethal Company):
--   * a small bar of square slots at the bottom: your hand [1] and two pockets [2] [3], each with a 3D icon,
--     and the bag's fill and weight beside them. 2 or 3 swaps that pocket's item into your hand. The item's name
--     fades in above the bar when it changes, and the bar dims when nothing has happened for a while.
--   * Tab (or opening a dropped bag): the screen dims and blurs, the bag's slots and yours sit in the middle and a
--     details card on the right shows the item under the mouse (icon, name, weight, what it is) with Read, Use and
--     Drop. Click an item, then click where it goes.
-- B drops your bag, U uses a power bank. The server checks every move (src/server/Campaign/Inventories.luau).
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Inventory = require(ReplicatedStorage.Shared.Inventory)
local ItemLooks = require(script.Parent.ItemLooks)
local StoryUi = require(script.Parent.StoryUi)

local player = Players.LocalPlayer
local BagUi = {}

local HOT = 64 -- hotbar slot (pixels)
local BIG = 76 -- slot in the open bag
local GOLD = Color3.fromRGB(255, 216, 120)
local LINE = Color3.fromRGB(70, 66, 74)
local CARD = Color3.fromRGB(16, 15, 18)
local IDLE = 5 -- seconds until the bar dims

BagUi.inv = nil :: Inventory.Inv? -- the latest inventory (Viewmodel reads the hand item)
local changed = Instance.new("BindableEvent")
BagUi.changed = changed.Event

local function short(item: Inventory.Item?): string
	if not item then
		return ""
	end
	local name = Inventory.nameOf(item.id)
	if item.id == "papers" and item.texts then
		return `{name} ({#item.texts})`
	end
	return name
end

local function label(parent: Instance, text: string, size: number, color: Color3?, font: Enum.Font?): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextSize = size
	t.TextColor3 = color or StoryUi.TEXT
	t.Font = font or Enum.Font.GothamMedium
	t.Size = UDim2.new(1, 0, 0, size + 6)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextWrapped = true
	t.Parent = parent
	return t
end

-- A square slot: dark glass, a thin outline, an optional key number in the corner and the item's icon.
local function slot(parent: Instance, px: number, key: string?): (TextButton, UIStroke)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(px, px)
	b.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
	b.BackgroundTransparency = 0.35
	b.AutoButtonColor = false
	b.Text = ""
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.Color = LINE
	stroke.Thickness = 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
	if key then
		local k = Instance.new("TextLabel")
		k.Name = "Key"
		k.BackgroundTransparency = 1
		k.Position = UDim2.fromOffset(6, 3)
		k.Size = UDim2.fromOffset(16, 14)
		k.Text = key
		k.TextSize = 12
		k.Font = Enum.Font.GothamBold
		k.TextColor3 = StoryUi.MUTED
		k.TextXAlignment = Enum.TextXAlignment.Left
		k.ZIndex = 3
		k.Parent = b
	end
	b.Parent = parent
	return b, stroke
end

local function setIcon(b: GuiObject, id: string?, px: number)
	local old = b:FindFirstChild("Icon")
	if old and old:GetAttribute("Id") == (id or "") then
		return
	end
	if old then
		old:Destroy()
	end
	local icon = ItemLooks.icon(b, id, px)
	icon:SetAttribute("Id", id or "")
end

function BagUi.init(remotes: Folder)
	local action = remotes:WaitForChild("BagAction") :: RemoteEvent

	-- Hotbar ---------------------------------------------------------------------------------------------------
	local hotGui = StoryUi.gui("Hotbar", 2)
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -62) -- above the stamina and phone battery bars (Controls)
	bar.Size = UDim2.fromOffset(3 * (HOT + 8) + 96, HOT + 30)
	bar.BackgroundTransparency = 1
	bar.Visible = false
	bar.Parent = hotGui
	local nameTag = Instance.new("TextLabel")
	nameTag.BackgroundTransparency = 1
	nameTag.Size = UDim2.new(1, 0, 0, 20)
	nameTag.Text = ""
	nameTag.TextSize = 16
	nameTag.Font = Enum.Font.GothamMedium
	nameTag.TextColor3 = GOLD
	nameTag.TextStrokeTransparency = 0.6
	nameTag.TextTransparency = 1
	nameTag.Parent = bar
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(0, 26)
	row.Size = UDim2.new(1, 0, 0, HOT)
	row.Parent = bar
	local rowList = Instance.new("UIListLayout")
	rowList.FillDirection = Enum.FillDirection.Horizontal
	rowList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	rowList.Padding = UDim.new(0, 8)
	rowList.SortOrder = Enum.SortOrder.LayoutOrder
	rowList.Parent = row
	local HOT_SLOTS = { "hand", "pocketL", "pocketR" }
	local hot: { TextButton } = {}
	local hotStroke: { UIStroke } = {}
	for i = 1, 3 do
		local b, stroke = slot(row, HOT, tostring(i))
		b.LayoutOrder = i
		b.Active = false
		hot[i], hotStroke[i] = b, stroke
	end
	hotStroke[1].Color = GOLD -- the hand
	hotStroke[1].Thickness = 2
	-- The bag: how full and how much it slows you.
	local bagBox = Instance.new("Frame")
	bagBox.LayoutOrder = 4
	bagBox.Size = UDim2.fromOffset(80, HOT)
	bagBox.BackgroundTransparency = 1
	bagBox.Parent = row
	local bagText = label(bagBox, "", 13, StoryUi.MUTED)
	bagText.Position = UDim2.fromOffset(6, 8)
	local weight = Instance.new("Frame")
	weight.Position = UDim2.fromOffset(6, 40)
	weight.Size = UDim2.fromOffset(68, 5)
	weight.BackgroundColor3 = LINE
	weight.BorderSizePixel = 0
	weight.Parent = bagBox
	local weightFill = Instance.new("Frame")
	weightFill.Size = UDim2.fromScale(1, 1)
	weightFill.BackgroundColor3 = GOLD
	weightFill.BorderSizePixel = 0
	weightFill.Parent = weight

	local lastActive = os.clock()
	local dimmed = false
	local function setDim(dim: boolean)
		dimmed = dim
		local info = TweenInfo.new(if dim then 0.6 else 0.15)
		for _, b in hot do
			TweenService:Create(b, info, { BackgroundTransparency = if dim then 0.75 else 0.35 }):Play()
			local icon = b:FindFirstChild("Icon")
			if icon then
				TweenService:Create(icon, info, { ImageTransparency = if dim then 0.5 else 0 }):Play()
			end
		end
		TweenService:Create(bagText, info, { TextTransparency = if dim then 0.6 else 0 }):Play()
	end
	local function wake()
		lastActive = os.clock()
		if dimmed then
			setDim(false)
		end
	end
	task.spawn(function()
		while true do
			task.wait(0.5)
			if os.clock() - lastActive > IDLE and not dimmed then
				setDim(true)
			end
		end
	end)
	local nameToken = 0
	local function showName(text: string)
		nameToken += 1
		local token = nameToken
		nameTag.Text = text
		nameTag.TextTransparency = 0
		task.delay(1.8, function()
			if token == nameToken then
				TweenService:Create(nameTag, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			end
		end)
	end

	-- Open bag ---------------------------------------------------------------------------------------------------
	local gui = StoryUi.gui("Bag", 7)
	gui.IgnoreGuiInset = true
	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.35
	overlay.Visible = false
	overlay.Parent = gui
	StoryUi.freeMouseWhile(gui, overlay)
	local blur = Instance.new("BlurEffect")
	blur.Name = "BagBlur"
	blur.Size = 0
	blur.Enabled = false
	blur.Parent = Lighting

	local center = Instance.new("Frame")
	center.AnchorPoint = Vector2.new(0.5, 0.5)
	center.Position = UDim2.fromScale(0.42, 0.5)
	center.Size = UDim2.fromOffset(4 * (BIG + 10) + 10, 400)
	center.BackgroundTransparency = 1
	center.Parent = overlay
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0, 0.5)
	card.Position = UDim2.new(0.42, (4 * (BIG + 10)) / 2 + 30, 0.5, 0)
	card.Size = UDim2.fromOffset(300, 400)
	card.BackgroundColor3 = CARD
	card.BackgroundTransparency = 0.15
	card.Parent = overlay
	StoryUi.corner(card)
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = LINE
	cardStroke.Parent = card
	local cardPad = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(cardPad :: any)[side] = UDim.new(0, 14)
	end
	cardPad.Parent = card
	local cardList = Instance.new("UIListLayout")
	cardList.Padding = UDim.new(0, 8)
	cardList.SortOrder = Enum.SortOrder.LayoutOrder
	cardList.Parent = card

	local view = nil :: any -- {owner, ownerName, bag} while a dropped bag is open
	local mode = "none" -- "bag" | "carry" | "none"
	local selected = nil :: { slot: string, index: number? }?
	local hovered = nil :: { slot: string, index: number? }?
	local reading = false

	local function itemAt(slot: string, index: number?): Inventory.Item?
		if slot == "bag" then
			local list = if view then view.bag else (BagUi.inv and BagUi.inv.bag)
			return list and index and list[index] or nil
		end
		return BagUi.inv and (BagUi.inv :: any)[slot]
	end

	local render: () -> ()
	local renderCard: () -> ()

	local function click(slot: string, index: number?)
		if mode == "carry" and slot == "bag" then
			return -- the bag is on your back: drop it first
		end
		if selected then
			if selected.slot ~= slot or selected.index ~= index then
				action:FireServer("move", { from = selected.slot, fromIndex = selected.index, to = slot, toIndex = index })
			end
			selected = nil
		elseif itemAt(slot, index) then
			selected = { slot = slot, index = index }
		end
		reading = false
		render()
	end

	local function setOpen(open: boolean)
		overlay.Visible = open
		blur.Enabled = open
		TweenService:Create(blur, TweenInfo.new(0.2), { Size = if open then 14 else 0 }):Play()
	end

	local function close()
		if mode == "bag" then
			action:FireServer("close")
		end
		mode = "none"
		view = nil
		selected = nil
		hovered = nil
		reading = false
		setOpen(false)
	end

	local function button(parent: Instance, text: string, order: number, color: Color3?): TextButton
		local b = StoryUi.button(parent, text, order, color)
		b.Size = UDim2.new(1, 0, 0, 34)
		b.Parent = parent
		return b
	end

	renderCard = function()
		for _, c in card:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local at = selected or hovered
		local item = at and itemAt(at.slot, at.index)
		if not item then
			local hint = label(card, if mode == "carry"
				then "What you carry. Click an item, then click where it goes.\n\nThe bag is on your back: drop it (B) and open it to take things out."
				else "Click an item, then click where it goes.", 14, StoryUi.MUTED)
			hint.AutomaticSize = Enum.AutomaticSize.Y
			return
		end
		local iconBox = Instance.new("Frame")
		iconBox.Size = UDim2.new(1, 0, 0, 120)
		iconBox.BackgroundTransparency = 1
		iconBox.LayoutOrder = 1
		iconBox.Parent = card
		setIcon(iconBox, item.id, 120)
		local name = label(card, short(item), 20, GOLD, Enum.Font.GothamBold)
		name.LayoutOrder = 2
		local info = Inventory.ITEMS[item.id]
		local kg = if info then info.kg elseif Inventory.isSmall(item.id) then 0.05 else 0.5
		local meta = label(card, `{if Inventory.isSmall(item.id) then "Fits a pocket" else "Hand or bag only"}  ·  {kg} kg`,
			13, StoryUi.MUTED)
		meta.LayoutOrder = 3
		local about = label(card, ItemLooks.about(item.id), 14)
		about.LayoutOrder = 4
		about.AutomaticSize = Enum.AutomaticSize.Y
		if reading and item.texts then
			local paper = Instance.new("Frame")
			paper.LayoutOrder = 5
			paper.Size = UDim2.new(1, 0, 0, 0)
			paper.AutomaticSize = Enum.AutomaticSize.Y
			paper.BackgroundColor3 = Color3.fromRGB(236, 230, 210)
			paper.Parent = card
			StoryUi.corner(paper)
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
			pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
			pad.Parent = paper
			local text = label(paper, "- " .. table.concat(item.texts, "\n- "), 14, Color3.fromRGB(40, 36, 30),
				Enum.Font.Gotham)
			text.AutomaticSize = Enum.AutomaticSize.Y
		end
		if not selected then
			return
		end
		local from = selected
		if item.id == "papers" then
			button(card, if reading then "Hide" else "Read", 6).Activated:Connect(function()
				reading = not reading
				renderCard()
			end)
		end
		if item.id == "battery" and from.slot ~= "bag" then
			button(card, "Use: charge the phone", 7).Activated:Connect(function()
				action:FireServer("use")
				selected = nil
			end)
		end
		button(card, "Drop on the floor", 8, StoryUi.ACCENT).Activated:Connect(function()
			action:FireServer("floor", { slot = from.slot, index = from.index })
			selected = nil
		end)
	end

	local function bigSlot(parent: Instance, slotName: string, index: number?, caption: string, item: Inventory.Item?,
		order: number, dim: boolean)
		local holder = Instance.new("Frame")
		holder.LayoutOrder = order
		holder.Size = UDim2.fromOffset(BIG, BIG + 18)
		holder.BackgroundTransparency = 1
		holder.Parent = parent
		local b, stroke = slot(holder, BIG, nil)
		setIcon(b, item and item.id, BIG - 10)
		if dim then
			b.BackgroundTransparency = 0.7
			local icon = b:FindFirstChild("Icon") :: ViewportFrame?
			if icon then
				icon.ImageTransparency = 0.6
			end
		end
		if selected and selected.slot == slotName and selected.index == index then
			stroke.Color = GOLD
			stroke.Thickness = 2.5
		end
		local cap = label(holder, caption, 11, StoryUi.MUTED)
		cap.Position = UDim2.fromOffset(0, BIG + 2)
		cap.TextXAlignment = Enum.TextXAlignment.Center
		cap.TextTruncate = Enum.TextTruncate.AtEnd
		b.MouseEnter:Connect(function()
			hovered = { slot = slotName, index = index }
			if not selected then
				renderCard()
			end
		end)
		b.Activated:Connect(function()
			click(slotName, index)
		end)
	end

	local function grid(order: number, cells: number): Frame
		local f = Instance.new("Frame")
		f.LayoutOrder = order
		f.BackgroundTransparency = 1
		f.Size = UDim2.new(1, 0, 0, math.ceil(cells / 4) * (BIG + 28))
		f.Parent = center
		local g = Instance.new("UIGridLayout")
		g.CellSize = UDim2.fromOffset(BIG, BIG + 18)
		g.CellPadding = UDim2.fromOffset(10, 10)
		g.SortOrder = Enum.SortOrder.LayoutOrder
		g.Parent = f
		return f
	end

	render = function()
		for _, c in center:GetChildren() do
			c:Destroy()
		end
		if mode == "none" or not BagUi.inv then
			setOpen(false)
			return
		end
		local inv = BagUi.inv :: Inventory.Inv
		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 8)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = center
		local title = label(center, if mode == "bag" then `{string.upper(view.ownerName)}'S BAG` else "YOUR BAG", 18, GOLD,
			Enum.Font.GothamBold)
		title.LayoutOrder = 1
		local bagList = if mode == "bag" then view.bag else inv.bag
		local bagGrid = grid(2, Inventory.BAG_SLOTS)
		for i = 1, Inventory.BAG_SLOTS do
			local item = bagList[i]
			bigSlot(bagGrid, "bag", i, short(item), item, i, mode == "carry")
		end
		local you = label(center, "ON YOU", 14, GOLD, Enum.Font.GothamBold)
		you.LayoutOrder = 3
		local youGrid = grid(4, 3)
		for i, s in HOT_SLOTS do
			local item = (inv :: any)[s]
			bigSlot(youGrid, s, nil, ({ "Hand", "Left pocket", "Right pocket" })[i], item, i, false)
		end
		local closeHint = label(center, "Tab or Esc to close", 12, StoryUi.MUTED)
		closeHint.LayoutOrder = 5
		renderCard()
		setOpen(true)
	end

	local lastHand = ""
	local function renderHotbar()
		local inv = BagUi.inv
		bar.Visible = inv ~= nil and player:GetAttribute("State") == "alive"
		if not inv then
			return
		end
		for i, s in HOT_SLOTS do
			setIcon(hot[i], (inv :: any)[s] and (inv :: any)[s].id, HOT - 12)
		end
		bagText.Text = if inv.bagWorn then `Bag {#inv.bag}/{Inventory.BAG_SLOTS}` else "Bag dropped"
		local speed = Inventory.speed(inv)
		weightFill.Size = UDim2.fromScale(math.clamp((1 - speed) / 0.3, 0.02, 1), 1)
		weightFill.BackgroundColor3 = if speed < 0.8 then Color3.fromRGB(230, 120, 90) else GOLD
		local hand = short(inv.hand)
		if hand ~= lastHand then
			lastHand = hand
			if hand ~= "" then
				showName(hand)
			end
		end
		wake()
	end

	-- Keys -------------------------------------------------------------------------------------------------------
	local function toHand(pocket: string)
		local inv = BagUi.inv
		if inv and (inv :: any)[pocket] then
			action:FireServer("move", { from = pocket, to = "hand" })
		end
		wake()
	end
	local bound = false
	local function bindKeys()
		local inv = BagUi.inv
		local want = inv ~= nil and player:GetAttribute("State") == "alive"
		if want ~= bound then
			bound = want
			if want then
				ContextActionService:BindAction("CarryPanel", function(_, state)
					if state == Enum.UserInputState.Begin then
						if mode ~= "none" then
							close()
						else
							mode = "carry"
							render()
						end
					end
					return Enum.ContextActionResult.Sink
				end, true, require(script.Parent.ClientSettings).key("bag"))
				ContextActionService:SetTitle("CarryPanel", "Items")
				ContextActionService:SetPosition("CarryPanel", UDim2.new(1, -230, 1, -210))
				ContextActionService:BindAction("UseItem", function(_, state)
					if state == Enum.UserInputState.Begin then
						action:FireServer("use")
					end
					return Enum.ContextActionResult.Sink
				end, false, require(script.Parent.ClientSettings).key("useItem"))
				ContextActionService:BindAction("PocketToHand", function(_, state, input)
					if state == Enum.UserInputState.Begin and mode == "none" then
						toHand(if input.KeyCode == Enum.KeyCode.Two then "pocketL" else "pocketR")
					end
					return Enum.ContextActionResult.Pass
				end, false, Enum.KeyCode.Two, Enum.KeyCode.Three)
				ContextActionService:BindAction("CloseBag", function(_, state)
					if mode == "none" then
						return Enum.ContextActionResult.Pass
					end
					if state == Enum.UserInputState.Begin then
						close()
					end
					return Enum.ContextActionResult.Sink
				end, false, Enum.KeyCode.Escape)
				pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false)
			else
				ContextActionService:UnbindAction("CarryPanel")
				ContextActionService:UnbindAction("UseItem")
				ContextActionService:UnbindAction("PocketToHand")
				ContextActionService:UnbindAction("CloseBag")
				pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, true)
			end
		end
		-- B drops the bag only while it is on your back; at a dropped bag B is the "Put on" prompt.
		local dropKey = want and inv ~= nil and inv.bagWorn
		if dropKey then
			ContextActionService:BindAction("DropBag", function(_, state)
				if state == Enum.UserInputState.Begin then
					action:FireServer("drop")
				end
				return Enum.ContextActionResult.Sink
			end, true, require(script.Parent.ClientSettings).key("dropBag"))
			ContextActionService:SetTitle("DropBag", "Drop bag")
			ContextActionService:SetPosition("DropBag", UDim2.new(1, -110, 1, -270))
		else
			ContextActionService:UnbindAction("DropBag")
		end
	end

	(remotes:WaitForChild("Inventory") :: RemoteEvent).OnClientEvent:Connect(function(data)
		BagUi.inv = data and data.inv
		if not data then
			close()
		elseif mode ~= "none" then
			render()
		end
		renderHotbar()
		bindKeys()
		changed:Fire()
	end);
	(remotes:WaitForChild("BagView") :: RemoteEvent).OnClientEvent:Connect(function(data)
		if data and player:GetAttribute("State") ~= "alive" then
			action:FireServer("close")
			return
		end
		if data then
			view = data
			mode = "bag"
			if selected and selected.slot == "bag" and not itemAt("bag", selected.index) then
				selected = nil
			end
			render()
		elseif mode == "bag" then
			mode = "none"
			view = nil
			selected = nil
			setOpen(false)
		end
	end)
	player:GetAttributeChangedSignal("State"):Connect(function()
		if player:GetAttribute("State") ~= "alive" then
			close()
		end
		renderHotbar()
		bindKeys()
	end)
	-- New keys from the settings: bind again.
	require(script.Parent.ClientSettings).changed:Connect(function()
		if bound then
			bound = false
			for _, name in { "CarryPanel", "UseItem", "PocketToHand", "CloseBag", "DropBag" } do
				ContextActionService:UnbindAction(name)
			end
			bindKeys()
		end
	end)
end

return BagUi
