--!strict
-- What every room is for and what it is called in the real school. Generated from the map editor's school-map.json
-- by tools/map-editor/import-map.luau (the block between the markers); only "other" rooms are closed.

export type Kind = string -- "normal" | "computer" | "lab" | "office" | "library" | "wc" | "gym" | "changing"
-- | "entrance" | "dining" | "kitchen" | "storage" | "medical" | "corridor" | "other" (closed)

local Rooms = {}

Rooms.CLOSED_MESSAGE = "Not available in the demo."

-- BEGIN GENERATED MAP (tools/map-editor/import-map.luau from school-map.json: edit the map, not this block)
local KIND: { [string]: Kind } = {
	["10"] = "office",
	["105/a"] = "office",
	["105/b"] = "office",
	["109"] = "normal",
	["11"] = "office",
	["113"] = "normal",
	["114"] = "normal",
	["12"] = "office",
	["120"] = "normal",
	["121"] = "normal",
	["125"] = "normal",
	["129"] = "normal",
	["13"] = "office",
	["133"] = "normal",
	["14"] = "normal",
	["15"] = "office",
	["16/a"] = "storage",
	["16/b"] = "storage",
	["19"] = "storage",
	["19/b"] = "storage",
	["20"] = "storage",
	["201"] = "office",
	["205"] = "normal",
	["21"] = "storage",
	["225"] = "normal",
	["229"] = "normal",
	["23"] = "normal",
	["233"] = "normal",
	["24"] = "normal",
	["27"] = "gym",
	["28"] = "normal",
	["3"] = "office",
	["30"] = "storage",
	["31"] = "changing",
	["32"] = "storage",
	["33"] = "normal",
	["34"] = "changing",
	["35"] = "normal",
	["38"] = "storage",
	["39"] = "office",
	["40"] = "changing",
	["41"] = "changing",
	["42"] = "normal",
	["42/b"] = "normal",
	["43"] = "normal",
	["44"] = "normal",
	["45"] = "normal",
	["46"] = "normal",
	["5"] = "normal",
	["8"] = "office",
	["Bejárat"] = "entrance",
	["Büfé"] = "kitchen",
	["Cisco"] = "lab",
	["Ebédlő"] = "dining",
	["Fejl."] = "office",
	["GT1"] = "computer",
	["GT10"] = "computer",
	["GT11-12"] = "computer",
	["GT2"] = "computer",
	["GT3-GT4"] = "computer",
	["GT47"] = "computer",
	["GT5"] = "computer",
	["GT6"] = "computer",
	["GT7"] = "computer",
	["GT8"] = "computer",
	["GT9"] = "computer",
	["Gazd."] = "office",
	["Igazgatói Iroda"] = "office",
	["Konyha"] = "kitchen",
	["Könyvtár"] = "library",
	["Porta"] = "entrance",
	["Tanári"] = "office",
	["Tornaterem"] = "gym",
	["Tárgyaló"] = "office",
	["WC"] = "wc",
}
local REAL: { [string]: string } = {
	["201"] = "Iskolatitkár",
	["31"] = "Lány Öltöző",
	["34"] = "Fiú Öltöző",
	["40"] = "Fiú Öltöző",
	["41"] = "Fiú Öltöző",
}
-- END GENERATED MAP

function Rooms.typeOf(label: string): Kind
	return KIND[label] or "other"
end

function Rooms.isOpen(label: string): boolean
	return Rooms.typeOf(label) ~= "other"
end

-- The room's name in the real school ("Lány öltöző"), or its code when it has none.
function Rooms.realName(label: string): string
	return REAL[label] or label
end

return Rooms
