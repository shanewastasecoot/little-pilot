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
const WINDOW_SIZE := Vector2(5.0, 4.6)
const WINDOW_Y := 5.6


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
	return interior


static func _build_room(interior: Interior, data: Dictionary, room: Dictionary, rng: RandomNumberGenerator) -> void:
	var r: Array = room.rect
	var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	var storey: float = data.get("storey_height", 11.0)
	var base := float(room.get("floor", 0)) * storey
	var node := Node3D.new()
	node.name = str(room.id)
	interior.add_child(node)
	interior.rooms.append({"id": room.id, "type": room.type, "rect": rect, "floor": int(room.get("floor", 0)), "base": base, "node": node})
	# Floor (solid) and a soft light.
	var floor_mi := BuildKit.add(node, BuildKit.box(Vector3(rect.size.x, 0.6, rect.size.y)), str(room.get("floor_colour", "c8a27a")),
			Vector3(rect.get_center().x, base - 0.3, rect.get_center().y))
	floor_mi.material_override = _mat(str(room.get("floor_colour", "c8a27a")))
	BuildKit.collider(node, BuildKit.box_shape(Vector3(rect.size.x, 0.6, rect.size.y)), Vector3(rect.get_center().x, base - 0.3, rect.get_center().y))
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(rect.get_center().x, base + storey * 0.8, rect.get_center().y)
	lamp.omni_range = maxf(rect.size.x, rect.size.y) * 0.9
	lamp.light_energy = 0.35
	lamp.light_color = Color("fff1d6")
	node.add_child(lamp)
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
	var spans: Array = []
	for g in gaps:
		spans.append([u, g[0], 0.0, storey])          # full-height piece before the gap
		spans.append([g[0], g[1], door_h, storey])    # lintel over the gap
		u = g[1]
	spans.append([u, length, 0.0, storey])
	for sp in spans:
		var a: float = sp[0]
		var b: float = sp[1]
		if b - a < 0.05:
			continue
		var mid: Vector2 = point.call((a + b) * 0.5)
		var h: float = sp[3] - sp[2]
		var size := Vector3(b - a, h, t) if along_x else Vector3(t, h, b - a)
		var mi := BuildKit.add(node, BuildKit.box(size), colour, Vector3(mid.x, base + sp[2] + h * 0.5, mid.y))
		mi.material_override = _mat(colour)
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
	var path := FURNITURE + item + ".gltf"
	if not ResourceLoader.exists(path):
		push_warning("No furniture model %s" % path)
		return null
	var piece: Node3D = (load(path) as PackedScene).instantiate()
	piece.name = item
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
			_put(node, data, rect, base, ab.call("pictureframe_large"), 0.62, (data.get("wall_thickness", 0.5) + 0.3) / rect.size.y,
					0.0, 1.3, false, 6.5)
			_put(node, data, rect, base, ab.call("cactus_medium"), 0.92, 0.84, rng.randf() * 360.0, 1.3)
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


# --- Materials ------------------------------------------------------------------------

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
