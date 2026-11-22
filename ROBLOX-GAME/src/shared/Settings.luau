--!strict
-- Player settings (menu) and private lobby codes: defaults, limits and validation. Pure, so the server can trust
-- nothing a client sends and the tests can run in Lune.

export type Values = { fov: number, sensitivity: number, volume: number, ambience: number, showFps: boolean,
	graphics: string, bobbing: boolean, keys: { [string]: string } }

-- Keys come from Keybinds (no `require` in shared modules: whoever uses Settings hands it in once with useKeybinds).
local Keybinds: any = nil

local Settings = {}

-- name -> { min, max, step, default }
Settings.RANGES = ({
	fov = { 60, 100, 5, 70 },
	sensitivity = { 0.2, 2, 0.1, 1 },
	volume = { 0, 1, 0.1, 0.8 },
	ambience = { 0, 1, 0.1, 0.8 },
}) :: { [string]: { number } }

Settings.GRAPHICS = { "low", "medium", "high" } -- shadows and screen effects (applied by the client)

function Settings.useKeybinds(k: any)
	Keybinds = k
end

local function snap(name: string, value: number): number
	local r = Settings.RANGES[name]
	local stepped = r[1] + math.round((value - r[1]) / r[3]) * r[3]
	-- Round away float noise (0.30000000000000004).
	return math.clamp(math.round(stepped * 1000) / 1000, r[1], r[2])
end

function Settings.clean(raw: any): Values
	local t = if type(raw) == "table" then raw else {}
	local out = {} :: any
	for name, r in Settings.RANGES do
		local v = t[name]
		out[name] = if type(v) == "number" and v == v then snap(name, v) else r[4]
	end
	out.showFps = t.showFps == true
	out.bobbing = t.bobbing ~= false
	out.graphics = if type(t.graphics) == "string" and table.find(Settings.GRAPHICS, t.graphics) then t.graphics
		else "high"
	out.keys = if Keybinds then Keybinds.clean(t.keys) else {}
	return out :: Values
end

-- One step up (+1) or down (-1) of a numeric setting.
function Settings.step(name: string, value: number, direction: number): number
	return snap(name, value + Settings.RANGES[name][3] * direction)
end

-- Lobby codes: 5 characters without look-alikes (no 0/O, 1/I).
local ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

function Settings.cleanCode(raw: any): string?
	if type(raw) ~= "string" then
		return nil
	end
	local code = string.upper((string.gsub(raw, "%s", "")))
	if #code ~= 5 or string.find(code, "[^A-Z0-9]") then
		return nil
	end
	return code
end

-- `random(n)` returns an integer from 1 to n (math.random in the game).
function Settings.newCode(random: (n: number) -> number): string
	local chars = {}
	for i = 1, 5 do
		local k = random(#ALPHABET)
		chars[i] = string.sub(ALPHABET, k, k)
	end
	return table.concat(chars)
end

return Settings
