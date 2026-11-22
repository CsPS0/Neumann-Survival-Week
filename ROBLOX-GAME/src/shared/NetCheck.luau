--!strict
-- The networking lesson's checker, a very small "packet tracer": devices on a desk and the cables between them.
-- A PC, a server or the internet has one port, a switch eight and a router four. A task is right when the cables are
-- exactly the ones asked for (in any order and direction).

local NetCheck = {}

NetCheck.MAX_LINKS = 20

export type Device = { id: string, kind: string } -- kind: "pc" | "server" | "switch" | "router" | "cloud"
export type Link = { string } -- two device ids

NetCheck.PORTS = { pc = 1, server = 1, cloud = 1, switch = 8, router = 4 } :: { [string]: number }

local function key(a: string, b: string): string
	return if a < b then a .. "|" .. b else b .. "|" .. a
end

local function kindOf(devices: { Device }, id: string): string?
	for _, d in devices do
		if d.id == id then
			return d.kind
		end
	end
	return nil
end

-- Can a cable go from `a` to `b`, given the cables already there? Returns false and why when not.
function NetCheck.canLink(devices: { Device }, links: { Link }, a: string, b: string): (boolean, string?)
	local ka, kb = kindOf(devices, a), kindOf(devices, b)
	if not ka or not kb then
		return false, "no such device"
	end
	if a == b then
		return false, "a cable needs two different devices"
	end
	local used: { [string]: number } = {}
	for _, l in links do
		if key(l[1], l[2]) == key(a, b) then
			return false, "they are already connected"
		end
		used[l[1]] = (used[l[1]] or 0) + 1
		used[l[2]] = (used[l[2]] or 0) + 1
	end
	for _, pair in { { a, ka }, { b, kb } } do
		if (used[pair[1]] or 0) >= NetCheck.PORTS[pair[2]] then
			return false, `{pair[1]} has no free port`
		end
	end
	if (ka == "pc" or ka == "server") and (kb == "pc" or kb == "server") then
		return false, "end devices connect to a switch, not to each other"
	end
	return true, nil
end

-- Right when every cable is allowed and the cables are exactly the required ones. `links` comes from a client, so
-- it is checked for shape and size first.
function NetCheck.grade(devices: { Device }, required: { Link }, links: any): boolean
	if type(links) ~= "table" or #links > NetCheck.MAX_LINKS then
		return false
	end
	local built: { Link } = {}
	for _, l in links do
		if type(l) ~= "table" or type(l[1]) ~= "string" or type(l[2]) ~= "string" then
			return false
		end
		if not NetCheck.canLink(devices, built, l[1], l[2]) then
			return false
		end
		table.insert(built, { l[1], l[2] })
	end
	if #built ~= #required then
		return false
	end
	local want: { [string]: boolean } = {}
	for _, l in required do
		want[key(l[1], l[2])] = true
	end
	for _, l in built do
		if not want[key(l[1], l[2])] then
			return false
		end
	end
	return true
end

return NetCheck
