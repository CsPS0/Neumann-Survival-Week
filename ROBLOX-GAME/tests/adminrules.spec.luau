local AdminRules = require("../src/shared/AdminRules")

local function who(over)
	local w = { userId = 5, creatorId = 9, creatorIsGroup = false, groupRank = 0, privateOwnerId = 0, studio = false }
	for k, v in over or {} do
		w[k] = v
	end
	return w
end

return function(t)
	t.test("who is admin", function()
		t.eq(AdminRules.isAdmin(who()), false, "a visitor")
		t.eq(AdminRules.isAdmin(who({ userId = 9 })), true, "the place's creator")
		t.eq(AdminRules.isAdmin(who({ privateOwnerId = 5 })), true, "the private server's owner")
		t.eq(AdminRules.isAdmin(who({ creatorIsGroup = true, groupRank = 255 })), true, "the group's owner")
		t.eq(AdminRules.isAdmin(who({ creatorIsGroup = true, groupRank = 200 })), false, "a group member")
		t.eq(AdminRules.isAdmin(who({ studio = true })), true, "testing in Studio")
	end)

	t.test("requests are checked", function()
		t.eq(AdminRules.check("time", { hour = 13 }).hour, 13)
		t.eq(AdminRules.check("time", { hour = 30 }), nil)
		t.eq(AdminRules.check("speed", { times = 2 }).times, 2)
		t.eq(AdminRules.check("speed", { times = 50 }), nil, "no super speed")
		t.eq(AdminRules.check("give", { item = "biscuit" }).item, "biscuit")
		t.eq(AdminRules.check("give", { item = "roomkey:14" }), nil, "only listed items")
		t.eq(AdminRules.check("teleport", { room = "23", floor = 0 }).room, "23")
		t.eq(AdminRules.check("teleport", { room = "23", floor = 7 }), nil)
		t.eq(AdminRules.check("explode", {}), nil)
		t.eq(AdminRules.check(5, {}), nil)
		t.truthy(AdminRules.check("end", "x"))
	end)
end
