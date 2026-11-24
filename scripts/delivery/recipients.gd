class_name Recipients
extends RefCounted
## Everyone on the map who can get a parcel, and the post offices with
## their posties. Palette cells: see docs/characters.md.

## Post offices: [where (x, z), facing (compass degrees), postie id].
## The airport's is north of the runway near its west end (where the plane
## waits); the city's is just outside its west edge; the town's at the east
## end of Town Island's main street, facing the landing meadow.
const POST_OFFICES := [
	[Vector2(-330, -100), 180.0, "postie"],
	[Vector2(-95, 520), 90.0, "postie_city"],
	[Vector2(-3200, 445), 90.0, "postie_town"],
]
## Kept for older code and tests: the airport post office.
const POST_OFFICE: Vector2 = Vector2(-330, -100)
const POST_OFFICE_FACE := 180.0

static var _all: Array[RecipientData] = []


static func all() -> Array[RecipientData]:
	if _all.is_empty():
		_all = _build()
	return _all


static func get_recipient(id: String) -> RecipientData:
	for r in all():
		if r.id == id:
			return r
	return null


static func deliverable() -> Array[RecipientData]:
	var out: Array[RecipientData] = []
	for r in all():
		if r.deliverable:
			out.append(r)
	return out


## A point beside a post office (offset in its own space: +x right of the
## door as you face it... from outside, +z out in front).
static func by_post_office(po: Array, offset: Vector2) -> Vector2:
	var yaw := deg_to_rad(-float(po[1])) + PI
	return Vector2(po[0]) + Vector2(offset.x * cos(yaw) + offset.y * sin(yaw), -offset.x * sin(yaw) + offset.y * cos(yaw))


static func _postie(id: String, po: Array) -> RecipientData:
	return RecipientData.make(id,
			OutfitData.make("postie", "Rogue", {"r1c0": Color("2f6fdb"), "r0c5": Color("1b2440"), "r0c6": Color("1b2440"),
				"r2c5": Color("1b2440"), "r1c7": Color("ffd23f")}, [["Postie_Cap", "head"], ["Mail_Bag", "chest"]], ["Rogue_Cape"]),
			["Rogue", {"r0c1": Color("6b3e26")}], by_post_office(po, Vector2(-14, 14)), float(po[1]), Color("4aa8ff"),
			"airport", 0, Vector2.ZERO, false)


static func _build() -> Array[RecipientData]:
	var list: Array[RecipientData] = []
	list.append(_postie("postie", POST_OFFICES[0]))
	list.append(_postie("postie_city", POST_OFFICES[1]))
	list.append(_postie("postie_town", POST_OFFICES[2]))
	# --- First lessons: a short walk from the airport post office -------------------
	list.append(RecipientData.make("balloon_kid",
			OutfitData.make("balloon_kid", "Rogue", {"r1c0": Color("ffd23f"), "r0c5": Color("3a7bd5"), "r0c6": Color("ff5a5f"),
				"r2c5": Color("ff5a5f")}, [["Balloon", "root"]], ["Rogue_Cape"]),
			["Knight", {}], Vector2(-500, 75), 60.0, Color("ff4d6d"), "airport", 0, Vector2(-420, 0)))
	list.append(RecipientData.make("grandma",
			OutfitData.make("grandma", "Mage", {"r1c0": Color("b8a1e3"), "r0c3": Color("f3e1ff"), "r0c4": Color("f3e1ff")},
				[["Sun_Hat", "head"]]),
			["Mage", {"r0c1": Color("d9d9e0")}], Vector2(-290, 110), 0.0, Color("f7a8c4"), "airport", 0, Vector2(-420, 0)))
	# --- Elsewhere on the main island ---------------------------------------------------
	list.append(RecipientData.make("mechanic",
			OutfitData.make("mechanic", "Knight", {"r0c3": Color("3a7bd5"), "r0c7": Color("2c5fa8"), "r0c6": Color("ffd23f"),
				"r0c4": Color("6b7a8f"), "r1c0": Color("e63946"), "r1c2": Color("ffd23f"), "r1c7": Color("2c5fa8")},
				[["Flat_Cap", "head"]]),
			["Rogue", {"r0c1": Color("3b2a20")}], Vector2(45, -52), 200.0, Color("e63946"), "airport", 1, Vector2(-100, 0)))
	list.append(RecipientData.make("farmer",
			OutfitData.make("farmer", "Rogue", {"r1c0": Color("d64545"), "r0c5": Color("3a6ea5"), "r0c6": Color("6b4226"),
				"r2c5": Color("6b4226")}, [["Straw_Hat", "head"]], ["Rogue_Cape"]),
			["Barbarian", {}], Vector2(-470, 420), 300.0, Color("e9c46a"), "farm", 1, Vector2(-560, 380)))
	list.append(RecipientData.make("keeper",
			OutfitData.make("keeper", "Rogue", {"r1c0": Color("1d4e89"), "r0c5": Color("f4f4f4"), "r0c6": Color("2b2b2b"),
				"r2c5": Color("2b2b2b")}, [["Beanie", "head"]], ["Rogue_Cape"]),
			["Barbarian", {"r0c1": Color("e8e8e8")}], Vector2(860, 735), 225.0, Color("4aa8ff"), "lighthouse", 1, Vector2(950, 560)))
	list.append(RecipientData.make("painter",
			OutfitData.make("painter", "Mage", {"r1c0": Color("2ec4b6"), "r0c3": Color("ffffff"), "r0c4": Color("ffd23f")},
				[["Beret", "head"]]),
			["Rogue", {"r0c1": Color("2a2522")}], Vector2(100, 640), 270.0, Color("2ec4b6"), "city", 1, Vector2(-160, 450)))
	# --- Other islands: fly there, land, walk up ----------------------------------------
	list.append(RecipientData.make("baker",
			OutfitData.make("baker", "Rogue", {"r1c0": Color("ffffff"), "r0c5": Color("8a8f99"), "r0c6": Color("5a3a22"),
				"r2c5": Color("5a3a22")}, [["Chef_Hat", "head"]], ["Rogue_Cape"]),
			["Knight", {"r0c1": Color("a0522d")}], Vector2(-3250, 500), 90.0, Color("ff9f1c"), "town", 2, Vector2(-3060, 580)))
	list.append(RecipientData.make("explorer",
			OutfitData.make("explorer", "Rogue", {"r1c0": Color("ff8c42"), "r0c5": Color("3a3f58"), "r0c6": Color("3a3f58"),
				"r2c5": Color("3a3f58")}, [], ["Rogue_Cape"]),
			["Rogue_Hooded", {}], Vector2(580, -3300), 120.0, Color("4cc9f0"), "ice", 2, Vector2(620, -3280)))
	list.append(RecipientData.make("ranger",
			OutfitData.make("ranger", "Knight", {"r0c3": Color("8f9a5b"), "r0c7": Color("6f7a45"), "r0c6": Color("6b4e2e"),
				"r0c4": Color("c2a36b"), "r1c0": Color("4cc06a"), "r1c2": Color("6b4e2e"), "r1c7": Color("6f7a45")},
				[["Ranger_Hat", "head"]]),
			["Rogue", {"r0c1": Color("c08a4a")}], Vector2(2700, 2140), 225.0, Color("4cc06a"), "dino", 2, Vector2(2650, 2080)))
	list.append(RecipientData.make("knight",
			OutfitData.make("knight", "Knight", {"r1c0": Color("9b5de5")}, [], [], [], ["Knight_Helmet", "Knight_Cape"]),
			["Knight", {}], Vector2(-480, 3500), 60.0, Color("9b5de5"), "castle", 2, Vector2(-440, 3520)))
	# --- Parachute mail: somewhere the plane can't land; fly low over them -------------------
	list.append(RecipientData.air(RecipientData.make("sailor",
			OutfitData.make("sailor", "Rogue", {"r1c0": Color("f4f4f4"), "r0c5": Color("1d3f8a"), "r0c6": Color("1d3f8a"),
				"r2c5": Color("1d3f8a"), "r1c7": Color("e63946")}, [["Beanie", "head"]], ["Rogue_Cape"]),
			["Rogue", {"r0c1": Color("d9a066")}], Vector2(300, 1860), 0.0, Color("1d6fdb"), "boat", 1),
			50.0, 70.0, "Boat", Vector3(0, 1.3, -3.5)))
	list.append(RecipientData.air(RecipientData.make("hiker",
			OutfitData.make("hiker", "Rogue", {"r1c0": Color("ff5a5f"), "r0c5": Color("4a5a3a"), "r0c6": Color("6b4226"),
				"r2c5": Color("6b4226")}, [["Sun_Hat", "head"]], ["Rogue_Cape"]),
			["Barbarian", {"r0c1": Color("8b5a2b")}], Vector2(195, -897), 180.0, Color("ff8c42"), "mountain", 1),
			45.0, 70.0))
	list.append(RecipientData.air(RecipientData.make("captain",
			OutfitData.make("captain", "Knight", {"r0c3": Color("e63946"), "r0c7": Color("1b1b24"), "r0c6": Color("1b1b24"),
				"r0c4": Color("ffd23f"), "r1c0": Color("e63946"), "r1c2": Color("ffd23f"), "r1c7": Color("1b1b24")},
				[["Ranger_Hat", "head"]]),
			["Barbarian", {"r0c1": Color("2a1d14")}], Vector2(2550, 0), 0.0, Color("e63946"), "boat", 2),
			75.0, 120.0, "PirateShip", Vector3(4.0, 6.7, -3.0)))
	# --- Mermaid mail: on rocks at sea; fly low over them to drop the parcel -----------------
	list.append(RecipientData.mermaid("mermaid_beach", Vector2(1400, 160), 90.0, Color("ff7eb9"), Color("ff7eb9"), 1))
	list.append(RecipientData.mermaid("mermaid_cove", Vector2(-620, 2220), 270.0, Color("7b6cff"), Color("7b6cff")))
	list.append(RecipientData.mermaid("mermaid_lagoon", Vector2(-120, -1980), 0.0, Color("3cc9a8"), Color("3cc9a8")))
	return list
