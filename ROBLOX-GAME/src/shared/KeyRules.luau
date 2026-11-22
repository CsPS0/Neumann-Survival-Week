--!strict
-- The Porta's room keys in the story (HORROR-GAME/scripts/porta.gd, changed). Classrooms, computer rooms and the gym
-- start locked; the porter lends their keys. By day he lends one key at a time, but sometimes he forgets the one you
-- already have and hands over another, so you can end up carrying several. Keys go back any time, all at once, and
-- the room does not have to be closed again first. At night he hands out whatever you ask for. A key opens its room
-- for good (it never locks again). Pure rules: src/server/Campaign/Keys.luau wires the doors, the porter and the bags.

local KeyRules = {}

KeyRules.FORGET = 0.35 -- the chance he forgets the key you already have
KeyRules.RECALL = 30 -- seconds an answer stands: asking again straight away gets the same answer
KeyRules.KEYED = { normal = true, computer = true, gym = true } :: { [string]: boolean }

local PREFIX = "roomkey:"

function KeyRules.itemId(room: string): string
	return PREFIX .. room
end

-- The room of a room key's item id, or nil for any other item.
function KeyRules.roomOf(id: string): string?
	if string.sub(id, 1, #PREFIX) == PREFIX then
		return string.sub(id, #PREFIX + 1)
	end
	return nil
end

function KeyRules.isKey(id: string): boolean
	return KeyRules.roomOf(id) ~= nil
end

-- A room that is locked with a key: a keyed kind with a single way in. A room with two or more doors can be the way
-- through to other rooms, so it stays open.
function KeyRules.isKeyed(kind: string, doors: number): boolean
	return KeyRules.KEYED[kind] == true and doors == 1
end

-- How many ways in a room has: door panels and openings ("S10.8 n41.3" is two).
function KeyRules.doorCount(doors: string): number
	local n = 0
	for _ in string.gmatch(doors, "%a[%d%.]*") do
		n += 1
	end
	return n
end

-- What the porter remembers about one player.
export type Ledger = {
	out: { [string]: boolean }, -- keys he remembers lending them and not getting back
	answers: { [string]: { at: number, forgot: boolean } }, -- his last answer per room
}

function KeyRules.newLedger(): Ledger
	return { out = {}, answers = {} }
end

local function first(set: { [string]: boolean }): string?
	local list = {}
	for room in set do
		table.insert(list, room)
	end
	table.sort(list)
	return list[1]
end

local function name(room: string): string
	return if room == "Tornaterem" then "the gym" else `room {room}`
end

-- Asking for `room`'s key. `carried`: the rooms whose keys the player has on them. `roll` returns 0..1.
-- Returns whether he hands it over and what he says.
function KeyRules.ask(ledger: Ledger, room: string, carried: { string }, now: number, night: boolean,
	roll: () -> number): (boolean, string)
	if table.find(carried, room) then
		return false, `You already have the key for {name(room)}.`
	end
	if night then
		ledger.out[room] = true
		return true, `The key for {name(room)}. Take it, nobody checks at night.`
	end
	local other = first(ledger.out)
	if not other then
		ledger.out[room] = true
		return true, `Here is the key for {name(room)}. Bring it back when you are done.`
	end
	local answer = ledger.answers[room]
	if not answer or now - answer.at > KeyRules.RECALL then
		answer = { at = now, forgot = roll() < KeyRules.FORGET }
		ledger.answers[room] = answer
	end
	if not answer.forgot then
		return false, `You still have the key for {name(other)}. One key at a time, bring it back first.`
	end
	-- He forgets every key he lent you before this one.
	ledger.out = { [room] = true }
	ledger.answers[room] = nil
	return true, `The key for {name(room)}... here. (He does not seem to remember the key for {name(other)}.)`
end

-- Giving back every room key the player carries (`returned`); he takes them whatever state the rooms are in.
function KeyRules.giveBack(ledger: Ledger, returned: { string }): string
	if #returned == 0 then
		local other = first(ledger.out)
		if other then
			return `You still have the key for {name(other)}. Bring it back when you find it.`
		end
		return "Need a key? Try the room's door first, then come and tell me."
	end
	for _, room in returned do
		ledger.out[room] = nil
	end
	table.sort(returned)
	return if #returned == 1 then `Thanks. The key for {name(returned[1])} is back on its hook.`
		else `Thanks. {#returned} keys back on their hooks: {table.concat(returned, ", ")}.`
end

return KeyRules
