--!strict
-- Story data for the campaign, ported from HORROR-GAME/scripts/lessons.gd, clues.gd and endings.gd.
-- All 8 teachers are invented; no real person's name belongs in this project.

export type Question = { text: string, options: { string }, correct: number, extra: { string } }
-- How a subject is answered at the desk: "choice" (tick one), "written" (write the answer on the paper; Easy ticks
-- instead), "code" (write a small program on the PC: src/shared/CodeCheck.luau) or "network" (cable the devices on
-- the desk: src/shared/NetCheck.luau).
export type Kind = "choice" | "written" | "code" | "network"
export type CodeTask = { text: string, expect: string, starter: string? }
export type NetTask = { text: string, devices: { { id: string, kind: string } }, links: { { string } } }
export type Subject = { room: string, floor: number, teachers: { string }, kind: Kind, questions: { Question },
	code: { CodeTask }?, network: { NetTask }? }

local CampaignData = {}

CampaignData.TEACHERS = {
	karpati = "Kárpáti Lajos",
	szentgyorgyi = "Dr. Szentgyörgyi Aranka",
	halmos = "Halmos Ervin",
	voros = "Vörös Ildikó",
	pasztor = "Pásztor Margit",
	onodi = "Ónodi Bence",
	fekete = "Fekete Zsombor",
	lazar = "Lázár Tivadar",
} :: { [string]: string }

-- Accusation order.
CampaignData.SUSPECTS = { "karpati", "szentgyorgyi", "halmos", "voros", "pasztor", "onodi", "fekete", "lazar" }

local function q(text: string, options: { string }, correct: number, extra: { string }?): Question
	return { text = text, options = options, correct = correct, extra = extra or {} }
end

CampaignData.SUBJECTS = {
	Maths = { room = "23", floor = 0, teachers = { "karpati", "szentgyorgyi" }, kind = "written", questions = {
		q("What is 7 x 8?", { "54", "56", "63", "48" }, 2),
		q("Solve: x + 9 = 20", { "x = 9", "x = 11", "x = 29", "x = 10" }, 2, { "11" }),
		q("What is 15% of 200?", { "15", "20", "30", "25" }, 3),
		q("Derivative of x squared?", { "x", "2x", "x squared", "2" }, 2),
	} },
	Literature = { room = "113", floor = 1, teachers = { "voros" }, kind = "choice", questions = {
		q("Who wrote 'The Raven'?", { "Poe", "Petőfi", "Dickens", "Wilde" }, 1, { "Edgar Allan Poe", "Edgar Poe" }),
		q("A comparison using 'like' or 'as' is a...", { "metaphor", "simile", "rhyme", "pun" }, 2),
		q("Who wrote 'Toldi'?", { "Arany János", "Jókai Mór", "Ady Endre", "Kosztolányi" }, 1, { "Arany", "János Arany" }),
		q("How many lines does a sonnet have?", { "10", "12", "14", "16" }, 3, { "fourteen" }),
	} },
	Programming = { room = "GT11-12", floor = 0, teachers = { "onodi" }, kind = "code", questions = {
		q("Which loop runs while a condition holds?", { "for-each", "while", "switch", "try" }, 2, { "while loop" }),
		q("What does 'int x = 5 / 2;' store in C#?", { "2.5", "3", "2", "0" }, 3),
		q("Which is NOT a loop keyword?", { "for", "while", "foreach", "when" }, 4),
		q("An array index usually starts at...", { "0", "1", "-1", "2" }, 1, { "zero" }),
	}, code = {
		{ text = "Write a program that prints: Hello, World!", expect = "Hello, World!" },
		{ text = "Print the sum of 17 and 25.", expect = "42" },
		{ text = "Store 7 in a variable called x, then print x times 6.", expect = "42", starter = "x = " },
		{ text = "Print the numbers 1 to 5, one per line, with a for loop.", expect = "1\n2\n3\n4\n5",
			starter = "for i in range(" },
		{ text = 'Make a variable name = "Neumann" and print: Hello, Neumann', expect = "Hello, Neumann" },
		{ text = "Add up the numbers 1 to 10 with a loop and print the total.", expect = "55",
			starter = "total = 0\n" },
	} },
	Physics = { room = "28", floor = 0, teachers = { "halmos" }, kind = "written", questions = {
		q("Unit of force?", { "Joule", "Newton", "Watt", "Pascal" }, 2, { "N", "newtons" }),
		q("Speed of light is about...", { "300 km/s", "3000 km/s", "300 000 km/s", "30 000 km/s" }, 3,
			{ "300000", "299792", "299792 km/s" }),
		q("Ohm's law: U = ?", { "I / R", "I x R", "R / I", "I + R" }, 2,
			{ "R x I", "I * R", "R * I", "I times R", "IR" }),
		q("What does a fuse protect against?", { "Cold", "Overcurrent", "Noise", "Rust" }, 2,
			{ "over current", "too much current", "excess current", "overload", "short circuit" }),
	} },
	History = { room = "109", floor = 1, teachers = { "lazar" }, kind = "choice", questions = {
		q("Year of the Hungarian 1848 revolution?", { "1818", "1848", "1867", "1914" }, 2),
		q("Who was the first king of Hungary?", { "Saint Stephen", "Matthias", "Árpád", "Louis I" }, 1,
			{ "Stephen", "Szent István", "István", "St. Stephen", "Stephen I" }),
		q("The Battle of Mohács was in...", { "1456", "1526", "1686", "1241" }, 2),
		q("The Compromise (Kiegyezés) was in...", { "1848", "1867", "1920", "1900" }, 2),
	} },
	English = { room = "121", floor = 1, teachers = { "pasztor" }, kind = "choice", questions = {
		q("Past tense of 'go'?", { "goed", "went", "gone", "going" }, 2),
		q("'Their', 'there' or 'they're': '___ going home.'", { "Their", "There", "They're", "Theyre" }, 3,
			{ "they are" }),
		q("Plural of 'child'?", { "childs", "childes", "children", "child" }, 3),
		q("Which is a question word?", { "because", "where", "under", "while" }, 2),
	} },
	Networks = { room = "GT2", floor = 0, teachers = { "fekete" }, kind = "network", questions = {
		q("Default port of HTTP?", { "21", "80", "443", "25" }, 2, { "port 80" }),
		q("What does DNS do?", { "Encrypts data", "Names to addresses", "Sends mail", "Blocks ads" }, 2,
			{ "name to address", "names to IP addresses", "translates names to addresses", "domain names to IP addresses" }),
		q("An IPv4 address has how many bytes?", { "2", "4", "6", "8" }, 2, { "four" }),
		q("Which device connects different networks?", { "Switch", "Hub", "Router", "Cable" }, 3, { "a router" }),
	}, network = {
		{ text = "Connect both PCs to the switch.",
			devices = { { id = "PC1", kind = "pc" }, { id = "PC2", kind = "pc" }, { id = "Switch", kind = "switch" } },
			links = { { "PC1", "Switch" }, { "PC2", "Switch" } } },
		{ text = "Connect the three PCs to the switch and the switch to the router.",
			devices = { { id = "PC1", kind = "pc" }, { id = "PC2", kind = "pc" }, { id = "PC3", kind = "pc" },
				{ id = "Switch", kind = "switch" }, { id = "Router", kind = "router" } },
			links = { { "PC1", "Switch" }, { "PC2", "Switch" }, { "PC3", "Switch" }, { "Switch", "Router" } } },
		{ text = "Two classrooms: PC1 on Switch1, PC2 on Switch2, and both switches on the router.",
			devices = { { id = "PC1", kind = "pc" }, { id = "PC2", kind = "pc" }, { id = "Switch1", kind = "switch" },
				{ id = "Switch2", kind = "switch" }, { id = "Router", kind = "router" } },
			links = { { "PC1", "Switch1" }, { "PC2", "Switch2" }, { "Switch1", "Router" }, { "Switch2", "Router" } } },
		{ text = "Put the PC and the web server on the switch, the switch on the router, the router on the internet.",
			devices = { { id = "PC", kind = "pc" }, { id = "Server", kind = "server" }, { id = "Switch", kind = "switch" },
				{ id = "Router", kind = "router" }, { id = "Internet", kind = "cloud" } },
			links = { { "PC", "Switch" }, { "Server", "Switch" }, { "Switch", "Router" }, { "Router", "Internet" } } },
	} },
} :: { [string]: Subject }

CampaignData.TIMETABLES = {
	{ "Maths", "Literature", "Programming", "Physics", "History", "English", "Networks" },
	{ "Programming", "Maths", "English", "History", "Networks", "Physics", "Literature" },
	{ "Physics", "English", "Maths", "Networks", "Literature", "Programming", "History" },
}

-- The teacher of a subject; a subject with two teachers alternates by timetable row.
function CampaignData.teacherOf(subject: string, row: number): string
	local list = CampaignData.SUBJECTS[subject].teachers
	return list[(row - 1) % #list + 1]
end

-- Clue texts per teacher: initials, ink, smell, place, item (two of each). All clues of a run describe the culprit.
CampaignData.TRAITS = {
	karpati = {
		"A detention slip signed 'K.L.'.", "A Maths test margin note, initialled K.L.",
		"Notes in tiny slanted green ink.", "Green ink again, slanted so far it almost lies down.",
		"The page smells faintly of sulphur, like the old Chemistry club.", "Sulphur on a glove. Someone still visits Lab 14.",
		"The caretaker's log: 'Mr K. in Lab 14 again, 21:40.'", "Seen leaving Lab 14 after dark, every night.",
		"A brass key tagged 14 on a lanyard.", "Chalk-dust fingerprints and a brass key.",
	},
	szentgyorgyi = {
		"A graded test signed 'Sz.A.'.", "A homework sheet initialled Sz.A. with a gold star.",
		"Red pen, every correction circled and starred.", "Red-ink circles again, one pressed through the paper.",
		"Chalk dust and rose perfume cling to the page.", "Rose perfume on a torn handkerchief.",
		"Seen in the Aula by the altar after dark.", "'Dr Sz. in the Aula, 23:15', says the caretaker.",
		"A charm bracelet with a tiny silver bell.", "A silver bell charm, snapped off a bracelet.",
	},
	halmos = {
		"A lab report signed 'H.E.'.", "A circuit diagram initialled H.E.",
		"Ruler-straight pencil lines, never an eraser mark.", "More ruler-straight pencil: a wiring plan of the school.",
		"The page smells of ozone, like air after a spark.", "Ozone on a cable tie. Something was switched on and off.",
		"Seen at the fuse box in room 24, at night.", "'Mr H. at the fuse box, 01:50', says the log.",
		"A multimeter with one taped probe.", "A spool of fuse wire and a taped probe.",
	},
	voros = {
		"A reading list signed 'V.I.'.", "An essay returned with the initials V.I.",
		"Looped purple ink with poems in the margins.", "Purple ink again, a verse about hunger.",
		"A page that smells of lavender and old paper.", "Lavender and dust on the cover.",
		"Always in the library after hours, the log says.", "'Ms V. in the library, 23:10', says the caretaker.",
		"A dog-eared Poe with a hall pass for a bookmark.", "A poetry collection with a pressed black feather.",
	},
	pasztor = {
		"A vocabulary test signed 'P.M.'.", "A dictation sheet initialled P.M.",
		"Neat blue cursive with every key word underlined.", "Blue cursive again, underlined three times.",
		"Peppermint tea: the page smells of it.", "A peppermint tea stain on a staff memo.",
		"Seen in the staff room after hours, talking to herself in English.", "'Ms P. in the staff room, 22:30', says the log.",
		"An English-Hungarian dictionary with a red ribbon.", "A dictionary with every 'ghost' entry underlined.",
	},
	onodi = {
		"A commit log signed 'Ó.B.'.", "A grade sheet initialled Ó.B.",
		"Block capitals, like comments in code.", "More block capitals: 'DO NOT TOUCH. Ó.'",
		"Solder and coffee: the page reeks of both.", "A burnt-solder smell on a cable tie.",
		"The computer lab lit up at 03:00, every night.", "'Mr Ó. in the computer lab, 03:05', says the log.",
		"A USB stick labelled 'ROOT'.", "A stack of old keyboards and a USB stick labelled 'ROOT'.",
	},
	fekete = {
		"A network diagram signed 'F.Zs.'.", "A router config initialled F.Zs.",
		"Tiny diagrams of boxes and arrows in every margin.", "Boxes and arrows again, all pointing at one room.",
		"Warm dust, like the back of an old router.", "Warm router dust on a glove.",
		"Seen pulling cable in the server room at 03:00.", "'Mr F. in the server room, 03:10', says the log.",
		"A spool of network cable cut to odd lengths.", "Cable offcuts laid out in a spiral.",
	},
	lazar = {
		"A circular signed 'L.T.'.", "A history test initialled L.T.",
		"Official black fountain-pen ink.", "Fountain-pen ink and a perfect, cold signature.",
		"Cigar smoke and floor polish cling to the page.", "Old paper and smoke on a school crest ring.",
		"The old archive light on, and nobody seen leaving.", "'Mr L. in the archive, all night', says the log.",
		"A master keyring and a school crest ring.", "A crest ring and a key to the archive.",
	},
} :: { [string]: { string } }

CampaignData.CHAT = {
	karpati = "Maths is just rules for things that fall. Mind your step.",
	szentgyorgyi = "Check your working. Twice. The answer is never the point.",
	halmos = "If it hums, it is working. If it stops humming, run.",
	voros = "Read something every day. Stories are the only honest ghosts.",
	pasztor = "Say it again, slowly. Languages forgive the patient.",
	onodi = "If it is not working, turn it off and on. Works on most things.",
	fekete = "Everything is a network. Even this corridor. Even you.",
	lazar = "Attendance matters. I see everything in this school.",
} :: { [string]: string }

-- The culprit lets more slip as the day goes on (one line per break so far, capped at 3).
CampaignData.STRANGE = {
	"... Did you hear that? No. Of course not.",
	"... I do not sleep much anymore. The school is so quiet at night. Is it not?",
	"... You are looking at me. Everyone is. Why is everyone looking?",
}

export type Ending = { title: string, color: { number }, text: string }

CampaignData.ENDINGS = {
	{ title = "Caught", color = { 0.9, 0.2, 0.2 },
		text = "It was never a ghost. It was someone who knew your name.\nThe school keeps one more student." },
	{ title = "Banished", color = { 0.5, 1.0, 0.6 },
		text = "The bell rings once and the whispers stop.\nThe school is free. The teacher wakes with no memory of the day." },
	{ title = "Expelled", color = { 1.0, 0.75, 0.3 },
		text = "Your parents are called. The investigation ends at the front gate.\nSomething in the building is relieved." },
	{ title = "Top student", color = { 0.4, 0.8, 1.0 },
		text = "Perfect marks, a banished demon and a school that finally sleeps.\nThe principal calls it a record year." },
	{ title = "Ran away", color = { 0.8, 0.8, 0.85 },
		text = "You walk out and keep walking. You will never know who it was.\nThe school stays open." },
	{ title = "Pact", color = { 0.75, 0.3, 0.9 },
		text = "The deal is simple: it leaves you alone, you leave it the school.\nYou graduate on time." },
	{ title = "Overtime", color = { 0.6, 0.6, 0.5 },
		text = "The night ends without an answer. Morning comes.\nThe corridors are still listening." },
	{ title = "Wrong person", color = { 1.0, 0.4, 0.5 },
		text = "You point at the wrong teacher and the whole school sees it.\nThe real one smiles from the back of the room." },
	{ title = "Destroyed", color = { 1.0, 0.55, 0.2 },
		text = "The demon dies with the body it wore. The whispers stop for good.\nOne chair in the staff room stays empty. Nobody asks why." },
} :: { Ending }

-- What each teacher wears (jacket and trousers, 0-255 RGB): the NPCs by day, and the shreds the entity wears.
CampaignData.LOOKS = {
	karpati = { jacket = { 86, 70, 52 }, trousers = { 60, 58, 56 } },
	szentgyorgyi = { jacket = { 140, 40, 52 }, trousers = { 40, 40, 46 } },
	halmos = { jacket = { 70, 96, 120 }, trousers = { 50, 50, 54 } },
	voros = { jacket = { 100, 60, 120 }, trousers = { 46, 42, 50 } },
	pasztor = { jacket = { 60, 90, 150 }, trousers = { 80, 76, 72 } },
	onodi = { jacket = { 56, 56, 60 }, trousers = { 36, 50, 80 } },
	fekete = { jacket = { 30, 30, 34 }, trousers = { 30, 30, 34 } },
	lazar = { jacket = { 70, 70, 72 }, trousers = { 24, 24, 28 } },
} :: { [string]: { jacket: { number }, trousers: { number } } }

-- The one thing the entity still carries from its host, matching that teacher's "item" clues.
CampaignData.ENTITY_MARKS = {
	karpati = "lanyard_key", -- a brass key tagged 14 on a lanyard
	szentgyorgyi = "bell_bracelet", -- a charm bracelet with a silver bell
	halmos = "fuse_wire", -- a spool of fuse wire on the belt
	voros = "black_feather", -- a black feather in the hair
	pasztor = "red_ribbon", -- a red ribbon round the neck
	onodi = "usb_lanyard", -- a USB stick on a lanyard
	fekete = "cable_arm", -- network cable wound round one arm
	lazar = "crest_ring", -- a crest ring and a keyring
} :: { [string]: string }

-- Fixed story rooms {label, floor} (main.gd STORY_ROOMS) and the after-hours clue rooms.
export type Place = { room: string, floor: number }

CampaignData.STORY = {
	fuse = { room = "24", floor = 0 },
	safe = { room = "229", floor = 2 },
	lab = { room = "14", floor = 0 },
	staffClue = { room = "33", floor = 0 },
} :: { [string]: Place }
CampaignData.AFTER_ROOMS = ({ { room = "205", floor = 2 }, { room = "GT8", floor = 2 }, { room = "114", floor = 1 } }) :: { Place }
-- Open rooms clue tables and notes may go to (normal and computer rooms that are not story or lesson rooms).
CampaignData.CLUE_ROOMS = ({
	{ room = "5", floor = 0 }, { room = "35", floor = 0 }, { room = "42", floor = 0 }, { room = "43", floor = 0 }, { room = "44", floor = 0 }, { room = "45", floor = 0 }, { room = "46", floor = 0 }, { room = "GT1", floor = 0 },
	{ room = "GT47", floor = 0 }, { room = "120", floor = 1 }, { room = "125", floor = 1 }, { room = "129", floor = 1 }, { room = "133", floor = 1 }, { room = "GT10", floor = 1 }, { room = "225", floor = 2 }, { room = "233", floor = 2 },
	{ room = "GT5", floor = 2 }, { room = "GT6", floor = 2 }, { room = "GT7", floor = 2 }, { room = "GT9", floor = 2 },
}) :: { Place }

return CampaignData
