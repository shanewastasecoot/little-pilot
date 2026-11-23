class_name CityDistrict
extends Landmark
## The city, south-east of the runway: a 5x5 grid of blocks round a
## fountain plaza. Downtown (the middle 3x3) has five skyscrapers
## (100-200 m), shops and two construction sites with swinging tower cranes;
## the outer ring adds more towers, apartment and shop pairs, a third
## building site, a park with a pond, and a big turning Ferris wheel.
## Streets have lane markings, street lights and traffic lights. Node sits at
## the city centre on its flat ground.
## The city keeps growing as the player flies (CityGrowth, a child): the
## outer ring of lots fills in and the three construction sites finish.

const ENV := "res://assets/environment/"
const PITCH := 80.0      # block spacing (block + road)
const ROAD_W := 16.0
const GRID := 5          # blocks per side (odd, centred on the plaza)
const WHEEL_R := 34.0    # Ferris wheel radius

var _cranes: Array[Node3D] = []
var _crane_speed := 0.12
var _fountain: CPUParticles3D
var _wheel: Node3D
var _gondolas: Array[Node3D] = []
var _wheel_speed := 0.08
var growth: CityGrowth
var crowd: CityCrowd
## Today's towers (cells): people go in and out of them.
const TOWER_CELLS := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1),
	Vector2i(-2, -2), Vector2i(2, 2), Vector2i(-2, 0), Vector2i(2, 0)]
## Pavement ring round a block (people walk on it): inner edge at the block
## edge (32 m from its centre), 3.5 m wide, on top of the road.
const PAVE_IN := 32.0
const PAVE_W := 3.5
const PAVE_Y := 0.3
## Construction sites by cell: {"core": frame/structure, "edge": floor,
## barriers and crane}. The core goes when its building starts rising, the
## edge when it opens.
var _sites: Dictionary = {}
## Downtown shop pairs by cell (holder node), and what each was built from,
## so a restarted city gets back any that were upgraded into towers.
var _pairs: Dictionary = {}
var _pair_models: Dictionary = {}


func _init() -> void:
	landmark_name = "City"
	discovery_radius = 400.0
	discovery_sound = "bells"


func build() -> void:
	_build_streets()
	_build_plaza()
	# Blocks: [grid x, grid z] -> contents. Towers sized to the plane
	# (~5 m wingspan): 100-200 m tall, 37-45 m wide, filling their blocks.
	_skyscraper("sky_glass_c", Vector2(-1, -1), 36.0, 5.5)    # ~200 m, the tallest
	_skyscraper("sky_glass", Vector2(1, -1), 34.0, 4.08)      # ~140 m
	_skyscraper("sky_glass_b", Vector2(-1, 0), 32.0, 4.48)    # ~145 m
	_skyscraper("sky_grey", Vector2(1, 0), 30.0, 4.08)        # ~120 m
	_skyscraper("sky_classic", Vector2(-1, 1), 32.0, 3.15)    # ~100 m
	_pair(Vector2(0, -1), "bld_b", "bld_c")
	# Outer ring.
	_skyscraper("sky_grey", Vector2(-2, -2), 28.0, 4.08, 90.0)       # ~115 m
	_skyscraper("sky_glass_b", Vector2(2, 2), 28.0, 4.48, 90.0)      # ~125 m
	_skyscraper("sky_classic", Vector2(-2, 0), 24.0, 3.15, 180.0)    # ~75 m
	_skyscraper("sky_glass", Vector2(2, 0), 25.0, 4.08, 270.0)       # ~100 m
	for cell in [Vector2(-1, -2), Vector2(0, -2), Vector2(1, -2), Vector2(-2, -1), Vector2(-2, 1),
			Vector2(2, -1), Vector2(-1, 2), Vector2(0, 2), Vector2(1, 2)]:
		var flip := int(cell.x + cell.y) % 2 == 0
		_pair(cell, "bld_c" if flip else "bld_b", "bld_b" if flip else "bld_c")
	_ferris_wheel(Vector2(2, -2))
	_park(Vector2(-2, 2))
	var cells: Array[Vector2i] = []
	for x in range(-2, 3):
		for z in range(-2, 3):
			cells.append(Vector2i(x, z))
	add_child(pavements(cells))
	crowd = CityCrowd.new()
	crowd.name = "Crowd"
	crowd.city = self
	add_child(crowd)
	# Townspeople cheer and wave: at a honk or a low pass over them, and when
	# she cheers at them on foot (WorldEvents).
	WorldReaction.add(self, 700.0, ["honk", "low_pass", "cheer"], 0.5, func(kind: String, where: Vector3):
		crowd.cheer_near(where, {"honk": 70.0, "low_pass": 60.0, "cheer": 28.0}[kind], 2.5))
	growth = CityGrowth.new()
	growth.name = "Growth"
	growth.city = self
	add_child(growth)  # builds the sites (reset_sites) and everything grown so far


## Pavement rings round `cells` as one MultiMesh (one draw call).
static func pavements(cells: Array[Vector2i]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var long := (PAVE_IN + PAVE_W) * 2.0
	mm.mesh = BuildKit.box(Vector3(long, 0.12, PAVE_W))
	mm.instance_count = cells.size() * 4
	var mid := PAVE_IN + PAVE_W * 0.5
	var i := 0
	for cell in cells:
		var c := Vector3(cell.x * PITCH, PAVE_Y, cell.y * PITCH)
		for k in 4:
			var yaw := PI * 0.5 * k
			var off := Vector3(0, 0, -mid).rotated(Vector3.UP, yaw)
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw), c + off))
			i += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = BuildKit.mat("c9c4bb")
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	return mmi


## Today's blocks for the crowd, as they stand now: cell -> {"doors":
## [building centres], "open": bool (park/plaza), "plaza": bool}.
## Construction sites have no doors yet; knocked-down pairs drop out.
func core_blocks() -> Dictionary:
	var out := {}
	for x in range(-2, 3):
		for z in range(-2, 3):
			out[Vector2i(x, z)] = {"doors": [], "open": false}
	out[Vector2i(0, 0)] = {"doors": [], "open": true, "plaza": true}
	out[Vector2i(2, -2)].open = true    # Ferris wheel park
	out[Vector2i(-2, 2)].open = true    # park
	for cell in TOWER_CELLS:
		out[cell].doors.append(Vector3(cell.x * PITCH, 0, cell.y * PITCH))
	for cell in _pairs:
		var c := Vector3(cell.x * PITCH, 0, cell.y * PITCH)
		out[cell].doors.append(c + Vector3(-16, 0, 0))
		out[cell].doors.append(c + Vector3(16, 0, 0))
	return out


## Put the three construction sites and every old shop pair back as they
## were (start of the city).
func reset_sites() -> void:
	for cell in _sites.keys():
		clear_site(cell)
	for cell in _pair_models:
		if not _pairs.has(cell):
			var m: Array = _pair_models[cell]
			_pair(Vector2(cell), m[0], m[1])
	_construction(Vector2(0, 1), true)
	_construction(Vector2(1, 1), false)
	_construction(Vector2(2, 1), false)


## An old shop pair is being replaced by a tower: knock it down.
func clear_pair(cell: Vector2i) -> void:
	if _pairs.has(cell) and is_instance_valid(_pairs[cell]):
		_pairs[cell].free()
	_pairs.erase(cell)


## Its building has started rising: take away the old frame.
func clear_site_core(cell: Vector2i) -> void:
	var s: Dictionary = _sites.get(cell, {})
	if s.has("core") and is_instance_valid(s.core):
		s.core.free()
	s.erase("core")


## Its building has opened: take away the whole site.
func clear_site(cell: Vector2i) -> void:
	clear_site_core(cell)
	var s: Dictionary = _sites.get(cell, {})
	if s.has("edge") and is_instance_valid(s.edge):
		s.edge.free()
	_sites.erase(cell)


# --- Streets -------------------------------------------------------------------

func _build_streets() -> void:
	var half := GRID * 0.5
	var span := PITCH * GRID + ROAD_W
	var dashes: Array[Transform3D] = []
	for k in GRID + 1:
		var o := -PITCH * half + k * PITCH
		for along_x in [true, false]:
			var size := Vector3(span, 0.3, ROAD_W) if along_x else Vector3(ROAD_W, 0.3, span)
			var pos := Vector3(0, 0.12, o) if along_x else Vector3(o, 0.13, 0)
			var road := BuildKit.add(self, BuildKit.box(size), "4a4f57", pos)
			road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# Dashed centre line (collected into one MultiMesh below).
			var n := GRID * 4
			for d in n:
				var t := -span * 0.5 + 12.0 + d * (span - 24.0) / (n - 1)
				var p := Vector3(t, 0.32, o) if along_x else Vector3(o, 0.32, t)
				dashes.append(Transform3D(Basis(Vector3.UP, 0.0 if along_x else PI * 0.5), p))
	var dash_mm := MultiMesh.new()
	dash_mm.transform_format = MultiMesh.TRANSFORM_3D
	dash_mm.mesh = BuildKit.box(Vector3(5, 0.1, 0.6))
	dash_mm.instance_count = dashes.size()
	for i in dashes.size():
		dash_mm.set_instance_transform(i, dashes[i])
	var dash_mi := MultiMeshInstance3D.new()
	dash_mi.multimesh = dash_mm
	dash_mi.material_override = BuildKit.mat("ffffff")
	dash_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dash_mi.visibility_range_end = 900.0
	add_child(dash_mi)
	# Street lights along every road (one MultiMesh), traffic lights at the
	# downtown crossings.
	var data: Array = AssetLib.mesh_of(ENV + "street_light.glb")
	var xforms: Array[Transform3D] = []
	for k in GRID + 1:
		var o := -PITCH * half + k * PITCH
		for d in GRID * 2 + 1:
			var t := -PITCH * half + d * PITCH * 0.5
			for along_x in [true, false]:
				var p := Vector3(t, 0, o + ROAD_W * 0.5 + 1.5) if along_x else Vector3(o + ROAD_W * 0.5 + 1.5, 0, t)
				var yaw := PI if along_x else PI * 0.5
				xforms.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * 1.6), p) * data[1])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = data[0]
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = 1400.0
	add_child(mmi)
	for cx in [-1.5, -0.5, 0.5, 1.5]:
		for cz in [-1.5, -0.5, 0.5, 1.5]:
			if absf(cx) > 1.0 and absf(cz) > 1.0:
				continue  # downtown's crossings only (12 of them)
			AssetLib.place(self, ENV + "traffic_light.glb", Vector3(cx * PITCH + ROAD_W * 0.5 + 1.0, 0, cz * PITCH + ROAD_W * 0.5 + 1.0), 1.5)


func _block_centre(cell: Vector2) -> Vector3:
	return Vector3(cell.x * PITCH, 0, cell.y * PITCH)


# --- Buildings -----------------------------------------------------------------

func _skyscraper(model: String, cell: Vector2, s: float, model_h: float, yaw := 0.0) -> void:
	var c := _block_centre(cell)
	AssetLib.place(self, ENV + model + ".glb", c, s, yaw)
	var h := model_h * s
	BuildKit.collider(self, BuildKit.box_shape(Vector3(1.25 * s, h, 1.35 * s)), c + Vector3(0, h * 0.5, 0))
	BuildKit.push_volume(self, 0.65 * s + 16.0, h + 40.0, c)


func _pair(cell: Vector2, a: String, b: String) -> void:
	var c := _block_centre(cell)
	var holder := Node3D.new()
	add_child(holder)
	_pairs[Vector2i(cell)] = holder
	_pair_models[Vector2i(cell)] = [a, b]
	for side in [-1.0, 1.0]:
		var model: String = a if side < 0.0 else b
		var p := c + Vector3(side * 16.0, 0, 0)
		AssetLib.place(holder, ENV + model + ".glb", p, 16.0, 180.0 if cell.y < 0 or (cell.y == 0 and cell.x < 0) else 0.0)
		var h := (3.05 if model == "bld_b" else 2.35) * 16.0
		BuildKit.collider(holder, BuildKit.box_shape(Vector3(32, h, 32)), p + Vector3(0, h * 0.5, 0))
	BuildKit.push_volume(holder, 44.0, 90.0, c)


func _construction(cell: Vector2, half_built: bool) -> void:
	var c := _block_centre(cell)
	var edge := Node3D.new()
	var core := Node3D.new()
	add_child(edge)
	add_child(core)
	_sites[Vector2i(cell)] = {"edge": edge, "core": core}
	# Site floor and barriers round the edge.
	BuildKit.add(edge, BuildKit.box(Vector3(60, 0.5, 60)), "b9a88a", c + Vector3(0, 0.25, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 16:
		var side := k / 4
		var t := -24.0 + (k % 4) * 16.0
		var p := Vector3(t, 0, 29) if side == 0 else Vector3(t, 0, -29) if side == 1 else Vector3(29, 0, t) if side == 2 else Vector3(-29, 0, t)
		AssetLib.place(edge, ENV + "barrier.glb", c + p + Vector3(0, 0.06 * 15.0, 0), 15.0, 0.0 if side < 2 else 90.0)
	if half_built:
		AssetLib.place(core, ENV + "structure.glb", c + Vector3(-6, 0, 0), 5.5)
		BuildKit.collider(core, BuildKit.box_shape(Vector3(57, 42, 41)), c + Vector3(-6, 21, 0))
	else:
		# Foundation with a steel frame rising: the next tower going up.
		BuildKit.add(core, BuildKit.box(Vector3(44, 3, 44)), "9aa0a8", c + Vector3(0, 1.5, 0))
		for fx in 4:
			for fz in 4:
				BuildKit.add(core, BuildKit.box(Vector3(1.2, 46, 1.2)), "6b7a8f", c + Vector3(-19.5 + fx * 13.0, 26, -19.5 + fz * 13.0))
		for level in 4:
			BuildKit.add(core, BuildKit.box(Vector3(42, 1.0, 42)), "8a97a8", c + Vector3(0, 12 + level * 12.0, 0))
		BuildKit.collider(core, BuildKit.box_shape(Vector3(44, 50, 44)), c + Vector3(0, 25, 0))
	make_crane(edge, c + Vector3(26, 0, -22), 110.0 if half_built else 95.0)


## A tower crane `h` m tall under `parent`; its top turns with the others.
func make_crane(parent: Node3D, at: Vector3, h: float) -> void:
	var crane := Node3D.new()
	crane.position = at
	parent.add_child(crane)
	# Mast: four yellow legs with cross braces (reads as a lattice).
	for lx in [-1.2, 1.2]:
		for lz in [-1.2, 1.2]:
			BuildKit.add(crane, BuildKit.box(Vector3(0.5, h, 0.5)), "ffc21a", Vector3(lx, h * 0.5, lz))
	for k in int(h / 6.0):
		BuildKit.add(crane, BuildKit.box(Vector3(2.9, 0.35, 2.9)), "e0a800", Vector3(0, 3.0 + k * 6.0, 0))
	BuildKit.collider(crane, BuildKit.box_shape(Vector3(3.5, h, 3.5)), Vector3(0, h * 0.5, 0))
	BuildKit.push_volume(crane, 52.0, h + 30.0)
	# Rotating top: jib, counter-jib with weights, cab, hook.
	var top := Node3D.new()
	top.position.y = h
	crane.add_child(top)
	BuildKit.add(top, BuildKit.box(Vector3(46, 2.2, 2.2)), "ffc21a", Vector3(23, 1.1, 0))
	BuildKit.add(top, BuildKit.box(Vector3(14, 2.2, 2.2)), "ffc21a", Vector3(-7, 1.1, 0))
	BuildKit.add(top, BuildKit.box(Vector3(5, 4, 4)), "6d7480", Vector3(-12, -1.2, 0))
	BuildKit.add(top, BuildKit.box(Vector3(4, 4, 4)), "ffffff", Vector3(2, -2, 0))
	BuildKit.add(top, BuildKit.box(Vector3(0.8, 8, 0.8)), "ffc21a", Vector3(0, 5, 0))
	BuildKit.add(top, BuildKit.box(Vector3(0.2, 30, 0.2)), "333333", Vector3(32, -15, 0))
	BuildKit.add(top, BuildKit.box(Vector3(2.4, 2, 2.4)), "ff5a5f", Vector3(32, -31, 0))
	top.rotation.y = randf() * TAU
	_cranes.append(top)


# --- Ferris wheel and park ---------------------------------------------------------

## A big Ferris wheel in a little park: A-frame legs, two rims with spokes,
## and twelve coloured cars that stay upright as the wheel turns.
func _ferris_wheel(cell: Vector2) -> void:
	var c := _block_centre(cell)
	BuildKit.add(self, BuildKit.box(Vector3(62, 0.5, 62)), "7ccf6a", c + Vector3(0, 0.25, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hub_y := WHEEL_R + 8.0
	var frame := Node3D.new()
	frame.position = c
	frame.rotation.y = PI * 0.25  # turned to face the plaza diagonal
	add_child(frame)
	for side in [-1.0, 1.0]:
		for lean in [-1.0, 1.0]:
			var leg := BuildKit.add(frame, BuildKit.box(Vector3(1.6, hub_y * 1.08, 1.6)), "e8e8f0", Vector3(lean * 9.0, hub_y * 0.5, side * 4.5))
			leg.rotation.z = -lean * 0.24
	BuildKit.add(frame, BuildKit.cyl(1.2, 11.0, -1, 10), "c0c4cc", Vector3(0, hub_y, 0), Vector3(90, 0, 0))
	_wheel = Node3D.new()
	_wheel.position.y = hub_y
	frame.add_child(_wheel)
	# Rims and spokes merged into one mesh (they turn together).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim := TorusMesh.new()
	rim.inner_radius = WHEEL_R - 0.8
	rim.outer_radius = WHEEL_R + 0.8
	rim.rings = 48
	rim.ring_segments = 6
	for z in [-3.0, 3.0]:
		st.append_from(rim, 0, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, z)))
	var spoke_mesh := BuildKit.box(Vector3(0.5, WHEEL_R, 0.5))
	for k in 12:
		var a := TAU * k / 12.0
		for z in [-3.0, 3.0]:
			st.append_from(spoke_mesh, 0, Transform3D(Basis(Vector3.BACK, a - PI * 0.5), Vector3(cos(a), sin(a), 0) * WHEEL_R * 0.5 + Vector3(0, 0, z)))
	var frame_mesh := MeshInstance3D.new()
	frame_mesh.mesh = st.commit()
	frame_mesh.material_override = BuildKit.mat("ff5a8a")
	_wheel.add_child(frame_mesh)
	var colors := ["ff5a5f", "ffd23f", "4cc06a", "4aa8ff", "9b5de5", "ff8c42"]
	for k in 12:
		var a := TAU * k / 12.0
		var car := Node3D.new()
		car.position = Vector3(cos(a), sin(a), 0) * WHEEL_R
		_wheel.add_child(car)
		BuildKit.add(car, BuildKit.cyl(2.4, 3.4, 2.0, 10), colors[k % colors.size()], Vector3(0, -2.6, 0))
		BuildKit.add(car, BuildKit.cyl(2.6, 0.5, 0.6, 10), "ffffff", Vector3(0, -0.6, 0))
		_gondolas.append(car)
	# The plane steers round it like any tall building.
	var col := BuildKit.collider(self, BuildKit.cyl_shape(WHEEL_R + 4.0, 10.0), c + Vector3(0, hub_y, 0))
	col.rotation = Vector3(PI * 0.5, PI * 0.25, 0)  # disc along the axle
	BuildKit.push_volume(self, WHEEL_R + 18.0, hub_y + WHEEL_R + 30.0, c)
	for k in 6:
		var a := TAU * k / 6.0
		AssetLib.place(self, ENV + "tree_round.glb", c + Vector3(cos(a) * 26.0, 0, sin(a) * 26.0), 2.0)


## A green park with a pond and trees.
func _park(cell: Vector2) -> void:
	var c := _block_centre(cell)
	BuildKit.add(self, BuildKit.box(Vector3(62, 0.5, 62)), "7ccf6a", c + Vector3(0, 0.25, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	BuildKit.add(self, BuildKit.cyl(14.0, 0.6, -1, 24), "c9c3b6", c + Vector3(4, 0.4, -3))
	BuildKit.add(self, BuildKit.cyl(12.8, 0.3, -1, 24), "4fb6ff", c + Vector3(4, 0.75, -3))
	BuildKit.add(self, BuildKit.box(Vector3(3, 0.4, 40)), "e2d6b8", c + Vector3(-14, 0.55, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 14:
		var p := Vector3(rng.randf_range(-26, 26), 0, rng.randf_range(-26, 26))
		if p.distance_to(Vector3(4, 0, -3)) < 18.0 or absf(p.x + 14.0) < 4.0:
			continue
		AssetLib.place(self, ENV + "tree_round.glb", c + p, rng.randf_range(1.8, 2.6), rng.randf() * 360.0)


# --- Plaza -------------------------------------------------------------------------

func _build_plaza() -> void:
	BuildKit.add(self, BuildKit.box(Vector3(60, 0.4, 60)), "d8d0c0", Vector3(0, 0.2, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	BuildKit.add(self, BuildKit.cyl(10, 1.6, -1, 24), "c9c3b6", Vector3(0, 0.8, 0))
	BuildKit.add(self, BuildKit.cyl(8.8, 0.3, -1, 24), "4fb6ff", Vector3(0, 1.5, 0))
	BuildKit.add(self, BuildKit.cyl(1.2, 5, -1, 12), "c9c3b6", Vector3(0, 2.5, 0))
	_fountain = PickupBurst.new(30, 6.0, [Color("bfe9ff"), Color.WHITE])
	_fountain.one_shot = false
	_fountain.explosiveness = 0.0
	_fountain.spread = 12.0
	_fountain.lifetime = 1.4
	_fountain.gravity = Vector3(0, -9, 0)
	_fountain.position = Vector3(0, 5, 0)
	_fountain.finished.disconnect(_fountain.queue_free)
	add_child(_fountain)
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		AssetLib.place(self, ENV + "tree_round.glb", Vector3(cos(a) * 20.0, 0, sin(a) * 20.0), 2.2)


func _process(delta: float) -> void:
	if _wheel:
		_wheel.rotate_z(_wheel_speed * delta)
		for car in _gondolas:
			car.global_rotation = Vector3(0, PI * 0.25, 0)  # cars hang level
		_wheel_speed = move_toward(_wheel_speed, 0.08, delta * 0.1)
	for i in _cranes.size():
		if not is_instance_valid(_cranes[i]):
			continue
		_cranes[i].rotate_y(_crane_speed * delta * (1.0 if i % 2 == 0 else -0.8))
	_crane_speed = move_toward(_crane_speed, 0.12, delta * 0.2)


func react() -> void:
	_crane_speed = 1.2
	_wheel_speed = 0.6
	var confetti := PickupBurst.new(60, 22.0, [Color("ffd23f"), Color("ff5a5f"), Color("4aa8ff"), Color("4cc06a")])
	confetti.position = Vector3(0, 120, 0)
	add_child(confetti)
