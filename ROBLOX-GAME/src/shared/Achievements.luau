--!strict
-- The achievements (HORROR-GAME/scripts/achievements.gd, the ones this one-day port can trigger, plus the school's
-- games). The server awards them (src/server/AchievementService.luau) and keeps them per player.

local Achievements = {}

export type Info = { name: string, about: string }

Achievements.ORDER = {
	"first_lesson", "straight_a", "hello_world", "net_admin", "key_collector", "detective", "right_suspect",
	"good_boy", "dog_walker", "explorer", "ping_pong", "hoops", "free_spirit",
	"ending_1", "ending_2", "ending_3", "ending_4", "ending_5", "ending_6", "ending_7", "ending_8", "ending_9",
	"ending_10", "completionist",
}

Achievements.ENDINGS = 10 -- story endings (CampaignData.ENDINGS)

Achievements.LIST = {
	first_lesson = { name = "First Day", about = "Sit a test in a lesson." },
	straight_a = { name = "Straight A", about = "Get every task of a test right." },
	hello_world = { name = "Hello, World!", about = "Write a program that works in the programming lesson." },
	net_admin = { name = "Cable Guy", about = "Cable a network right in the networking lesson." },
	key_collector = { name = "Key Collector", about = "Borrow 5 different keys from the porter." },
	detective = { name = "Detective", about = "Find every clue in one story run." },
	right_suspect = { name = "Right Suspect", about = "Name the entity correctly." },
	good_boy = { name = "Good Boy", about = "Pet Csoki." },
	dog_walker = { name = "Dog Walker", about = "Give Csoki a biscuit and take it for a walk." },
	explorer = { name = "Explorer", about = "Walk into 30 different rooms in one visit." },
	ping_pong = { name = "Table Tennis", about = "Win a game of ping pong in the Aula." },
	hoops = { name = "Hoops", about = "Score 5 baskets in the gym." },
	free_spirit = { name = "Free Spirit", about = "Roam the school in free roam." },
	ending_1 = { name = "Caught", about = "Reach ending 1." },
	ending_2 = { name = "Banished", about = "Reach ending 2." },
	ending_3 = { name = "Expelled", about = "Reach ending 3." },
	ending_4 = { name = "Top Student", about = "Reach ending 4." },
	ending_5 = { name = "Ran Away", about = "Reach ending 5." },
	ending_6 = { name = "Pact", about = "Reach ending 6." },
	ending_7 = { name = "Expelled at Dawn", about = "Reach ending 7." },
	ending_8 = { name = "Wrong Person", about = "Reach ending 8." },
	ending_9 = { name = "Destroyed", about = "Reach ending 9." },
	ending_10 = { name = "Safe at Home", about = "Reach ending 10." },
	completionist = { name = "Completionist", about = "See all 9 endings." },
} :: { [string]: Info }

Achievements.EXPLORER_ROOMS = 30
Achievements.KEYS = 5
Achievements.BASKETS = 5

function Achievements.isKnown(id: string): boolean
	return Achievements.LIST[id] ~= nil
end

-- Adds `id` to a saved list (a set of ids). Returns true when it is new. Ending achievements also bring
-- "completionist" once all ten are there (returned as a second new id).
function Achievements.add(have: { [string]: boolean }, id: string): (boolean, string?)
	if not Achievements.isKnown(id) or have[id] then
		return false, nil
	end
	have[id] = true
	if string.sub(id, 1, 7) == "ending_" and not have.completionist then
		for i = 1, Achievements.ENDINGS do
			if not have[`ending_{i}`] then
				return true, nil
			end
		end
		have.completionist = true
		return true, "completionist"
	end
	return true, nil
end

-- A saved value from a DataStore (any shape) as a clean set of known ids.
function Achievements.clean(saved: any): { [string]: boolean }
	local have = {}
	if type(saved) == "table" then
		for id, v in saved do
			if type(id) == "string" and v == true and Achievements.isKnown(id) then
				have[id] = true
			end
		end
	end
	return have
end

return Achievements
