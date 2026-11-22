local Inventory = require("../src/shared/Inventory")

local function item(id: string, texts: { string }?)
	return { id = id, texts = texts }
end

return function(t)
	t.test("add fills the hand, then a pocket, then the bag", function()
		local inv = Inventory.new()
		t.eq(Inventory.add(inv, item("key")), "hand")
		t.eq(Inventory.add(inv, item("vial")), "pocketL")
		t.eq(Inventory.add(inv, item("battery")), "pocketR")
		t.eq(Inventory.add(inv, item("salt")), "bag")
		t.eq(#inv.bag, 1)
	end)

	t.test("big items never go in a pocket", function()
		local inv = Inventory.new()
		Inventory.add(inv, item("key")) -- hand taken
		t.eq(Inventory.add(inv, item("fuse")), "bag")
		t.eq(inv.pocketL, nil)
		inv.bagWorn = false
		t.eq(Inventory.add(inv, item("bell")), nil, "bag off: no room for a big item")
		t.eq(Inventory.add(inv, item("vial")), "pocketL", "small still fits a pocket")
	end)

	t.test("a full bag refuses", function()
		local inv = Inventory.new()
		inv.hand = item("salt")
		inv.pocketL = item("key")
		inv.pocketR = item("vial")
		for _ = 1, Inventory.BAG_SLOTS do
			t.eq(Inventory.add(inv, item("battery")), "bag")
		end
		t.eq(Inventory.add(inv, item("battery")), nil)
	end)

	t.test("papers merge into one stack wherever it is", function()
		local inv = Inventory.new()
		inv.hand = item("salt")
		t.eq(Inventory.add(inv, item("papers", { "a" })), "pocketL")
		inv.pocketR = item("key")
		t.eq(Inventory.add(inv, item("papers", { "b", "c" })), "pocketL")
		t.eq(#(inv.pocketL :: any).texts, 3)
		t.eq(#inv.bag, 0)
	end)

	t.test("reachable and take ignore the bag", function()
		local inv = Inventory.new()
		inv.bag = { item("fuse") }
		t.eq(Inventory.reachable(inv, "fuse"), nil)
		t.eq(Inventory.take(inv, "fuse"), nil)
		inv.pocketR = item("vial")
		t.eq(Inventory.reachable(inv, "vial"), "pocketR")
		local taken = Inventory.take(inv, "vial")
		t.eq(taken and taken.id, "vial")
		t.eq(inv.pocketR, nil)
	end)

	t.test("move, swap and the pocket rule", function()
		local inv = Inventory.new()
		inv.bag = { item("fuse"), item("key") }
		t.eq(Inventory.move(inv, "bag", 1, inv, "pocketL", nil), false, "big into a pocket")
		t.eq(Inventory.move(inv, "bag", 1, inv, "hand", nil), true)
		t.eq((inv.hand :: any).id, "fuse")
		t.eq(#inv.bag, 1)
		-- swap: the key in the bag with the fuse in the hand
		t.eq(Inventory.move(inv, "bag", 1, inv, "hand", nil), true)
		t.eq((inv.hand :: any).id, "key")
		t.eq(inv.bag[1].id, "fuse")
		-- a swap that would put the fuse into a pocket is refused
		inv.pocketL = item("battery")
		t.eq(Inventory.move(inv, "pocketL", nil, inv, "bag", 1), false)
		-- between two inventories (a friend's dropped bag)
		local other = Inventory.new()
		other.bag = { item("bell") }
		t.eq(Inventory.move(other, "bag", 1, inv, "bag", nil), true)
		t.eq(#other.bag, 0)
		t.eq(inv.bag[2].id, "bell")
		t.eq(Inventory.move(inv, "bag", 9, inv, "hand", nil), false, "no such slot")
	end)

	t.test("moving an item onto itself is refused (no self-merge)", function()
		local inv = Inventory.new()
		inv.hand = item("papers", { "a" })
		t.eq(Inventory.move(inv, "hand", nil, inv, "hand", 1), false)
		t.eq(Inventory.move(inv, "hand", 3, inv, "hand", nil), false)
		t.eq(#(inv.hand :: any).texts, 1)
	end)

	t.test("moving papers onto papers merges", function()
		local inv = Inventory.new()
		inv.pocketL = item("papers", { "a" })
		inv.bag = { item("papers", { "b" }) }
		t.eq(Inventory.move(inv, "bag", 1, inv, "pocketL", nil), true)
		t.eq(#(inv.pocketL :: any).texts, 2)
		t.eq(#inv.bag, 0)
	end)

	t.test("the bag weight slows you", function()
		local inv = Inventory.new()
		t.near(Inventory.speed(inv), 0.91, 1e-6)
		for _ = 1, 8 do
			table.insert(inv.bag, item("bell"))
		end
		t.near(Inventory.speed(inv), 0.7, 1e-6)
		inv.bagWorn = false
		t.eq(Inventory.speed(inv), 1)
	end)

	t.test("all lists every item", function()
		local inv = Inventory.new()
		inv.hand = item("salt")
		inv.pocketR = item("key")
		inv.bag = { item("fuse") }
		t.eq(#Inventory.all(inv), 3)
	end)
end
