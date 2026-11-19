class_name Recipients
extends RefCounted
## Everyone on the map who can get a parcel (delivery phase 1: the main
## island), plus the airport's postie. Palette cells: see docs/characters.md.

## The airport post office: north of the runway near its west end, where
## the plane waits, facing the runway (south).
const POST_OFFICE := Vector2(-330, -100)
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


static func _build() -> Array[RecipientData]:
	var list: Array[RecipientData] = []
	# The postie, at the post office door (gives out the parcels).
	list.append(RecipientData.make("postie",
			OutfitData.make("postie", "Rogue", {"r1c0": Color("2f6fdb"), "r0c5": Color("1b2440"), "r0c6": Color("1b2440"),
				"r2c5": Color("1b2440"), "r1c7": Color("ffd23f")}, [["Postie_Cap", "head"], ["Mail_Bag", "chest"]], ["Rogue_Cape"]),
			["Rogue", {"r0c1": Color("6b3e26")}], POST_OFFICE + Vector2(-14, 14), 180.0, Color("4aa8ff"), false, false))
	# First lessons: a short walk from the post office.
	list.append(RecipientData.make("balloon_kid",
			OutfitData.make("balloon_kid", "Rogue", {"r1c0": Color("ffd23f"), "r0c5": Color("3a7bd5"), "r0c6": Color("ff5a5f"),
				"r2c5": Color("ff5a5f")}, [["Balloon", "root"]], ["Rogue_Cape"]),
			["Knight", {}], Vector2(-500, 75), 60.0, Color("ff4d6d"), true))
	list.append(RecipientData.make("grandma",
			OutfitData.make("grandma", "Mage", {"r1c0": Color("b8a1e3"), "r0c3": Color("f3e1ff"), "r0c4": Color("f3e1ff")},
				[["Sun_Hat", "head"]]),
			["Mage", {"r0c1": Color("d9d9e0")}], Vector2(-290, 110), 0.0, Color("f7a8c4"), true))
	# Further away on the main island.
	list.append(RecipientData.make("mechanic",
			OutfitData.make("mechanic", "Knight", {"r0c3": Color("3a7bd5"), "r0c7": Color("2c5fa8"), "r0c6": Color("ffd23f"),
				"r0c4": Color("6b7a8f"), "r1c0": Color("e63946"), "r1c2": Color("ffd23f"), "r1c7": Color("2c5fa8")},
				[["Flat_Cap", "head"]]),
			["Rogue", {"r0c1": Color("3b2a20")}], Vector2(45, -52), 200.0, Color("e63946")))
	list.append(RecipientData.make("farmer",
			OutfitData.make("farmer", "Rogue", {"r1c0": Color("d64545"), "r0c5": Color("3a6ea5"), "r0c6": Color("6b4226"),
				"r2c5": Color("6b4226")}, [["Straw_Hat", "head"]], ["Rogue_Cape"]),
			["Barbarian", {}], Vector2(-470, 420), 300.0, Color("e9c46a")))
	list.append(RecipientData.make("keeper",
			OutfitData.make("keeper", "Rogue", {"r1c0": Color("1d4e89"), "r0c5": Color("f4f4f4"), "r0c6": Color("2b2b2b"),
				"r2c5": Color("2b2b2b")}, [["Beanie", "head"]], ["Rogue_Cape"]),
			["Barbarian", {"r0c1": Color("e8e8e8")}], Vector2(860, 735), 225.0, Color("4aa8ff")))
	return list
