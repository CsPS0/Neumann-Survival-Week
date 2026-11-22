local D = require("../src/shared/Daylight")

return function(t)
	t.test("day, night, dawn and dusk", function()
		t.eq(D.at(0.5), 0)
		t.eq(D.at(10.5), 1)
		t.eq(D.at(6), 0.5)
		t.eq(D.at(18.25), 0.5)
		t.eq(D.at(21), 0)
	end)
end
