--!strict
-- Social Deduction evidence: which room each player was in, keyed by tag. The server records every living player's
-- room once a second; a meeting shows the last minute of it.

export type Entry = { label: string, t: number }

local RoomLog = {}
RoomLog.__index = RoomLog

export type RoomLog = typeof(setmetatable({} :: { entries: { [string]: { Entry } } }, RoomLog))

function RoomLog.new(): RoomLog
	return setmetatable({ entries = {} }, RoomLog)
end

-- Appends only when the label changed.
function RoomLog.record(self: RoomLog, key: string, label: string, t: number)
	local list = self.entries[key]
	if not list then
		list = {}
		self.entries[key] = list
	end
	local last = list[#list]
	if not last or last.label ~= label then
		table.insert(list, { label = label, t = t })
	end
end

-- Entries from the last `age` seconds, oldest first, led by the last older entry so the room at the start of the
-- window is known.
function RoomLog.recent(self: RoomLog, key: string, now: number, age: number): { Entry }
	local list = self.entries[key]
	if not list then
		return {}
	end
	local out: { Entry } = {}
	for i, e in list do
		local nextEntry = list[i + 1]
		if e.t >= now - age or (nextEntry == nil or nextEntry.t >= now - age) then
			table.insert(out, e)
		end
	end
	return out
end

function RoomLog.clear(self: RoomLog)
	self.entries = {}
end

return RoomLog
