class_name IslandMap
extends GameMap
## The real island: terrain, ocean, sky, landmarks and star trails.
## Everything is generated from IslandShape at load time.

const STAR_CLEARANCE := 24.0  # metres above ground for "low" stars


func _init() -> void:
	# West end of the runway, facing east down it (in the air, for tests and
	# respawns; the game itself starts parked on the runway).
	spawn_position = Vector3(-260, 32, 0)
	spawn_heading_deg = -90.0


## Where the plane waits on the runway before take-off (runway surface).
func runway_start() -> Vector3:
	return Vector3(-IslandShape.RUNWAY_HALF.x + 30.0, IslandShape.height(0, 0) + 0.4, 0)


func _ready() -> void:
	_build_environment()
	TerrainBuilder.build(self, IslandShape.height, IslandShape.color, IslandShape.TERRAIN_CENTRE, IslandShape.SIZE, 308)
	TerrainBuilder.build(self, IslandShape.palm_height, IslandShape.palm_color, IslandShape.PALM_ISLAND, 760.0, 64, "PalmTerrain")
	TerrainBuilder.build(self, IslandShape.volcano_height, IslandShape.volcano_color, IslandShape.VOLCANO, 1000.0, 84, "VolcanoTerrain")
	TerrainBuilder.build(self, OuterIslands.ice_height, OuterIslands.ice_color, OuterIslands.ICE, 1100.0, 70, "IceTerrain")
	TerrainBuilder.build(self, OuterIslands.dino_height, OuterIslands.dino_color, OuterIslands.DINO, 1200.0, 76, "DinoTerrain")
	TerrainBuilder.build(self, OuterIslands.castle_height, OuterIslands.castle_color, OuterIslands.CASTLE, 1000.0, 66, "CastleTerrain")
	TerrainBuilder.build(self, OuterIslands.town_height, OuterIslands.town_color, OuterIslands.TOWN, 1100.0, 70, "TownTerrain")
	_build_ocean()
	_place_landmarks()
	_place_stars()
	Islets.build_all(self, get_node("Stars"))
	for pad in [LandingPads.DINO, LandingPads.VOLCANO]:
		add_child(LandingPads.windsock(pad))
	_place_details()
	add_child(Clouds.new())


## The sky, fog, glow and tonemap (resources/world_environment.tres: tune it
## live in the editor). The sun stays here, below.
const ENVIRONMENT := "res://resources/world_environment.tres"


func _build_environment() -> void:
	var env: Environment = load(ENVIRONMENT)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46, -30, 0)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.92, 0.78)  # golden afternoon sun (G2, the parent's pick)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	# Two cascades: crisp shadows near the plane, buildings and trees
	# still grounded further out.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_split_1 = 0.25
	sun.directional_shadow_max_distance = 420.0
	sun.directional_shadow_blend_splits = true
	add_child(sun)

	var bounds := WorldBounds.new()
	bounds.radius = 4700.0
	bounds.edge_band = 300.0
	bounds.ceiling = 380.0
	bounds.ceiling_band = 40.0
	add_child(bounds)


func _build_ocean() -> void:
	add_child(Ocean.new())


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
	_add_landmark(CityDistrict.new(), IslandShape.CITY)
	var her_house := HerHouse.new()
	her_house.name = "HerHouse"
	her_house.rotation.y = PI  # front door towards the runway (north); before it builds
	_add_landmark(her_house, IslandShape.HOUSE)
	# The hat shop: beside the airport post office, facing the runway too.
	var hat_shop := HatShop.new()
	hat_shop.name = "HatShop"
	hat_shop.position = Vector3(IslandShape.HAT_SHOP.x, _ground(IslandShape.HAT_SHOP), IslandShape.HAT_SHOP.y)
	add_child(hat_shop)
	# Where honks echo (EchoZone): the mountains and Dragon Peak, the
	# dragon's cave, the city.
	add_child(EchoZone.make(GameSettings.BUS_HONK_ECHO, Vector3(75, 200, -880), Vector3(1550, 700, 760), 1))
	add_child(EchoZone.make(GameSettings.BUS_HONK_ECHO, Vector3(IslandShape.DRAGON_PEAK.x, 150, IslandShape.DRAGON_PEAK.y), Vector3(360, 0, 0), 1))
	add_child(EchoZone.make(GameSettings.BUS_HONK_CAVE, Vector3(IslandShape.LAIR.x, IslandShape.LAIR_FLOOR + 20.0, IslandShape.LAIR.y), Vector3(IslandShape.LAIR_RADIUS + 15.0, 0, 0), 3))
	add_child(EchoZone.make(GameSettings.BUS_HONK_CITY, Vector3(IslandShape.CITY.x, 120, IslandShape.CITY.y), Vector3(960, 320, 960), 2))
	# Quiet sounds of places (AmbientZone).
	add_child(AmbientZone.make("amb_birds", _air(IslandShape.FARM, 10.0), 220.0, -14.0))
	add_child(AmbientZone.make("amb_city", Vector3(IslandShape.CITY.x, 20.0, IslandShape.CITY.y), 520.0, -16.0))
	add_child(AmbientZone.make("amb_wind", _air(IslandShape.FOREST, 25.0), 420.0, -15.0))
	add_child(AmbientZone.make("amb_rumble", Vector3(IslandShape.VOLCANO.x, IslandShape.VOLCANO_HEIGHT * 0.6, IslandShape.VOLCANO.y), 650.0, -10.0))
	add_child(AmbientZone.make("amb_cave", Vector3(IslandShape.LAIR.x, IslandShape.LAIR_FLOOR + 8.0, IslandShape.LAIR.y), 140.0, -9.0))
	for shore in [Vector2(-560, 900), Vector2(820, 150), IslandShape.PALM_ISLAND + Vector2(-260, 0)]:
		add_child(AmbientZone.make("amb_waves", Vector3(shore.x, 3.0, shore.y), 260.0, -15.0))
	var rainbow := RainbowArch.new()
	rainbow.position = Vector3(IslandShape.RAINBOW.x, 0, IslandShape.RAINBOW.y)
	add_child(rainbow)
	_place_outer(IceIsland.new(), OuterIslands.ICE)
	_place_outer(DinoIsland.new(), OuterIslands.DINO)
	_place_outer(CastleIsland.new(), OuterIslands.CASTLE)
	_place_outer(TownIsland.new(), OuterIslands.TOWN)
	add_child(PirateShip.new())
	var lair := DragonLair.new()
	lair.name = "DragonLair"
	lair.position = Vector3(IslandShape.LAIR.x, IslandShape.LAIR_FLOOR, IslandShape.LAIR.y)
	var face := IslandShape.LAIR_CLEARING - IslandShape.LAIR
	lair.rotation.y = atan2(face.x, face.y)  # mouth (+Z) toward the clearing
	add_child(lair)
	var dragon := Dragon.new()
	dragon.name = "Dragon"
	dragon.lair = lair
	dragon.add_to_group("dragon")
	add_child(dragon)
	var whale := Whale.new()
	whale.position = Vector3(-1640, 0, 300)
	add_child(whale)


## Small details that make the land less empty: boulders on the mountain
## slopes and bushes dotted over the meadows (cheap MultiMeshes with a
## short view distance).
func _place_details() -> void:
	var env := "res://assets/environment/"
	var h := IslandShape.height
	var root := Node3D.new()
	root.name = "Details"
	add_child(root)
	# Scatter expects its parent at the scatter centre.
	var mountains := Node3D.new()
	mountains.position = Vector3(0, 0, -800)
	root.add_child(mountains)
	IslandDecor.scatter(mountains, env + "rocks.glb", 90, Vector2(0, -800), 0.0, 520.0, h, 35.0, 75.0, 45.0, 210.0, 71, 1300.0)
	IslandDecor.scatter(mountains, env + "rock.glb", 70, Vector2(0, -800), 0.0, 560.0, h, 30.0, 65.0, 40.0, 190.0, 72, 1300.0)
	IslandDecor.scatter(root, env + "tree_round.glb", 260, Vector2.ZERO, 150.0, 1050.0, h, 0.9, 1.4, 9.0, 70.0, 73, 900.0, _open_meadow)
	# Bushes are too small to need shadows from the air (saves shadow passes).
	(root.get_child(root.get_child_count() - 1) as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _open_meadow(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	if IslandShape.on_runway(x, z) or absf(z) < 120.0 and absf(x) < IslandShape.RUNWAY_HALF.x + 80.0:
		return false
	if IslandShape.in_city_area(x, z, 40.0) or p.distance_to(IslandShape.FARM) < 200.0:
		return false
	if p.distance_to(IslandShape.HANGAR) < 90.0 or IslandShape.p_in_forest(x, z) or IslandShape.in_house_yard(x, z, 20.0):
		return false
	return true


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
	_trail(stars, 6, [_air(Vector2(-650, 1500), 16), _air(Vector2(-200, 1540), 16), _air(Vector2(250, 1510), 16)])
	# Expansion: stepping stones over the sea, through the rainbow, to Palm Island.
	_trail(stars, 8, [Vector3(1320, 28, 270), Vector3(1560, 50, 340), Vector3(1780, 30, 365)])
	# A ring round Palm Island.
	var ring: Array[Vector3] = []
	for i in 9:
		var a := TAU * i / 8.0
		var pt := IslandShape.PALM_ISLAND + Vector2(cos(a), sin(a)) * 170.0
		ring.append(Vector3(pt.x, IslandShape.palm_height(pt.x, pt.y) + 30.0, pt.y))
	_trail(stars, 8, ring)
	# Out across the sea to Volcano Island, then a spiral up the cone.
	_trail(stars, 6, [_air(Vector2(-1000, -780), 30), _air(Vector2(-1220, -920), 30), _air(Vector2(-1420, -1040), 35)])
	var spiral_v: Array[Vector3] = []
	for i in 7:
		var a := 2.2 + i * 1.0
		var r := 300.0 - i * 28.0
		var pt := IslandShape.VOLCANO + Vector2(cos(a), sin(a)) * r
		spiral_v.append(Vector3(pt.x, IslandShape.volcano_height(pt.x, pt.y) + 32.0, pt.y))
	_trail(stars, 7, spiral_v)
	_trail(stars, 1, [Vector3(IslandShape.VOLCANO.x, IslandShape.VOLCANO_HEIGHT + 60.0, IslandShape.VOLCANO.y)])
	# Outer islands: a trail of stepping stones out to each, and a ring round it.
	_stepping_stones(stars, Vector2(320, -1840), OuterIslands.ICE, OuterIslands.ICE_RADIUS, OuterIslands.ice_height)
	_stepping_stones(stars, IslandShape.PALM_ISLAND + Vector2(150, 220), OuterIslands.DINO, OuterIslands.DINO_RADIUS, OuterIslands.dino_height)
	_stepping_stones(stars, Vector2(-430, 1500), OuterIslands.CASTLE, OuterIslands.CASTLE_RADIUS, OuterIslands.castle_height)
	_stepping_stones(stars, Vector2(-1500, 450), OuterIslands.TOWN, OuterIslands.TOWN_RADIUS, OuterIslands.town_height)
	# City: a ring of stars round the new district.
	var city_ring: Array[Vector3] = []
	for i in 9:
		var a := TAU * i / 8.0
		var p := IslandShape.CITY + Vector2(cos(a), sin(a)) * 370.0
		city_ring.append(Vector3(p.x, maxf(_ground(p), 0.0) + 55.0, p.y))
	_trail(stars, 8, city_ring)
	# "Main Street": a line of stars weaving between the towers.
	var c := IslandShape.CITY
	_trail(stars, 8, [Vector3(c.x + 40, 85, c.y - 270), Vector3(c.x + 40, 75, c.y), Vector3(c.x + 40, 85, c.y + 270)])
	# A few near the spawn to start with.
	_trail(stars, 3, [_air(Vector2(-200, 90), 28), _air(Vector2(-100, 100), 30), _air(Vector2(0, 90), 32)])


## Stars from `start` (a coast) across the sea to an island, then a ring round it.
func _stepping_stones(parent: Node3D, start: Vector2, centre: Vector2, radius: float, height_fn: Callable) -> void:
	var landing := centre + (start - centre).normalized() * (radius + 40.0)
	var gap := start.distance_to(landing)
	_trail(parent, maxi(int(gap / 230.0), 4), [_air(start, 35), Vector3(landing.x, 35, landing.y)])
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
