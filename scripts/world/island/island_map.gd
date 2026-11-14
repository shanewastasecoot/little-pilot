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
	TerrainBuilder.build(self, IslandShape.height, IslandShape.color, Vector2.ZERO, IslandShape.SIZE, 160)
	TerrainBuilder.build(self, IslandShape.palm_height, IslandShape.palm_color, IslandShape.PALM_ISLAND, 760.0, 54, "PalmTerrain")
	TerrainBuilder.build(self, IslandShape.volcano_height, IslandShape.volcano_color, IslandShape.VOLCANO, 1000.0, 72, "VolcanoTerrain")
	TerrainBuilder.build(self, OuterIslands.ice_height, OuterIslands.ice_color, OuterIslands.ICE, 1100.0, 70, "IceTerrain")
	TerrainBuilder.build(self, OuterIslands.dino_height, OuterIslands.dino_color, OuterIslands.DINO, 1200.0, 76, "DinoTerrain")
	TerrainBuilder.build(self, OuterIslands.castle_height, OuterIslands.castle_color, OuterIslands.CASTLE, 1000.0, 66, "CastleTerrain")
	TerrainBuilder.build(self, OuterIslands.town_height, OuterIslands.town_color, OuterIslands.TOWN, 1100.0, 70, "TownTerrain")
	_build_ocean()
	_place_landmarks()
	_place_stars()
	add_child(Clouds.new())


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
	env.fog_density = 0.00032
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
	bounds.radius = 4700.0
	bounds.edge_band = 300.0
	bounds.ceiling = 380.0
	bounds.ceiling_band = 40.0
	add_child(bounds)


func _build_ocean() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(14000, 14000)
	mesh.subdivide_width = 160
	mesh.subdivide_depth = 160
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ocean.gdshader")
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# Flat water collider for the safety system.
	BuildKit.collider(self, BuildKit.box_shape(Vector3(14000, 2, 14000)), Vector3(0, -1, 0))


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
	var palm := PalmIsland.new()
	palm.position = Vector3(IslandShape.PALM_ISLAND.x, 0, IslandShape.PALM_ISLAND.y)
	add_child(palm)
	var volcano := VolcanoIsland.new()
	var crater_floor := IslandShape.volcano_height(IslandShape.VOLCANO.x, IslandShape.VOLCANO.y)
	volcano.position = Vector3(IslandShape.VOLCANO.x, crater_floor, IslandShape.VOLCANO.y)
	add_child(volcano)
	var rainbow := RainbowArch.new()
	rainbow.position = Vector3(IslandShape.RAINBOW.x, 0, IslandShape.RAINBOW.y)
	add_child(rainbow)
	_place_outer(IceIsland.new(), OuterIslands.ICE)
	_place_outer(DinoIsland.new(), OuterIslands.DINO)
	_place_outer(CastleIsland.new(), OuterIslands.CASTLE)
	_place_outer(TownIsland.new(), OuterIslands.TOWN)
	add_child(PirateShip.new())
	var whale := Whale.new()
	whale.position = Vector3(-1080, 0, 250)
	add_child(whale)


func _place_outer(l: Landmark, at: Vector2) -> void:
	l.position = Vector3(at.x, 0, at.y)
	add_child(l)


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
	# Expansion: stepping stones over the sea, through the rainbow, to Palm Island.
	_trail(stars, 8, [Vector3(990, 28, 230), Vector3(1230, 50, 300), Vector3(1420, 30, 320)])
	# A ring round Palm Island.
	var ring: Array[Vector3] = []
	for i in 9:
		var a := TAU * i / 8.0
		var pt := IslandShape.PALM_ISLAND + Vector2(cos(a), sin(a)) * 170.0
		ring.append(Vector3(pt.x, IslandShape.palm_height(pt.x, pt.y) + 30.0, pt.y))
	_trail(stars, 8, ring)
	# Out across the sea to Volcano Island, then a spiral up the cone.
	_trail(stars, 6, [Vector3(-760, 40, -620), Vector3(-950, 40, -760), Vector3(-1150, 45, -880)])
	var spiral_v: Array[Vector3] = []
	for i in 7:
		var a := 2.2 + i * 1.0
		var r := 300.0 - i * 28.0
		var pt := IslandShape.VOLCANO + Vector2(cos(a), sin(a)) * r
		spiral_v.append(Vector3(pt.x, IslandShape.volcano_height(pt.x, pt.y) + 32.0, pt.y))
	_trail(stars, 7, spiral_v)
	_trail(stars, 1, [Vector3(IslandShape.VOLCANO.x, IslandShape.VOLCANO_HEIGHT + 60.0, IslandShape.VOLCANO.y)])
	# Outer islands: a trail of stepping stones out to each, and a ring round it.
	_stepping_stones(stars, Vector2(150, -980), OuterIslands.ICE, OuterIslands.ICE_RADIUS, OuterIslands.ice_height)
	_stepping_stones(stars, IslandShape.PALM_ISLAND + Vector2(150, 220), OuterIslands.DINO, OuterIslands.DINO_RADIUS, OuterIslands.dino_height)
	_stepping_stones(stars, Vector2(-300, 1000), OuterIslands.CASTLE, OuterIslands.CASTLE_RADIUS, OuterIslands.castle_height)
	_stepping_stones(stars, Vector2(-1000, 300), OuterIslands.TOWN, OuterIslands.TOWN_RADIUS, OuterIslands.town_height)
	# A few near the spawn to start with.
	_trail(stars, 3, [_air(Vector2(-200, 90), 28), _air(Vector2(-100, 100), 30), _air(Vector2(0, 90), 32)])


## Stars from `start` (a coast) across the sea to an island, then a ring round it.
func _stepping_stones(parent: Node3D, start: Vector2, centre: Vector2, radius: float, height_fn: Callable) -> void:
	var landing := centre + (start - centre).normalized() * (radius + 40.0)
	var gap := start.distance_to(landing)
	_trail(parent, maxi(int(gap / 230.0), 4), [Vector3(start.x, 35, start.y), Vector3(landing.x, 35, landing.y)])
	var ring: Array[Vector3] = []
	for i in 9:
		var a := TAU * i / 8.0
		var p := centre + Vector2(cos(a), sin(a)) * radius * 0.6
		ring.append(Vector3(p.x, maxf(height_fn.call(p.x, p.y), 0.0) + 34.0, p.y))
	_trail(parent, 8, ring)


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
