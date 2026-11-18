class_name Outfits
extends RefCounted
## The player character's outfits, in character-screen order (1-based in
## the save). Each is an OutfitData: a KayKit base body, palette repaints and
## props on bones.

static var _list: Array[OutfitData] = []


static func all() -> Array[OutfitData]:
	if _list.is_empty():
		_list = [
			OutfitData.make("adventurer", "Rogue"),
			OutfitData.make("adventurer", "Rogue"),
			OutfitData.make("adventurer", "Rogue"),
			OutfitData.make("adventurer", "Rogue"),
			OutfitData.make("adventurer", "Rogue"),
		]
	return _list


static func get_outfit(n: int) -> OutfitData:
	var list := all()
	return list[clampi(n, 1, list.size()) - 1]
