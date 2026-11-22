local CampaignData = require("../src/shared/CampaignData")
local F = require("../src/shared/FloorData")
local R = require("../src/shared/Rooms")

return function(t)
	t.test("room lookup", function()
		-- Porta on the ground floor: plan 42.5-47.8 x 40.1-43, origin 42.6, 21.9.
		t.eq(F.roomLabelAt(0, 2.0, 19.5), "Porta")
		t.eq(F.roomLabelAt(1, -16, -18), "109")
		t.eq(F.roomLabelAt(0, -2.6, 10.0), "Corridor") -- the Aula
	end)
	t.test("log label adds the floor", function()
		t.eq(F.logLabel(1, -16, -18), "109 (1st floor)")
		t.eq(F.logLabel(0, -2.6, 10.0), "Corridor (ground floor)")
	end)
	t.test("roomRect", function()
		local r = F.roomRect(0, "Porta")
		t.truthy(r, "Porta exists")
		if r then
			-- Where the map puts it, give or take a tidy-up (tools/map-editor/tidy-map.luau moves walls up to 0.4 m).
			t.near(r.x0, -0.1, 0.3)
			t.near(r.z0, 18.2, 0.3)
			t.near(r.x1, 5.2, 0.3)
			t.near(r.z1, 21.1, 0.3)
		end
		t.eq(F.roomRect(0, "nope"), nil)
	end)
	t.test("data sizes", function()
		t.eq(#F.FLOORS, 3)
		t.eq(#F.LOCKERS, 14)
		t.eq(#F.STAIRS, 4)
		for i, floor in F.FLOORS do
			t.truthy(#floor.patrol >= 4, `patrol points on floor {i - 1}`)
			t.truthy(floor.rect.x0 <= floor.core.x0 and floor.rect.x1 >= floor.core.x1, "rect holds the core")
		end
	end)
	t.test("floorAt", function()
		t.eq(F.floorAt(0.1), 0)
		t.eq(F.floorAt(4.2), 1)
		t.eq(F.floorAt(9), 2)
		t.eq(F.floorAt(-1), 0)
	end)
	t.test("toWorld", function()
		local x, z = F.toWorld(2, 0, 0)
		t.near(x, -20.3, 1e-9)
		t.near(z, -21.9, 1e-9)
	end)

	-- The map comes from the editor: the story must still find every room it uses, open.
	t.test("every story room exists and is open", function()
		local places = {}
		for _, info in CampaignData.SUBJECTS do
			table.insert(places, { room = info.room, floor = info.floor })
		end
		for _, p in CampaignData.STORY do
			table.insert(places, p)
		end
		for _, p in CampaignData.AFTER_ROOMS do
			table.insert(places, p)
		end
		for _, p in CampaignData.CLUE_ROOMS do
			table.insert(places, p)
		end
		table.insert(places, { room = "Porta", floor = 0 })
		for _, p in places do
			t.truthy(F.roomRect(p.floor, p.room), `room {p.room} on floor {p.floor} exists`)
			t.truthy(R.isOpen(p.room), `room {p.room} is open`)
		end
	end)

	t.test("lockers stand free (not in a courtyard or a stairwell)", function()
		for _, l in F.LOCKERS do
			local floor = F.FLOORS[l.floor + 1]
			for _, s in floor.solids do
				t.truthy(not (l.x > s.x0 and l.x < s.x1 and l.y > s.y0 and l.y < s.y1),
					`locker {l.x}, {l.y} on floor {l.floor} is inside a courtyard`)
			end
			local wx, wz = F.toWorld(l.floor, l.x, l.y)
			for _, s in F.STAIRS do
				t.truthy(not (wx > s.x0 - 0.5 and wx < s.x1 + 0.5 and wz > s.z0 - 0.5 and wz < s.z1 + 0.5),
					`locker {l.x}, {l.y} on floor {l.floor} is in a stairwell`)
			end
		end
	end)
end
