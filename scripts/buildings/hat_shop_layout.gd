class_name HatShopLayout
extends RefCounted
## The hat shop's inside (Phase 5), and where its front door is on each shop
## model that can be one: the hat shop by the airport (HatShop, a
## shop_small_a at scale 16) and the city's shops whose news named them a
## "hat shop" (CityBuild). Kept apart from CityPlan so saved cities don't
## change.
##
## One room the size of the shop: the counter and the milliner at the back,
## hat stands round the walls, the try-on mirror (HatMirror: Y to choose a
## hat) and one hidden star. Built by BuildingGenerator (room type
## "hat_shop", HatShopFurnisher).

## model: [door x, window xs, adds a door] in the model's own units (times
## its scale = metres; the front is +Z). Measured from front views
## (docs/images/door_shop_small_*.png). shop_small_b has no door of its own
## on the ground floor, so the city puts one in the middle.
const MODELS := {
	"shop_small_a": [0.18, [-0.54, -0.18], false],
	"shop_small_b": [0.0, [], true],
}


static func has(model: String) -> bool:
	return MODELS.has(model)


## The front door (on the ground, in the front wall) for `model` at `scale`
## with footprint `size` (metres, centred on the origin).
static func door_local(model: String, scale: float, size: Vector3) -> Vector3:
	return Vector3(float(MODELS[model][0]) * scale, 0, size.z * 0.5)


## Does the city need to add a door to the outside of `model`?
static func adds_door(model: String) -> bool:
	return bool(MODELS[model][2])


## The floor plan for a shop of `model` at `scale`, footprint `size`
## (metres); `seed` varies the stands' colours.
static func layout(model: String, scale: float, size: Vector3, seed: int) -> Dictionary:
	var w := size.x
	var d := size.z
	var door_x := float(MODELS[model][0]) * scale
	var windows: Array = []
	for wx in MODELS[model][1]:
		windows.append({"side": "S", "at": clampf(0.5 + float(wx) * scale / w, 0.12, 0.88)})
	if windows.is_empty():
		# No front windows on this model: one in the side wall away from
		# the door (the mirror is on the door's side), near the front.
		windows.append({"side": "W" if door_x >= 0.0 else "E", "at": 0.72})
	return {
		"name": "hat_shop_" + model,
		"storey_height": 10.0,
		"wall_thickness": 0.5,
		"door_width": 6.0,
		"door_height": 8.0,
		"furniture_scale": 2.27,
		"seed": seed,
		"backdrop": "plain",
		"sticker": "hat_shop",
		"rooms": [{
			"id": "shop",
			"type": "hat_shop",
			"floor": 0,
			"rect": [-w * 0.5, -d * 0.5, w, d],
			"wall": "fde2ec",
			"floor_colour": "b98a5e",
			"doors": [{"side": "S", "at": 0.5 + door_x / w, "exit": true}],
			"windows": windows,
		}],
		"stairs": [],
	}
