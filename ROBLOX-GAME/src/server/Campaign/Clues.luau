-- Clues: papers on tables in empty rooms, in three waves (at the start, halfway through the lessons, and the
-- afternoon in the after-hours rooms and the staff room). Every clue describes the culprit (clues.gd TRAITS).
-- A clue read by anyone joins the team's list.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CampaignData = require(ReplicatedStorage.Shared.CampaignData)
local Pickups = require(script.Parent.Pickups)

local Clues = {}
Clues.__index = Clues

export type Run = {
	culprit: string,
	count: number,
	folder: Instance,
	onFound: (player: Player, text: string) -> (),
	takePaper: (player: Player, text: string) -> boolean, -- into the reader's papers; false = no room, it stays
	usedRooms: { [string]: boolean },
}

function Clues.new(run: Run)
	local self = setmetatable({}, Clues)
	self.run = run
	self.waiting = {} :: { { room: string, floor: number, text: string } } -- planned, not spawned yet
	self.live = {} :: { [Model]: { room: string, floor: number } }
	self.counted = {} :: { [Model]: boolean } -- read, but the paper is still lying there (no room)
	-- Pick `count` different traits of the culprit, spread over the 10 (two per kind).
	local order = {}
	for k = 1, 10 do
		order[k] = k
	end
	for k = 10, 2, -1 do
		local j = math.random(k)
		order[k], order[j] = order[j], order[k]
	end
	self.texts = {}
	for k = 1, run.count do
		self.texts[k] = CampaignData.TRAITS[run.culprit][order[k]]
	end
	return self
end

local function shuffled(list: { any }): { any }
	local out = table.clone(list)
	for k = #out, 2, -1 do
		local j = math.random(k)
		out[k], out[j] = out[j], out[k]
	end
	return out
end

-- Spawns `n` of the remaining clue texts in free rooms from `rooms`.
function Clues:spawn(n: number, rooms: { CampaignData.Place })
	local candidates = shuffled(rooms)
	local spawned = 0
	for _, place in candidates do
		if spawned >= n or #self.texts == 0 then
			break
		end
		if not self.run.usedRooms[place.room] then
			local at = Pickups.spot(place.floor, place.room, math.random(-10, 10) / 10, math.random(-10, 10) / 10)
			if at then
				self.run.usedRooms[place.room] = true
				local text = table.remove(self.texts, 1) :: string
				local model = Pickups.paper(self.run.folder, "Clue", at, "Clue", function(player, model)
					if not self.live[model] then
						return
					end
					if not self.counted[model] then
						self.counted[model] = true
						self.run.onFound(player, text) -- the team has the clue from the first read
					end
					if self.run.takePaper(player, text) then
						self.live[model] = nil
						self.counted[model] = nil
						model:Destroy()
					end
				end)
				self.live[model] = { room = place.room, floor = place.floor }
				spawned += 1
			end
		end
	end
end

-- Wave sizes for `count` clues: a third now, a third halfway, the rest in the afternoon.
function Clues:wave(k: number)
	local total = self.run.count
	local per = math.ceil(total / 3)
	if k == 3 then
		local after = { CampaignData.STORY.staffClue }
		for _, p in CampaignData.AFTER_ROOMS do
			table.insert(after, p)
		end
		self:spawn(#self.texts, after)
		if #self.texts > 0 then
			self:spawn(#self.texts, CampaignData.CLUE_ROOMS)
		end
	else
		self:spawn(math.min(per, #self.texts), CampaignData.CLUE_ROOMS)
	end
end

-- The room of a clue still lying around (for Easy's exact guidance), or nil.
function Clues:nextRoom(): string?
	for model, place in self.live do
		if not self.counted[model] then
			return place.room
		end
	end
	return nil
end

function Clues:nextPosition(): Vector3?
	for model in self.live do
		if self.counted[model] then
			continue
		end
		local paper = model:FindFirstChild("Paper") :: BasePart?
		if paper then
			return paper.Position
		end
	end
	return nil
end

return Clues
