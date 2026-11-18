class_name Outfits
extends RefCounted
## The player character's outfits, in character-screen order (1-based in
## the save). Each is an OutfitData: a KayKit base body, repaints of its
## palette texture (cells "r<row>c<col>") and props from props.glb on bones.
## All original designs.
##
## Rogue body cells: r1c0 tunic, r1c1 collar, r0c5/r0c6 straps and belt,
## r2c5 gloves, r2c3 trousers, r1c7 boots. Mage: r1c0 robe, r0c3/r0c4
## trims, r0c5 sash, r2c2 lining, r2c7 cuffs. Knight: r0c3 plates, r0c7
## edges, r0c6 straps, r1c0 tabard, r1c2/r1c7 under-layers.

static var _list: Array[OutfitData] = []


static func all() -> Array[OutfitData]:
	if _list.is_empty():
		_list = [
			# 1 Pilot: brown bomber jacket, cream scarf, leather cap with goggles, boots.
			OutfitData.make("pilot", "Rogue",
				{"r1c0": Color("7a4a28"), "r1c1": Color("f4ead5"), "r0c5": Color("4a3020"), "r0c6": Color("5b3a1e"),
				 "r2c5": Color("5b3a1e"), "r2c3": Color("c9b27c"), "r1c7": Color("3d2a1c")},
				[["Pilot_Cap", "head"], ["Pilot_Scarf", "chest"]], ["Rogue_Cape"],
				[Color("7a4a28"), Color("c9b27c"), Color("3d2a1c"), Color("f4ead5")]),
			# 2 Princess: lilac gown with mint sash and bow, rose-gold tiara.
			OutfitData.make("princess", "Mage",
				{"r1c0": Color("c9a0f0"), "r0c3": Color("f3e1ff"), "r0c4": Color("f3e1ff"), "r0c5": Color("6fd6c4"),
				 "r2c2": Color("6fd6c4"), "r1c7": Color("f3e1ff"), "r2c7": Color("ffffff")},
				[["Princess_Gown", "hips"], ["Princess_Tiara", "head"]], ["Mage_LegLeft", "Mage_LegRight"],
				[Color("c9a0f0"), Color("c9a0f0"), Color("a77ee0"), Color("6fd6c4")]),
			# 3 Astronaut: white suit with orange and blue, helmet and air pack.
			OutfitData.make("astronaut", "Knight",
				{"r0c3": Color("f2f4f7"), "r0c7": Color("c8ced6"), "r0c6": Color("ff8c2a"), "r0c4": Color("9aa6b4"),
				 "r1c0": Color("3a7bd5"), "r1c2": Color("ff8c2a"), "r1c7": Color("6b7a8f")},
				[["Astro_Helmet", "head"], ["Astro_Pack", "chest"]], [],
				[Color("f2f4f7"), Color("f2f4f7"), Color("6b7a8f"), Color("ff8c2a")]),
			# 4 Superhero: blue suit, red boots and gloves, gold belt and star, red cape.
			OutfitData.make("superhero", "Rogue",
				{"r1c0": Color("2f6fdb"), "r1c1": Color("e63946"), "r0c5": Color("ffd23f"), "r0c6": Color("ffd23f"),
				 "r2c5": Color("e63946"), "r2c3": Color("2f6fdb"), "r1c7": Color("e63946")},
				[["Hero_Cape", "chest"], ["Hero_Emblem", "chest"]], ["Rogue_Cape"],
				[Color("2f6fdb"), Color("2f6fdb"), Color("e63946"), Color("ffd23f")]),
			# 5 Dino: a green dinosaur costume with hood, spikes and tail.
			OutfitData.make("dino", "Rogue",
				{"r1c0": Color("5cbf45"), "r1c1": Color("f6e7a8"), "r0c5": Color("3f9e4a"), "r0c6": Color("3f9e4a"),
				 "r2c5": Color("5cbf45"), "r2c3": Color("5cbf45"), "r1c7": Color("2f7a38")},
				[["Dino_Hood", "head"], ["Dino_Tail", "hips"]], ["Rogue_Cape"],
				[Color("5cbf45"), Color("5cbf45"), Color("2f7a38"), Color("ff9f1c")]),
		]
	return _list


static func get_outfit(n: int) -> OutfitData:
	var list := all()
	return list[clampi(n, 1, list.size()) - 1]


static func count() -> int:
	return all().size()
