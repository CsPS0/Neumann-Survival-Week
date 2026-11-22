local Achievements = require("../src/shared/Achievements")

return function(t)
	t.test("every listed achievement is in the order and the other way round", function()
		local seen = {}
		for _, id in Achievements.ORDER do
			t.truthy(Achievements.LIST[id], id)
			seen[id] = true
		end
		for id in Achievements.LIST do
			t.truthy(seen[id], id .. " missing from ORDER")
		end
	end)

	t.test("adding is once only; unknown ids are refused", function()
		local have = {}
		t.eq((Achievements.add(have, "good_boy")), true)
		t.eq((Achievements.add(have, "good_boy")), false)
		t.eq((Achievements.add(have, "nonsense")), false)
	end)

	t.test("all nine endings bring the completionist", function()
		local have = {}
		for i = 1, 8 do
			local _, extra = Achievements.add(have, `ending_{i}`)
			t.eq(extra, nil)
		end
		local new, extra = Achievements.add(have, "ending_9")
		t.eq(new, true)
		t.eq(extra, "completionist")
		t.eq(have.completionist, true)
	end)

	t.test("saved data is cleaned", function()
		local have = Achievements.clean({ good_boy = true, hacked = true, hoops = "yes", [5] = true })
		t.eq(have.good_boy, true)
		t.eq(have.hacked, nil)
		t.eq(have.hoops, nil)
		t.eq(next(Achievements.clean("nope")), nil)
	end)
end
