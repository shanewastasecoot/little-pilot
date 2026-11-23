class_name Hats
extends RefCounted
## The hats in the hat shop (Phase 5), in shop order: each a prop from
## props.glb worn on the head bone, and its price in stars (picture-only:
## the shop shows that many little stars, so 10 at most). A hat she's
## bought is hers for good; wearing one replaces her outfit's own headgear,
## and "no hat" (SaveManager.hat == "") puts the outfit's back.

## [id, prop, price]
const LIST := [
	["straw", "Straw_Hat", 3],
	["beanie", "Beanie", 3],
	["flat_cap", "Flat_Cap", 4],
	["beret", "Beret", 4],
	["sun", "Sun_Hat", 5],
	["postie", "Postie_Cap", 5],
	["ranger", "Ranger_Hat", 6],
	["chef", "Chef_Hat", 6],
	["pilot", "Pilot_Cap", 7],
	["dino", "Dino_Hood", 8],
	["tiara", "Princess_Tiara", 9],
	["astro", "Astro_Helmet", 10],
]


static func has(id: String) -> bool:
	return _row(id).size() > 0


static func ids() -> Array[String]:
	var out: Array[String] = []
	for r in LIST:
		out.append(r[0])
	return out


## The props.glb mesh for hat `id` ("" if unknown).
static func prop_of(id: String) -> String:
	var r := _row(id)
	return r[1] if r.size() > 0 else ""


static func price(id: String) -> int:
	var r := _row(id)
	return r[2] if r.size() > 0 else 0


static func _row(id: String) -> Array:
	for r in LIST:
		if r[0] == id:
			return r
	return []
