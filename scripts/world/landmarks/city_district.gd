class_name CityDistrict
extends Landmark
## The start of a city, south-east of the runway: a 3x3 grid of blocks with
## a fountain plaza, five skyscrapers (100-200 m), colourful shop
## buildings, and two construction sites with swinging tower cranes (the
## city is still being built). Streets have lane markings, street lights and
## traffic lights. Node sits at the city centre on its flat ground.

const ENV := "res://assets/environment/"
const PITCH := 80.0      # block spacing (block + road)
const ROAD_W := 16.0

var _cranes: Array[Node3D] = []
var _crane_speed := 0.12
var _fountain: CPUParticles3D


func _init() -> void:
	landmark_name = "City"
	discovery_radius = 320.0
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
	_construction(Vector2(0, 1), true)
	_construction(Vector2(1, 1), false)


# --- Streets -------------------------------------------------------------------

func _build_streets() -> void:
	var span := PITCH * 3.0 + ROAD_W
	for k in 4:
		var o := -PITCH * 1.5 + k * PITCH
		for along_x in [true, false]:
			var size := Vector3(span, 0.3, ROAD_W) if along_x else Vector3(ROAD_W, 0.3, span)
			var pos := Vector3(0, 0.12, o) if along_x else Vector3(o, 0.13, 0)
			var road := BuildKit.add(self, BuildKit.box(size), "4a4f57", pos)
			road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# Dashed centre line
			for d in 12:
				var t := -span * 0.5 + 12.0 + d * (span - 24.0) / 11.0
				var dash := Vector3(5, 0.1, 0.6) if along_x else Vector3(0.6, 0.1, 5)
				BuildKit.add(self, BuildKit.box(dash), "ffffff", Vector3(t, 0.32, o) if along_x else Vector3(o, 0.32, t))
	# Street lights along every road (one MultiMesh), traffic lights at the
	# four middle crossings.
	var data: Array = AssetLib.mesh_of(ENV + "street_light.glb")
	var xforms: Array[Transform3D] = []
	for k in 4:
		var o := -PITCH * 1.5 + k * PITCH
		for d in 7:
			var t := -PITCH * 1.5 + d * PITCH * 0.5
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
	for cx in [-0.5, 0.5]:
		for cz in [-0.5, 0.5]:
			AssetLib.place(self, ENV + "traffic_light.glb", Vector3(cx * PITCH + ROAD_W * 0.5 + 1.0, 0, cz * PITCH + ROAD_W * 0.5 + 1.0), 1.5)


func _block_centre(cell: Vector2) -> Vector3:
	return Vector3(cell.x * PITCH, 0, cell.y * PITCH)


# --- Buildings -----------------------------------------------------------------

func _skyscraper(model: String, cell: Vector2, s: float, model_h: float) -> void:
	var c := _block_centre(cell)
	AssetLib.place(self, ENV + model + ".glb", c, s)
	var h := model_h * s
	BuildKit.collider(self, BuildKit.box_shape(Vector3(1.25 * s, h, 1.35 * s)), c + Vector3(0, h * 0.5, 0))
	BuildKit.push_volume(self, 0.65 * s + 16.0, h + 40.0, c)


func _pair(cell: Vector2, a: String, b: String) -> void:
	var c := _block_centre(cell)
	for side in [-1.0, 1.0]:
		var model: String = a if side < 0.0 else b
		var p := c + Vector3(side * 16.0, 0, 0)
		AssetLib.place(self, ENV + model + ".glb", p, 16.0, 180.0 if cell.y < 0 else 0.0)
		var h := (3.05 if model == "bld_b" else 2.35) * 16.0
		BuildKit.collider(self, BuildKit.box_shape(Vector3(32, h, 32)), p + Vector3(0, h * 0.5, 0))
	BuildKit.push_volume(self, 44.0, 90.0, c)


func _construction(cell: Vector2, half_built: bool) -> void:
	var c := _block_centre(cell)
	# Site floor and barriers round the edge.
	BuildKit.add(self, BuildKit.box(Vector3(60, 0.5, 60)), "b9a88a", c + Vector3(0, 0.25, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 16:
		var side := k / 4
		var t := -24.0 + (k % 4) * 16.0
		var p := Vector3(t, 0, 29) if side == 0 else Vector3(t, 0, -29) if side == 1 else Vector3(29, 0, t) if side == 2 else Vector3(-29, 0, t)
		AssetLib.place(self, ENV + "barrier.glb", c + p + Vector3(0, 0.06 * 15.0, 0), 15.0, 0.0 if side < 2 else 90.0)
	if half_built:
		AssetLib.place(self, ENV + "structure.glb", c + Vector3(-6, 0, 0), 5.5)
		BuildKit.collider(self, BuildKit.box_shape(Vector3(57, 42, 41)), c + Vector3(-6, 21, 0))
	else:
		# Foundation with a steel frame rising: the next tower going up.
		BuildKit.add(self, BuildKit.box(Vector3(44, 3, 44)), "9aa0a8", c + Vector3(0, 1.5, 0))
		for fx in 4:
			for fz in 4:
				BuildKit.add(self, BuildKit.box(Vector3(1.2, 46, 1.2)), "6b7a8f", c + Vector3(-19.5 + fx * 13.0, 26, -19.5 + fz * 13.0))
		for level in 4:
			BuildKit.add(self, BuildKit.box(Vector3(42, 1.0, 42)), "8a97a8", c + Vector3(0, 12 + level * 12.0, 0))
		BuildKit.collider(self, BuildKit.box_shape(Vector3(44, 50, 44)), c + Vector3(0, 25, 0))
	_crane(c + Vector3(26, 0, -22), half_built)


func _crane(at: Vector3, tall: bool) -> void:
	var h := 110.0 if tall else 95.0
	var crane := Node3D.new()
	crane.position = at
	add_child(crane)
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
	for i in _cranes.size():
		_cranes[i].rotate_y(_crane_speed * delta * (1.0 if i % 2 == 0 else -0.8))
	_crane_speed = move_toward(_crane_speed, 0.12, delta * 0.2)


func react() -> void:
	_crane_speed = 1.2
	var confetti := PickupBurst.new(60, 22.0, [Color("ffd23f"), Color("ff5a5f"), Color("4aa8ff"), Color("4cc06a")])
	confetti.position = Vector3(0, 120, 0)
	add_child(confetti)
