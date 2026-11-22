local Config = require("../src/shared/Config")

return function(t)
	t.test("studs converts metres", function()
		t.eq(Config.studs(1), 3)
		t.near(Config.studs(2.2), 6.6, 1e-9)
		t.near(Config.studs(Config.FLOOR_HEIGHT), 12, 1e-9)
	end)
end
