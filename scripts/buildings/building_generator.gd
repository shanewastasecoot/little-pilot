class_name BuildingGenerator
extends RefCounted
## Builds the inside of a building from data (a JSON file, see
## resources/buildings/her_house.json): floors, walls with doorways, framed
## windows, a daylight exit door, a soft light per room, and furniture per
## room type (KayKit Furniture Bits, CC0), varied by a seed. Later
## buildings reuse it with their own layouts.
##
## Floor plan: x right, z towards the front door, y up; a room is
## rect = [x, z, width, depth] on storey `floor`. Walls are built just
## inside each room's edge, so two rooms sharing an edge get a wall each
## (back to back); doorways are cut through both.

const FURNITURE := "res://assets/furniture/kaykit_furniture_bits/"
## Kitchen and dining things (KayKit Restaurant Bits, CC0): item names
## starting with "r:" come from here.
const RESTAURANT := "res://assets/furniture/kaykit_restaurant_bits/"
const WINDOW_SIZE := Vector2(5.0, 4.6)
const WINDOW_Y := 5.6
## Walls stop this far below the storey above (under its floor slab).
const WALL_GAP := 0.7
## Sophia's toys: mermaids about 1.6 m (a 5 m girl), stuffies about 2 m.
const MERMAID_TOY_SCALE := 1.7
const STUFFY_SCALE := 3.0


static func load_data(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Can't open building data %s" % path)
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}


## Build the interior described by `data` (a parsed JSON layout).
static func build(data: Dictionary) -> Interior:
	var interior := Interior.new()
	interior.name = "Interior_" + str(data.get("name", "building"))
	interior.data = data
	var rng := RandomNumberGenerator.new()
	rng.seed = int(data.get("seed", 1))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, 28, 0)
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	interior.add_child(sun)
	for room: Dictionary in data.get("rooms", []):
		_build_room(interior, data, room, rng)
	for st: Dictionary in data.get("stairs", []):
		_build_stairs(interior, data, st)
	_add_garden(interior, data)
	return interior


## The view out of the windows: a garden round the ground floor's footprint
## with the path out from the front door.
static func _add_garden(interior: Interior, data: Dictionary) -> void:
	var footprint := Rect2()
	var first := true
	var door := Vector2.ZERO
	for room: Dictionary in data.get("rooms", []):
		var r: Array = room.rect
		var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		footprint = rect if first else footprint.merge(rect)
		first = false
		for d: Dictionary in room.get("doors", []):
			if d.get("exit", false):
				var at := float(d.at)
				match str(d.side):
					"S": door = Vector2(rect.position.x + at * rect.size.x, rect.end.y)
					"N": door = Vector2(rect.position.x + at * rect.size.x, rect.position.y)
					"W": door = Vector2(rect.position.x, rect.position.y + at * rect.size.y)
					_: door = Vector2(rect.end.x, rect.position.y + at * rect.size.y)
	var garden := HouseGarden.new()
	garden.name = "Garden"
	garden.footprint = footprint
	garden.front_door = door
	interior.add_child(garden)


static func _build_room(interior: Interior, data: Dictionary, room: Dictionary, rng: RandomNumberGenerator) -> void:
	var r: Array = room.rect
	var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	var storey: float = data.get("storey_height", 11.0)
	var base := float(room.get("floor", 0)) * storey
	var node := Node3D.new()
	node.name = str(room.id)
	interior.add_child(node)
	var info := {"id": room.id, "type": room.type, "rect": rect, "floor": int(room.get("floor", 0)), "base": base, "node": node,
		"own_materials": str(room.type) == "bedroom", "mats": [], "hers": room.get("hers", false)}
	interior.rooms.append(info)
	# Floor (solid, with any holes left open) and a soft light.
	var floor_mat := _room_mat(info, str(room.get("floor_colour", "c8a27a")))
	var holes: Array = room.get("holes", [])
	for piece: Rect2 in _floor_pieces(rect, holes):
		var fmi := BuildKit.add(node, BuildKit.box(Vector3(piece.size.x, 0.6, piece.size.y)), "ffffff",
				Vector3(piece.get_center().x, base - 0.3, piece.get_center().y))
		fmi.material_override = floor_mat
		BuildKit.collider(node, BuildKit.box_shape(Vector3(piece.size.x, 0.6, piece.size.y)), Vector3(piece.get_center().x, base - 0.3, piece.get_center().y))
	for h: Array in holes:
		_hole_rails(data, Rect2(float(h[0]), float(h[1]), float(h[2]), float(h[3])), rect, base, node)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(rect.get_center().x, base + storey * 0.8, rect.get_center().y)
	lamp.omni_range = maxf(rect.size.x, rect.size.y) * 0.9
	lamp.light_energy = 0.35
	lamp.light_color = Color("fff1d6")
	node.add_child(lamp)
	info["light"] = lamp
	# Walls, side by side.
	for side in ["N", "S", "W", "E"]:
		_build_side(interior, data, room, rect, base, side, node)
	_furnish(interior, data, room, rect, base, node, rng)


## One side of a room: wall pieces around its doorways, lintels over them,
## windows on it, and (for exit doors) the daylight doorway.
static func _build_side(interior: Interior, data: Dictionary, room: Dictionary, rect: Rect2, base: float, side: String, node: Node3D) -> void:
	var t: float = data.get("wall_thickness", 0.5)
	var storey: float = data.get("storey_height", 11.0)
	var door_w: float = data.get("door_width", 7.0)
	var door_h: float = data.get("door_height", 8.5)
	var colour := str(room.get("wall", "fff1d6"))
	var along_x := side == "N" or side == "S"
	var length := rect.size.x if along_x else rect.size.y
	# Where the wall's centre line runs, and which way is into the room.
	var fixed: float
	var inward: Vector2
	match side:
		"N":
			fixed = rect.position.y + t * 0.5
			inward = Vector2(0, 1)
		"S":
			fixed = rect.end.y - t * 0.5
			inward = Vector2(0, -1)
		"W":
			fixed = rect.position.x + t * 0.5
			inward = Vector2(1, 0)
		_:
			fixed = rect.end.x - t * 0.5
			inward = Vector2(-1, 0)
	var start := rect.position.x if along_x else rect.position.y
	var point := func(u: float) -> Vector2:
		return Vector2(start + u, fixed) if along_x else Vector2(fixed, start + u)
	var gaps: Array = []
	for d: Dictionary in room.get("doors", []):
		if d.side == side:
			gaps.append([float(d.at) * length - door_w * 0.5, float(d.at) * length + door_w * 0.5, d])
	gaps.sort_custom(func(a, b): return a[0] < b[0])
	var pieces: Array[GeometryInstance3D] = []
	var u := 0.0
	# Walls stop just under the floor above (their tops can't show through
	# it or flicker against it).
	var top := storey - WALL_GAP
	var spans: Array = []
	for g in gaps:
		spans.append([u, g[0], 0.0, top])          # full-height piece before the gap
		spans.append([g[0], g[1], door_h, top])    # lintel over the gap
		u = g[1]
	spans.append([u, length, 0.0, top])
	for sp in spans:
		var a: float = sp[0]
		var b: float = sp[1]
		if b - a < 0.05:
			continue
		var mid: Vector2 = point.call((a + b) * 0.5)
		var h: float = sp[3] - sp[2]
		var size := Vector3(b - a, h, t) if along_x else Vector3(t, h, b - a)
		var mi := BuildKit.add(node, BuildKit.box(size), colour, Vector3(mid.x, base + sp[2] + h * 0.5, mid.y))
		mi.material_override = _room_mat(interior.rooms[interior.rooms.size() - 1], colour, true)
		BuildKit.collider(node, BuildKit.box_shape(size), mi.position)
		pieces.append(mi)
	# Windows: a frame and glowing sky glass on the room side.
	for w: Dictionary in room.get("windows", []):
		if w.side != side:
			continue
		var c: Vector2 = point.call(float(w.at) * length) + inward * (t * 0.5 + 0.08)
		var ws := Vector3(WINDOW_SIZE.x, WINDOW_SIZE.y, 0.2) if along_x else Vector3(0.2, WINDOW_SIZE.y, WINDOW_SIZE.x)
		var frame := BuildKit.add(node, BuildKit.box(ws + (Vector3(0.9, 0.9, 0.0) if along_x else Vector3(0.0, 0.9, 0.9))), "ffffff",
				Vector3(c.x, base + WINDOW_Y, c.y))
		frame.material_override = _mat("ffffff")
		var glass := BuildKit.add(node, BuildKit.box(ws), "9fd8ff", Vector3(c.x, base + WINDOW_Y, c.y) + Vector3(inward.x, 0, inward.y) * 0.12)
		glass.material_override = _glow_mat(Color("bfe6ff"))
		var bar_size := Vector3(0.3, WINDOW_SIZE.y, 0.3) if along_x else Vector3(0.3, WINDOW_SIZE.y, 0.3)
		var bar := BuildKit.add(node, BuildKit.box(bar_size), "ffffff", glass.position + Vector3(inward.x, 0, inward.y) * 0.12)
		bar.material_override = _mat("ffffff")
		pieces.append_array([frame, glass, bar])
	# Exit doors: bright daylight in the doorway, a mat, and the way out.
	for g in gaps:
		var d: Dictionary = g[2]
		if not d.get("exit", false):
			continue
		var c: Vector2 = point.call((g[0] + g[1]) * 0.5)
		var out := -inward
		var light_pos := Vector3(c.x + out.x * (t + 0.4), base + door_h * 0.5, c.y + out.y * (t + 0.4))
		var panel_size := Vector3(door_w, door_h, 0.3) if along_x else Vector3(0.3, door_h, door_w)
		var daylight := BuildKit.add(node, BuildKit.box(panel_size), "fffbe6", light_pos)
		daylight.material_override = _glow_mat(Color("fff6cf"))
		BuildKit.collider(node, BuildKit.box_shape(panel_size), light_pos)
		var mat_pos := Vector3(c.x + inward.x * 3.0, base + 0.06, c.y + inward.y * 3.0)
		var mat_size := Vector3(door_w - 1.0, 0.12, 4.0) if along_x else Vector3(4.0, 0.12, door_w - 1.0)
		BuildKit.add(node, BuildKit.box(mat_size), "8b5a2b", mat_pos).material_override = _mat("8b5a2b")
		interior.add_exit(Vector3(c.x + inward.x * 1.6, base + 2.0, c.y + inward.y * 1.6),
				Vector3(c.x + inward.x * 9.0, base, c.y + inward.y * 9.0), atan2(-inward.x, -inward.y))
		pieces.append(daylight)
	interior.walls.append({"room": room.id, "a": point.call(0.0), "b": point.call(length), "inward": inward,
			"floor": int(room.get("floor", 0)), "pieces": pieces})


# --- Furniture ----------------------------------------------------------------------

## A piece of KayKit furniture at (fx, fz) as fractions of the room, turned
## `yaw` degrees, `scale` x the furniture scale. Solid pieces get a box
## you bump into. Returns the node.
static func _put(node: Node3D, data: Dictionary, rect: Rect2, base: float, item: String, fx: float, fz: float,
		yaw := 0.0, scale := 1.0, solid := true, lift := 0.0) -> Node3D:
	var s: float = float(data.get("furniture_scale", 2.27)) * scale
	var path := (RESTAURANT + item.substr(2) if item.begins_with("r:") else FURNITURE + item) + ".gltf"
	if not ResourceLoader.exists(path):
		push_warning("No furniture model %s" % path)
		return null
	var piece: Node3D = (load(path) as PackedScene).instantiate()
	piece.name = item.trim_prefix("r:")
	piece.scale = Vector3.ONE * s
	piece.rotation_degrees.y = yaw
	piece.position = Vector3(rect.position.x + fx * rect.size.x, base + lift, rect.position.y + fz * rect.size.y)
	node.add_child(piece)
	if solid:
		var box := AABB()
		var first := true
		for mi: MeshInstance3D in piece.find_children("*", "MeshInstance3D", true, false):
			var xf := Transform3D()
			var n: Node = mi
			while n != piece:
				xf = (n as Node3D).transform * xf
				n = n.get_parent()
			var b: AABB = xf * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
		if not first and box.size.y > 0.15:
			var body := StaticBody3D.new()
			body.collision_layer = GameSettings.LAYER_WORLD
			var cs := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = box.size
			cs.shape = shape
			cs.position = box.get_center()
			body.add_child(cs)
			piece.add_child(body)
			body.add_to_group("furniture")
	return piece


## Distance from a wall (fraction of the room) for something `depth` m deep
## (in furniture units) standing against it.
static func _against(data: Dictionary, rect_len: float, depth: float) -> float:
	var t: float = data.get("wall_thickness", 0.5)
	return (t + depth * float(data.get("furniture_scale", 2.27)) * 0.5 + 0.3) / rect_len


static func _furnish(interior: Interior, data: Dictionary, room: Dictionary, rect: Rect2, base: float, node: Node3D,
		rng: RandomNumberGenerator) -> void:
	var ab := func(name: String) -> String: return name + ("_A" if rng.randf() < 0.5 else "_B")
	var jitter := func() -> float: return rng.randf_range(-0.02, 0.02)
	match str(room.type):
		"hall":
			_put(node, data, rect, base, ab.call("rug_rectangle_stripes"), 0.5, 0.45, 90.0, 1.7, false)
			var n_wall := _against(data, rect.size.y, 1.1)
			_put(node, data, rect, base, "cabinet_small_decorated", 0.15 + jitter.call(), n_wall)
			_put(node, data, rect, base, "lamp_standing", 0.9, _against(data, rect.size.y, 1.0))
			_put(node, data, rect, base, ab.call("pictureframe_large"), 0.25, (data.get("wall_thickness", 0.5) + 0.3) / rect.size.y,
					0.0, 1.3, false, 6.5)
			_put(node, data, rect, base, ab.call("cactus_medium"), 0.1, 0.86, rng.randf() * 360.0, 1.3)
		"playroom":
			_put(node, data, rect, base, ab.call("rug_oval"), 0.52, 0.52, 0.0, 2.2, false)
			var tb := ToyBox.new()
			tb.name = "ToyBox"
			tb.position = Vector3(rect.position.x + 0.28 * rect.size.x, base, rect.position.y + _against(data, rect.size.y, 2.0) * rect.size.y)
			node.add_child(tb)
			interior.toy_boxes.append(tb)
			var ball := BouncyBall.new()
			ball.name = "Ball"
			ball.home = Vector3(rect.position.x + 0.6 * rect.size.x, base + 2.0, rect.position.y + 0.6 * rect.size.y)
			node.add_child(ball)
			interior.balls.append(ball)
			_put(node, data, rect, base, "table_small", 0.2, 0.78, 0.0, 1.0)
			_put(node, data, rect, base, "chair_stool", 0.2 - 0.07, 0.78, 0.0, 1.0)
			_put(node, data, rect, base, "chair_stool", 0.2 + 0.07, 0.78, 0.0, 1.0)
			_put(node, data, rect, base, "shelf_B_large_decorated", (data.get("wall_thickness", 0.5) + 0.7) / rect.size.x, 0.5, 90.0, 1.2,
					false, 5.0)
			_put(node, data, rect, base, "pillow_A", 0.82, 0.84, rng.randf() * 360.0, 2.0, false)
			_put(node, data, rect, base, "pillow_B", 0.88, 0.76, rng.randf() * 360.0, 2.0, false)
			_put(node, data, rect, base, "lamp_standing", 0.07, _against(data, rect.size.y, 1.0))
			_put(node, data, rect, base, ab.call("pictureframe_small"), 0.75, 1.0 - (data.get("wall_thickness", 0.5) + 0.3) / rect.size.y,
					180.0, 1.6, false, 6.0)
		"kitchen":
			_furnish_kitchen(interior, data, rect, base, node, rng)
		"dining":
			_furnish_dining(interior, data, rect, base, node, rng)
		"living":
			_furnish_living(interior, data, rect, base, node, rng)
		"bedroom":
			_furnish_bedroom(interior, data, room, rect, base, node, rng)


## Along the back (north) wall: the fridge, counters, the sink and the stove
## with the bubbling pot; cupboards above; crates of vegetables in a corner.
static func _furnish_kitchen(interior: Interior, data: Dictionary, rect: Rect2, base: float, node: Node3D,
		rng: RandomNumberGenerator) -> void:
	var f: float = data.get("furniture_scale", 2.27)
	var t: float = data.get("wall_thickness", 0.5)
	var unit := 2.0 * f  # one counter's width
	var z := rect.position.y + t + 1.02 * f + 0.2
	var x := rect.position.x + t + unit * 0.5 + 0.3
	var fridge := KitchenFridge.new()
	fridge.name = "Fridge"
	fridge.furniture_scale = f
	fridge.position = Vector3(x, base, rect.position.y + t + 0.75 * f + 0.25)
	node.add_child(fridge)
	interior.fridges.append(fridge)
	var meals := MealPicker.new()
	meals.name = "Meals"
	meals.fridge = fridge
	meals.furniture_scale = f
	# A row along the south wall, facing the fridge: off the way to it,
	# so walking up to the fridge doesn't pick one up by accident.
	meals.position = Vector3(rect.position.x + 12.0, base, rect.end.y - t - 3.0)
	node.add_child(meals)
	interior.meal_pickers.append(meals)
	x += unit
	var row := ["r:kitchencounter_straight_A_backsplash", "r:kitchencounter_sink_backsplash", "r:kitchencounter_straight_A_decorated",
		"stove", "r:kitchencounter_straight_A_backsplash"]
	for item in row:
		var fx := (x - rect.position.x) / rect.size.x
		var fz := (z - rect.position.y) / rect.size.y
		if item == "stove":
			_put(node, data, rect, base, "r:stove_multi", fx, fz)
			var pot := BubblingPot.new()
			pot.name = "Pot"
			pot.furniture_scale = f
			pot.position = Vector3(x - 0.45 * f, base + 1.2 * f, z + 0.25 * f)
			node.add_child(pot)
			interior.pots.append(pot)
		else:
			_put(node, data, rect, base, item, fx, fz)
		if item != "stove" and rng.randf() < 0.7:
			_put(node, data, rect, base, "r:kitchencabinet", fx, (t + 0.55 * f) / rect.size.y, 0.0, 1.0, false, 4.6)
		x += unit
	# Jars and a chopping board on the counter, vegetables in the corner.
	_put(node, data, rect, base, "r:jar_A_medium", (rect.position.x + t + unit * 1.3 - rect.position.x) / rect.size.x,
			(z - rect.position.y) / rect.size.y, 0.0, 1.0, false, 1.0 * f)
	_put(node, data, rect, base, "r:cuttingboard", (rect.position.x + t + unit * 3.5 - rect.position.x) / rect.size.x,
			(z - rect.position.y) / rect.size.y, 10.0, 1.0, false, 1.0 * f)
	_put(node, data, rect, base, "r:crate_carrots", 0.9, 0.82, rng.randf_range(-20, 20))
	_put(node, data, rect, base, "r:crate_tomatoes", 0.78, 0.86, rng.randf_range(-20, 20))
	_put(node, data, rect, base, "lamp_standing", 0.95, 0.12)


## A long table with chairs round it (it sets itself when you walk up), a
## cabinet, a picture and a lamp.
static func _furnish_dining(interior: Interior, data: Dictionary, rect: Rect2, base: float, node: Node3D,
		rng: RandomNumberGenerator) -> void:
	var f: float = data.get("furniture_scale", 2.27)
	var table := SettableTable.new()
	table.name = "DiningTable"
	table.furniture_scale = f
	var c := Vector3(rect.get_center().x, base, rect.get_center().y - 1.0)
	table.position = c
	node.add_child(table)
	interior.tables.append(table)
	_put(node, data, rect, base, "table_medium_long", (c.x - rect.position.x) / rect.size.x, (c.z - rect.position.y) / rect.size.y,
			0.0, 1.35)
	var chair := "chair_A_wood" if rng.randf() < 0.5 else "chair_B_wood"
	var top := 1.0 * f * 1.35 + 0.05
	var half_x := 1.5 * 1.35 * f
	var half_z := 1.0 * 1.35 * f
	for k in 3:
		var px := c.x - half_x * 0.66 + k * half_x * 0.66
		for side in [-1.0, 1.0]:
			var pz: float = c.z + side * (half_z + 0.9 * f)
			_put(node, data, rect, base, chair, (px - rect.position.x) / rect.size.x, (pz - rect.position.y) / rect.size.y,
					180.0 if side > 0 else 0.0, 1.35)
			table.places.append(Vector3(px - c.x, top, side * (half_z - 0.6 * f)))
	var n_wall := BuildingGenerator._against(data, rect.size.y, 1.0)
	_put(node, data, rect, base, "cabinet_medium_decorated", 0.2, n_wall, 0.0, 1.2)
	_put(node, data, rect, base, "lamp_standing", 0.9, n_wall)
	_put(node, data, rect, base, "pictureframe_large_B", 0.7, (data.get("wall_thickness", 0.5) + 0.3) / rect.size.y, 0.0, 1.3, false, 6.5)


## A sofa you can bounce on, armchairs, a low table on a rug, a lamp,
## pictures and the trophy shelf for dragon treasure.
static func _furnish_living(interior: Interior, data: Dictionary, rect: Rect2, base: float, node: Node3D,
		rng: RandomNumberGenerator) -> void:
	var f: float = data.get("furniture_scale", 2.27)
	var t: float = data.get("wall_thickness", 0.5)
	_put(node, data, rect, base, "rug_rectangle_" + ("A" if rng.randf() < 0.5 else "B"), 0.56, 0.5, 90.0, 2.2, false)
	var tv := TVSet.new()
	tv.name = "TV"
	tv.furniture_scale = f
	tv.position = Vector3(rect.end.x - t - 0.5 * f - 0.4, base, rect.get_center().y)
	tv.rotation.y = -PI * 0.5  # facing west, into the room
	node.add_child(tv)
	interior.tvs.append(tv)
	# The sofa facing the TV (east) from the middle of the room.
	var sofa_x := rect.position.x + 0.36 * rect.size.x
	var sofa := _put(node, data, rect, base, "couch_pillows", 0.36, 0.5, 90.0, 1.0, false)
	if sofa:
		_bouncy_seat(sofa, f)
		interior.sofas.append(sofa)
	_put(node, data, rect, base, "table_low", (sofa_x + 8.0 - rect.position.x) / rect.size.x, 0.5, 90.0, 1.0)
	# Armchairs either side, turned towards the TV.
	var tvp := Vector2(tv.position.x, tv.position.z)
	for fz in [0.18, 0.82]:
		var at := Vector2(rect.position.x + 0.5 * rect.size.x, rect.position.y + fz * rect.size.y)
		var to := tvp - at
		_put(node, data, rect, base, "armchair_pillows", 0.5, fz, rad_to_deg(atan2(to.x, to.y)), 1.0)
	_put(node, data, rect, base, "lamp_standing", (t + 0.5 * f + 0.3) / rect.size.x, (t + 0.5 * f + 0.3) / rect.size.y)
	_put(node, data, rect, base, "pictureframe_large_A", 0.3, 1.0 - (t + 0.3) / rect.size.y, 180.0, 1.4, false, 6.5)
	var shelf := TrophyShelf.new()
	shelf.name = "TrophyShelf"
	shelf.position = Vector3(rect.position.x + 0.45 * rect.size.x, base + 5.2, rect.position.y + t)
	node.add_child(shelf)
	interior.trophy_shelf = shelf


## A sofa's colliders: a low, bouncy seat (you can jump onto it: landing on
## it bounces you high) and a solid back.
static func _bouncy_seat(sofa: Node3D, f: float) -> void:
	var seat := StaticBody3D.new()
	seat.collision_layer = GameSettings.LAYER_WORLD
	seat.add_to_group("bouncy")
	var cs := CollisionShape3D.new()
	cs.shape = BuildKit.box_shape(Vector3(2.8, 0.5, 1.1))
	cs.position = Vector3(0, 0.25, 0.15)
	seat.add_child(cs)
	sofa.add_child(seat)
	var back := StaticBody3D.new()
	back.collision_layer = GameSettings.LAYER_WORLD
	var bs := CollisionShape3D.new()
	bs.shape = BuildKit.box_shape(Vector3(3.0, 1.22, 0.45))
	bs.position = Vector3(0, 0.61, -0.57)
	back.add_child(bs)
	sofa.add_child(back)


# --- Floors with holes, railings, stairs --------------------------------------------

## The floor of `rect` cut round its holes (one hole: up to four pieces).
static func _floor_pieces(rect: Rect2, holes: Array) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if holes.is_empty():
		out.append(rect)
		return out
	var h := Rect2(float(holes[0][0]), float(holes[0][1]), float(holes[0][2]), float(holes[0][3])).intersection(rect)
	for r in [Rect2(rect.position.x, rect.position.y, h.position.x - rect.position.x, rect.size.y),
			Rect2(h.end.x, rect.position.y, rect.end.x - h.end.x, rect.size.y),
			Rect2(h.position.x, rect.position.y, h.size.x, h.position.y - rect.position.y),
			Rect2(h.position.x, h.end.y, h.size.x, rect.end.y - h.end.y)]:
		if r.size.x > 0.05 and r.size.y > 0.05:
			out.append(r)
	return out


## Railings round a hole in the floor, on every edge that isn't against a
## wall or where the stairs come up (walk-into-proof: a tall invisible wall
## behind a low white rail).
static func _hole_rails(data: Dictionary, hole: Rect2, rect: Rect2, base: float, node: Node3D) -> void:
	var t: float = data.get("wall_thickness", 0.5)
	var tops: Array[Vector2] = []
	for st: Dictionary in data.get("stairs", []):
		tops.append(Vector2(float(st.top[0]), float(st.top[1])))
	var edges := [[hole.position, Vector2(hole.end.x, hole.position.y)], [Vector2(hole.position.x, hole.end.y), hole.end],
			[hole.position, Vector2(hole.position.x, hole.end.y)], [Vector2(hole.end.x, hole.position.y), hole.end]]
	for e in edges:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var mid := (a + b) * 0.5
		var near_wall := absf(mid.x - rect.position.x) < t + 0.4 or absf(mid.x - rect.end.x) < t + 0.4 \
				or absf(mid.y - rect.position.y) < t + 0.4 or absf(mid.y - rect.end.y) < t + 0.4
		var at_top := false
		for tp in tops:
			if Geometry2D.get_closest_point_to_segment(tp, a, b).distance_to(tp) < 1.0:
				at_top = true
		if near_wall or at_top:
			continue
		var length := a.distance_to(b)
		var along_x := absf(b.y - a.y) < 0.01
		var size := Vector3(length, 0.4, 0.4) if along_x else Vector3(0.4, 0.4, length)
		var bar := BuildKit.add(node, BuildKit.box(size), "ffffff", Vector3(mid.x, base + 3.2, mid.y))
		bar.material_override = _mat("ffffff")
		var posts := int(length / 2.5)
		for k in posts + 1:
			var p := a.lerp(b, float(k) / maxf(posts, 1))
			BuildKit.add(node, BuildKit.box(Vector3(0.3, 3.2, 0.3)), "ffffff", Vector3(p.x, base + 1.6, p.y)).material_override = _mat("ffffff")
		var wall := Vector3(length, 6.0, 0.4) if along_x else Vector3(0.4, 6.0, length)
		BuildKit.collider(node, BuildKit.box_shape(wall), Vector3(mid.x, base + 3.0, mid.y))


## A straight flight of stairs: stepped blocks to see, a solid wedge to
## walk on (smooth, so nothing snags and nothing's underneath), and a
## banister on the open side. It's listed with the room below (so it
## shows and hides with that storey).
static func _build_stairs(interior: Interior, data: Dictionary, st: Dictionary) -> void:
	var below: Dictionary = interior.find_room(str(st.from))
	var above: Dictionary = interior.find_room(str(st.to))
	if below.is_empty() or above.is_empty():
		return
	var node: Node3D = below.node
	var y0: float = below.base
	var y1: float = above.base
	var b := Vector2(float(st.bottom[0]), float(st.bottom[1]))
	var tp := Vector2(float(st.top[0]), float(st.top[1]))
	var w: float = st.get("width", 6.0)
	var dir := (tp - b).normalized()
	var side := Vector2(-dir.y, dir.x) * w * 0.5
	var run := b.distance_to(tp)
	var steps := 14
	for i in steps:
		var f0 := float(i) / steps
		var f1 := float(i + 1) / steps
		var c := b.lerp(tp, (f0 + f1) * 0.5)
		var h := (y1 - y0) * f1
		var size := Vector3(run / steps if absf(dir.x) > 0.5 else w, h, w if absf(dir.x) > 0.5 else run / steps)
		var step := BuildKit.add(node, BuildKit.box(size), "c8a27a" if i % 2 == 0 else "b98a5e", Vector3(c.x, y0 + h * 0.5, c.y))
		step.material_override = _mat("c8a27a" if i % 2 == 0 else "b98a5e")
	# The wedge you walk on.
	var body := StaticBody3D.new()
	body.collision_layer = GameSettings.LAYER_WORLD
	var shape := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for s in [side, -side]:
		pts.append(Vector3(b.x + s.x, y0, b.y + s.y))
		pts.append(Vector3(tp.x + s.x, y0, tp.y + s.y))
		pts.append(Vector3(tp.x + s.x, y1, tp.y + s.y))
	shape.points = pts
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	node.add_child(body)
	# Banisters on the sides that aren't against a wall.
	var rect: Rect2 = below.rect
	var banisters: Array[Vector2] = []
	for sd in [side, -side]:
		if _dist_to_rect_edge((b + tp) * 0.5 + sd, rect) > 1.5:
			banisters.append(sd)
	for open in banisters:
		_banister(node, b, tp, y0, y1, open, w)
	interior.stairs.append({"from": str(st.from), "to": str(st.to), "bottom": Vector3(b.x, y0, b.y), "top": Vector3(tp.x, y1, tp.y)})


## A banister along one side of a flight: posts you see and a slanted wall
## you can't walk or jump through.
static func _banister(node: Node3D, b: Vector2, tp: Vector2, y0: float, y1: float, open: Vector2, w: float) -> void:
	var o := open.normalized() * (w * 0.5 + 0.2)
	var rail := StaticBody3D.new()
	rail.collision_layer = GameSettings.LAYER_WORLD
	var rshape := ConvexPolygonShape3D.new()
	var rp := PackedVector3Array()
	for k in [0.0, 0.4]:
		var off: Vector2 = open.normalized() * float(k)
		for e in [[b, y0], [tp, y1]]:
			var p: Vector2 = e[0] + o + off
			rp.append(Vector3(p.x, e[1], p.y))
			rp.append(Vector3(p.x, e[1] + 5.5, p.y))
	rshape.points = rp
	var rcs := CollisionShape3D.new()
	rcs.shape = rshape
	rail.add_child(rcs)
	node.add_child(rail)
	for i in 8:
		var f := (i + 0.5) / 8.0
		var p := b.lerp(tp, f) + o
		var h := (y1 - y0) * f
		BuildKit.add(node, BuildKit.box(Vector3(0.3, 3.2, 0.3)), "ffffff", Vector3(p.x, y0 + h + 1.6, p.y)).material_override = _mat("ffffff")


static func _dist_to_rect_edge(p: Vector2, r: Rect2) -> float:
	return minf(minf(p.x - r.position.x, r.end.x - p.x), minf(p.y - r.position.y, r.end.y - p.y))


# --- Bedrooms --------------------------------------------------------------------

## A bed (land on it to bounce), a nightstand and lamp, a rug, a picture,
## a shelf, and a light switch by the door. Her room also has paint pots
## (walk into one to colour the walls) and cushions (the bed's quilt), and
## the house's hidden star is tucked into one room's corner.
static func _furnish_bedroom(interior: Interior, data: Dictionary, room: Dictionary, rect: Rect2, base: float, node: Node3D,
		rng: RandomNumberGenerator) -> void:
	var f: float = data.get("furniture_scale", 2.27)
	var t: float = data.get("wall_thickness", 0.5)
	var info: Dictionary = interior.find_room(str(room.id))
	var door_side := "S"
	var door_at := 0.5
	for d: Dictionary in room.get("doors", []):
		door_side = str(d.side)
		door_at = float(d.at)
	var back_north := door_side == "S"
	var back_z := (t + 1.5 * f + 0.4) / rect.size.y
	var bz := back_z if back_north else 1.0 - back_z
	var double: bool = rng.randf() < 0.5 or bool(room.get("hers", false))
	var bed_name := ("bed_double_" if double else "bed_single_") + ("A" if rng.randf() < 0.5 else "B")
	var bed := _put(node, data, rect, base, bed_name, 0.5, bz, 0.0 if back_north else 180.0, 1.0, false)
	if bed:
		var seat := StaticBody3D.new()
		seat.collision_layer = GameSettings.LAYER_WORLD
		seat.add_to_group("bouncy")
		seat.add_to_group("bed")
		var cs := CollisionShape3D.new()
		var bw := 3.1 if double else 1.6
		cs.shape = BuildKit.box_shape(Vector3(bw, 0.55, 2.9))
		cs.position = Vector3(0, 0.275, 0.05)
		seat.add_child(cs)
		bed.add_child(seat)
		interior.beds.append(bed)
		if room.get("hers", false):
			var quilt := MeshInstance3D.new()
			quilt.mesh = BuildKit.box(Vector3(bw * 0.92, 0.12, 1.7))
			quilt.position = Vector3(0, 0.6, 0.55)
			var qm := StandardMaterial3D.new()
			qm.albedo_color = Color("ffffff")
			qm.roughness = 1.0
			quilt.material_override = qm
			bed.add_child(quilt)
			info["quilt"] = qm
	var side_x := 0.5 + (2.0 if double else 1.3) * f / rect.size.x + 0.06
	_put(node, data, rect, base, "cabinet_small", side_x, bz - (0.25 if back_north else -0.25) * 0.0 + (-0.04 if back_north else 0.04), 0.0 if back_north else 180.0)
	_put(node, data, rect, base, "lamp_table", side_x, bz + (-0.04 if back_north else 0.04), 0.0, 1.0, false, 1.0 * f)
	_put(node, data, rect, base, "rug_oval_" + ("A" if rng.randf() < 0.5 else "B"), 0.5, 0.55 if back_north else 0.45, 0.0, 1.6, false)
	if not room.get("hers", false):
		_put(node, data, rect, base, "pictureframe_medium", 0.25, (t + 0.3) / rect.size.y if back_north else 1.0 - (t + 0.3) / rect.size.y,
				0.0 if back_north else 180.0, 1.5, false, 6.5)
		_put(node, data, rect, base, "shelf_A_small", 1.0 - (t + 0.6) / rect.size.x, 0.5, -90.0, 1.4, false, 5.0)
	# Light switch on the door wall, beside the door.
	var sw := LightSwitch.new()
	sw.name = "LightSwitch"
	var door_w: float = data.get("door_width", 7.0)
	var sx := rect.position.x + rect.size.x * door_at + door_w * 0.5 + 2.2
	if sx > rect.end.x - t - 1.0:
		sx = rect.position.x + rect.size.x * door_at - door_w * 0.5 - 2.2
	var sz := rect.end.y - t if back_north else rect.position.y + t
	sw.position = Vector3(sx, base + 4.0, sz)
	sw.rotation.y = PI if back_north else 0.0
	sw.light = info.get("light")
	for m in info.mats:
		sw.materials.append(m)
	node.add_child(sw)
	interior.switches.append(sw)
	# Her room: paint pots for the walls, cushions for the quilt.
	if room.get("hers", false):
		var pots := ColourPicker.new()
		pots.name = "WallPaint"
		pots.kind = "pot"
		pots.position = Vector3(rect.position.x + t + 2.0, base, rect.get_center().y)
		pots.rotation.y = PI * 0.5
		node.add_child(pots)
		var cushions := ColourPicker.new()
		cushions.name = "BedColours"
		cushions.kind = "cushion"
		cushions.spacing = 3.4
		# In a row just past the foot of the bed.
		var foot := 1.5 * f + 3.2
		cushions.position = Vector3(rect.get_center().x - 3.0, base, rect.position.y + rect.size.y * bz + (foot if back_north else -foot))
		node.add_child(cushions)
		interior.her_room = info
		info["wall_picker"] = pots
		info["bed_picker"] = cushions
		pots.picked.connect(func(i): interior.paint_her_walls(i, true))
		cushions.picked.connect(func(i): interior.colour_her_quilt(i, true))
		_furnish_sophia(interior, data, rect, base, node)
	# The hidden star: tucked into the far corner of the south-east bedroom.
	if str(room.id) == "bedroom_se":
		var star := HouseStar.new()
		star.name = "HiddenStar"
		star.position = Vector3(rect.end.x - t - 2.5, base, rect.end.y - t - 2.5)
		node.add_child(star)
		interior.house_star = star


# --- Materials ------------------------------------------------------------------------

## A room's material: shared, unless the room has its own (bedrooms: their
## lights dim them, her room's walls get painted). Walls are marked so her
## paint only colours walls.
static func _room_mat(info: Dictionary, hex: String, wall := false) -> StandardMaterial3D:
	if not info.get("own_materials", false):
		return _mat(hex)
	var key := ("wall_" if wall else "floor_") + hex
	for m: StandardMaterial3D in info.mats:
		if m.get_meta("key", "") == key:
			return m
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = 1.0
	m.set_meta("key", key)
	m.set_meta("wall", wall)
	info.mats.append(m)
	return m

static var _mats: Dictionary = {}


## A plain matte material in this colour (shared; walls fade with
## GeometryInstance3D.transparency, so they use standard materials).
static func _mat(hex: String) -> StandardMaterial3D:
	if not _mats.has(hex):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(hex)
		m.roughness = 1.0
		_mats[hex] = m
	return _mats[hex]


static func _glow_mat(c: Color) -> StandardMaterial3D:
	var key := "glow" + c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.6
		_mats[key] = m
	return _mats[key]


## Sophia's room extras: a TV on the east wall, a bookshelf by the door,
## mermaid toys round a little blue play pool and stuffies on and by the bed.
static func _furnish_sophia(interior: Interior, data: Dictionary, rect: Rect2, base: float, node: Node3D) -> void:
	var f: float = data.get("furniture_scale", 2.27)
	var t: float = data.get("wall_thickness", 0.5)
	var tv := TVSet.new()
	tv.name = "TV"
	tv.furniture_scale = f
	tv.screen_size = Vector2(6.4, 3.7)
	tv.position = Vector3(rect.end.x - t - 0.5 * f - 0.4, base, rect.position.y + rect.size.y * 0.55)
	tv.rotation.y = -PI * 0.5
	node.add_child(tv)
	interior.tvs.append(tv)
	# The bookshelf: on the south wall between the west wall and the door.
	var shelf := Node3D.new()
	shelf.name = "Bookshelf"
	shelf.position = Vector3(rect.position.x + 6.0, base, rect.end.y - t - 1.0)
	shelf.rotation.y = PI
	node.add_child(shelf)
	var wood := _mat("c8a27a")
	for part in [[Vector3(7.0, 0.3, 1.8), Vector3(0, 0.15, 0)], [Vector3(7.0, 0.3, 1.8), Vector3(0, 7.0, 0)],
			[Vector3(0.3, 7.15, 1.8), Vector3(-3.35, 3.58, 0)], [Vector3(0.3, 7.15, 1.8), Vector3(3.35, 3.58, 0)],
			[Vector3(7.0, 7.15, 0.2), Vector3(0, 3.58, -0.8)], [Vector3(6.4, 0.25, 1.6), Vector3(0, 2.4, 0)],
			[Vector3(6.4, 0.25, 1.6), Vector3(0, 4.7, 0)]]:
		BuildKit.add(shelf, BuildKit.box(part[0]), "c8a27a", part[1]).material_override = wood
	BuildKit.collider(shelf, BuildKit.box_shape(Vector3(7.0, 7.2, 1.8)), Vector3(0, 3.6, 0))
	var books: PackedScene = load(FURNITURE + "book_set.gltf")
	for y in [0.3, 2.53, 4.83]:
		for k in 3:
			var b: Node3D = books.instantiate()
			b.scale = Vector3.ONE * f
			b.position = Vector3(-2.2 + k * 2.2, y, 0.1)
			b.rotation.y = [0.0, PI, 0.15][k]
			shelf.add_child(b)
	# Mermaid toys round a little play pool in the north-east corner.
	var pool_at := Vector3(rect.end.x - 6.0, base, rect.position.y + 7.0)
	var pool := MeshInstance3D.new()
	pool.mesh = BuildKit.cyl(3.4, 0.5, -1, 32)
	pool.position = pool_at + Vector3(0, 0.25, 0)
	var pool_mat := StandardMaterial3D.new()
	pool_mat.albedo_color = Color("5ec8f0")
	pool_mat.roughness = 0.3
	pool.material_override = pool_mat
	node.add_child(pool)
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 3.3
	torus.outer_radius = 4.0
	rim.mesh = torus
	rim.position = pool_at + Vector3(0, 0.4, 0)
	rim.material_override = _mat("ff9ecb")
	node.add_child(rim)
	BuildKit.collider(node, BuildKit.cyl_shape(4.0, 0.8), pool_at + Vector3(0, 0.4, 0))
	var mermaid: PackedScene = load("res://scenes/characters/mermaid.tscn")
	var tails := [Color("ff7eb9"), Color("7b6cff"), Color("3cc9a8")]
	for k in 3:
		var m: Node3D = mermaid.instantiate()
		m.set("tail_color", tails[k])
		# On the pool's east, south and north sides (the cushions are west).
		var a: float = [0.0, PI * 0.5, -PI * 0.5][k]
		m.position = pool_at + Vector3(cos(a) * 4.4, 0.0, sin(a) * 4.4)
		m.rotation.y = atan2(-cos(a), -sin(a))  # facing the pool
		m.scale = Vector3.ONE * MERMAID_TOY_SCALE
		m.name = "MermaidToy%d" % k
		node.add_child(m)
		interior.mermaid_toys.append(m)
	# Stuffies: a teddy and a bunny on the bed by the pillow, a dolphin and
	# another bear sitting on the rug.
	var bed_z := rect.position.y + t + 1.5 * f + 0.4
	var cx := rect.get_center().x
	for st in [["Teddy_Bear", Vector3(cx - 2.2, base + 1.05 * f, bed_z - 1.8), 0.0],
			["Plush_Bunny", Vector3(cx + 2.2, base + 1.05 * f, bed_z - 1.8), 0.0],
			["Plush_Dolphin", Vector3(rect.end.x - 5.0, base, rect.end.y - 5.0), -2.4],
			["Teddy_Bear", Vector3(rect.position.x + 4.0, base, rect.position.y + 4.0), 0.8]]:
		var toy := CharacterLook.prop(st[0])
		toy.scale = Vector3.ONE * STUFFY_SCALE
		toy.position = st[1]
		toy.rotation.y = PI + float(st[2])  # props face -Y in Blender: turn to face into the room
		node.add_child(toy)
		interior.stuffies.append(toy)
