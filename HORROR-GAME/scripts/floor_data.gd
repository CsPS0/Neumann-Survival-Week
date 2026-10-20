extends RefCounted
## Floor-plan data, in metres of the school's fire evacuation plans (tuzriado terv) redrawn on a clean grid. Each floor has
## its own origin (the plan point that is world 0,0) and scale. The plan units are metres at WORLD_SCALE 1.25.
## The ground floor keeps the plan's orientation (Zalan utca north, Kerepesi ut west, Rakosfalva utca south, the gym east).
## The two upper plans are drawn turned by 90 degrees on the wall; here they are turned back, so north is up on every floor.
##
## "rooms":  [label, x0, y0, x1, y1, doors]
##           doors = space-separated tokens "<side><position>": N/S/E/W = door with panel + label,
##           lowercase = doorless opening, position optional (defaults to the middle of the edge).
## "solids": [x0, y0, x1, y1] full-height blocks without a door (courtyards on the ground floor, roof terraces above).
## "end_walls": [x0, y0, x1, y1] extra wall lines closing corridor ends.
## "lights": ceiling lamp positions.  "patrol": waypoints for the entity.
## "corridors": polylines the crowd and the break teachers walk.  "csoki": the dog's route.

## The whole building is built WORLD_SCALE times larger than the plan measurements: the one knob for the size of the
## school. Replace the plan data and keep this; each floor `scale` is metres per plan unit * WORLD_SCALE.
const WORLD_SCALE := 1.25

## Ground floor, 104 x 43.8 m. Left to right: the west wing (Kerepesi ut) with a corridor and two courtyards, the Aula
## with the dining hall (Ebedlo) and the four stairwells, the east wing with two more courtyards, and the gym.
## The entrance, the Porta and the two WCs sit on the south side of the Aula.
const GROUND := {
	"origin": Vector2(42.6, 21.9),
	"scale": 0.8 * WORLD_SCALE,
	"rect": Rect2(0, 0, 104, 43.8),
	"rooms": [
		# North row, west of the Aula.
		["GT11-12", 0, 0, 13.1, 6.2, "S10.8"], ["19", 13.1, 0, 17.8, 6.2, "S15.5"], ["19/b", 17.8, 0, 21.4, 6.2, "S19.8"],
		["20", 21.4, 0, 25.4, 6.2, "S23.5"], ["21", 25.4, 0, 29, 6.2, "S27.6"],
		# North of the Aula: stores and the kitchen behind the dining hall.
		["", 29, 0, 35.4, 6.8, "S"], ["", 35.4, 0, 42.3, 6.8, "S"], ["Konyha", 42.3, 0, 49.8, 6.8, "S"],
		["", 49.8, 0, 56.2, 6.8, "S"],
		# North row, east of the Aula.
		["27", 56.2, 0, 63.1, 6.2, "S"], ["28", 63.1, 0, 72.6, 6.2, "S"], ["", 72.6, 0, 76.2, 6.2, "S"],
		["30", 76.2, 0, 79.8, 6.2, "S"], ["32", 79.8, 0, 83.5, 6.2, "S"], ["33", 83.5, 0, 96.4, 6.2, "S"],
		["35", 96.4, 0, 104, 6.2, "S"],
		# West wing: outer column along Kerepesi ut, then the corridor (x 8.5 to 11.5), then the inner cells.
		["16", 0, 9.8, 8.5, 12.4, "E"], ["14", 0, 12.4, 8.5, 22.6, "E14.6"], ["8", 0, 22.6, 8.5, 25.8, "E"],
		["GT2", 0, 25.8, 8.5, 31, "E"], ["GT1", 0, 31, 8.5, 38, "E"],
		["5", 0, 38, 12.9, 43.8, "N10"], ["3", 12.9, 38, 19.8, 43.8, "N"], ["", 19.8, 38, 31, 43.8, "N"],
		["Cisco", 11.5, 9.8, 15.5, 13.2, "W"], ["15", 11.5, 13.2, 15.5, 16.4, "W"], ["13", 11.5, 16.4, 15.5, 18.8, "W"],
		["12", 11.5, 18.8, 15.5, 21.2, "W"], ["11", 11.5, 21.2, 15.5, 24.2, "W"], ["10", 11.5, 24.2, 15.5, 27.7, "W"],
		["Gazd.", 11.5, 27.7, 15.5, 31.3, "W"], ["Fejl.", 11.5, 31.3, 15.5, 35.2, "W"],
		# Between the two west courtyards. GT3 and GT4 are entered through 23 and 24, as on the plan.
		["GT3", 15.5, 16.9, 22, 22.3, "e19.6"], ["GT4", 15.5, 22.3, 22, 27.7, "e25"],
		["23", 22, 16.9, 29, 22.3, "E W19.6"], ["24", 22, 22.3, 29, 27.7, "E w25"],
		# East block between the two east courtyards.
		["Könyvtár", 56.2, 16.9, 63.5, 27.7, "W"], ["38", 63.5, 16.9, 68, 23.5, "E"], ["39", 63.5, 23.5, 68, 27.7, "E"],
		# The gym with its changing rooms, and the south row.
		["Tornaterem", 71, 13.2, 104, 31, "W22 n101.8"],
		["31", 71, 9.8, 85, 13.2, "N78"], ["34", 85, 9.8, 99.5, 13.2, "N92"],
		["40", 71, 31, 80, 35.2, "S75.5"], ["41", 80, 31, 88, 35.2, "S84"], ["Szertár", 88, 31, 95.6, 35.2, "S91.8"],
		["42", 95.6, 31, 104, 38, "W36.6"],
		["GT47", 56.2, 38, 63, 43.8, "N59.6"], ["46", 63, 38, 71.5, 43.8, "N67.2"], ["45", 71.5, 38, 81.5, 43.8, "N76.5"],
		["44", 81.5, 38, 92.5, 43.8, "N87"], ["43", 92.5, 38, 104, 43.8, "N94"],
		# South side of the Aula: WC, entrance, Porta, buffet, WC.
		["WC", 31, 39.6, 36.4, 43.8, "N33.7"], ["Bejárat", 36.4, 39.6, 42.5, 43.8, "N39.5"],
		["Porta", 42.5, 39.6, 46.5, 43.8, "N44.5"], ["Büfé", 46.5, 39.6, 50, 43.8, "N48.2"],
		["WC", 50, 39.6, 56.2, 43.8, "N53.1"],
		# The dining hall is open to the Aula on three sides on the plan; closed in the demo.
		["Ebédlő", 35.4, 6.8, 49.8, 21, "n38 s42.6 w20 e20"],
	],
	"solids": [[15.5, 9.8, 29, 16.9], [15.5, 27.7, 29, 35.2], [56.2, 9.8, 68, 16.9], [56.2, 27.7, 68, 35.2]],
	"end_walls": [[0, 6.2, 0, 9.8], [104, 6.2, 104, 13.2]],
	"lights": [
		Vector2(6, 8), Vector2(20, 8), Vector2(60, 8), Vector2(76, 8), Vector2(92, 8), Vector2(10, 18), Vector2(10, 30),
		Vector2(22, 36.6), Vector2(31, 24), Vector2(54, 24), Vector2(42.6, 36), Vector2(38, 30), Vector2(47.5, 30),
		Vector2(69.5, 18), Vector2(69.5, 30), Vector2(64, 36.6), Vector2(80, 36.6), Vector2(80, 22), Vector2(95, 22),
		Vector2(39.5, 41.7), Vector2(48.2, 41.7),
	],
	"corridors": [
		[Vector2(10, 36.6), Vector2(10, 8), Vector2(28, 8)],
		[Vector2(58, 8), Vector2(102, 8)],
		[Vector2(69.5, 8), Vector2(69.5, 36.6), Vector2(93, 36.6)],
		[Vector2(10, 37), Vector2(30, 37), Vector2(43, 38.2)],
		[Vector2(47.5, 24), Vector2(47.5, 36)],
	],
	"csoki": [Vector2(37.5, 28), Vector2(48, 28), Vector2(37.5, 36), Vector2(48, 36)],
	"patrol": [
		Vector2(10, 8), Vector2(26, 8), Vector2(40, 24), Vector2(60, 8), Vector2(69.5, 8), Vector2(69.5, 24),
		Vector2(88, 36.6), Vector2(42.6, 37), Vector2(20, 36.6), Vector2(10, 24),
	],
}

## Upper floors, 40.6 x 43.8 m, over the middle of the building. Two roof terraces (solid blocks) sit between two long
## corridors that run north to south, with the stairwells on the terrace side of each corridor. A cross hall joins the
## corridors between the terraces, split by a wall with one door gap. Rooms: four corners, two on the middle of the west and east side, two at the north
## end and two at the south end, plus a WC and a store beside each terrace.
const FIRST := {
	"origin": Vector2(20.3, 21.9),
	"scale": 0.8 * WORLD_SCALE,
	"rect": Rect2(0, 0, 40.6, 43.8),
	"rooms": [
		# West side, from north to south. The doors sit where the fire plan shows the wall gaps.
		["109", 0, 0, 7.5, 8.2, "E6.4"],
		["WC", 0, 8.2, 7.5, 10.53, "E9.4"],
		["", 0, 10.53, 7.5, 12.87, "E11.7"],
		["", 0, 12.87, 7.5, 15.2, "E14.0"],
		["Raktár", 0, 15.2, 7.5, 17.9, "E16.5"],
		["Tanári", 0, 17.9, 7.5, 26.1, "E24"],
		["Raktár", 0, 26.1, 7.5, 28.8, "E27.4"],
		["WC", 0, 28.8, 7.5, 31.07, "E29.9"],
		["", 0, 31.07, 7.5, 33.33, "E32.2"],
		["", 0, 33.33, 7.5, 35.6, "E34.5"],
		["GT10", 0, 35.6, 7.5, 43.8, "E37"],
		# East side, from north to south.
		["125", 33.1, 0, 40.6, 8.2, "W7"],
		["WC", 33.1, 8.2, 40.6, 10.53, "W9.4"],
		["", 33.1, 10.53, 40.6, 12.87, "W11.7"],
		["", 33.1, 12.87, 40.6, 15.2, "W14.0"],
		["Raktár", 33.1, 15.2, 40.6, 17.9, "W16.5"],
		["129", 33.1, 17.9, 40.6, 26.1, "W19.4"],
		["Raktár", 33.1, 26.1, 40.6, 28.8, "W27.4"],
		["WC", 33.1, 28.8, 40.6, 31.07, "W29.9"],
		["", 33.1, 31.07, 40.6, 33.33, "W32.2"],
		["", 33.1, 33.33, 40.6, 35.6, "W34.5"],
		["133", 33.1, 35.6, 40.6, 43.8, "W36.3"],
		# North and south ends, between the corridors. Each pair shares a door in the wall between them.
		["113", 13.1, 0, 20.3, 8.2, "W6.5 E6.7"],
		["121", 20.3, 0, 27.5, 8.2, "E6.8 w6.7"],
		["114", 13.1, 35.6, 20.3, 43.8, "W37 E39.2"],
		["120", 20.3, 35.6, 27.5, 43.8, "E36.6 w39.2"],
		# Two-cell stores closing the corridors at both ends.
		["Raktár", 7.5, 0, 10.3, 4.2, "S8.7"],
		["Raktár", 10.3, 0, 13.1, 4.2, "S11.6"],
		["Raktár", 27.5, 0, 30.3, 4.2, "S28.2"],
		["Raktár", 30.3, 0, 33.1, 4.2, "S31.9"],
		["Raktár", 7.5, 39.6, 10.3, 43.8, "N8.7"],
		["Raktár", 10.3, 39.6, 13.1, 43.8, "N12.3"],
		["Raktár", 27.5, 39.6, 30.3, 43.8, "N28.7"],
		["Raktár", 30.3, 39.6, 33.1, 43.8, "N32.5"],
	],
	"solids": [[13.1, 8.2, 27.5, 17.9], [13.1, 26.1, 27.5, 35.6]],
	"end_walls": [[20.3, 17.9, 20.3, 20.5], [20.3, 22.5, 20.3, 26.1]],
	"lights": [
		Vector2(9.4, 7), Vector2(9.4, 16), Vector2(9.4, 30), Vector2(9.4, 38), Vector2(31.2, 7), Vector2(31.2, 16),
		Vector2(31.2, 30), Vector2(31.2, 38), Vector2(20.3, 21.5),
	],
	"corridors": [
		[Vector2(9.4, 5.5), Vector2(9.4, 38.5)],
		[Vector2(31.2, 5.5), Vector2(31.2, 38.5)],
		[Vector2(9.4, 21.5), Vector2(31.2, 21.5)],
	],
	"patrol": [
		Vector2(9.4, 8), Vector2(20.3, 21.5), Vector2(31.2, 8), Vector2(31.2, 36), Vector2(20.3, 21.5), Vector2(9.4, 36),
	],
}

const SECOND := {
	"origin": Vector2(20.3, 21.9),
	"scale": 0.8 * WORLD_SCALE,
	"rect": Rect2(0, 0, 40.6, 43.8),
	"rooms": [
		# West side, from north to south. The doors sit where the fire plan shows the wall gaps.
		["GT9", 0, 0, 7.5, 8.2, "E6.4"],
		["WC", 0, 8.2, 7.5, 10.53, "E9.4"],
		["", 0, 10.53, 7.5, 12.87, "E11.7"],
		["", 0, 12.87, 7.5, 15.2, "E14.0"],
		["Raktár", 0, 15.2, 7.5, 17.9, "E16.5"],
		["205", 0, 17.9, 7.5, 26.1, "E24"],
		["Raktár", 0, 26.1, 7.5, 28.8, "E27.4"],
		["WC", 0, 28.8, 7.5, 31.07, "E29.9"],
		["", 0, 31.07, 7.5, 33.33, "E32.2"],
		["", 0, 33.33, 7.5, 35.6, "E34.5"],
		["GT5", 0, 35.6, 7.5, 43.8, "E37"],
		# East side, from north to south.
		["225", 33.1, 0, 40.6, 8.2, "W7"],
		["WC", 33.1, 8.2, 40.6, 10.53, "W9.4"],
		["", 33.1, 10.53, 40.6, 12.87, "W11.7"],
		["", 33.1, 12.87, 40.6, 15.2, "W14.0"],
		["Raktár", 33.1, 15.2, 40.6, 17.9, "W16.5"],
		["229", 33.1, 17.9, 40.6, 26.1, "W19.4"],
		["Raktár", 33.1, 26.1, 40.6, 28.8, "W27.4"],
		["WC", 33.1, 28.8, 40.6, 31.07, "W29.9"],
		["", 33.1, 31.07, 40.6, 33.33, "W32.2"],
		["", 33.1, 33.33, 40.6, 35.6, "W34.5"],
		["233", 33.1, 35.6, 40.6, 43.8, "W36.3"],
		# North and south ends, between the corridors. Each pair shares a door in the wall between them.
		["GT7", 13.1, 0, 20.3, 8.2, "W6.5 E6.7"],
		["GT8", 20.3, 0, 27.5, 8.2, "E6.8 w6.7"],
		["GT6", 13.1, 35.6, 20.3, 43.8, "W37 E39.2"],
		["Tanári", 20.3, 35.6, 27.5, 43.8, "E36.6 w39.2"],
		# Two-cell stores closing the corridors at both ends.
		["Raktár", 7.5, 0, 10.3, 4.2, "S8.7"],
		["Raktár", 10.3, 0, 13.1, 4.2, "S11.6"],
		["Raktár", 27.5, 0, 30.3, 4.2, "S28.2"],
		["Raktár", 30.3, 0, 33.1, 4.2, "S31.9"],
		["Raktár", 7.5, 39.6, 10.3, 43.8, "N8.7"],
		["Raktár", 10.3, 39.6, 13.1, 43.8, "N12.3"],
		["Raktár", 27.5, 39.6, 30.3, 43.8, "N28.7"],
		["Raktár", 30.3, 39.6, 33.1, 43.8, "N32.5"],
	],
	"solids": [[13.1, 8.2, 27.5, 17.9], [13.1, 26.1, 27.5, 35.6]],
	"end_walls": [[20.3, 17.9, 20.3, 20.5], [20.3, 22.5, 20.3, 26.1]],
	"lights": [
		Vector2(9.4, 7), Vector2(9.4, 16), Vector2(9.4, 30), Vector2(9.4, 38), Vector2(31.2, 7), Vector2(31.2, 16),
		Vector2(31.2, 30), Vector2(31.2, 38), Vector2(20.3, 21.5),
	],
	"corridors": [
		[Vector2(9.4, 5.5), Vector2(9.4, 38.5)],
		[Vector2(31.2, 5.5), Vector2(31.2, 38.5)],
		[Vector2(9.4, 21.5), Vector2(31.2, 21.5)],
	],
	"patrol": [
		Vector2(9.4, 8), Vector2(20.3, 21.5), Vector2(31.2, 8), Vector2(31.2, 36), Vector2(20.3, 21.5), Vector2(9.4, 36),
	],
}

const FLOORS := [GROUND, FIRST, SECOND]


## World rectangle (x, z in metres) of the first room with this label on a floor.
static func room_rect(floor_index: int, label: String) -> Rect2:
	var data: Dictionary = FLOORS[floor_index]
	var origin: Vector2 = data["origin"]
	var scale: float = data["scale"]
	for room: Array in data["rooms"]:
		if room[0] == label:
			var a := (Vector2(room[1], room[2]) - origin) * scale
			var b := (Vector2(room[3], room[4]) - origin) * scale
			return Rect2(a, b - a).abs()
	return Rect2()


## Label of the room that contains a world point (x, z in metres) on a floor, "Corridor" when it is in none.
## Unnamed rooms count as the corridor.
static func room_label_at(floor_index: int, x: float, z: float) -> String:
	var data: Dictionary = FLOORS[floor_index]
	var origin: Vector2 = data["origin"]
	var scale: float = data["scale"]
	var point := Vector2(x, z)
	for room: Array in data["rooms"]:
		if room[0] == "":
			continue
		var a := (Vector2(room[1], room[2]) - origin) * scale
		var b := (Vector2(room[3], room[4]) - origin) * scale
		if Rect2(a, b - a).abs().has_point(point):
			return room[0]
	return "Corridor"
