class_name CityHouseLayouts
extends RefCounted
## The insides of the city's houses: one floor plan per house MODEL (every
## house of the same model has the same rooms; the furniture varies by a seed
## from where it stands). Kept apart from CityPlan so saved cities don't
## change. Each plan is the size of the model as the city places it (fitted
## into a 22 m spot, under 24 m tall) and its front door is where the
## model's door is (measured from front views: docs/images/door_*.png).
## Plans use BuildingGenerator's format (x right, z towards the front door).
## Mostly one floor; home_4 (the tallest with room for stairs) has two.
##
## The insides are built on their own (up above the house), so they don't
## have to fit the outside: they're INSIDE_SCALE times the model's size each
## way, so the rooms feel like a home rather than a little shack (her own
## house's rooms are bigger still).
const INSIDE_SCALE := 1.6

## model -> [width, depth, door x offset, two floors]
const MODELS := {
	"house_a": [20.8, 22.0, -2.0, false],
	"house_b": [15.2, 18.8, 0.0, false],
	"home_1": [22.0, 22.0, 0.0, false],
	"home_2": [20.5, 22.0, 0.0, false],
	"home_3": [22.0, 12.7, 2.1, false],
	"home_4": [21.7, 22.0, 0.0, true],
	"home_5": [22.0, 17.0, 0.0, false],
}
## Townspeople who live in them (KayKit looks), picked by the seed.
const OWNER_LOOKS := [
	["Rogue", {"r1c0": Color("ff5a5f"), "r0c5": Color("2b2d42"), "r0c6": Color("ffffff"), "r2c5": Color("ffffff")}, [["Beanie", "head"]], ["Rogue_Cape"], ["Rogue", {"r0c1": Color("3b2a20")}]],
	["Mage", {"r1c0": Color("4aa8ff"), "r0c3": Color("fff0f5"), "r0c4": Color("4aa8ff")}, [["Sun_Hat", "head"]], [], ["Mage", {"r0c1": Color("7a4a2a")}]],
	["Rogue", {"r1c0": Color("4cc06a"), "r0c5": Color("6b4226"), "r0c6": Color("6b4226"), "r2c5": Color("6b4226")}, [["Straw_Hat", "head"]], ["Rogue_Cape"], ["Barbarian", {}]],
	["Mage", {"r1c0": Color("9b5de5"), "r0c3": Color("ffffff"), "r0c4": Color("ffd23f")}, [["Beret", "head"]], [], ["Mage", {"r0c1": Color("2a2522")}]],
	["Knight", {"r0c3": Color("6b7a8f"), "r0c7": Color("3a4250"), "r0c6": Color("6b4226"), "r0c4": Color("8a8f99"), "r1c0": Color("e9c46a"), "r1c2": Color("6b4226"), "r1c7": Color("3a4250")}, [["Flat_Cap", "head"]], [], ["Rogue", {"r0c1": Color("d9d9e0")}]],
	["Rogue", {"r1c0": Color("ffd23f"), "r0c5": Color("3a7bd5"), "r0c6": Color("ff5a5f"), "r2c5": Color("ff5a5f")}, [], ["Rogue_Cape"], ["Knight", {}]],
]


static func has(model: String) -> bool:
	return MODELS.has(model)


## The front door on the model (local to the house, on the ground, at the
## front wall) and its footprint.
static func door_local(model: String) -> Vector3:
	var m: Array = MODELS[model]
	return Vector3(m[2], 0, m[1] * 0.5)


static func footprint(model: String) -> Vector2:
	var m: Array = MODELS[model]
	return Vector2(m[0], m[1])


## The size of the inside (INSIDE_SCALE times the model's footprint).
static func inside_size(model: String) -> Vector2:
	return footprint(model) * INSIDE_SCALE


## Where the front door is on the inside plan (x, at the front wall).
static func inside_door_x(model: String) -> float:
	return float(MODELS[model][2]) * INSIDE_SCALE


## The floor plan for a house of `model`, furniture varied by `seed`.
static func layout(model: String, seed: int) -> Dictionary:
	var m: Array = MODELS[model]
	var w: float = float(m[0]) * INSIDE_SCALE
	var d: float = float(m[1]) * INSIDE_SCALE
	var door_x: float = inside_door_x(model)
	var rooms: Array
	var stairs: Array = []
	if model == "home_3":
		rooms = _side_by_side(w, d, door_x)
	elif m[3]:
		var two := _two_floors(w, d, door_x)
		rooms = two[0]
		stairs = two[1]
	else:
		rooms = _front_and_back(w, d, door_x)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var walls := ["fff1d6", "e8f5e0", "dff0ff", "ffe4ec", "fff8c4"]
	for r: Dictionary in rooms:
		r["wall"] = walls[rng.randi() % walls.size()]
		r["floor_colour"] = ["c8a27a", "b98a5e", "d9b48a"][rng.randi() % 3]
	# (A small exit trigger right in the doorway: the rooms are small, and
	# crossing the living room shouldn't take her outside.)
	return {"name": "city_house_" + model, "storey_height": 10.0, "wall_thickness": 0.5, "door_width": 4.0, "exit_radius": 1.6,
		"door_height": 8.0, "furniture_scale": 2.27, "seed": seed, "backdrop": "plain", "rooms": rooms, "stairs": stairs,
		"owner": OWNER_LOOKS[rng.randi() % OWNER_LOOKS.size()], "sticker": "city_house"}


static func _at(x: float, from: float, length: float) -> float:
	return clampf((x - from) / length, 0.1, 0.9)


## Living room across the front (the front door into it), kitchen and a
## bedroom behind.
static func _front_and_back(w: float, d: float, door_x: float) -> Array:
	var x0 := -w * 0.5
	var z0 := -d * 0.5
	var split := z0 + d * 0.48
	var kw := w * 0.45
	var front_depth := d * 0.5 - split
	var kitchen_cx := x0 + kw * 0.5
	var bed_cx := x0 + kw + (w - kw) * 0.5
	var living_windows := [{"side": "W", "at": 0.5}, {"side": "E", "at": 0.5}]
	if door_x < -0.5:
		living_windows.append({"side": "S", "at": 0.8})
	elif door_x > 0.5:
		living_windows.append({"side": "S", "at": 0.2})
	else:
		living_windows += [{"side": "S", "at": 0.18}, {"side": "S", "at": 0.82}]
	return [
		{"id": "living", "type": "small_living", "floor": 0, "rect": [x0, split, w, front_depth],
			"doors": [{"side": "S", "at": _at(door_x, x0, w), "exit": true}, {"side": "N", "at": _at(kitchen_cx, x0, w)},
				{"side": "N", "at": _at(bed_cx, x0, w)}], "windows": living_windows},
		{"id": "kitchen", "type": "small_kitchen", "floor": 0, "rect": [x0, z0, kw, split - z0],
			"doors": [{"side": "S", "at": 0.5}], "windows": [{"side": "W", "at": 0.5}]},
		{"id": "bedroom", "type": "small_bedroom", "floor": 0, "rect": [x0 + kw, z0, w - kw, split - z0],
			"doors": [{"side": "S", "at": 0.5}], "windows": [{"side": "N", "at": 0.7}, {"side": "E", "at": 0.5}]},
	]


## A wide, shallow house: kitchen, living room (front door) and bedroom in a row.
static func _side_by_side(w: float, d: float, door_x: float) -> Array:
	var x0 := -w * 0.5
	var z0 := -d * 0.5
	var kw := 6.0 * INSIDE_SCALE
	var lx0 := x0 + kw
	var lw := 10.0 * INSIDE_SCALE
	return [
		{"id": "kitchen", "type": "small_kitchen", "floor": 0, "rect": [x0, z0, kw, d],
			"doors": [{"side": "E", "at": 0.5}], "windows": [{"side": "W", "at": 0.5}]},
		{"id": "living", "type": "small_living", "floor": 0, "rect": [lx0, z0, lw, d],
			"doors": [{"side": "S", "at": _at(door_x, lx0, lw), "exit": true}, {"side": "W", "at": 0.5}, {"side": "E", "at": 0.5}],
			"windows": [{"side": "N", "at": 0.25}]},
		{"id": "bedroom", "type": "small_bedroom", "floor": 0, "rect": [lx0 + lw, z0, w - kw - lw, d],
			"doors": [{"side": "W", "at": 0.5}], "windows": [{"side": "E", "at": 0.5}, {"side": "N", "at": 0.5}]},
	]


## Two floors: living room (front door) and kitchen downstairs beside a
## stairwell; upstairs a landing and two bedrooms (the back one through the
## front one). Stairs run up the side, back to front, with room to step off
## at the top and on at the bottom.
static func _two_floors(w: float, d: float, door_x: float) -> Array:
	var x0 := -w * 0.5
	var z0 := -d * 0.5
	var sw := 7.0
	var sx0 := w * 0.5 - sw
	var mw := w - sw
	var split := z0 + 10.0 * INSIDE_SCALE
	var bottom := z0 + 4.0
	var top := d * 0.5 - 6.5
	var sx := sx0 + sw * 0.5
	var rooms := [
		{"id": "living", "type": "small_living", "floor": 0, "rect": [x0, split, mw, d * 0.5 - split],
			"doors": [{"side": "S", "at": _at(door_x, x0, mw), "exit": true}, {"side": "N", "at": 0.5}],
			"windows": [{"side": "W", "at": 0.5}, {"side": "S", "at": 0.15}]},
		{"id": "kitchen", "type": "small_kitchen", "floor": 0, "rect": [x0, z0, mw, split - z0],
			"doors": [{"side": "S", "at": 0.5}, {"side": "E", "at": 2.2 / (split - z0)}], "windows": [{"side": "W", "at": 0.5}, {"side": "N", "at": 0.3}]},
		{"id": "stairwell", "type": "stairwell", "floor": 0, "rect": [sx0, z0, sw, d],
			"doors": [{"side": "W", "at": 2.2 / d}], "windows": [{"side": "E", "at": 0.12}]},
		{"id": "landing", "type": "landing", "floor": 1, "rect": [sx0, z0, sw, d],
			"holes": [[sx0 + 1.0, bottom, sw - 2.0, top - bottom]],
			"doors": [{"side": "W", "at": (top + 3.25 - z0) / d}], "windows": [{"side": "E", "at": 0.85}]},
		{"id": "bedroom", "type": "small_bedroom", "floor": 1, "rect": [x0, split, mw, d * 0.5 - split],
			"doors": [{"side": "E", "at": (top + 3.25 - split) / (d * 0.5 - split)}, {"side": "N", "at": 0.5}],
			"windows": [{"side": "S", "at": 0.3}, {"side": "W", "at": 0.5}]},
		{"id": "bedroom2", "type": "small_bedroom", "floor": 1, "rect": [x0, z0, mw, split - z0],
			"doors": [{"side": "S", "at": 0.5}], "windows": [{"side": "N", "at": 0.5}, {"side": "W", "at": 0.5}]},
	]
	var stairs := [{"from": "stairwell", "to": "landing", "bottom": [sx, bottom], "top": [sx, top], "width": 4.0}]
	return [rooms, stairs]
