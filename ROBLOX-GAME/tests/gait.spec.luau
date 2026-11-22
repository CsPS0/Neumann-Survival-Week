local Gait = require("../src/shared/Gait")

return function(t)
	t.test("standing still is idle", function()
		local p = Gait.pose(0)
		t.eq(p.idle, 1)
		t.eq(p.walk, 0)
	end)

	t.test("the game's walk (9 studs/s) is a pure walk with feet on the ground", function()
		local p = Gait.pose(9)
		t.eq(p.walk, 1)
		t.eq(p.run, 0)
		t.near(p.walkSpeed, 9 / 6.4, 1e-6)
	end)

	t.test("the sprint (16.5 studs/s) is a pure run", function()
		local p = Gait.pose(16.5)
		t.eq(p.run, 1)
		t.eq(p.walk, 0)
		t.near(p.runSpeed, 16.5 / 12.8, 1e-6)
	end)

	t.test("between walk and run they crossfade, weights add up to one", function()
		local p = Gait.pose(12.5)
		t.truthy(p.walk > 0 and p.run > 0)
		t.near(p.walk + p.run + p.idle, 1, 1e-9)
	end)

	t.test("a smaller body takes shorter steps: the same speed plays faster", function()
		t.truthy(Gait.pose(6, 0.8).walkSpeed > Gait.pose(6, 1).walkSpeed)
		t.eq(Gait.pose(1).walkSpeed, 0.4, "very slow: clamped, never a frozen pose")
	end)
end
