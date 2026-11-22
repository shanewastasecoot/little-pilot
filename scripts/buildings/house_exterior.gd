class_name HouseExterior
extends Node3D
## The outside of a house, built from the same floor plan (JSON) as its
## inside, so the two always match: the outer walls of each storey (where a
## room meets the outdoors), the windows exactly where the rooms have them,
## the front door, a porch, and pitched roofs over every part with nothing
## above it (the upstairs gets the big roof, single-storey wings their own).
## Solid (walls and roofs collide). Origin = the plan's origin at ground level;
## the front door is on the plan's +Z side.

const WALL := "f4ead5"
const TRIM := "ffffff"
const ROOF := "d9667a"
const PLINTH := "c9b8a0"
const GLASS := "9fd8ff"
const DOOR := "3a7bd5"
## How far the outside skin stands out from the plan's room edges.
const SKIN := 0.5
const THICK := 0.8
const OVERHANG := 2.0

var data: Dictionary
## The front door (plan space, at ground level) and which way it faces out.
var door_point := Vector3.ZERO
var door_out := Vector3(0, 0, 1)
## Everything the house covers on the plan (all storeys).
var footprint := Rect2()
var _storey := 11.0
var _mats := {}


func _ready() -> void:
	_storey = data.get("storey_height", 11.0)
	var floors := {}
	for room: Dictionary in data.rooms:
		var f := int(room.get("floor", 0))
		if not floors.has(f):
			floors[f] = []
		var r: Array = room.rect
		var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		floors[f].append(rect)
		footprint = rect if footprint.size == Vector2.ZERO else footprint.merge(rect)
	var top := 0
	for f: int in floors:
		top = maxi(top, f)
	for f: int in floors:
		_build_storey(f, floors[f])
	for f: int in floors:
		var above: Array = floors.get(f + 1, [])
		_build_roofs(f, floors[f], above)
	_build_windows_and_door()
	MeshMerge.merge_children(self)  # one draw per colour
	for gi: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
		gi.visibility_range_end = 0.0


func _mat(hex: String) -> StandardMaterial3D:
	if not _mats.has(hex):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(hex)
		m.roughness = 0.9
		_mats[hex] = m
	return _mats[hex]


func _box(at: Vector3, size: Vector3, hex: String, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(hex)
	mi.position = at
	mi.rotation = rot
	add_child(mi)
	return mi


# --- Walls --------------------------------------------------------------------------

## The outline of a storey: grid cells from the rooms' edges, inside if a
## room covers them; a wall wherever an inside cell meets an outside one.
static func outline(rects: Array) -> Array:
	var xs: Array[float] = []
	var zs: Array[float] = []
	for r: Rect2 in rects:
		for v in [r.position.x, r.end.x]:
			if not xs.has(v):
				xs.append(v)
		for v in [r.position.y, r.end.y]:
			if not zs.has(v):
				zs.append(v)
	xs.sort()
	zs.sort()
	var inside := func(i: int, j: int) -> bool:
		if i < 0 or j < 0 or i >= xs.size() - 1 or j >= zs.size() - 1:
			return false
		var c := Vector2((xs[i] + xs[i + 1]) * 0.5, (zs[j] + zs[j + 1]) * 0.5)
		for r: Rect2 in rects:
			if r.has_point(c):
				return true
		return false
	# Edges as [a, b, outward normal].
	var edges: Array = []
	for i in xs.size() - 1:
		for j in zs.size() - 1:
			if not inside.call(i, j):
				continue
			if not inside.call(i, j - 1):
				edges.append([Vector2(xs[i], zs[j]), Vector2(xs[i + 1], zs[j]), Vector2(0, -1)])
			if not inside.call(i, j + 1):
				edges.append([Vector2(xs[i], zs[j + 1]), Vector2(xs[i + 1], zs[j + 1]), Vector2(0, 1)])
			if not inside.call(i - 1, j):
				edges.append([Vector2(xs[i], zs[j]), Vector2(xs[i], zs[j + 1]), Vector2(-1, 0)])
			if not inside.call(i + 1, j):
				edges.append([Vector2(xs[i + 1], zs[j]), Vector2(xs[i + 1], zs[j + 1]), Vector2(1, 0)])
	# Join straight runs.
	var merged := true
	while merged:
		merged = false
		for a in edges.size():
			for b in edges.size():
				if a == b:
					continue
				var ea: Array = edges[a]
				var eb: Array = edges[b]
				if ea[2] == eb[2] and (ea[1] as Vector2).is_equal_approx(eb[0]):
					ea[1] = eb[1]
					edges.remove_at(b)
					merged = true
					break
			if merged:
				break
	return edges


func _build_storey(f: int, rects: Array) -> void:
	var y0 := f * _storey
	for e: Array in outline(rects):
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var n: Vector2 = e[2]
		var along_x := absf(n.y) > 0.5
		# Stretch along the wall so corners close (the skin stands outwards).
		var length := a.distance_to(b) + 2.0 * (SKIN + THICK * 0.5)
		var mid := (a + b) * 0.5 + n * (SKIN + THICK * 0.5)
		var size := Vector3(length, _storey, THICK) if along_x else Vector3(THICK, _storey, length)
		_box(Vector3(mid.x, y0 + _storey * 0.5, mid.y), size, WALL)
		# A white band at the top of each storey, and a plinth at the bottom.
		var band := Vector3(length + 0.6, 0.7, THICK + 0.5) if along_x else Vector3(THICK + 0.5, 0.7, length + 0.6)
		_box(Vector3(mid.x, y0 + _storey - 0.35, mid.y), band, TRIM)
		if f == 0:
			var pl := Vector3(length + 0.4, 2.4, THICK + 0.4) if along_x else Vector3(THICK + 0.4, 2.4, length + 0.4)
			_box(Vector3(mid.x, 0.0, mid.y), pl, PLINTH)
	# Solid: each room as a box (walls you bump into, nothing inside to see).
	for r: Rect2 in rects:
		BuildKit.collider(self, BuildKit.box_shape(Vector3(r.size.x + SKIN * 2.0, _storey, r.size.y + SKIN * 2.0)),
				Vector3(r.get_center().x, y0 + _storey * 0.5, r.get_center().y))


# --- Roofs --------------------------------------------------------------------------

## Pitched roofs over the parts of storey `f` with nothing above.
func _build_roofs(f: int, rects: Array, above: Array) -> void:
	for piece: Rect2 in _uncovered(rects, above):
		_roof(piece, (f + 1) * _storey, above.is_empty())


## Split `rects` into rectangles not covered by `cover` (grid cells merged
## along rows, then rows with the same span merged).
static func _uncovered(rects: Array, cover: Array) -> Array:
	var xs: Array[float] = []
	var zs: Array[float] = []
	for r: Rect2 in rects + cover:
		for v in [r.position.x, r.end.x]:
			if not xs.has(v):
				xs.append(v)
		for v in [r.position.y, r.end.y]:
			if not zs.has(v):
				zs.append(v)
	xs.sort()
	zs.sort()
	var hit := func(list: Array, c: Vector2) -> bool:
		for r: Rect2 in list:
			if r.has_point(c):
				return true
		return false
	var rows: Array = []  # [z0, z1, x0, x1]
	for j in zs.size() - 1:
		var run_start := -1
		for i in xs.size():
			var on := false
			if i < xs.size() - 1:
				var c := Vector2((xs[i] + xs[i + 1]) * 0.5, (zs[j] + zs[j + 1]) * 0.5)
				on = hit.call(rects, c) and not hit.call(cover, c)
			if on and run_start < 0:
				run_start = i
			elif not on and run_start >= 0:
				rows.append([zs[j], zs[j + 1], xs[run_start], xs[i]])
				run_start = -1
	# Merge rows stacked with the same x span.
	var out: Array = []
	for row: Array in rows:
		var joined := false
		for o: Array in out:
			if is_equal_approx(o[1], row[0]) and is_equal_approx(o[2], row[2]) and is_equal_approx(o[3], row[3]):
				o[1] = row[1]
				joined = true
				break
		if not joined:
			out.append(row.duplicate())
	var rects_out: Array = []
	for o: Array in out:
		rects_out.append(Rect2(o[2], o[0], o[3] - o[2], o[1] - o[0]))
	return rects_out


## A gable roof over `r` at height `y` (ridge along its long side).
func _roof(r: Rect2, y: float, main: bool) -> void:
	var long_x := r.size.x >= r.size.y
	var span := (r.size.y if long_x else r.size.x) + (SKIN + OVERHANG) * 2.0
	var length := (r.size.x if long_x else r.size.y) + (SKIN + OVERHANG) * 2.0
	var rise := clampf(span * 0.32, 5.0, 16.0)
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(span, rise, length)
	mi.mesh = pm
	mi.material_override = _mat(ROOF)
	mi.position = Vector3(r.get_center().x, y + rise * 0.5, r.get_center().y)
	if long_x:
		mi.rotation.y = PI * 0.5
	add_child(mi)
	# Gable ends in the wall colour (a slim triangle just inside each end).
	for s in [-1.0, 1.0]:
		var end := MeshInstance3D.new()
		var em := PrismMesh.new()
		em.size = Vector3(span - OVERHANG * 2.0, rise - 1.0, 0.4)
		end.mesh = em
		end.material_override = _mat(WALL)
		var off: float = (length * 0.5 - OVERHANG - 0.1) * s
		end.position = mi.position + (Vector3(off, -0.5, 0) if long_x else Vector3(0, -0.5, off))
		end.rotation.y = mi.rotation.y
		add_child(end)
	# Solid: a box over the lower part of the roof.
	var cs := Vector3(r.size.x + SKIN * 2.0, rise * 0.6, r.size.y + SKIN * 2.0)
	BuildKit.collider(self, BuildKit.box_shape(cs), Vector3(r.get_center().x, y + rise * 0.3, r.get_center().y))
	if main:
		# A chimney on the big roof.
		var cx := r.position.x + r.size.x * 0.75
		var cz := r.position.y + r.size.y * 0.3
		_box(Vector3(cx, y + rise * 0.7, cz), Vector3(3.0, rise * 0.9, 3.0), "c96f5a")
		_box(Vector3(cx, y + rise * 1.15, cz), Vector3(3.6, 0.6, 3.6), TRIM)


# --- Windows and the front door ---------------------------------------------------

func _build_windows_and_door() -> void:
	var ws := BuildingGenerator.WINDOW_SIZE
	var floors := {}
	for room: Dictionary in data.rooms:
		var f := int(room.get("floor", 0))
		if not floors.has(f):
			floors[f] = []
		var r: Array = room.rect
		floors[f].append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
	for room: Dictionary in data.rooms:
		var r: Array = room.rect
		var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		var f := int(room.get("floor", 0))
		var y0 := f * _storey
		for w: Dictionary in room.get("windows", []):
			var spot := _side_point(rect, str(w.side), float(w.at))
			if not _on_outline(spot[0], spot[1], floors[f]):
				continue
			var p: Vector2 = spot[0] + spot[1] * (SKIN + THICK + 0.05)
			var along_x := absf((spot[1] as Vector2).y) > 0.5
			var fs := Vector3(ws.x + 1.0, ws.y + 1.0, 0.3) if along_x else Vector3(0.3, ws.y + 1.0, ws.x + 1.0)
			var gs := Vector3(ws.x, ws.y, 0.32) if along_x else Vector3(0.32, ws.y, ws.x)
			_box(Vector3(p.x, y0 + BuildingGenerator.WINDOW_Y, p.y), fs, TRIM)
			_box(Vector3(p.x, y0 + BuildingGenerator.WINDOW_Y, p.y) + Vector3(spot[1].x, 0, spot[1].y) * 0.05, gs, GLASS)
			var sill := Vector3(ws.x + 1.6, 0.4, 1.0) if along_x else Vector3(1.0, 0.4, ws.x + 1.6)
			_box(Vector3(p.x, y0 + BuildingGenerator.WINDOW_Y - ws.y * 0.5 - 0.6, p.y) + Vector3(spot[1].x, 0, spot[1].y) * 0.4, sill, TRIM)
			# A flower box under the ground-floor windows.
			if f == 0:
				var fb := Vector3(ws.x, 0.8, 1.2) if along_x else Vector3(1.2, 0.8, ws.x)
				_box(Vector3(p.x, y0 + BuildingGenerator.WINDOW_Y - ws.y * 0.5 - 1.3, p.y) + Vector3(spot[1].x, 0, spot[1].y) * 0.8, fb, "8b5a2b")
				for k in 4:
					var o := (k - 1.5) * ws.x * 0.25
					var off := Vector3(o, 0, 0) if along_x else Vector3(0, 0, o)
					var fl := BuildKit.add(self, BuildKit.sphere(0.45, 8), ["ff7eb9", "ffd166", "ffffff", "b388ff"][k],
							Vector3(p.x, y0 + BuildingGenerator.WINDOW_Y - ws.y * 0.5 - 0.7, p.y) + Vector3(spot[1].x, 0, spot[1].y) * 0.8 + off)
					fl.material_override = _mat(["ff7eb9", "ffd166", "ffffff", "b388ff"][k])
		for d: Dictionary in room.get("doors", []):
			if not d.get("exit", false):
				continue
			var spot := _side_point(rect, str(d.side), float(d.at))
			var n: Vector2 = spot[1]
			var p: Vector2 = spot[0] + n * (SKIN + THICK + 0.05)
			var along_x := absf(n.y) > 0.5
			var dw: float = data.get("door_width", 7.0)
			var dh: float = data.get("door_height", 8.5)
			_box(Vector3(p.x, dh * 0.5 + 0.6, p.y), Vector3(dw + 1.2, dh + 1.2, 0.35) if along_x else Vector3(0.35, dh + 1.2, dw + 1.2), TRIM)
			_box(Vector3(p.x, dh * 0.5 + 0.3, p.y) + Vector3(n.x, 0, n.y) * 0.1, Vector3(dw, dh, 0.4) if along_x else Vector3(0.4, dh, dw), DOOR)
			var knob := Vector3(dw * 0.35, 0, 0) if along_x else Vector3(0, 0, dw * 0.35)
			BuildKit.add(self, BuildKit.sphere(0.35, 8), "ffd166", Vector3(p.x, dh * 0.45, p.y) + Vector3(n.x, 0, n.y) * 0.4 + knob).material_override = _mat("ffd166")
			# The porch: a low step and a little roof on posts.
			var porch_c := p + n * 4.0
			# (Low and not solid: you walk straight onto it, no step to climb.)
			var ps := Vector3(dw + 6.0, 0.25, 8.0) if along_x else Vector3(8.0, 0.25, dw + 6.0)
			_box(Vector3(porch_c.x, 0.12, porch_c.y), ps, PLINTH)
			var canopy := Vector3(dw + 6.0, 0.5, 8.0) if along_x else Vector3(8.0, 0.5, dw + 6.0)
			_box(Vector3(porch_c.x, dh + 1.6, porch_c.y), canopy, ROOF)
			for s in [-1.0, 1.0]:
				var side: Vector2 = Vector2(n.y, -n.x) * (dw * 0.5 + 2.5) * s
				var post: Vector2 = p + n * 7.4 + side
				_box(Vector3(post.x, (dh + 1.6) * 0.5, post.y), Vector3(0.6, dh + 1.6, 0.6), TRIM)
			door_point = Vector3(p.x, 0.0, p.y)
			door_out = Vector3(n.x, 0, n.y)


## A point on a room's side (fraction `at` along it) and the side's outward normal.
static func _side_point(rect: Rect2, side: String, at: float) -> Array:
	match side:
		"N": return [Vector2(rect.position.x + at * rect.size.x, rect.position.y), Vector2(0, -1)]
		"S": return [Vector2(rect.position.x + at * rect.size.x, rect.end.y), Vector2(0, 1)]
		"W": return [Vector2(rect.position.x, rect.position.y + at * rect.size.y), Vector2(-1, 0)]
		_: return [Vector2(rect.end.x, rect.position.y + at * rect.size.y), Vector2(1, 0)]


## Is this point (with outward normal n) on the storey's outside wall?
static func _on_outline(p: Vector2, n: Vector2, rects: Array) -> bool:
	var outside := p + n * 0.6
	for r: Rect2 in rects:
		if r.has_point(outside):
			return false
	return true
