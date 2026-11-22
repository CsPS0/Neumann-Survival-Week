-- Runs every tests/*.spec.luau with Lune: `lune run tests/run` from ROBLOX-GAME/.
-- A spec returns function(t); t.test(name, fn) registers a test, t.eq / t.near / t.truthy assert.
local fs = require("@lune/fs")
local process = require("@lune/process")

local passed, failed = 0, 0

local function show(value: any): string
	return if type(value) == "string" then string.format("%q", value) else tostring(value)
end

local t = {}

function t.eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "eq"}: expected {show(expected)}, got {show(actual)}`, 2)
	end
end

function t.near(actual: number, expected: number, tolerance: number, msg: string?)
	if type(actual) ~= "number" or math.abs(actual - expected) > tolerance then
		error(`{msg or "near"}: expected {expected} +- {tolerance}, got {show(actual)}`, 2)
	end
end

function t.truthy(value: any, msg: string?)
	if not value then
		error(`{msg or "truthy"}: got {show(value)}`, 2)
	end
end

local files = {}
for _, name in fs.readDir("tests") do
	if string.match(name, "%.spec%.luau$") then
		table.insert(files, name)
	end
end
table.sort(files)

for _, name in files do
	local ok, spec = pcall(require, "./" .. string.gsub(name, "%.luau$", ""))
	if not ok then
		failed += 1
		print(`FAIL {name} (load): {spec}`)
		continue
	end
	t.test = function(testName: string, fn: () -> ())
		local good, err = pcall(fn)
		if good then
			passed += 1
		else
			failed += 1
			print(`FAIL {name} {testName}: {err}`)
		end
	end
	spec(t)
end

print(`{passed} passed, {failed} failed`)
process.exit(if failed > 0 then 1 else 0)
