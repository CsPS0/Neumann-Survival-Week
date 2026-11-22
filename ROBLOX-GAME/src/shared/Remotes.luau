--!strict
-- Names of the RemoteEvents in ReplicatedStorage.Remotes. The server creates them at boot; clients WaitForChild them.

local Remotes = {}

Remotes.NAMES = {
	"StartRound", -- client -> server: (mode, entity)
	"BackToLobby", -- client -> server
	"Sprint", -- client -> server: (sprinting)
	"Torch", -- client -> server: (on)
	"Flash", -- client -> server: (look direction)
	"Breath", -- client -> server: (holding)
	"LeaveLocker", -- client -> server
	"CallMeeting", -- client -> server
	"Vote", -- client -> server: (tag or "skip")
	"Role", -- server -> one client: (role, partner tag?)
	"Banner", -- server -> clients: (text, seconds?)
	"MeetingStarted", -- server -> clients: (info)
	"MeetingResult", -- server -> clients: (ejected tag?, wasEntity?, counts)
	"Flicker", -- server -> clients: (position, seconds)
	"Stunned", -- server -> one client: (seconds)
	"Sound", -- server -> clients: (name, position?)
	"CreateLobby", -- client -> server: make a private lobby and go there
	"JoinLobby", -- client -> server: (code)
	"SaveSettings", -- client -> server: (settings table)
	"Settings", -- server -> one client: (saved settings table)
	-- Story campaign
	"CampaignState", -- server -> clients: (snapshot table)
	"QuizStart", -- server -> one client: ({lesson, subject, mode, questions = {{text, options?}}})
	"QuizAnswer", -- client -> server: (lesson, questionIndex, answer string or option index)
	"QuizResult", -- server -> one client: ({lesson, questionIndex?, correct?, done?, right, total})
	"Dialogue", -- server -> one client: ({name, lines})
	"TeamVote", -- server -> clients: ({id, title, options, endsAt} or nil to close)
	"TeamVoteCast", -- client -> server: (id, optionIndex)
	"Keypad", -- server -> one client: (open)
	"KeypadEnter", -- client -> server: (code string)
	"Ending", -- server -> clients: ({id, title, color, text, stats})
	-- Hand, pockets and bag (story)
	"Inventory", -- server -> one client: ({inv, bagDropped} or nil)
	"BagAction", -- client -> server: (op, args?) op = drop | close | move | floor | use
	"BagView", -- server -> one client: ({owner, ownerName, bag} or nil when closed)
	-- Achievements, the school's games, free roam
	"Achievements", -- server -> one client: (list of unlocked ids, newly unlocked id?)
	"PingPongHit", -- client -> server: swing the paddle
	"PingPongState", -- server -> clients: ({active, a, b, t0, dur, score, names, top}) the ball's flight and the score
	"BallThrow", -- client -> server: (look direction) throw the basketball you hold
	"AdminAction", -- client -> server: (op, args) free roam admin panel
	"Grab", -- server -> the held player: (kind, data) the entity holds you (Grab.luau)
	"StoryScene", -- server -> clients: (kind, data) story cards: "intro", "slip", "home", "back" (StoryScenes.luau)
	"Struggle", -- client -> server: one press of the defend key while held
}

-- UnreliableRemoteEvents: frequent updates where a lost packet does not matter (the next one replaces it).
Remotes.UNRELIABLE = {
	"Look", -- client -> server: (pitch in radians), 15 Hz; server -> other clients: (player, pitch)
}

return Remotes
