-- Writes build/manifest.sync.json: every script in src/ with where it lives in the place, for the fast Studio sync
-- (an Edit-datamodel script fetches each file from `python -m http.server 34877` and sets its Source).
-- Run from ROBLOX-GAME/: `lune run tools/sync-manifest` (after adding or renaming a script).
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local FOLDERS = {
	{ "src/shared", "ReplicatedStorage.Shared" },
	{ "src/server", "ServerScriptService.Server" },
	{ "src/server/Campaign", "ServerScriptService.Server.Campaign" },
	{ "src/client", "StarterPlayer.StarterPlayerScripts.Client" },
}

local out = {}
for _, folder in FOLDERS do
	local names = fs.readDir(folder[1])
	table.sort(names)
	for _, file in names do
		local path = `{folder[1]}/{file}`
		if fs.isFile(path) and string.sub(file, -5) == ".luau" then
			local name = string.sub(file, 1, -6)
			local class = "ModuleScript"
			if string.sub(name, -7) == ".server" then
				class, name = "Script", string.sub(name, 1, -8)
			elseif string.sub(name, -7) == ".client" then
				class, name = "LocalScript", string.sub(name, 1, -8)
			end
			table.insert(out, { path = path, parent = folder[2], name = name, class = class })
		end
	end
end
fs.writeFile("build/manifest.sync.json", serde.encode("json", out))
print(`build/manifest.sync.json: {#out} scripts`)
