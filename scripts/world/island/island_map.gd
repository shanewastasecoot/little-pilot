class_name IslandMap
extends GameMap
## The real island: terrain, ocean, sky, landmarks and star trails.
## Everything is generated from IslandShape at load time.

const STAR_CLEARANCE := 24.0  # metres above ground for "low" stars


func _init() -> void:
	# West end of the runway, facing east down it.
	spawn_position = Vector3(-260, 32, 0)
	spawn_heading_deg = -90.0


func _ready() -> void:
	_build_environment()
	TerrainBuilder.build(self)
	_build_ocean()
	_place_landmarks()
	_place_stars()


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("3d9cff")
	sky_mat.sky_horizon_color = Color("bfe6ff")
	sky_mat.ground_horizon_color = Color("bfe6ff")
	sky_mat.ground_bottom_color = Color("2f7fc0")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("cfeaff")
	env.fog_density = 0.00045
	env.fog_sky_affect = 0.15
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	add_child(sun)

	var bounds := WorldBounds.new()
	bounds.radius = 1450.0
	bounds.edge_band = 220.0
	bounds.ceiling = 380.0
	bounds.ceiling_band = 40.0
	add_child(bounds)


func _build_ocean() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(5000, 5000)
	mesh.subdivide_width = 80
	mesh.subdivide_depth = 80
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ocean.gdshader")
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# Flat water collider for the safety system.
	BuildKit.collider(self, BuildKit.box_shape(Vector3(5000, 2, 5000)), Vector3(0, -1, 0))


func _place_landmarks() -> void:
	_add_landmark(Airport.new(), IslandShape.RUNWAY)
	_add_landmark(Farm.new(), IslandShape.FARM)
	_add_landmark(Lighthouse.new(), IslandShape.LIGHTHOUSE)
	_add_landmark(WindFarm.new(), (IslandShape.RIDGE_A + IslandShape.RIDGE_B) * 0.5)
	_add_landmark(Forest.new(), IslandShape.FOREST)
	var valley := _ground(IslandShape.VALLEY)
	var m := Mountains.new()
	m.position = Vector3(IslandShape.VALLEY.x, valley + 40.0, IslandShape.VALLEY.y)
	add_child(m)
	var boat := Boat.new()
	add_child(boat)
	var whale := Whale.new()
	whale.position = Vector3(-1080, 0, 250)
	add_child(whale)


func _add_landmark(l: Landmark, at: Vector2) -> void:
	l.position = Vector3(at.x, _ground(at), at.y)
	add_child(l)


func _place_stars() -> void:
	var stars := Node3D.new()
	stars.name = "Stars"
	add_child(stars)
	# Runway: an arc leading away east from the far end.
	_trail(stars, 6, [_air(Vector2(-120, 0), 26), _air(Vector2(120, -30), 34), _air(Vector2(320, -110), 40), _air(Vector2(420, -230), 46)])
	# Mountains: through the valley, then one on top of the tallest peak.
	var v := IslandShape.VALLEY
	_trail(stars, 7, [_air(v + Vector2(0, 200), 40), _air(v, 40), _air(v + Vector2(0, -200), 40)])
	var peak: Vector4 = IslandShape.PEAKS[1]
	_trail(stars, 1, [_air(Vector2(peak.x, peak.y), 30)])
	# Forest: weave over the treetops.
	var f := IslandShape.FOREST
	_trail(stars, 7, [_air(f + Vector2(150, 120), 34), _air(f + Vector2(50, 20), 34), _air(f + Vector2(-50, 60), 34), _air(f + Vector2(-140, -60), 34)])
	# Farm: a heart over the fields.
	var heart: Array[Vector3] = []
	for i in 9:
		var t := TAU * i / 8.0
		var hx := 16.0 * pow(sin(t), 3)
		var hy := 13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)
		heart.append(Vector3(IslandShape.FARM.x + hx * 6.0, IslandShape.FARM_HEIGHT + 50.0 + hy * 3.0, IslandShape.FARM.y + 160.0))
	_trail(stars, 8, heart)
	# Lighthouse: a spiral around the tower.
	var spiral: Array[Vector3] = []
	var lh := IslandShape.LIGHTHOUSE
	var base := _ground(lh)
	for i in 8:
		var a := i * 0.9
		spiral.append(Vector3(lh.x + cos(a) * 55.0, base + 25.0 + i * 6.0, lh.y + sin(a) * 55.0))
	_trail(stars, 8, spiral)
	# Wind farm: between turbines (never inside the blade sweep).
	for i in 4:
		var p := IslandShape.RIDGE_A.lerp(IslandShape.RIDGE_B, (i + 1.0) / WindFarm.COUNT)
		_trail(stars, 1, [Vector3(p.x, _ground(p) + WindFarm.TOWER_H, p.y)])
	# Ocean: low stars skimming the water along the south coast.
	_trail(stars, 6, [Vector3(-500, 16, 960), Vector3(-150, 16, 1010), Vector3(150, 16, 980)])
	# A few near the spawn to start with.
	_trail(stars, 3, [_air(Vector2(-200, 90), 28), _air(Vector2(-100, 100), 30), _air(Vector2(0, 90), 32)])


func _trail(parent: Node3D, count: int, points: Array) -> void:
	var curve := Curve3D.new()
	for p in points:
		curve.add_point(p)
	var trail := StarTrail.new()
	trail.curve = curve
	trail.star_count = count
	parent.add_child(trail)


## A point `above` metres over the ground (or water) at (x, z).
func _air(at: Vector2, above: float) -> Vector3:
	return Vector3(at.x, maxf(_ground(at), 0.0) + above, at.y)


func _ground(at: Vector2) -> float:
	return IslandShape.height(at.x, at.y)
