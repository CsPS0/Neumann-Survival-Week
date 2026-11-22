-- Hinged doors (HORROR-GAME/scripts/door.gd): a panel that swings 100 degrees around its hinge with E.
-- Closed demo rooms get a locked door that only shows "Not available in the demo.".
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Rooms = require(ReplicatedStorage.Shared.Rooms)

local OPEN_ANGLE = math.rad(100)
local SWING_TIME = 0.45
local THICKNESS = 0.18 -- studs (0.06 m)

local OPEN_COLOR = Color3.fromRGB(232, 230, 224) -- the white classroom doors of the photo
local BRASS = Color3.fromRGB(180, 140, 70)
local CLOSED_COLOR = Color3.fromRGB(70, 70, 76)

-- A creak for everyone near a door that opens (at most every 3 s per door, people walk through often).
local creakedAt: { [Model]: number } = {}
local function creak(door: Model, at: Vector3)
	local t = os.clock()
	if t - (creakedAt[door] or 0) < 3 then
		return
	end
	creakedAt[door] = t
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local sound = remotes and remotes:FindFirstChild("Sound")
	if sound then
		(sound :: RemoteEvent):FireAllClients("door", at)
	end
end

type DoorState = {
	panel: Part,
	hinge: CFrame,
	width: number,
	height: number,
	sign: number,
	angle: NumberValue,
	prompt: ProximityPrompt,
	open: boolean,
	locked: boolean,
	handles: { [Part]: CFrame },
	-- What E does on a locked story door (the red room's key), if anything.
	onLockedUse: ((Player) -> ())?,
}

local states: { [Model]: DoorState } = {}

local Doors = {}

local function place(state: DoorState)
	state.panel.CFrame = state.hinge
		* CFrame.Angles(0, state.angle.Value, 0)
		* CFrame.new(state.width * 0.5, state.height * 0.5, 0)
	for handle, offset in state.handles do
		handle.CFrame = state.panel.CFrame * offset
	end
end

-- `hinge` is in studs, at floor level, with the panel running along its local +X. `openSign` is +1 or -1.
function Doors.create(parent: Instance, hinge: CFrame, width: number, height: number, openSign: number, locked: boolean): Model
	local model = Instance.new("Model")
	model.Name = if locked then "ClosedDoor" else "Door"

	local panel = Instance.new("Part")
	panel.Name = "Panel"
	panel.Anchored = true
	panel.CanTouch = false
	panel.Size = Vector3.new(width, height, THICKNESS)
	panel.Material = if locked then Enum.Material.WoodPlanks else Enum.Material.SmoothPlastic
	panel.Color = if locked then CLOSED_COLOR else OPEN_COLOR
	panel.Parent = model
	model.PrimaryPart = panel
	-- A brass handle on both sides; place() moves them with the panel.
	local handles: { [Part]: CFrame } = {}
	for side = -1, 1, 2 do
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(0.4, 0.07, 0.07)
		handle.Material = Enum.Material.Metal
		handle.Color = BRASS
		handle.Anchored = true
		handle.CanCollide = false
		handle.CanQuery = false
		handle.CanTouch = false
		handle.CastShadow = false
		handle.Massless = true
		handle.Parent = model
		handles[handle] = CFrame.new(width * 0.5 - 0.45, -height * 0.5 + 3.1, side * (THICKNESS * 0.5 + 0.06))
	end

	local angle = Instance.new("NumberValue")
	angle.Name = "Angle"
	angle.Parent = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DoorPrompt"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.ActionText = if locked then "Closed" else "Open"
	prompt.ObjectText = if locked then Rooms.CLOSED_MESSAGE else "Door"
	prompt:SetAttribute("For", "all")
	prompt.Parent = panel

	if not locked then
		-- The computer entity paths through doors and opens them on the way.
		local modifier = Instance.new("PathfindingModifier")
		modifier.PassThrough = true
		modifier.Parent = panel
	end

	local state: DoorState = {
		panel = panel,
		hinge = hinge,
		width = width,
		height = height,
		sign = openSign,
		angle = angle,
		prompt = prompt,
		open = false,
		locked = locked,
		handles = handles,
	}
	states[model] = state
	angle.Changed:Connect(function()
		place(state)
	end)
	place(state)

	prompt.Triggered:Connect(function(player)
		if not state.locked then
			Doors.setOpen(model, not state.open)
		elseif state.onLockedUse then
			state.onLockedUse(player)
		end
	end)

	model:SetAttribute("Open", false)
	model:SetAttribute("Locked", locked)
	CollectionService:AddTag(model, "Door")
	model.Parent = parent
	return model
end

function Doors.setOpen(door: Model, open: boolean)
	local state = states[door]
	if not state or state.locked or state.open == open then
		return
	end
	state.open = open
	state.prompt.ActionText = if open then "Close" else "Open"
	door:SetAttribute("Open", open)
	local target = if open then OPEN_ANGLE * state.sign else 0
	TweenService:Create(state.angle, TweenInfo.new(SWING_TIME, Enum.EasingStyle.Quad), { Value = target }):Play()
	if open then
		creak(door, state.panel.Position)
	end
end

-- Locks or unlocks a door for the story (the red room, Lab 14). A locked door closes and says it is locked; with
-- `onUse`, E on the locked door calls it instead (one prompt per door, so E always reaches it) and shows `action`.
function Doors.setLocked(door: Model, locked: boolean, message: string?, onUse: ((Player) -> ())?, action: string?)
	local state = states[door]
	if not state then
		return
	end
	if locked then
		Doors.setOpen(door, false)
	end
	state.locked = locked
	state.onLockedUse = if locked then onUse else nil
	door:SetAttribute("Locked", locked)
	state.prompt.ActionText = if locked then (action or "Locked") elseif state.open then "Close" else "Open"
	state.prompt.ObjectText = if locked then (message or "It is locked.") else "Door"
	local modifier = state.panel:FindFirstChildOfClass("PathfindingModifier")
	if not locked and not modifier then
		modifier = Instance.new("PathfindingModifier")
		modifier.PassThrough = true
		modifier.Parent = state.panel
	elseif locked and modifier then
		modifier:Destroy()
	end
end

-- The first door model of a room (doors carry Room and Floor attributes), or nil.
function Doors.find(room: string, floor: number): Model?
	for door, _ in states do
		if door:GetAttribute("Room") == room and door:GetAttribute("Floor") == floor then
			return door
		end
	end
	return nil
end

-- Every door panel of a room (a room can have a door on more than one wall).
function Doors.ofRoom(room: string, floor: number): { Model }
	local list = {}
	for door, _ in states do
		if door:GetAttribute("Room") == room and door:GetAttribute("Floor") == floor then
			table.insert(list, door)
		end
	end
	return list
end

function Doors.isOpen(door: Model): boolean
	local state = states[door]
	return state ~= nil and state.open
end

return Doors
