-- The phone (phone_viewmodel.gd, phone_map.gd). The phone key (Q) brings it up to your face, the hands key (R)
-- switches between one hand and two hands, Q again (or Back on the home screen) puts it away.
--   While it is up the mouse cursor is free: click the screen of the phone in your hand (one hand) or the big screen
--   (two hands). The arrow keys, Space and Backspace work too. W A S D still walk, but looking at a phone while
--   walking makes you dizzy (the view sways and blurs) and, kept up too long, you trip and fall.
-- Home screen apps: e-Kretén (grades, timetable, absences, the class), Neugram (the school's photo feed), NeuMap
-- (the floor plan, and Route: a dotted trail to a room, Route.luau) and Notes (tasks and clues). One UI tree moves
-- between a SurfaceGui on the phone and a ScreenGui.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local FloorData = require(ReplicatedStorage.Shared.FloorData)
local Rooms = require(ReplicatedStorage.Shared.Rooms)
local State = require(script.Parent.State)
local Route = require(script.Parent.Route)
local StoryUi = require(script.Parent.StoryUi)
local Viewmodel = require(script.Parent.Viewmodel)
local MouseLock = require(script.Parent.MouseLock)
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Phone = {}

local W, H = 300, 600 -- logical screen size
local BG = Color3.fromRGB(12, 14, 20)
local DIZZY_RATE = 0.12 -- per second of walking with the phone up (at walking speed)
local DIZZY_RECOVER = 0.25 -- per second with the phone down or standing still
local TILE = Color3.fromRGB(32, 38, 54)
local HIGHLIGHT = Color3.fromRGB(255, 216, 90)
local TYPE_FILL = {
	normal = Color3.fromRGB(26, 41, 82), computer = Color3.fromRGB(20, 61, 66), wc = Color3.fromRGB(41, 48, 64),
	gym = Color3.fromRGB(92, 51, 20), entrance = Color3.fromRGB(87, 77, 20), other = Color3.fromRGB(23, 23, 26),
	changing = Color3.fromRGB(100, 66, 34), lab = Color3.fromRGB(90, 60, 24), office = Color3.fromRGB(70, 46, 86),
	library = Color3.fromRGB(46, 70, 34), dining = Color3.fromRGB(86, 72, 46), kitchen = Color3.fromRGB(72, 72, 46),
	storage = Color3.fromRGB(46, 46, 50), medical = Color3.fromRGB(96, 46, 56), corridor = Color3.fromRGB(46, 46, 52),
}
local NAV = "PhoneNav"
local NAV_KEYS = {
	Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.Space,
	Enum.KeyCode.Backspace,
}

local function label(parent: Instance, text: string, size: number, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextSize = size
	l.Font = Enum.Font.GothamMedium
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.Text = text
	l.Parent = parent
	return l
end

function Phone.init(remotes: Folder)
	local story = nil :: any -- the latest CampaignState snapshot (story only)
	local mode = "down" -- "down" | "one" | "two"
	local page = "home"
	local focus = 1 -- highlighted tile or row on the page
	local floor = 0
	local focusables: { GuiObject } = {}
	local scroller: ScrollingFrame? = nil

	-- The screen: one tree, moved between the phone's SurfaceGui and a full-screen ScreenGui.
	local root = Instance.new("Frame")
	root.Name = "PhoneScreen"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = BG
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.Size = UDim2.fromOffset(W, H)
	local scale = Instance.new("UIScale")
	scale.Parent = root
	root.BackgroundColor3 = Color3.new(1, 1, 1) -- the gradient below gives the colour
	local wallpaper = Instance.new("UIGradient")
	wallpaper.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 34, 70)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(46, 24, 64)), ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 12, 22)) })
	wallpaper.Rotation = 70
	wallpaper.Parent = root
	MouseLock.track(root) -- the cursor is free while the phone is up (either hand)

	local surface = Instance.new("SurfaceGui")
	surface.Name = "PhoneSurface"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surface.CanvasSize = Vector2.new(W, H)
	surface.LightInfluence = 0
	surface.Brightness = 1.5
	surface.AlwaysOnTop = false
	surface.ResetOnSpawn = false
	surface.Enabled = false
	surface.Adornee = Viewmodel.phonePart()
	surface.Parent = player:WaitForChild("PlayerGui")

	local screenGui = StoryUi.gui("PhoneFull", 6)
	screenGui.Enabled = false
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(0.5, 0.94)
	holder.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
	holder.Parent = screenGui
	StoryUi.corner(holder)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = W / H
	aspect.Parent = holder
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.Position = UDim2.fromOffset(8, 8)
	inner.Size = UDim2.new(1, -16, 1, -16)
	inner.BackgroundTransparency = 1
	inner.ClipsDescendants = true
	inner.Parent = holder
	StoryUi.freeMouseWhile(screenGui, holder)

	-- Status bar and content.
	local status = label(root, "", 14, Color3.fromRGB(200, 200, 210))
	status.Size = UDim2.new(1, -16, 0, 22)
	status.Position = UDim2.fromOffset(8, 4)
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Position = UDim2.fromOffset(0, 28)
	content.Size = UDim2.new(1, 0, 1, -28)
	content.BackgroundTransparency = 1
	content.Parent = root

	local render: () -> ()

	local function apps(): { { id: string, name: string } }
		return { { id = "ekreten", name = "e-Kretén" }, { id = "neugram", name = "Neugram" },
			{ id = "map", name = "NeuMap" }, { id = "notes", name = "Notes" } }
	end

	-- App icons, drawn (no uploaded images): a rounded square with a gradient and a simple glyph.
	local function glyphBox(parent: Instance, pos: UDim2, size: UDim2, color: Color3, round: number?): Frame
		local f = Instance.new("Frame")
		f.Position = pos
		f.Size = size
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.Parent = parent
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, round or 2)
		c.Parent = f
		return f
	end
	local function drawIcon(icon: Frame, id: string)
		local grad = Instance.new("UIGradient")
		grad.Rotation = 45
		grad.Parent = icon
		local white = Color3.new(1, 1, 1)
		if id == "ekreten" then
			grad.Color = ColorSequence.new(Color3.fromRGB(40, 110, 220), Color3.fromRGB(20, 60, 150))
			local t = label(icon, "eK", 26, white)
			t.Size = UDim2.fromScale(1, 0.75)
			t.Font = Enum.Font.GothamBlack
			t.TextXAlignment = Enum.TextXAlignment.Center
			glyphBox(icon, UDim2.fromScale(0.22, 0.72), UDim2.fromScale(0.56, 0.06), white) -- a grade line
		elseif id == "neugram" then
			grad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(250, 200, 80)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(230, 60, 110)), ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 60, 200)) })
			local frame = glyphBox(icon, UDim2.fromScale(0.2, 0.2), UDim2.fromScale(0.6, 0.6), white, 12)
			frame.BackgroundTransparency = 1
			local s = Instance.new("UIStroke")
			s.Color = white
			s.Thickness = 3
			s.Parent = frame
			local lens = glyphBox(icon, UDim2.fromScale(0.36, 0.36), UDim2.fromScale(0.28, 0.28), white, 99)
			lens.BackgroundTransparency = 1
			local s2 = s:Clone()
			s2.Parent = lens
			glyphBox(icon, UDim2.fromScale(0.66, 0.27), UDim2.fromScale(0.07, 0.07), white, 99)
		elseif id == "map" then
			grad.Color = ColorSequence.new(Color3.fromRGB(60, 190, 110), Color3.fromRGB(20, 110, 80))
			glyphBox(icon, UDim2.fromScale(0.3, 0.18), UDim2.fromScale(0.4, 0.4), Color3.fromRGB(240, 70, 60), 99)
			glyphBox(icon, UDim2.fromScale(0.42, 0.3), UDim2.fromScale(0.16, 0.16), white, 99)
			local tip = glyphBox(icon, UDim2.fromScale(0.42, 0.5), UDim2.fromScale(0.16, 0.18), Color3.fromRGB(240, 70, 60))
			tip.Rotation = 45
			glyphBox(icon, UDim2.fromScale(0.15, 0.78), UDim2.fromScale(0.7, 0.05), white)
		else -- notes
			grad.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90), Color3.fromRGB(240, 170, 40))
			for k = 0, 3 do
				glyphBox(icon, UDim2.fromScale(0.2, 0.25 + k * 0.15), UDim2.fromScale(if k == 3 then 0.4 else 0.6, 0.05),
					Color3.fromRGB(110, 80, 20))
			end
		end
	end
	local function appIcon(parent: Instance, app: { id: string, name: string }, i: number, onOpen: () -> ())
		local b = Instance.new("TextButton")
		b.BackgroundTransparency = 1
		b.Text = ""
		b.LayoutOrder = i
		b.Parent = parent
		local icon = Instance.new("Frame")
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.fromScale(0.5, 0)
		icon.Size = UDim2.fromOffset(70, 70)
		icon.BackgroundColor3 = Color3.new(1, 1, 1)
		icon.Parent = b
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 18)
		c.Parent = icon
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Thickness = 3
		stroke.Color = HIGHLIGHT
		stroke.Enabled = false
		stroke.Parent = icon
		drawIcon(icon, app.id)
		local name = label(b, app.name, 13, Color3.new(1, 1, 1))
		name.Position = UDim2.fromOffset(0, 74)
		name.Size = UDim2.new(1, 0, 0, 18)
		name.TextXAlignment = Enum.TextXAlignment.Center
		b.MouseEnter:Connect(function()
			TweenService:Create(icon, TweenInfo.new(0.1), { Size = UDim2.fromOffset(76, 76) }):Play()
		end)
		b.MouseLeave:Connect(function()
			TweenService:Create(icon, TweenInfo.new(0.1), { Size = UDim2.fromOffset(70, 70) }):Play()
		end)
		b.Activated:Connect(onOpen)
		table.insert(focusables, b)
	end

	local function openPage(id: string)
		page = id
		focus = 1
		render()
	end

	local function back()
		if page == "home" then
			Phone.setMode("down")
		else
			openPage("home")
		end
	end

	local function tile(parent: Instance, text: string, i: number, onOpen: () -> ())
		local b = Instance.new("TextButton")
		b.BackgroundColor3 = TILE
		b.TextColor3 = Color3.new(1, 1, 1)
		b.TextSize = 18
		b.Font = Enum.Font.GothamBold
		b.Text = text
		b.AutoButtonColor = true
		b.LayoutOrder = i
		StoryUi.corner(b)
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Thickness = 3
		stroke.Color = HIGHLIGHT
		stroke.Enabled = false
		stroke.Parent = b
		b.Activated:Connect(onOpen)
		b.Parent = parent
		table.insert(focusables, b)
		b:SetAttribute("Open", true)
		return b
	end

	local function listPage(title: string, lines: { string })
		label(content, title, 20, StoryUi.GOLD).Size = UDim2.new(1, -16, 0, 26)
		local scroll = Instance.new("ScrollingFrame")
		scroll.Position = UDim2.fromOffset(8, 30)
		scroll.Size = UDim2.new(1, -16, 1, -64)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 4
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.new()
		scroll.Parent = content
		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 6)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = scroll
		for i, line in lines do
			local l = label(scroll, line, 15)
			l.Size = UDim2.new(1, -6, 0, 0)
			l.AutomaticSize = Enum.AutomaticSize.Y
			l.LayoutOrder = i
		end
		scroller = scroll
	end

	local function mapPage()
		local data = FloorData.FLOORS[floor + 1]
		label(content, `Map: {FloorData.FLOOR_NAMES[floor + 1]}  < >`, 18, StoryUi.GOLD).Size = UDim2.new(1, -16, 0, 24)
		local area = Instance.new("Frame")
		area.Position = UDim2.fromOffset(8, 30)
		area.Size = UDim2.new(1, -16, 1, -70)
		area.BackgroundTransparency = 1
		area.Parent = content
		-- Bounds of every room on this floor (world metres).
		local rects = {}
		local x0, z0, x1, z1 = math.huge, math.huge, -math.huge, -math.huge
		for _, r in data.rooms do
			local ax, az = FloorData.toWorld(floor, r.x0, r.y0)
			local bx, bz = FloorData.toWorld(floor, r.x1, r.y1)
			local rect = { label = r.label, kind = r.kind, x0 = math.min(ax, bx), z0 = math.min(az, bz), x1 = math.max(ax, bx),
				z1 = math.max(az, bz) }
			table.insert(rects, rect)
			x0, z0 = math.min(x0, rect.x0), math.min(z0, rect.z0)
			x1, z1 = math.max(x1, rect.x1), math.max(z1, rect.z1)
		end
		-- The plan runs along the phone's height: world x -> screen y, world z -> screen x.
		local function place(frame: GuiObject, rx0: number, rz0: number, rx1: number, rz1: number)
			frame.Position = UDim2.fromScale((rz0 - z0) / (z1 - z0), (rx0 - x0) / (x1 - x0))
			frame.Size = UDim2.fromScale((rz1 - rz0) / (z1 - z0), (rx1 - rx0) / (x1 - x0))
		end
		for _, rect in rects do
			local f = Instance.new("Frame")
			f.BackgroundColor3 = TYPE_FILL[rect.kind] or TYPE_FILL.other
			f.BorderSizePixel = 1
			f.BorderColor3 = Color3.fromRGB(90, 90, 100)
			local t = Route.target()
			if t and t.floor == floor and t.label == rect.label then
				local ring = Instance.new("UIStroke")
				ring.Color = HIGHLIGHT
				ring.Thickness = 2
				ring.Parent = f
			end
			place(f, rect.x0, rect.z0, rect.x1, rect.z1)
			f.Parent = area
			if rect.label ~= "" and (rect.x1 - rect.x0) * (rect.z1 - rect.z0) > 30 then
				local t = label(f, rect.label, 9)
				t.Size = UDim2.fromScale(1, 1)
				t.TextXAlignment = Enum.TextXAlignment.Center
				t.TextYAlignment = Enum.TextYAlignment.Center
			end
		end
		-- Your marker: outside the story, and on Easy in the story.
		local showMe = not story or story.difficulty == "Easy"
		local character = player.Character
		local me = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if showMe and me then
			local m = me.Position / Config.STUDS_PER_METRE
			if FloorData.floorAt(m.Y) == floor then
				local dot = Instance.new("Frame")
				dot.AnchorPoint = Vector2.new(0.5, 0.5)
				dot.Size = UDim2.fromOffset(9, 9)
				dot.BackgroundColor3 = Color3.fromRGB(255, 80, 70)
				dot.Position = UDim2.fromScale((m.Z - z0) / (z1 - z0), (m.X - x0) / (x1 - x0))
				dot.Parent = area
				StoryUi.corner(dot)
			end
		end
	end

	-- The rooms you can be led to on a floor: open rooms with a name, each name once (WCs lead to the nearest).
	local ROW = 30
	local function routeRooms(f: number): { string }
		local seen, list = {}, {}
		for _, r in FloorData.FLOORS[f + 1].rooms do
			if r.label ~= "" and Rooms.isOpen(r.label) and not seen[r.label] then
				seen[r.label] = true
				table.insert(list, r.label)
			end
		end
		table.sort(list, function(a, b)
			local na, nb = tonumber(string.match(a, "%d+")), tonumber(string.match(b, "%d+"))
			if (na ~= nil) ~= (nb ~= nil) then
				return na == nil -- names (Aula, Porta, WC) first
			end
			if na and nb and na ~= nb then
				return na < nb
			end
			return a < b
		end)
		return list
	end

	-- Route page entries: "Stop" while a route is set, then the rooms of the shown floor.
	local function routeEntries(): { { text: string, run: () -> () } }
		local out = {}
		local t = Route.target()
		if t then
			table.insert(out, { text = `Stop the route to {t.label}`, run = function()
				Route.stop()
				render()
			end })
		end
		for _, labelText in routeRooms(floor) do
			local real = Rooms.realName(labelText)
			local word = if real ~= labelText then "  " .. real
				else (({ computer = "  (PCs)", gym = "  (gym)" } :: { [string]: string })[Rooms.typeOf(labelText)] or "")
			table.insert(out, { text = labelText .. word, run = function()
				Route.set(floor, labelText)
				Phone.setMode("down") -- put the phone away and follow the dots
			end })
		end
		return out
	end

	local function routePage()
		label(content, `Route: {FloorData.FLOOR_NAMES[floor + 1]}  < >`, 18, StoryUi.GOLD).Size = UDim2.new(1, -16, 0, 24)
		local scroll = Instance.new("ScrollingFrame")
		scroll.Position = UDim2.fromOffset(8, 30)
		scroll.Size = UDim2.new(1, -16, 1, -64)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 4
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.new()
		scroll.Parent = content
		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 4)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = scroll
		for i, entry in routeEntries() do
			local b = Instance.new("TextButton")
			b.Size = UDim2.new(1, -6, 0, ROW)
			b.LayoutOrder = i
			b.BackgroundColor3 = if i == 1 and Route.target() then Color3.fromRGB(70, 40, 36) else TILE
			b.TextColor3 = Color3.new(1, 1, 1)
			b.TextSize = 15
			b.Font = Enum.Font.GothamMedium
			b.TextXAlignment = Enum.TextXAlignment.Left
			b.Text = "  " .. entry.text
			StoryUi.corner(b)
			local stroke = Instance.new("UIStroke")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Thickness = 2
			stroke.Color = HIGHLIGHT
			stroke.Enabled = false
			stroke.Parent = b
			b.Activated:Connect(entry.run)
			b.Parent = scroll
			table.insert(focusables, b)
		end
		-- Keep the highlighted row in view.
		scroll.CanvasPosition = Vector2.new(0, math.max(0, (focus - 1) * (ROW + 4) - (H - 120) / 2))
	end

	render = function()
		for _, c in content:GetChildren() do
			c:Destroy()
		end
		focusables = {}
		scroller = nil
		if page == "home" then
			-- The clock widget, then the app icons (two by two).
			local clock = label(content, if story then story.clock else os.date("%H:%M") :: string, 54,
				Color3.new(1, 1, 1))
			clock.Font = Enum.Font.GothamBold
			clock.Position = UDim2.fromOffset(0, 24)
			clock.Size = UDim2.new(1, 0, 0, 60)
			clock.TextXAlignment = Enum.TextXAlignment.Center
			local day = label(content, if story then "Neumann Survival Week" else "Neumann János Technikum", 13,
				Color3.fromRGB(210, 210, 230))
			day.Position = UDim2.fromOffset(0, 86)
			day.Size = UDim2.new(1, 0, 0, 18)
			day.TextXAlignment = Enum.TextXAlignment.Center
			local grid = Instance.new("Frame")
			grid.Position = UDim2.fromOffset(30, 150)
			grid.Size = UDim2.new(1, -60, 1, -210)
			grid.BackgroundTransparency = 1
			grid.Parent = content
			local layout = Instance.new("UIGridLayout")
			layout.CellSize = UDim2.fromOffset(100, 104)
			layout.CellPadding = UDim2.fromOffset(40, 24)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Parent = grid
			for i, app in apps() do
				appIcon(grid, app, i, function()
					openPage(app.id)
				end)
			end
		elseif page == "map" then
			mapPage()
			local toRoute = Instance.new("TextButton")
			toRoute.AnchorPoint = Vector2.new(1, 1)
			toRoute.Position = UDim2.new(1, -8, 1, -6)
			toRoute.Size = UDim2.fromOffset(80, 26)
			toRoute.BackgroundColor3 = Color3.fromRGB(40, 120, 80)
			toRoute.TextColor3 = Color3.new(1, 1, 1)
			toRoute.TextSize = 14
			toRoute.Font = Enum.Font.GothamBold
			toRoute.Text = "Route"
			StoryUi.corner(toRoute)
			toRoute.Activated:Connect(function()
				openPage("route")
			end)
			toRoute.Parent = content
		elseif page == "ekreten" then
			local lines = {}
			if story then
				local right, total = story.quiz.right, story.quiz.total
				local grade = if total == 0 then "-" else tostring(math.clamp(math.round(1 + 4 * right / total), 1, 5))
				table.insert(lines, `Grade average so far: {grade}  ({right}/{total} right)`)
				local skips = if story.skipLimit > 0 then `{story.skips}/{story.skipLimit}` else `{story.skips}`
				table.insert(lines, `Absences (skipped lessons): {skips}`)
				table.insert(lines, "")
				table.insert(lines, "TIMETABLE")
				for _, l in story.timetable do
					table.insert(lines, `{if l.done then "[x]" else "[ ]"} {l.time}  {l.subject}, room {l.room}, {l.teacher}`)
				end
				table.insert(lines, "")
			else
				table.insert(lines, "No lessons today. The story day fills in your grades and timetable.")
				table.insert(lines, "")
			end
			table.insert(lines, "CLASS")
			for _, p in Players:GetPlayers() do
				table.insert(lines, `{p.DisplayName}: {p:GetAttribute("State") or "lobby"}`)
			end
			listPage("e-Kretén", lines)
		elseif page == "neugram" then
			local posts = {
				"@neu.diakonkormanyzat  Ping pong in the Aula after the last lesson! Bring your own paddle.",
				"@csoki.official  *sniff sniff* who has biscuits",
				"@gt_rooms  Reminder: no food near the PCs. Yes, that means you, GT2.",
				"@buffet_neumann  Fresh pogácsa until it runs out.",
				"@neu.sport  Basketball hoop in the gym is back up. Score 5 and earn eternal glory.",
				"@anonymous_student  Did anyone else hear knocking from Lab 14 last night??",
				"@porta  Keys go back on the hook. I remember who has which. Mostly.",
			}
			if story then
				for _, c in story.clues do
					table.insert(posts, 1, `@whisper_neumann  saw this today: "{c}"`)
				end
			end
			listPage("Neugram", posts)
		elseif page == "notes" then
			local lines = {}
			if story then
				table.insert(lines, "TO DO")
				table.insert(lines, story.objective)
				if story.altar then
					local a = story.altar
					table.insert(lines, `Altar: salt {if a.salt then "yes" else "no"}, holy water `
						.. `{if a.vial then "yes" else "no"}, bell {if a.bell then "yes" else "no"}`)
				end
				table.insert(lines, "")
				table.insert(lines, `CLUES ({#story.clues})`)
				for _, c in story.clues do
					table.insert(lines, "- " .. c)
				end
				if #story.clues == 0 then
					table.insert(lines, "None yet. They lie on small tables in empty rooms.")
				end
			else
				table.insert(lines, "- Find Csoki and give him a biscuit (Büfé, kitchen)")
				table.insert(lines, "- Beat the computer at ping pong in the Aula")
				table.insert(lines, "- Score 5 baskets in the gym")
				table.insert(lines, "- Walk into 30 different rooms")
			end
			listPage("Notes", lines)
		elseif page == "route" then
			routePage()
		elseif page == "tasks" and story then
			local lines = { story.objective }
			local skips = if story.skipLimit > 0 then `{story.skips}/{story.skipLimit}` else `{story.skips}`
			table.insert(lines, `Your skips: {skips}`)
			table.insert(lines, `Team quiz: {story.quiz.right}/{story.quiz.total}`)
			table.insert(lines, `Clues: {#story.clues}`)
			if story.altar then
				local a = story.altar
				table.insert(lines, `Altar: salt {if a.salt then "yes" else "no"}, holy water `
					.. `{if a.vial then "yes" else "no"}, bell {if a.bell then "yes" else "no"}`)
			end
			listPage(`Tasks  {story.clock}`, lines)
		elseif page == "timetable" and story then
			local lines = {}
			for _, l in story.timetable do
				table.insert(lines, `{if l.done then "[x]" else "[ ]"} {l.time}  {l.subject}, room {l.room}\n    {l.teacher}`)
			end
			listPage("Timetable", lines)
		elseif page == "clues" and story then
			local lines = {}
			for _, c in story.clues do
				table.insert(lines, "- " .. c)
			end
			if #lines == 0 then
				lines = { "No clues yet. They lie on small tables in empty rooms." }
			end
			listPage(`Clues ({#story.clues})`, lines)
		elseif page == "team" then
			local lines = {}
			for _, p in Players:GetPlayers() do
				local s = p:GetAttribute("State") or "lobby"
				table.insert(lines, `{p.DisplayName}: {s}`)
			end
			listPage("Team", lines)
		else
			page = "home"
			render()
			return
		end
		-- The back bar.
		local backButton = Instance.new("TextButton")
		backButton.AnchorPoint = Vector2.new(0.5, 1)
		backButton.Position = UDim2.new(0.5, 0, 1, -6)
		backButton.Size = UDim2.fromOffset(120, 26)
		backButton.BackgroundColor3 = TILE
		backButton.TextColor3 = Color3.new(1, 1, 1)
		backButton.TextSize = 14
		backButton.Font = Enum.Font.GothamMedium
		backButton.Text = if page == "home" then "Put away" else "Back"
		StoryUi.corner(backButton)
		backButton.Activated:Connect(back)
		backButton.Parent = content
		focus = math.clamp(focus, 1, math.max(1, #focusables))
		for i, f in focusables do
			local stroke = f:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Enabled = (i == focus) and mode == "one"
			end
		end
	end

	local function refreshStatus()
		local battery = math.floor(player:GetAttribute("Battery") or 0)
		local clock = if story then story.clock else os.date("%H:%M")
		status.Text = `{clock}        {battery}%{if player:GetAttribute("TorchOn") then "  light" else ""}`
	end

	-- Keys while the phone is up.
	local function onNav(_, inputState: Enum.UserInputState, input: InputObject)
		if inputState ~= Enum.UserInputState.Begin then
			-- Let releases through, so a key held when the phone came up does not stay "held" for walking.
			return Enum.ContextActionResult.Pass
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.Backspace then
			back()
		elseif (page == "map" or page == "route") and (key == Enum.KeyCode.Left or key == Enum.KeyCode.Right) then
			floor = (floor + (if key == Enum.KeyCode.Right then 1 else -1)) % #FloorData.FLOORS
			focus = 1
			render()
		elseif page == "route" then
			if key == Enum.KeyCode.Up or key == Enum.KeyCode.Down then
				focus = math.clamp(focus + (if key == Enum.KeyCode.Down then 1 else -1), 1, math.max(1, #focusables))
				render()
			elseif key == Enum.KeyCode.Space then
				local entry = routeEntries()[focus]
				if entry then
					entry.run()
				end
			end
		elseif scroller and (key == Enum.KeyCode.Up or key == Enum.KeyCode.Down) then
			local s = scroller :: ScrollingFrame
			s.CanvasPosition = Vector2.new(0, math.max(0, s.CanvasPosition.Y + (if key == Enum.KeyCode.Down then 60 else -60)))
		elseif page == "home" then
			local step = if key == Enum.KeyCode.Left then -1 elseif key == Enum.KeyCode.Right then 1
				elseif key == Enum.KeyCode.Up then -2 elseif key == Enum.KeyCode.Down then 2 else 0
			if step ~= 0 then
				focus = math.clamp(focus + step, 1, #focusables)
				render()
			elseif key == Enum.KeyCode.Space then
				local f = focusables[focus]
				local app = apps()[focus]
				if f and app then
					openPage(app.id)
				end
			end
		end
		return Enum.ContextActionResult.Sink
	end

	function Phone.setMode(newMode: string)
		if newMode == mode then
			return
		end
		mode = newMode
		Viewmodel.setPhone(newMode)
		if mode == "down" then
			ContextActionService:UnbindAction(NAV)
			surface.Enabled = false
			screenGui.Enabled = false
			return
		end
		ContextActionService:BindActionAtPriority(NAV, onNav, false, Enum.ContextActionPriority.High.Value,
			table.unpack(NAV_KEYS))
		if mode == "one" then
			root.Parent = surface
			root.Size = UDim2.fromOffset(W, H)
			scale.Scale = 1
			surface.Enabled = true
			screenGui.Enabled = false
		else
			root.Parent = inner
			screenGui.Enabled = true
			surface.Enabled = false
			task.defer(function()
				-- Fit the width; the screen is as tall as the frame (no empty strip at the bottom).
				local s = if inner.AbsoluteSize.X > 0 then inner.AbsoluteSize.X / W else 1
				scale.Scale = s
				root.Size = UDim2.fromOffset(W, math.max(H, inner.AbsoluteSize.Y / s))
			end)
		end
		refreshStatus()
		render()
	end

	local function usable(): boolean
		local s = State.mine()
		return (s == "alive" or s == "lobby") and not player:GetAttribute("Hidden")
			and player:GetAttribute("TorchAllowed") ~= false
	end

	local ClientSettings = require(script.Parent.ClientSettings)
	ClientSettings.bind("Phone", "phone", function(_, inputState, input)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Sink
		end
		if not usable() then
			return Enum.ContextActionResult.Pass
		end
		if input.UserInputType == Enum.UserInputType.Touch then
			Phone.setMode(if mode == "down" then "two" else "down")
		else
			Phone.setMode(if mode == "down" then "one" else "down")
		end
		return Enum.ContextActionResult.Sink
	end, true, { Enum.KeyCode.DPadUp })
	ContextActionService:SetTitle("Phone", "Phone")
	ContextActionService:SetPosition("Phone", UDim2.new(1, -110, 1, -150))
	ClientSettings.bind("PhoneHands", "phoneHands", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and mode ~= "down" then
			Phone.setMode(if mode == "one" then "two" else "one")
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false);

	(remotes:WaitForChild("CampaignState") :: RemoteEvent).OnClientEvent:Connect(function(state)
		story = state
		if mode ~= "down" and page ~= "map" and page ~= "home" then
			render()
		elseif mode ~= "down" and page == "home" then
			render()
		end
	end)

	-- Dizziness: walking with the phone up. The view sways and blurs; at the top you trip and fall.
	local dizzy = 0
	local warned = false
	local fallen = false
	local blur = Instance.new("BlurEffect")
	blur.Name = "DizzyBlur"
	blur.Size = 0
	blur.Parent = Lighting
	local function fall()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local body = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoid or not body or fallen then
			return
		end
		fallen = true
		Phone.setMode("down")
		StoryUi.toast("You trip over your own feet while staring at the phone.")
		humanoid.PlatformStand = true
		body.AssemblyLinearVelocity = body.CFrame.LookVector * 12 + Vector3.new(0, 6, 0)
		body.AssemblyAngularVelocity = body.CFrame.RightVector * -6
		task.delay(2.2, function()
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			fallen = false
		end)
		dizzy = 0.3
		warned = false
	end

	-- Put it away when you can no longer use it; keep the status bar and the map marker fresh.
	local nextTick = 0
	RunService.Heartbeat:Connect(function(dt)
		if mode ~= "down" and not usable() then
			Phone.setMode("down")
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local moving = humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.1 and humanoid.FloorMaterial ~= Enum.Material.Air
		if mode ~= "down" and moving then
			dizzy += dt * DIZZY_RATE * math.max(1, (humanoid :: Humanoid).WalkSpeed / Config.studs(Config.Player.walk))
		else
			dizzy = math.max(0, dizzy - dt * DIZZY_RECOVER)
		end
		if dizzy > 0.6 and not warned then
			warned = true
			StoryUi.toast("You feel dizzy. Stop walking or put the phone away.")
		elseif dizzy < 0.3 then
			warned = false
		end
		if dizzy >= 1 then
			fall()
		end
		player:SetAttribute("Dizzy", dizzy)
		blur.Size = math.clamp((dizzy - 0.35) * 18, 0, 12)
		local now = os.clock()
		if mode ~= "down" and now >= nextTick then
			nextTick = now + 1
			refreshStatus()
			if page == "map" then
				render()
			end
		end
	end)
end

return Phone
