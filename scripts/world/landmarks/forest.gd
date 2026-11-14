class_name Forest
extends Landmark
## Chunky low-poly trees (MultiMesh, in tiles with a visibility range) over
## the forest area plus scattered trees on open grass. Each tree gets a
## cheap collider so the safety system treats the canopy as solid ground.
## Birds fly out when discovered.

const TILE := 300.0
const VIEW_DISTANCE := 1100.0
## Beyond this, trees switch from the detailed models to cheap cones.
const DETAIL_DISTANCE := 420.0
const PINE := "res://assets/environment/pine.glb"
const ROUND := "res://assets/environment/tree_round.glb"
## Model scale so each tree is ~13 m tall (matches the old cones).
const MODEL_SCALE := {PINE: 1.5, ROUND: 2.4}

var tree_count: int = 0


func _init() -> void:
	landmark_name = "Forest"
	discovery_radius = 200.0
	discovery_sound = "chirp"


func build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var tiles: Dictionary = {}  # [Vector2i, variant] -> Array[Transform3D]
	var colors: Dictionary = {}
	var body := StaticBody3D.new()
	body.collision_layer = GameSettings.LAYER_WORLD
	body.top_level = true
	add_child(body)
	# Dense pass over the forest, then a sparse scatter across the island.
	var f := IslandShape.FOREST
	for pass_i in 2:
		var dense := pass_i == 0
		var step := 13.0 if dense else 26.0
		var lo := (f - Vector2(300, 300)) if dense else Vector2.ONE * -IslandShape.SIZE * 0.5
		var hi := (f + Vector2(300, 300)) if dense else Vector2.ONE * IslandShape.SIZE * 0.5
		var z := lo.y
		while z < hi.y:
			var x := lo.x
			while x < hi.x:
				var px := x + rng.randf_range(-step * 0.4, step * 0.4)
				var pz := z + rng.randf_range(-step * 0.4, step * 0.4)
				var in_forest := IslandShape.p_in_forest(px, pz)
				var chance := (0.8 if in_forest else 0.0) if dense else (0.0 if in_forest else 0.05)
				if rng.randf() < chance and _can_grow(px, pz):
					_plant(body, tiles, colors, rng, px, pz, PINE if dense else ROUND)
				x += step
			z += step
	var cone := _tree_mesh()
	for key in tiles:
		var variant: String = key[1]
		var detail: Array = AssetLib.mesh_of(variant)
		var model_xf: Transform3D = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * MODEL_SCALE[variant])) * detail[1]
		# Near: detailed model. Far: cheap tinted cone. Swapped by distance.
		_add_multimesh(detail[0], tiles[key], [], model_xf, 0.0, DETAIL_DISTANCE)
		_add_multimesh(cone, tiles[key], colors[key], Transform3D.IDENTITY, DETAIL_DISTANCE, VIEW_DISTANCE)


func _add_multimesh(mesh: Mesh, xforms: Array, cols: Array, local: Transform3D, begin: float, end: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not cols.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in mm.instance_count:
		mm.set_instance_transform(i, xforms[i] * local)
		if mm.use_colors:
			mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.top_level = true
	mmi.visibility_range_begin = begin
	mmi.visibility_range_end = end
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if begin == 0.0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _plant(body: StaticBody3D, tiles: Dictionary, colors: Dictionary, rng: RandomNumberGenerator, px: float, pz: float, variant: String) -> void:
	var h := IslandShape.height(px, pz)
	var s := rng.randf_range(0.85, 1.5)
	var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(px, h - 0.5, pz))
	var key := [Vector2i(floori(px / TILE), floori(pz / TILE)), variant]
	if not tiles.has(key):
		tiles[key] = []
		colors[key] = []
	tiles[key].append(xf)
	colors[key].append(Color.from_hsv(rng.randf_range(0.26, 0.36), rng.randf_range(0.55, 0.75), rng.randf_range(0.55, 0.8)))
	var owner := body.create_shape_owner(body)
	body.shape_owner_add_shape(owner, _tree_shape)
	body.shape_owner_set_transform(owner, Transform3D(Basis.IDENTITY, Vector3(px, h + 7.0 * s, pz)))
	tree_count += 1


static var _tree_shape: CylinderShape3D = BuildKit.cyl_shape(3.2, 14.0)


func _can_grow(x: float, z: float) -> bool:
	var h := IslandShape.height(x, z)
	if h < 8.0 or h > 130.0 or IslandShape.on_runway(x, z):
		return false
	if Vector2(x, z).distance_to(IslandShape.FARM) < 150.0:
		return false
	if Vector2(x, z).distance_to(IslandShape.RUNWAY) < 380.0 and absf(z) < 130.0:
		return false
	# Not on steep slopes
	var dx := IslandShape.height(x + 4, z) - h
	var dz := IslandShape.height(x, z + 4) - h
	return Vector2(dx, dz).length() < 3.0


## Trunk + two cone tiers in one mesh. Vertex colours: brown trunk, white
## canopy (tinted per instance by the MultiMesh colour).
func _tree_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_cone(st, 0.0, 4.0, 0.9, 0.7, Color(0.55, 0.36, 0.22) / 0.7)
	_add_cone(st, 3.0, 9.0, 4.2, 0.0, Color.WHITE)
	_add_cone(st, 7.5, 13.5, 3.0, 0.0, Color.WHITE)
	st.generate_normals()
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, m)
	return mesh


func _add_cone(st: SurfaceTool, y0: float, y1: float, r0: float, r1: float, col: Color) -> void:
	const SEG := 6
	for i in SEG:
		var a0 := TAU * i / SEG
		var a1 := TAU * (i + 1) / SEG
		var b0 := Vector3(cos(a0) * r0, y0, sin(a0) * r0)
		var b1 := Vector3(cos(a1) * r0, y0, sin(a1) * r0)
		var t0 := Vector3(cos(a0) * r1, y1, sin(a0) * r1)
		var t1 := Vector3(cos(a1) * r1, y1, sin(a1) * r1)
		st.set_color(col)
		st.set_smooth_group(-1)  # flat shading
		for v in [b0, t0, b1, b1, t0, t1]:
			st.add_vertex(v)
		st.add_vertex(Vector3(0, y0, 0))
		st.add_vertex(b0)
		st.add_vertex(b1)


func react() -> void:
	var birds := PickupBurst.new(18, 14.0, [Color("333344"), Color("554433")])
	birds.gravity = Vector3(0, 4, 0)
	birds.lifetime = 2.5
	add_child(birds)
	birds.global_position = global_position + Vector3(0, 20, 0)
