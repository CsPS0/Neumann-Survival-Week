local Keybinds = require("../src/shared/Keybinds")
local Settings = require("../src/shared/Settings")
Settings.useKeybinds(Keybinds)

return function(t)
	t.test("defaults are one-handed and unique", function()
		local keys = Keybinds.clean(nil)
		local used = {}
		for _, a in Keybinds.ACTIONS do
			local k = keys[a.id]
			t.truthy(k, a.id)
			t.eq(used[k], nil, "used twice: " .. k)
			used[k] = true
		end
		t.eq(keys.phone, "Q")
		t.eq(keys.menu, "Backquote")
	end)

	t.test("bad saves fall back to defaults", function()
		local keys = Keybinds.clean({ phone = "Escape", torch = "W", bag = 5, sprint = "LeftShift" })
		t.eq(keys.phone, "Q", "Escape is not allowed")
		t.eq(keys.torch, "F", "W moves")
		t.eq(keys.bag, "Tab")
	end)

	t.test("two actions on one key: the first keeps it, the other gets a free key", function()
		local keys = Keybinds.clean({ sprint = "Q" })
		t.eq(keys.sprint, "Q")
		t.truthy(keys.phone ~= "Q", "phone moved off Q")
	end)

	t.test("assigning a taken key swaps the two", function()
		local keys = Keybinds.assign(Keybinds.clean(nil), "phone", "F")
		t.eq(keys.phone, "F")
		t.eq(keys.torch, "Q")
		t.eq(Keybinds.assign(keys, "phone", "W").phone, "F", "reserved keys are refused")
	end)

	t.test("settings carry the keys and the new options", function()
		local v = Settings.clean({ keys = { phone = "Z" }, graphics = "low", ambience = 0.3 })
		t.eq(v.keys.phone, "Z")
		t.eq(v.graphics, "low")
		t.near(v.ambience, 0.3, 1e-9)
		t.eq(Settings.clean({ graphics = "ultra" }).graphics, "high")
		t.eq(Keybinds.label("Backquote"), "`")
	end)
end
