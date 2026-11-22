-- Every player's hand, pockets and bag in the story (src/shared/Inventory.luau holds the rules). B drops your bag
-- in front of you; anyone alive can open a dropped bag (E) and move things between it and their own hand and
-- pockets; only its owner puts it back on (B at the bag). Loose items lie on the floor as pickups. A player who goes
-- out or leaves spills: hand and pockets go into the bag, what does not fit drops beside it, the bag is dropped.
-- Inventories are keyed by UserId, so a bag outlives its owner leaving.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Characters = require(script.Parent.Parent.Characters)
local Pickups = require(script.Parent.Pickups)

local S = Config.studs
local REACH = 12 -- studs from a dropped bag to use it
local BATTERY_GAIN = 35

local COLORS = {
	key = Color3.fromRGB(196, 160, 70),
	vial = Color3.fromRGB(150, 200, 235),
	salt = Color3.fromRGB(235, 235, 235),
	fuse = Color3.fromRGB(200, 160, 60),
	bell = Color3.fromRGB(205, 205, 215),
	papers = Color3.fromRGB(236, 230, 210),
	battery = Color3.fromRGB(40, 40, 46),
	biscuit = Color3.fromRGB(170, 120, 70),
}

type Bag = { model: Model, ownerId: number, ownerName: string }

local Inventories = {}

local remotes: Folder? = nil
local folder: Instance? = nil
local invs: { [number]: Inventory.Inv } = {}
local bags: { [number]: Bag } = {} -- dropped bags by owner UserId
local viewing: { [Player]: number } = {} -- the bag (owner UserId) a player has open
local names: { [number]: string } = {}

local function remote(name: string): RemoteEvent
	return (remotes :: Folder):FindFirstChild(name) :: RemoteEvent
end

local function banner(player: Player, text: string)
	remote("Banner"):FireClient(player, text, 4)
end

local function alive(player: Player): boolean
	return player.Parent ~= nil and player:GetAttribute("State") == "alive"
end

function Inventories.isEnabled(): boolean
	return folder ~= nil
end

function Inventories.of(player: Player): Inventory.Inv
	local inv = invs[player.UserId]
	if not inv then
		inv = Inventory.new()
		invs[player.UserId] = inv
		names[player.UserId] = player.DisplayName
	end
	return inv
end

-- Sends the owner their inventory and the speed their bag allows.
local function send(player: Player?)
	if not player or not player.Parent or not folder then
		return
	end
	local inv = Inventories.of(player)
	player:SetAttribute("CarrySpeed", Inventory.speed(inv))
	remote("Inventory"):FireClient(player, { inv = inv, bagDropped = not inv.bagWorn })
end

local function sendView(player: Player)
	local ownerId = viewing[player]
	local bag = ownerId and bags[ownerId]
	if not bag then
		viewing[player] = nil
		remote("BagView"):FireClient(player, nil)
		return
	end
	remote("BagView"):FireClient(player, { owner = ownerId, ownerName = bag.ownerName, bag = invs[ownerId].bag })
end

local function near(player: Player, position: Vector3): boolean
	local root = Characters.root(player)
	return root ~= nil and (root.Position - position).Magnitude <= REACH
end

local function bagPosition(bag: Bag): Vector3
	return (bag.model.PrimaryPart :: BasePart).Position
end

-- After a bag changed: everyone who has it open (and is still alive and next to it), and its owner.
local function changedBag(ownerId: number)
	local bag = bags[ownerId]
	for player in viewing do
		if viewing[player] == ownerId then
			if bag and alive(player) and near(player, bagPosition(bag)) then
				sendView(player)
			else
				viewing[player] = nil
				remote("BagView"):FireClient(player, nil)
			end
		end
	end
	send(Players:GetPlayerByUserId(ownerId))
end

-- A loose item on the floor; E picks it up into the first free place.
function Inventories.dropItem(item: Inventory.Item, at: Vector3)
	if not folder then
		return
	end
	local small = Inventory.isSmall(item.id)
	local size = if small then Vector3.new(0.25, 0.12, 0.18) else Vector3.new(0.35, 0.3, 0.35)
	local part = Pickups.part(folder, Inventory.nameOf(item.id), at, size,
		COLORS[Inventory.lookOf(item.id)] or Color3.new(0.6, 0.6, 0.6))
	part.CanCollide = false
	Pickups.prompt(part, "Take", Inventory.nameOf(item.id), 0.3, function(player)
		if part.Parent and Inventories.give(player, item) then
			part:Destroy()
		end
	end)
end

-- Puts an item into a player's inventory. False (with a message) when there is no room.
function Inventories.give(player: Player, item: Inventory.Item): boolean
	local inv = Inventories.of(player)
	if not Inventory.add(inv, item) then
		banner(player, "No room. Drop your bag (B), open it and make space.")
		return false
	end
	send(player)
	if not inv.bagWorn and bags[player.UserId] then
		changedBag(player.UserId)
	end
	return true
end

function Inventories.reachable(player: Player, id: string): boolean
	return Inventory.reachable(Inventories.of(player), id) ~= nil
end

function Inventories.take(player: Player, id: string): Inventory.Item?
	local item = Inventory.take(Inventories.of(player), id)
	if item then
		send(player)
	end
	return item
end

-- The ids of the items on a player (hand, pockets, the worn bag) that pass `want`.
function Inventories.carried(player: Player, want: (string) -> boolean): { string }
	return Inventory.carried(Inventories.of(player), want)
end

-- Takes every item on a player that passes `want`; returns their ids.
function Inventories.takeAll(player: Player, want: (string) -> boolean): { string }
	local list = Inventory.takeAll(Inventories.of(player), want)
	if #list > 0 then
		send(player)
	end
	return list
end

local function closeViewsOf(ownerId: number)
	for player, open in viewing do
		if open == ownerId then
			viewing[player] = nil
			remote("BagView"):FireClient(player, nil)
		end
	end
end

local function wear(player: Player, ownerId: number)
	local bag = bags[ownerId]
	if not bag or player.UserId ~= ownerId or not alive(player) or not near(player, bagPosition(bag)) then
		return
	end
	closeViewsOf(ownerId)
	bag.model:Destroy()
	bags[ownerId] = nil
	Inventories.of(player).bagWorn = true
	send(player)
end

local function open(player: Player, ownerId: number)
	local bag = bags[ownerId]
	if bag and alive(player) and near(player, bagPosition(bag)) then
		viewing[player] = ownerId
		sendView(player)
	end
end

-- Drops a player's bag on the floor at `at` (in front of them by default).
local function dropBag(ownerId: number, at: Vector3)
	local inv = invs[ownerId]
	if not inv or not inv.bagWorn or not folder then
		return
	end
	inv.bagWorn = false
	local model = Instance.new("Model")
	model.Name = "Bag"
	local body = Pickups.part(model, "Body", at, Vector3.new(0.4, 0.46, 0.25), Color3.fromRGB(31, 51, 36),
		Enum.Material.Fabric)
	body.CanCollide = false
	model.PrimaryPart = body
	local flap = Pickups.part(model, "Flap", at + Vector3.new(0, S(0.36), 0), Vector3.new(0.4, 0.1, 0.26),
		Color3.fromRGB(24, 40, 28), Enum.Material.Fabric)
	flap.CanCollide = false
	model.Parent = folder
	local name = names[ownerId] or "someone"
	local bag: Bag = { model = model, ownerId = ownerId, ownerName = name }
	bags[ownerId] = bag
	local openPrompt = Pickups.prompt(body, "Open bag", `Bag of {name}`, 0.3, function(player)
		open(player, ownerId)
	end)
	openPrompt.Name = "OpenBag"
	local wearPrompt = Pickups.prompt(body, "Put on", "Your bag", 0.5, function(player)
		wear(player, ownerId)
	end)
	wearPrompt.Name = "WearBag"
	wearPrompt.KeyboardKeyCode = Enum.KeyCode.B
	wearPrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	wearPrompt.UIOffset = Vector2.new(0, 70)
	wearPrompt:SetAttribute("OnlyUser", ownerId)
	send(Players:GetPlayerByUserId(ownerId))
end

local function inFront(player: Player): Vector3?
	local root = Characters.root(player)
	if not root then
		return nil
	end
	local p = root.Position + root.CFrame.LookVector * S(0.8)
	return Vector3.new(p.X, root.Position.Y - 3, p.Z)
end

-- The inventory and slot a client names: "hand"/"pocketL"/"pocketR" are your own, "bag" is the open bag (or your
-- own when it lies on the floor next to you and you have it open).
local function resolve(player: Player, slot: any): (Inventory.Inv?, number?)
	if slot == "hand" or slot == "pocketL" or slot == "pocketR" then
		return Inventories.of(player), nil
	elseif slot == "bag" then
		local ownerId = viewing[player]
		local bag = ownerId and bags[ownerId]
		if bag and near(player, bagPosition(bag)) then
			return invs[ownerId], ownerId
		end
	end
	return nil, nil
end

local function onAction(player: Player, op: any, args: any)
	if op == "close" then
		viewing[player] = nil -- always allowed, also when downed or out
		return
	end
	if not folder or not alive(player) or type(op) ~= "string" then
		return
	end
	args = if type(args) == "table" then args else {}
	if op == "drop" then
		local at = inFront(player)
		if at then
			dropBag(player.UserId, at)
		end
	elseif op == "move" then
		local fromInv, fromBag = resolve(player, args.from)
		local toInv, toBag = resolve(player, args.to)
		if not fromInv or not toInv then
			return
		end
		local fromIndex = if type(args.fromIndex) == "number" then args.fromIndex else nil
		local toIndex = if type(args.toIndex) == "number" then args.toIndex else nil
		if Inventory.move(fromInv, args.from, fromIndex, toInv, args.to, toIndex) then
			send(player)
			for _, ownerId in { fromBag, toBag } do
				if ownerId then
					changedBag(ownerId)
				end
			end
		end
	elseif op == "floor" then
		local inv, ownerId = resolve(player, args.slot)
		local at = inFront(player)
		if not inv or not at then
			return
		end
		local index = if args.slot == "bag" and type(args.index) == "number" then args.index else nil
		local item = if args.slot == "bag" then (if index then inv.bag[index] else nil) else (inv :: any)[args.slot]
		if not item then
			return
		end
		if args.slot == "bag" then
			table.remove(inv.bag, index :: number)
		else
			(inv :: any)[args.slot] = nil
		end
		Inventories.dropItem(item, at)
		send(player)
		if ownerId then
			changedBag(ownerId)
		end
	elseif op == "use" then
		-- A power bank from the hand or a pocket charges the phone.
		if Inventories.take(player, "battery") then
			local max = Config.Torch.batteryMax
			player:SetAttribute("Battery", math.min(max, (player:GetAttribute("Battery") or 0) + BATTERY_GAIN))
			banner(player, "Phone charged.")
		else
			banner(player, "No power bank in your hand or pockets.")
		end
	end
end

-- Out or leaving: hand and pockets into the bag (what does not fit next to it), the bag on the floor.
function Inventories.spill(player: Player, fallback: Vector3?)
	local inv = invs[player.UserId]
	if not inv or not folder then
		return
	end
	local at = inFront(player) or fallback
	if not at then
		return
	end
	for _, slot in { "hand", "pocketL", "pocketR" } do
		local item = (inv :: any)[slot]
		if item then
			(inv :: any)[slot] = nil
			if #inv.bag < Inventory.BAG_SLOTS then
				table.insert(inv.bag, item)
			else
				Inventories.dropItem(item, at + Vector3.new(math.random(-10, 10) / 10, 0, math.random(-10, 10) / 10) * S(1))
			end
		end
	end
	if inv.bagWorn then
		dropBag(player.UserId, at)
	else
		changedBag(player.UserId)
	end
	viewing[player] = nil
end

-- Story start: fresh inventories for everyone; story end: everything gone.
function Inventories.enable(parent: Instance)
	Inventories.disable()
	local f = Instance.new("Folder")
	f.Name = "Bags"
	f.Parent = parent
	folder = f
	for _, player in Players:GetPlayers() do
		send(player)
	end
end

function Inventories.disable()
	if folder then
		folder:Destroy()
	end
	folder = nil
	invs = {}
	bags = {}
	viewing = {}
	names = {}
	if remotes then
		for _, player in Players:GetPlayers() do
			player:SetAttribute("CarrySpeed", nil)
			remote("Inventory"):FireClient(player, nil)
			remote("BagView"):FireClient(player, nil)
		end
	end
end

-- A player who joined mid-run gets their (empty) inventory.
function Inventories.join(player: Player)
	send(player)
end

function Inventories.init(remoteFolder: Folder)
	remotes = remoteFolder
	remote("BagAction").OnServerEvent:Connect(onAction)
	Players.PlayerRemoving:Connect(function(player)
		viewing[player] = nil
	end)
end

return Inventories
