--!strict
-- Who may use the free roam admin panel and which requests it accepts (checked again on the server, whatever a
-- client sends). Admin: the game's owner (the place creator, or anyone in a group-owned game's group with the owner
-- rank), the owner of a private server, or anyone while testing in Studio.

local AdminRules = {}

AdminRules.ITEMS = { "biscuit", "battery", "key", "vial", "salt", "fuse", "bell" }
AdminRules.SPEEDS = { 1, 1.5, 2, 3 } -- times the normal walk
AdminRules.HOURS = { 7, 10, 13, 16, 18.5, 21, 0 } -- clock times the panel offers

export type Who = {
	userId: number,
	creatorId: number,
	creatorIsGroup: boolean,
	groupRank: number, -- the player's rank in the owning group (0 when not a group game)
	privateOwnerId: number,
	studio: boolean,
}

function AdminRules.isAdmin(w: Who): boolean
	if w.studio then
		return true
	end
	if w.privateOwnerId ~= 0 and w.userId == w.privateOwnerId then
		return true
	end
	if w.creatorIsGroup then
		return w.groupRank >= 255
	end
	return w.userId == w.creatorId
end

-- A request from the panel, made safe: returns the cleaned arguments or nil when it is not allowed.
function AdminRules.check(op: any, args: any): any
	if type(op) ~= "string" then
		return nil
	end
	args = if type(args) == "table" then args else {}
	if op == "time" then
		local h = tonumber(args.hour)
		return if h and h >= 0 and h < 24 then { hour = h } else nil
	elseif op == "speed" then
		local m = tonumber(args.times)
		return if m and table.find(AdminRules.SPEEDS, m) then { times = m } else nil
	elseif op == "give" then
		return if type(args.item) == "string" and table.find(AdminRules.ITEMS, args.item) then { item = args.item }
			else nil
	elseif op == "teleport" then
		local floor = tonumber(args.floor)
		if type(args.room) ~= "string" or #args.room > 40 or not floor or floor % 1 ~= 0 or floor < 0 or floor > 2 then
			return nil
		end
		return { room = args.room, floor = floor }
	elseif op == "lights" or op == "csoki" or op == "people" or op == "end" or op == "demo" or op == "attackMe" then
		return {}
	end
	return nil
end

return AdminRules
