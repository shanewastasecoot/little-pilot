class_name CityCrowd
extends Node3D
## The city's townspeople. They walk the pavement round their block, now
## and then cross the road to the next block, walk up to a building's door,
## go in (shrinking away), stay a while and come out of another door. In
## parks and the plaza they wander in, stand about (idle) and wander off.
## There are more of them as the city grows: each building adds a few.
##
## Drawn with baked vertex animation (tools/bake_kaykit_people.gd): one MultiMesh
## per character, only people near the camera, so a few hundred walkers
## cost six draw calls. People never collide with anything (the plane flies
## over them). A child of CityDistrict, in city space.

const PEOPLE_DIR := "res://assets/characters/people/"
## KayKit townspeople in her own character's style (tools/bake_kaykit_people.gd).
const CHARACTERS := ["kk_baker", "kk_jogger", "kk_gardener", "kk_artist", "kk_grandad", "kk_lady"]
const SCALE := 1.0               # baked at her size (~5 m tall)
const PITCH := 80.0
const LOOP := 33.75              # pavement path, from the block centre
const EDGE := 32.0               # block edge (building fronts)
const WALK_SPEED := 3.4          # m/s at this scale (matches the walk loop)
const PAVEMENT_Y := 0.36
const DRAW_RADIUS := 300.0       # people further than this from the camera aren't drawn
## (The draw radius in use: DRAW_RADIUS, or the --bench-crowd toggle.)
var draw_radius := DRAW_RADIUS
const MAX_DRAWN := 50            # per character
const MAX_PEOPLE := 900
## Only people this near the camera are moved each frame; the rest wait
## where they are (nobody can see them) and carry on when you come back.
const STEP_RADIUS := DRAW_RADIUS + 30.0
## Nearer than this people are moved every frame. Out to MID_RADIUS, every
## second frame (two frames' worth at a time); beyond, every third frame:
## spread across frames, too small a step to notice at that distance.
const CLOSE_RADIUS := 50.0
const NEAR_RADIUS := 120.0
## People per thing in a block.
const PER_DOOR := 4
const PER_PARK := 10
const PER_PLAZA := 20
## How far a person can be from their block's centre (the pavement loop's
## corner, or halfway over the road to the next block): a block whose
## centre is further than STEP_RADIUS + this from the camera has nobody
## to move or draw, so it's skipped in one go.
const BLOCK_REACH := 62.0
## The nearest blocks are visited first (so the people drawn, at most
## MAX_DRAWN of each kind, are the nearest); the order is refreshed this
## often (frames).
const ORDER_EVERY := 30

enum { WALK, TO_DOOR, INSIDE, FROM_DOOR, TO_SPOT, IDLE, FROM_SPOT, CROSS }

var city: CityDistrict
## cell -> {"doors": Array of [path_s, door_point], "open": bool (park/plaza)}
var blocks: Dictionary = {}
var people: Array[Dictionary] = []
## (Graphics G1) cell -> the people in that block, so each frame only the
## blocks near the camera are visited, not all 900 people.
var _by_block: Dictionary = {}
## People who crossed to another block since the last update: [person, old cell].
var _crossed: Array = []
var _order: Array = []

var _mm: Array[MultiMesh] = []
var _buffers: Array[PackedFloat32Array] = []
var _rng := RandomNumberGenerator.new()
var _frame := 0


func _ready() -> void:
	_rng.seed = 99
	if BenchToggles.value("crowd") != "":
		draw_radius = clampf(float(BenchToggles.value("crowd")), 20.0, STEP_RADIUS)
	for c in CHARACTERS:
		var mesh: ArrayMesh = load(PEOPLE_DIR + c + "_crowd.res")
		var img: Image = load(PEOPLE_DIR + c + "_vat.res")
		var frames: Array = mesh.get_meta("frames")
		var mat := ShaderMaterial.new()
		mat.shader = load("res://scripts/world/city/people_vat.gdshader")
		mat.set_shader_parameter("vat", ImageTexture.create_from_image(img))
		mat.set_shader_parameter("walk_frames", frames[0])
		mat.set_shader_parameter("idle_frames", frames[1])
		mat.set_shader_parameter("cheer_frames", frames[2] if frames.size() > 2 else 0)
		mat.set_shader_parameter("bake_fps", mesh.get_meta("bake_fps"))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = MAX_DRAWN
		mm.visible_instance_count = 0
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		# Small and moving: no shadows (they'd cost a shadow pass per cascade).
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# People are spread over the whole city: never cull the batch as one.
		mmi.custom_aabb = AABB(Vector3(-600, -5, -600), Vector3(1200, 30, 1200))
		add_child(mmi)
		_mm.append(mm)
		var buf := PackedFloat32Array()
		buf.resize(MAX_DRAWN * 16)
		_buffers.append(buf)


## The blocks people can use changed (city loaded, building opened, reset):
## `new_blocks` is cell -> {"doors": [Vector3 building centres], "open": bool}.
## Grows (or shrinks) the crowd to match; people on removed blocks vanish.
func set_blocks(new_blocks: Dictionary) -> void:
	blocks.clear()
	var want := 0
	for cell in new_blocks:
		var info: Dictionary = new_blocks[cell]
		var doors := []
		for b: Vector3 in info.doors:
			doors.append(_door_for(cell, b))
		blocks[cell] = {"doors": doors, "open": info.open, "plaza": info.get("plaza", false)}
		want += doors.size() * PER_DOOR + (PER_PLAZA if info.get("plaza", false) else (PER_PARK if info.open else 0))
	want = mini(want, MAX_PEOPLE)
	people = people.filter(func(p): return blocks.has(p.block))
	while people.size() < want:
		people.append(_new_person())
	while people.size() > want:
		people.pop_back()
	_reindex()


## Rebuilds the per-block index (and the visiting order) from `people`.
func _reindex() -> void:
	_by_block.clear()
	_crossed.clear()
	_order.clear()
	for p in people:
		if not _by_block.has(p.block):
			_by_block[p.block] = []
		_by_block[p.block].append(p)


## Moves people who crossed the road into their new block's list.
func _apply_crossings() -> void:
	for c in _crossed:
		var p: Dictionary = c[0]
		var old: Array = _by_block.get(c[1], [])
		for j in old.size():
			if is_same(old[j], p):
				old.remove_at(j)
				break
		if p.block == c[1]:
			old.append(p)
			continue
		if not _by_block.has(p.block):
			_by_block[p.block] = []
			_order.clear()
		_by_block[p.block].append(p)
	_crossed.clear()


func population() -> int:
	return people.size()


## [loop position s, door point] for a building centred at `b` (city space)
## in block `cell`: the door is on the block edge nearest the building.
func _door_for(cell: Vector2i, b: Vector3) -> Array:
	var c := Vector3(cell.x * PITCH, 0, cell.y * PITCH)
	var l := b - c
	var door: Vector3
	if absf(l.z) >= absf(l.x):
		door = Vector3(l.x, 0, EDGE * (1.0 if l.z >= 0.0 else -1.0))
	else:
		door = Vector3(EDGE * (1.0 if l.x >= 0.0 else -1.0), 0, l.z)
	return [_s_of(door), c + door]


## Loop parameter (0..8*LOOP) nearest to local point `l`.
func _s_of(l: Vector3) -> float:
	var h := LOOP
	if absf(l.z) >= absf(l.x):
		return (h + l.x) if l.z < 0.0 else (5.0 * h - l.x)        # north side, south side
	return (3.0 * h + l.z) if l.x > 0.0 else (7.0 * h - l.z)      # east side, west side


## Point on the loop at parameter s (local to the block centre).
func _loop_point(s: float) -> Vector3:
	var h := LOOP
	s = fposmod(s, 8.0 * h)
	if s < 2.0 * h:
		return Vector3(-h + s, 0, -h)
	if s < 4.0 * h:
		return Vector3(h, 0, -h + (s - 2.0 * h))
	if s < 6.0 * h:
		return Vector3(h - (s - 4.0 * h), 0, h)
	return Vector3(-h, 0, h - (s - 6.0 * h))


func _new_person() -> Dictionary:
	var cells := blocks.keys()
	var cell: Vector2i = cells[_rng.randi() % cells.size()]
	var p := {"block": cell, "s": _rng.randf() * 8.0 * LOOP, "dir": 1.0 if _rng.randf() < 0.5 else -1.0,
		"state": WALK, "timer": _rng.randf_range(4.0, 25.0), "type": _rng.randi() % CHARACTERS.size(),
		"pos": Vector3.ZERO, "yaw": 0.0, "from": Vector3.ZERO, "to": Vector3.ZERO, "target_s": 0.0,
		"t_off": _rng.randf() * 10.0, "size": 1.0, "goal": false, "cheer": 0.0, "look": 0.0,
		"k": _rng.randi() % 6}  # which frames they move on, when further away
	p.pos = _centre(cell) + _loop_point(p.s)
	return p


func _centre(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * PITCH, 0, cell.y * PITCH)


func _process(delta: float) -> void:
	if people.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye := to_local(cam.global_position)
	if Vector2(eye.x, eye.z).length() > 450.0 + DRAW_RADIUS + 200.0 or eye.y > 900.0:
		for mm in _mm:
			mm.visible_instance_count = 0
		return  # far away: nobody to see, nothing to update
	delta = minf(delta, 0.1)
	var counts: Array[int] = [0, 0, 0, 0, 0, 0]
	var r2 := draw_radius * draw_radius
	var s2 := STEP_RADIUS * STEP_RADIUS
	var n2 := NEAR_RADIUS * NEAR_RADIUS
	var c2 := CLOSE_RADIUS * CLOSE_RADIUS
	_frame += 1
	if not _crossed.is_empty():
		_apply_crossings()
	if _by_block.size() != 0 and (_order.is_empty() or _frame % ORDER_EVERY == 0):
		_order = _by_block.keys()
		var at := Vector2(eye.x, eye.z)
		_order.sort_custom(func(a: Vector2i, b: Vector2i): return at.distance_squared_to(Vector2(a) * PITCH) < at.distance_squared_to(Vector2(b) * PITCH))
	var reach := STEP_RADIUS + BLOCK_REACH
	var f := _frame
	for cell: Vector2i in _order:
		if (_centre(cell) - eye).length_squared() > reach * reach:
			continue  # nobody in this block is near enough to move or draw
		for p: Dictionary in _by_block.get(cell, []):
			var d2: float = (p.pos - eye).length_squared()
			if d2 > s2:
				continue
			if d2 < c2:
				_step(p, delta)
			elif d2 < n2:
				if (p.k + f) % 2 == 0:
					_step(p, delta * 2.0)
			elif (p.k + f) % 3 == 0:
				_step(p, delta * 3.0)
			if p.state == INSIDE or p.size <= 0.02 or d2 > r2:
				continue
			var t: int = p.type
			if counts[t] >= MAX_DRAWN:
				continue
			_write(t, counts[t], p)
			counts[t] += 1
	if not _crossed.is_empty():
		_apply_crossings()
	for t in _mm.size():
		_mm[t].buffer = _buffers[t]
		_mm[t].visible_instance_count = counts[t]


func _write(t: int, i: int, p: Dictionary) -> void:
	# A turn about the up axis, scaled (written out: no Basis to build).
	var sc: float = SCALE * p.size
	var yaw: float = p.yaw
	var c := cos(yaw) * sc
	var s := sin(yaw) * sc
	var o: Vector3 = p.pos
	var buf := _buffers[t]
	var k := i * 16
	buf[k] = c; buf[k + 1] = 0.0; buf[k + 2] = s; buf[k + 3] = o.x
	buf[k + 4] = 0.0; buf[k + 5] = sc; buf[k + 6] = 0.0; buf[k + 7] = o.y + PAVEMENT_Y
	buf[k + 8] = -s; buf[k + 9] = 0.0; buf[k + 10] = c; buf[k + 11] = o.z
	buf[k + 12] = p.t_off
	buf[k + 13] = 2.0 if p.cheer > 0.0 else (1.0 if p.state == IDLE else 0.0)
	buf[k + 14] = 0.0
	buf[k + 15] = 0.0


## Everyone out and about within `radius` of `where` (world space) stops,
## turns to face it and cheers (waves) for about `secs` seconds, a little
## staggered. Returns how many. (She cheered at them; a honk; a low pass.)
func cheer_near(where: Vector3, radius: float, secs := 2.5) -> int:
	var at := to_local(where)
	var r2 := radius * radius
	var n := 0
	for p in people:
		if p.state == INSIDE or p.size < 0.5:
			continue
		var d: Vector3 = at - p.pos
		d.y = 0.0
		if d.length_squared() > r2:
			continue
		p.cheer = secs + _rng.randf_range(0.0, 0.8)
		p.look = atan2(d.x, d.z)
		n += 1
	return n


## Move one person along and decide what they do next.
func _step(p: Dictionary, delta: float) -> void:
	var info: Dictionary = blocks.get(p.block, {})
	if info.is_empty():
		return
	if p.cheer > 0.0:
		# Cheering: stand still, turned towards her, then carry on.
		p.cheer = maxf(p.cheer - delta, 0.0)
		p.yaw = lerp_angle(p.yaw, p.look, minf(delta * 8.0, 1.0))
		return
	var c := _centre(p.block)
	match p.state:
		WALK:
			var move := WALK_SPEED * delta
			if p.goal:
				# Heading round the pavement to a door: the short way.
				var diff := wrapf(p.target_s - p.s, -4.0 * LOOP, 4.0 * LOOP)
				p.dir = signf(diff) if diff != 0.0 else 1.0
				if absf(diff) <= move:
					p.s = p.target_s
					_face_along(p, c)
					p.goal = false
					p.state = TO_DOOR
					return
			var before: float = p.s
			p.s = fposmod(p.s + p.dir * move, 8.0 * LOOP)
			_face_along(p, c)
			p.timer -= delta
			# Passing a corner: sometimes cross the road to the next block.
			if not p.goal and _crossed_corner(before, p.s, p.dir) and _rng.randf() < 0.3:
				_try_cross(p, c)
				return
			if p.timer <= 0.0 and not p.goal:
				_choose(p, info, c)
		TO_DOOR, FROM_DOOR, TO_SPOT, FROM_SPOT, CROSS:
			var to: Vector3 = p.to
			var step: Vector3 = to - p.pos
			var dist := step.length()
			var move := WALK_SPEED * delta
			if dist > 0.01:
				p.yaw = atan2(step.x, step.z)
			if dist <= move:
				p.pos = to
				_arrive(p, info, c)
			else:
				p.pos += step / dist * move
			if p.state == TO_DOOR:
				p.size = clampf(p.pos.distance_to(to) / 3.0, 0.0, 1.0)  # shrink away at the door
			elif p.state == FROM_DOOR:
				p.size = clampf(p.pos.distance_to(p.from) / 3.0, 0.0, 1.0)
		INSIDE, IDLE:
			p.timer -= delta
			if p.timer <= 0.0:
				if p.state == INSIDE:
					# Out of a door of this block (maybe another one).
					var d: Array = info.doors[_rng.randi() % info.doors.size()] if not info.doors.is_empty() else [p.s, p.pos]
					p.from = d[1]
					p.pos = d[1]
					p.s = d[0]
					p.to = c + _loop_point(d[0])
					p.size = 0.0
					p.state = FROM_DOOR
				else:
					p.to = c + _loop_point(p.s)
					p.state = FROM_SPOT


func _face_along(p: Dictionary, c: Vector3) -> void:
	var a := _loop_point(p.s)
	var b := _loop_point(p.s + p.dir * 0.5)
	p.pos = c + a
	p.yaw = atan2(b.x - a.x, b.z - a.z)


## Did s pass a loop corner (at 0, 2h, 4h, 6h) this step?
func _crossed_corner(before: float, after: float, _dir: float) -> bool:
	var h2 := 2.0 * LOOP
	var a := int(floor(before / h2))
	var b := int(floor(after / h2))
	return a != b and absf(after - before) < LOOP


func _try_cross(p: Dictionary, c: Vector3) -> void:
	var corner := _loop_point(round(p.s / (2.0 * LOOP)) * 2.0 * LOOP)
	var options: Array[Vector2i] = []
	for d in [Vector2i(int(signf(corner.x)), 0), Vector2i(0, int(signf(corner.z)))]:
		if blocks.has(p.block + d):
			options.append(p.block + d)
	if options.is_empty():
		return
	var next: Vector2i = options[_rng.randi() % options.size()]
	_crossed.append([p, p.block])  # (moved to the new block's list after this update)
	var nc := _centre(next)
	# The neighbour's corner straight across the road.
	var local := c + corner - nc
	var target := Vector3(clampf(local.x, -LOOP, LOOP), 0, clampf(local.z, -LOOP, LOOP))
	p.block = next
	p.s = _s_of(target)
	p.to = nc + target
	p.state = CROSS


func _choose(p: Dictionary, info: Dictionary, c: Vector3) -> void:
	p.timer = _rng.randf_range(8.0, 30.0)
	if info.open and (info.doors.is_empty() or _rng.randf() < 0.5):
		# Into the park/plaza for a stand about.
		var spot := Vector3(_rng.randf_range(-24, 24), 0, _rng.randf_range(-24, 24))
		if info.plaza and spot.length() < 13.0:
			spot = spot.normalized() * 14.0  # not in the fountain
		p.to = c + spot
		p.state = TO_SPOT
	elif not info.doors.is_empty() and _rng.randf() < 0.6:
		var d: Array = info.doors[_rng.randi() % info.doors.size()]
		# Walk the pavement to the door first (WALK with a goal), then in.
		p.target_s = d[0]
		p.to = d[1]
		p.goal = true
	# else: keep strolling


func _arrive(p: Dictionary, info: Dictionary, c: Vector3) -> void:
	match p.state:
		TO_DOOR:
			p.state = INSIDE
			p.timer = _rng.randf_range(10.0, 45.0)
		TO_SPOT:
			p.state = IDLE
			p.timer = _rng.randf_range(4.0, 12.0)
		FROM_DOOR, FROM_SPOT, CROSS:
			p.size = 1.0
			p.state = WALK
			p.timer = _rng.randf_range(6.0, 25.0)
