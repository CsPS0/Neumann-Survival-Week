--!strict
-- The game's keys. Defaults keep everything in reach of the left hand on W A S D (as in the Godot game: Q phone,
-- Tab bag, B bag down...). Players can change them in the settings; a saved choice is checked here (only keys from
-- ALLOWED, never one key for two actions) so a broken save can never lock anyone out.

local Keybinds = {}

export type Action = { id: string, label: string, default: string }

Keybinds.ACTIONS = {
	{ id = "sprint", label = "Sprint", default = "LeftShift" },
	{ id = "crouch", label = "Crouch / slide", default = "C" },
	{ id = "torch", label = "Phone flashlight", default = "F" },
	{ id = "flash", label = "Flash burst", default = "T" },
	{ id = "phone", label = "Phone up / down", default = "Q" },
	{ id = "phoneHands", label = "Phone: one or two hands", default = "R" },
	{ id = "bag", label = "Bag and items", default = "Tab" },
	{ id = "dropBag", label = "Drop the bag", default = "B" },
	{ id = "useItem", label = "Use (power bank)", default = "V" },
	{ id = "meeting", label = "Call a meeting", default = "G" },
	{ id = "menu", label = "Menu", default = "Backquote" },
	{ id = "admin", label = "Admin panel (free roam)", default = "Five" },
} :: { Action }

-- Keys a player may choose: reachable letters, digits and modifiers (no mouse, no Escape: Roblox owns it).
Keybinds.ALLOWED = {
	"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "A", "S", "D", "F", "G", "H", "J", "K", "L", "Z", "X", "C", "V",
	"B", "N", "M", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Zero", "Tab",
	"LeftShift", "RightShift", "LeftControl", "RightControl", "LeftAlt", "CapsLock", "Backquote", "Space",
	"F1", "F2", "F3", "F4",
} :: { string }

-- Keys the game already uses for something fixed: moving, interacting, the pockets.
Keybinds.RESERVED = { W = true, A = true, S = true, D = true, E = true, Space = true, Two = true, Three = true }

local DEFAULTS: { [string]: string } = {}
for _, a in Keybinds.ACTIONS do
	DEFAULTS[a.id] = a.default
end

function Keybinds.default(id: string): string
	return DEFAULTS[id]
end

-- A saved table (any shape) as a full, valid set: every action has one key and no key is used twice.
function Keybinds.clean(raw: any): { [string]: string }
	local out: { [string]: string } = {}
	local used: { [string]: boolean } = {}
	local t = if type(raw) == "table" then raw else {}
	-- Valid choices first, in the order of ACTIONS; then defaults for whatever is missing or taken.
	for _, a in Keybinds.ACTIONS do
		local k = t[a.id]
		if type(k) == "string" and table.find(Keybinds.ALLOWED, k) and not Keybinds.RESERVED[k] and not used[k] then
			out[a.id] = k
			used[k] = true
		end
	end
	for _, a in Keybinds.ACTIONS do
		if not out[a.id] then
			local k = a.default
			if used[k] then
				-- The default was taken by another choice: the first free allowed key.
				for _, alt in Keybinds.ALLOWED do
					if not used[alt] and not Keybinds.RESERVED[alt] then
						k = alt
						break
					end
				end
			end
			out[a.id] = k
			used[k] = true
		end
	end
	return out
end

-- Setting `id` to `key`: if another action had that key, it gets `id`'s old key (a swap).
function Keybinds.assign(keys: { [string]: string }, id: string, key: string): { [string]: string }
	if not table.find(Keybinds.ALLOWED, key) or Keybinds.RESERVED[key] or not DEFAULTS[id] then
		return keys
	end
	local out = table.clone(keys)
	local old = out[id]
	for other, k in out do
		if k == key and other ~= id then
			out[other] = old
		end
	end
	out[id] = key
	return Keybinds.clean(out)
end

-- How a key is shown ("Backquote" -> "`").
function Keybinds.label(key: string): string
	local names = { Backquote = "`", LeftShift = "Shift", RightShift = "R-Shift", LeftControl = "Ctrl",
		RightControl = "R-Ctrl", LeftAlt = "Alt", CapsLock = "Caps", One = "1", Two = "2", Three = "3", Four = "4",
		Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9", Zero = "0" }
	return names[key] or key
end

return Keybinds
