extends RefCounted
## Clue texts that each match exactly one teacher, plus small-talk and the culprit's escalating slips.

const TRAITS := {
	"karpati": [
		"A detention slip signed 'K.L.'.", "A Maths test margin note, initialled K.L.",
		"Notes in tiny slanted green ink.", "Green ink again, slanted so far it almost lies down.",
		"The page smells faintly of sulphur, like the old Chemistry club.", "Sulphur on a glove. Someone still visits Lab 14.",
		"The caretaker's log: 'Mr K. in Lab 14 again, 21:40.'", "Seen leaving Lab 14 after dark, every night.",
		"A brass key tagged 14 on a lanyard.", "Chalk-dust fingerprints and a brass key.",
	],
	"szentgyorgyi": [
		"A graded test signed 'Sz.A.'.", "A homework sheet initialled Sz.A. with a gold star.",
		"Red pen, every correction circled and starred.", "Red-ink circles again, one pressed through the paper.",
		"Chalk dust and rose perfume cling to the page.", "Rose perfume on a torn handkerchief.",
		"Seen in the Aula by the altar after dark.", "'Dr Sz. in the Aula, 23:15', says the caretaker.",
		"A charm bracelet with a tiny silver bell.", "A silver bell charm, snapped off a bracelet.",
	],
	"halmos": [
		"A lab report signed 'H.E.'.", "A circuit diagram initialled H.E.",
		"Ruler-straight pencil lines, never an eraser mark.", "More ruler-straight pencil: a wiring plan of the school.",
		"The page smells of ozone, like air after a spark.", "Ozone on a cable tie. Something was switched on and off.",
		"Seen at the fuse box in room 24, at night.", "'Mr H. at the fuse box, 01:50', says the log.",
		"A multimeter with one taped probe.", "A spool of fuse wire and a taped probe.",
	],
	"voros": [
		"A reading list signed 'V.I.'.", "An essay returned with the initials V.I.",
		"Looped purple ink with poems in the margins.", "Purple ink again, a verse about hunger.",
		"A page that smells of lavender and old paper.", "Lavender and dust on the cover.",
		"Always in the library after hours, the log says.", "'Ms V. in the library, 23:10', says the caretaker.",
		"A dog-eared Poe with a hall pass for a bookmark.", "A poetry collection with a pressed black feather.",
	],
	"pasztor": [
		"A vocabulary test signed 'P.M.'.", "A dictation sheet initialled P.M.",
		"Neat blue cursive with every key word underlined.", "Blue cursive again, underlined three times.",
		"Peppermint tea: the page smells of it.", "A peppermint tea stain on a staff memo.",
		"Seen in the staff room after hours, talking to herself in English.", "'Ms P. in the staff room, 22:30', says the log.",
		"An English-Hungarian dictionary with a red ribbon.", "A dictionary with every 'ghost' entry underlined.",
	],
	"onodi": [
		"A commit log signed 'Ó.B.'.", "A grade sheet initialled Ó.B.",
		"Block capitals, like comments in code.", "More block capitals: 'DO NOT TOUCH. Ó.'",
		"Solder and coffee: the page reeks of both.", "A burnt-solder smell on a cable tie.",
		"The computer lab lit up at 03:00, every night.", "'Mr Ó. in the computer lab, 03:05', says the log.",
		"A USB stick labelled 'ROOT'.", "A stack of old keyboards and a USB stick labelled 'ROOT'.",
	],
	"fekete": [
		"A network diagram signed 'F.Zs.'.", "A router config initialled F.Zs.",
		"Tiny diagrams of boxes and arrows in every margin.", "Boxes and arrows again, all pointing at one room.",
		"Warm dust, like the back of an old router.", "Warm router dust on a glove.",
		"Seen pulling cable in the server room at 03:00.", "'Mr F. in the server room, 03:10', says the log.",
		"A spool of network cable cut to odd lengths.", "Cable offcuts laid out in a spiral.",
	],
	"lazar": [
		"A circular signed 'L.T.'.", "A history test initialled L.T.",
		"Official black fountain-pen ink.", "Fountain-pen ink and a perfect, cold signature.",
		"Cigar smoke and floor polish cling to the page.", "Old paper and smoke on a school crest ring.",
		"The old archive light on, and nobody seen leaving.", "'Mr L. in the archive, all night', says the log.",
		"A master keyring and a school crest ring.", "A crest ring and a key to the archive.",
	],
}

const CHAT := {
	"karpati": "Kárpáti Lajos: Maths is just rules for things that fall. Mind your step.",
	"szentgyorgyi": "Dr. Szentgyörgyi Aranka: Check your working. Twice. The answer is never the point.",
	"halmos": "Halmos Ervin: If it hums, it is working. If it stops humming, run.",
	"voros": "Vörös Ildikó: Read something every day. Stories are the only honest ghosts.",
	"pasztor": "Pásztor Margit: Say it again, slowly. Languages forgive the patient.",
	"onodi": "Ónodi Bence: If it is not working, turn it off and on. Works on most things.",
	"fekete": "Fekete Zsombor: Everything is a network. Even this corridor. Even you.",
	"lazar": "Lázár Tivadar: Attendance matters. I see everything in this school.",
}

const STRANGE := [
	"... Did you hear that? No. Of course not.",
	"... I do not sleep much anymore. The school is so quiet at night. Is it not?",
	"... You are looking at me. Everyone is. Why is everyone looking?",
]


static func text(teacher_id: String, k: int) -> String:
	return TRAITS[teacher_id][clampi(k, 0, 9)]


static func chat(teacher_id: String) -> String:
	return CHAT[teacher_id]


static func strange(day: int) -> String:
	return STRANGE[clampi(day, 1, 3) - 1]
