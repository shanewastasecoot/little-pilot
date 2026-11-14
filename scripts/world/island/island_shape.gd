class_name IslandShape
extends RefCounted
## The island's shape as pure maths: height and surface colour at any (x, z).
## Terrain, trees, landmarks and star placement all read from here, so they
## always agree. North is -Z. Units are metres; sea level is y = 0.

const SIZE := 3200.0          # terrain square edge length
const COAST_RADIUS := 1180.0

# Landmark anchor points (x, z)
const RUNWAY := Vector2(0, 0)            # runway centre, runs east-west
const RUNWAY_HALF := Vector2(300, 28)    # half length, half width
const HANGAR := Vector2(110, -95)        # hangar + apron footprint centre
## The new city (south-east of the runway).
const CITY := Vector2(380, 600)
const CITY_RADIUS := 250.0
const CITY_HEIGHT := 10.0
const HANGAR_HALF := Vector2(50, 50)
const FARM := Vector2(-560, 494)
const FARM_HEIGHT := 9.0
const FOREST := Vector2(-610, -340)
const RIDGE_A := Vector2(390, -340)      # turbine ridge start
const RIDGE_B := Vector2(830, -170)      # turbine ridge end
const LIGHTHOUSE := Vector2(910, 780)
const VALLEY := Vector2(-90, -830)       # gap between the two big peaks
const PEAKS := [                          # x, z, height, radius
	Vector4(-377, -858, 275, 300),
	Vector4(195, -897, 295, 288),
	Vector4(611, -728, 180, 220),
]

# Extra islands (map expansion)
const PALM_ISLAND := Vector2(2050, 380)
const PALM_RADIUS := 270.0
const VOLCANO := Vector2(-1780, -1200)
const VOLCANO_RADIUS := 380.0
const VOLCANO_HEIGHT := 235.0
const CRATER_RADIUS := 48.0
## Giant rainbow arch over the sea, on the way to Palm Island.
const RAINBOW := Vector2(1560, 340)

static var _noise: FastNoiseLite
static var _coast_noise: FastNoiseLite


static func _ensure_noise() -> void:
	if _noise:
		return
	_noise = FastNoiseLite.new()
	_noise.seed = 11
	_noise.frequency = 0.004
	_noise.fractal_octaves = 3
	_coast_noise = FastNoiseLite.new()
	_coast_noise.seed = 5
	_coast_noise.frequency = 0.9


## Distance from the centre where the coast is, in the direction of (x, z).
static func coast_radius(x: float, z: float) -> float:
	_ensure_noise()
	var a := atan2(z, x)
	var r := COAST_RADIUS + _coast_noise.get_noise_1d(a * 1.5) * 110.0
	# Lighthouse peninsula to the south-east.
	var la := atan2(LIGHTHOUSE.y, LIGHTHOUSE.x)
	r += 160.0 * maxf(0.0, cos((a - la) * 6.0)) ** 2 * float(absf(wrapf(a - la, -PI, PI)) < PI / 6.0)
	return r


static func height(x: float, z: float) -> float:
	_ensure_noise()
	var p := Vector2(x, z)
	var d := p.length()
	var coast := coast_radius(x, z)
	var land := smoothstep(coast + 70.0, coast - 110.0, d)  # 1 inland, 0 at sea

	var h := 18.0 + _noise.get_noise_2d(x, z) * 16.0
	# Mountains (north)
	for pk: Vector4 in PEAKS:
		var t := 1.0 - clampf(p.distance_to(Vector2(pk.x, pk.y)) / pk.w, 0.0, 1.0)
		# Rounded shoulders, gentle summit, plus rocky detail on the slopes.
		var profile := smoothstep(0.0, 1.0, t)
		h += pk.z * profile * profile * (3.0 - 2.0 * profile) * 0.92 + pk.z * 0.08 * profile
		h += t * (1.0 - t) * 4.0 * _noise.get_noise_2d(x * 3.0, z * 3.0) * 18.0
	# Turbine ridge (north-east)
	var rd := _dist_to_segment(p, RIDGE_A, RIDGE_B)
	h += 55.0 * smoothstep(110.0, 0.0, rd)
	# Rocky lighthouse point
	h += 22.0 * smoothstep(90.0, 0.0, p.distance_to(LIGHTHOUSE))
	# Flatten the runway and the farm fields
	var rw := minf(_box_dist(p - RUNWAY, RUNWAY_HALF + Vector2(40, 40)), _box_dist(p - HANGAR, HANGAR_HALF))
	h = lerpf(10.0, h, smoothstep(0.0, 110.0, rw))
	h = lerpf(FARM_HEIGHT, h, smoothstep(170.0, 260.0, p.distance_to(FARM)))
	h = lerpf(CITY_HEIGHT, h, smoothstep(CITY_RADIUS, CITY_RADIUS + 110.0, p.distance_to(CITY)))

	return lerpf(-28.0, h, land)


## Is this spot on the flat runway strip itself?
static func on_runway(x: float, z: float) -> bool:
	return _box_dist(Vector2(x, z) - RUNWAY, RUNWAY_HALF) <= 0.0


static func color(x: float, z: float, h: float, slope: float) -> Color:
	_ensure_noise()
	var wobble := _noise.get_noise_2d(x * 4.0, z * 4.0)  # breaks up hard lines
	if h < 6.5 + wobble * 1.5 and Vector2(x, z).length() > coast_radius(x, z) - 250.0:
		return Color("f2d98a")                       # sand (coast only)
	var grass := Color("7ccf5a").lerp(Color("9edc5f"), clampf((h - 10.0) / 60.0 + wobble * 0.3, 0.0, 1.0))
	if p_in_forest(x, z):
		grass = Color("4fa83e")
	var rock := Color("9a96a3").lerp(Color("8a8694"), clampf(wobble + 0.5, 0.0, 1.0))
	var rockiness := smoothstep(0.42, 0.62, slope + wobble * 0.08) + smoothstep(130.0, 175.0, h + wobble * 20.0)
	var col := grass.lerp(rock, clampf(rockiness, 0.0, 1.0))
	var snow := smoothstep(195.0, 215.0, h + wobble * 25.0) * (1.0 - smoothstep(0.7, 0.85, slope))
	return col.lerp(Color("f4f7ff"), snow)


static func p_in_forest(x: float, z: float) -> bool:
	_ensure_noise()
	return Vector2(x, z).distance_to(FOREST) + _noise.get_noise_2d(x * 2.0, z * 2.0) * 70.0 < 300.0


static func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _box_dist(p: Vector2, half: Vector2) -> float:
	var q := p.abs() - half
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)



# --- Palm Island: low, sandy, grassy middle ----------------------------------

static func palm_height(x: float, z: float) -> float:
	_ensure_noise()
	var p := Vector2(x, z) - PALM_ISLAND
	var d := p.length()
	var coast := PALM_RADIUS + _coast_noise.get_noise_1d(atan2(p.y, p.x) * 2.0 + 7.0) * 35.0
	var land := smoothstep(coast + 60.0, coast - 80.0, d)
	var h := 5.0 + 16.0 * smoothstep(PALM_RADIUS, 0.0, d) + _noise.get_noise_2d(x * 2.0, z * 2.0) * 3.0
	return lerpf(-28.0, h, land)


static func palm_color(_x: float, _z: float, h: float, _slope: float) -> Color:
	if h < 11.0:
		return Color("f6df8f")
	return Color("8fdc5c").lerp(Color("a6e36a"), clampf((h - 11.0) / 10.0, 0.0, 1.0))


# --- Volcano Island: tall cone with a crater ---------------------------------

static func volcano_height(x: float, z: float) -> float:
	_ensure_noise()
	var p := Vector2(x, z) - VOLCANO
	var d := p.length()
	var coast := VOLCANO_RADIUS + _coast_noise.get_noise_1d(atan2(p.y, p.x) * 2.0 + 21.0) * 45.0
	var land := smoothstep(coast + 70.0, coast - 90.0, d)
	var t := 1.0 - clampf(d / (VOLCANO_RADIUS * 0.9), 0.0, 1.0)
	var h := 8.0 + VOLCANO_HEIGHT * pow(t, 1.35) + _noise.get_noise_2d(x * 1.5, z * 1.5) * 6.0
	h -= 55.0 * smoothstep(CRATER_RADIUS * 1.6, CRATER_RADIUS * 0.5, d)  # crater bowl
	return lerpf(-28.0, h, land)


static func volcano_color(x: float, z: float, h: float, slope: float) -> Color:
	var d := Vector2(x, z).distance_to(VOLCANO)
	if h < 6.5:
		return Color("d9c58a")                       # dark sand
	if d < CRATER_RADIUS * 1.3:
		return Color("5a2e2a")                       # scorched crater
	if h > 150.0:
		return Color("4b4552")                       # dark rock
	if h > 60.0 or slope > 0.6:
		return Color("6e6773")                       # rock
	return Color("5fb84a")                           # lush lower slopes
