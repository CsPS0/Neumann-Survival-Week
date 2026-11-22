-- Compiles every .luau file under src/ with Lune to catch syntax errors without Roblox: `lune run tools/compile-check`.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local failed, total = 0, 0

local function walk(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif string.match(name, "%.luau$") then
			total += 1
			local ok, err = pcall(luau.compile, fs.readFile(path))
			if not ok then
				failed += 1
				print(`FAIL {path}: {err}`)
			end
		end
	end
end

walk("src")
print(`{total - failed} of {total} files compile`)
process.exit(if failed > 0 then 1 else 0)
