local Spring = require("../src/shared/Spring")

return function(t)
	t.test("settles on the target", function()
		local s = Spring.new(0, 1, 12)
		s.target = 10
		for _ = 1, 240 do
			s:update(1 / 60)
		end
		t.near(s.position, 10, 1e-3)
		t.near(s.velocity, 0, 1e-2)
	end)
	t.test("critically damped does not overshoot", function()
		local s = Spring.new(0, 1, 10)
		s.target = 1
		local peak = 0
		for _ = 1, 300 do
			s:update(1 / 60)
			peak = math.max(peak, s.position)
		end
		t.truthy(peak <= 1 + 1e-6, `peak {peak}`)
	end)
	t.test("underdamped overshoots", function()
		local s = Spring.new(0, 0.3, 10)
		s.target = 1
		local peak = 0
		for _ = 1, 300 do
			s:update(1 / 60)
			peak = math.max(peak, s.position)
		end
		t.truthy(peak > 1.1, `peak {peak}`)
	end)
	t.test("impulse moves it and it returns", function()
		local s = Spring.new(0, 0.8, 14)
		s:impulse(-5)
		s:update(1 / 60)
		t.truthy(s.position < 0)
		for _ = 1, 300 do
			s:update(1 / 60)
		end
		t.near(s.position, 0, 1e-3)
	end)
	t.test("large or zero steps stay finite", function()
		local s = Spring.new(0, 1, 30)
		s.target = 5
		s:update(0)
		s:update(2) -- a hitch
		t.truthy(s.position == s.position and math.abs(s.position) < 100)
	end)
end
