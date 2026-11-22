--!strict
-- What a player carries in the story (inventory.gd): one hand, two pockets and an 8-slot bag. Small items fit a
-- pocket, big ones only the hand or the bag. The bag is heavy and slows you while you wear it. Every paper you pick
-- up joins one "papers" stack. Only the hand and the pockets can be used directly: the bag has to come off and be
-- opened first. Pure data: the server owns the inventories (src/server/Inventories.luau).

export type Slot = string -- "hand" | "pocketL" | "pocketR" | "bag"
export type Item = { id: string, texts: { string }? }
export type Inv = { hand: Item?, pocketL: Item?, pocketR: Item?, bag: { Item }, bagWorn: boolean }

local Inventory = {}

Inventory.BAG_SLOTS = 8
local BAG_KG = 3.0 -- the empty bag
local KG_PENALTY = 0.03 -- share of the speed lost per kg on your back
local MIN_SPEED = 0.7

Inventory.ITEMS = {
	key = { name = "Storage key", small = true, kg = 0.1 },
	vial = { name = "Holy water", small = true, kg = 1.0 },
	salt = { name = "Salt", small = false, kg = 1.2 },
	fuse = { name = "Fuse", small = false, kg = 0.8 },
	bell = { name = "Silver bell", small = false, kg = 1.5 },
	papers = { name = "Papers", small = true, kg = 0.1 },
	battery = { name = "Power bank", small = true, kg = 0.2 },
	biscuit = { name = "Dog biscuit", small = true, kg = 0.05 },
} :: { [string]: { name: string, small: boolean, kg: number } }

-- Room keys from the Porta: one id per room, "roomkey:23" (KeyRules.itemId).
local ROOM_KEY = "roomkey:"

-- What an item id is: its entry in ITEMS, or a room key.
local function info(id: string): { name: string, small: boolean, kg: number }?
	if string.sub(id, 1, #ROOM_KEY) == ROOM_KEY then
		return { name = `Key {string.sub(id, #ROOM_KEY + 1)}`, small = true, kg = 0.05 }
	end
	return Inventory.ITEMS[id]
end

local HANDY: { Slot } = { "hand", "pocketL", "pocketR" }

function Inventory.new(): Inv
	return { hand = nil, pocketL = nil, pocketR = nil, bag = {}, bagWorn = true }
end

function Inventory.isSmall(id: string): boolean
	local i = info(id)
	return i ~= nil and i.small
end

function Inventory.nameOf(id: string): string
	local i = info(id)
	return if i then i.name else id
end

-- The look of an item in the hand and on the floor: room keys look like the storage key.
function Inventory.lookOf(id: string): string
	return if string.sub(id, 1, #ROOM_KEY) == ROOM_KEY then "key" else id
end

local function get(inv: Inv, slot: Slot, index: number?): Item?
	if slot == "bag" then
		return if index then inv.bag[index] else nil
	end
	return (inv :: any)[slot]
end

local function set(inv: Inv, slot: Slot, index: number?, item: Item?)
	if slot == "bag" then
		if item then
			if index and inv.bag[index] then
				inv.bag[index] = item
			else
				table.insert(inv.bag, item)
			end
		elseif index then
			table.remove(inv.bag, index)
		end
	else
		(inv :: any)[slot] = item
	end
end

local function fits(slot: Slot, item: Item): boolean
	if slot == "pocketL" or slot == "pocketR" then
		return Inventory.isSmall(item.id)
	end
	return true
end

local function merge(into: Item, from: Item)
	local texts: { string } = into.texts or {}
	local more: { string } = from.texts or {}
	for _, text in more do
		table.insert(texts, text)
	end
	into.texts = texts
end

-- Puts a new item where it fits: the hand, a pocket (small items), then the bag (worn, not full). Papers join an
-- existing stack first. Returns the slot, or nil when there is no room.
function Inventory.add(inv: Inv, item: Item): Slot?
	if item.id == "papers" then
		for _, slot in HANDY do
			local held = get(inv, slot)
			if held and held.id == "papers" then
				merge(held, item)
				return slot
			end
		end
		if inv.bagWorn then
			for _, held in inv.bag do
				if held.id == "papers" then
					merge(held, item)
					return "bag"
				end
			end
		end
	end
	for _, slot in HANDY do
		if get(inv, slot) == nil and fits(slot, item) then
			set(inv, slot, nil, item)
			return slot
		end
	end
	if inv.bagWorn and #inv.bag < Inventory.BAG_SLOTS then
		table.insert(inv.bag, item)
		return "bag"
	end
	return nil
end

-- Where an item can be used from: the hand or a pocket, never the bag.
function Inventory.reachable(inv: Inv, id: string): Slot?
	for _, slot in HANDY do
		local held = get(inv, slot)
		if held and held.id == id then
			return slot
		end
	end
	return nil
end

function Inventory.take(inv: Inv, id: string): Item?
	local slot = Inventory.reachable(inv, id)
	if not slot then
		return nil
	end
	local item = get(inv, slot)
	set(inv, slot, nil, nil)
	return item
end

-- Moves an item, swapping with whatever is at the target. `from` and `to` may be different inventories (a friend's
-- dropped bag). Bag indexes are 1..BAG_SLOTS; a missing or empty bag index appends. Papers onto papers merge.
function Inventory.move(from: Inv, fromSlot: Slot, fromIndex: number?, to: Inv, toSlot: Slot, toIndex: number?): boolean
	-- Indexes only mean something for the bag.
	if fromSlot ~= "bag" then
		fromIndex = nil
	end
	if toSlot ~= "bag" then
		toIndex = nil
	end
	if fromSlot == "bag" and (type(fromIndex) ~= "number" or fromIndex % 1 ~= 0) then
		return false
	end
	if toIndex ~= nil and (type(toIndex) ~= "number" or toIndex % 1 ~= 0 or toIndex < 1
		or toIndex > Inventory.BAG_SLOTS) then
		return false
	end
	local a = get(from, fromSlot, fromIndex)
	if not a then
		return false
	end
	if from == to and fromSlot == toSlot and fromIndex == toIndex then
		return false
	end
	local b = get(to, toSlot, toIndex)
	if b == a then
		return false -- onto itself
	end
	if b and a.id == "papers" and b.id == "papers" then
		merge(b, a)
		set(from, fromSlot, fromIndex, nil)
		return true
	end
	if not fits(toSlot, a) or (b and not fits(fromSlot, b)) then
		return false
	end
	if toSlot == "bag" and not b and #to.bag >= Inventory.BAG_SLOTS
		and not (from == to and fromSlot == "bag") then
		return false
	end
	if b then
		set(to, toSlot, toIndex, a)
		set(from, fromSlot, fromIndex, b)
	else
		set(from, fromSlot, fromIndex, nil)
		set(to, toSlot, toIndex, a)
	end
	return true
end

function Inventory.speed(inv: Inv): number
	if not inv.bagWorn then
		return 1
	end
	local kg = BAG_KG
	for _, item in inv.bag do
		local i = info(item.id)
		kg += if i then i.kg else 0.5
	end
	return math.max(MIN_SPEED, 1 - KG_PENALTY * kg)
end

-- Items on you (hand, pockets and the bag while you wear it) whose id passes `want`.
function Inventory.carried(inv: Inv, want: (string) -> boolean): { string }
	local list = {}
	for _, slot in HANDY do
		local held = get(inv, slot)
		if held and want(held.id) then
			table.insert(list, held.id)
		end
	end
	if inv.bagWorn then
		for _, item in inv.bag do
			if want(item.id) then
				table.insert(list, item.id)
			end
		end
	end
	return list
end

-- Takes every item on you whose id passes `want` (hand, pockets, the worn bag); returns their ids.
function Inventory.takeAll(inv: Inv, want: (string) -> boolean): { string }
	local list = Inventory.carried(inv, want)
	for _, slot in HANDY do
		local held = get(inv, slot)
		if held and want(held.id) then
			set(inv, slot, nil, nil)
		end
	end
	if inv.bagWorn then
		for i = #inv.bag, 1, -1 do
			if want(inv.bag[i].id) then
				table.remove(inv.bag, i)
			end
		end
	end
	return list
end

function Inventory.all(inv: Inv): { Item }
	local list = {}
	for _, slot in HANDY do
		local held = get(inv, slot)
		if held then
			table.insert(list, held)
		end
	end
	for _, item in inv.bag do
		table.insert(list, item)
	end
	return list
end

return Inventory
