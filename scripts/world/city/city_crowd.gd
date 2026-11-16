class_name CityCrowd
extends Node3D
## The city's townspeople. They walk the pavement round their block, now
## and then cross the road to the next block, walk up to a building's door,
## go in (shrinking away), stay a while and come out of another door. In
## parks and the plaza they wander in, stand about (idle) and wander off.
## There are more of them as the city grows: each building adds a few.
##
## Drawn with baked vertex animation (tools/bake_people.gd): one MultiMesh
## per character, only people near the camera, so a few hundred walkers
## cost six draw calls. People never collide with anything (the plane flies
## over them). A child of CityDistrict, in city space.

const PEOPLE_DIR := "res://assets/characters/people/"
const CHARACTERS := ["worker", "suit", "hoodie", "beach", "woman_a", "woman_b"]
const SCALE := 2.8               # storybook size: ~5 m tall
const PITCH := 80.0
const LOOP := 33.75              # pavement path, from the block centre
const EDGE := 32.0               # block edge (building fronts)
const WALK_SPEED := 3.4          # m/s at this scale (matches the walk loop)
const PAVEMENT_Y := 0.36
const DRAW_RADIUS := 300.0       # people further than this from the camera aren't drawn
const MAX_DRAWN := 50            # per character
const MAX_PEOPLE := 900
## Only people this near the camera are moved each frame; the rest wait
## where they are (nobody can see them) and carry on when you come back.
const STEP_RADIUS := DRAW_RADIUS + 30.0
## Beyond this, people are moved every third frame (three frames' worth at
## a time), spread across frames: a third of the work, too far to notice.
const NEAR_RADIUS := 120.0
## People per thing in a block.
const PER_DOOR := 4
const PER_PARK := 10
const PER_PLAZA := 20

enum { WALK, TO_DOOR, INSIDE, FROM_DOOR, TO_SPOT, IDLE, FROM_SPOT, CROSS }

var city: CityDistrict
## cell -> {"doors": Array of [path_s, door_point], "open": bool (park/plaza)}
var blocks: Dictionary = {}
var people: Array[Dictionary] = []

var _mm: Array[MultiMesh] = []
var _buffers: Array[PackedFloat32Array] = []
var _rng := RandomNumberGenerator.new()
var _frame := 0


func _ready() -> void:
	_rng.seed = 99
	for c in CHARACTERS:
		var mesh: ArrayMesh = load(PEOPLE_DIR + c + "_crowd.res")
		var img: Image = load(PEOPLE_DIR + c + "_vat.res")
		var frames: Array = mesh.get_meta("frames")
		var mat := ShaderMaterial.new()
		mat.shader = load("res://scripts/world/city/people_vat.gdshader")
		mat.set_shader_parameter("vat", ImageTexture.create_from_image(img))
		mat.set_shader_parameter("walk_frames", frames[0])
		mat.set_shader_parameter("idle_frames", frames[1])
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
		"t_off": _rng.randf() * 10.0, "size": 1.0, "goal": false}
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
	var r2 := DRAW_RADIUS * DRAW_RADIUS
	var s2 := STEP_RADIUS * STEP_RADIUS
	var n2 := NEAR_RADIUS * NEAR_RADIUS
	_frame += 1
	var i := 0
	for p in people:
		i += 1
		var d2: float = (p.pos - eye).length_squared()
		if d2 > s2:
			continue
		if d2 < n2:
			_step(p, delta)
		elif (i + _frame) % 3 == 0:
			_step(p, delta * 3.0)
		if p.state == INSIDE or p.size <= 0.02 or d2 > r2:
			continue
		var t: int = p.type
		if counts[t] >= MAX_DRAWN:
			continue
		_write(t, counts[t], p)
		counts[t] += 1
	for t in _mm.size():
		_mm[t].buffer = _buffers[t]
		_mm[t].visible_instance_count = counts[t]


func _write(t: int, i: int, p: Dictionary) -> void:
	var b := Basis(Vector3.UP, p.yaw).scaled(Vector3.ONE * SCALE * p.size)
	var o: Vector3 = p.pos + Vector3(0, PAVEMENT_Y, 0)
	var buf := _buffers[t]
	var k := i * 16
	buf[k] = b.x.x; buf[k + 1] = b.y.x; buf[k + 2] = b.z.x; buf[k + 3] = o.x
	buf[k + 4] = b.x.y; buf[k + 5] = b.y.y; buf[k + 6] = b.z.y; buf[k + 7] = o.y
	buf[k + 8] = b.x.z; buf[k + 9] = b.y.z; buf[k + 10] = b.z.z; buf[k + 11] = o.z
	buf[k + 12] = p.t_off
	buf[k + 13] = 1.0 if p.state == IDLE else 0.0
	buf[k + 14] = 0.0
	buf[k + 15] = 0.0


## Move one person along and decide what they do next.
func _step(p: Dictionary, delta: float) -> void:
	var info: Dictionary = blocks.get(p.block, {})
	if info.is_empty():
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
			if not p.goal and _rng.randf() < 0.3 and _crossed_corner(before, p.s, p.dir):
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
