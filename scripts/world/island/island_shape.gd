class_name IslandShape
extends RefCounted
## The island's shape as pure maths: height and surface colour at any (x, z).
## Terrain, trees, landmarks and star placement all read from here, so they
## always agree. North is -Z. Units are metres; sea level is y = 0.

const SIZE := 2400.0          # terrain square edge length
const COAST_RADIUS := 880.0

# Landmark anchor points (x, z)
const RUNWAY := Vector2(0, 0)            # runway centre, runs east-west
const RUNWAY_HALF := Vector2(300, 28)    # half length, half width
const HANGAR := Vector2(110, -95)        # hangar + apron footprint centre
const HANGAR_HALF := Vector2(50, 50)
const FARM := Vector2(-430, 380)
const FARM_HEIGHT := 9.0
const FOREST := Vector2(-470, -260)
const RIDGE_A := Vector2(300, -260)      # turbine ridge start
const RIDGE_B := Vector2(640, -130)      # turbine ridge end
const LIGHTHOUSE := Vector2(700, 600)
const VALLEY := Vector2(-70, -640)       # gap between the two big peaks
const PEAKS := [                          # x, z, height, radius
	Vector4(-290, -660, 270, 260),
	Vector4(150, -690, 290, 250),
	Vector4(470, -560, 170, 190),
]

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
	var r := COAST_RADIUS + _coast_noise.get_noise_1d(a * 1.5) * 90.0
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
		h += pk.z * smoothstep(0.0, 1.0, t) ** 1.4
	# Turbine ridge (north-east)
	var rd := _dist_to_segment(p, RIDGE_A, RIDGE_B)
	h += 55.0 * smoothstep(110.0, 0.0, rd)
	# Rocky lighthouse point
	h += 22.0 * smoothstep(90.0, 0.0, p.distance_to(LIGHTHOUSE))
	# Flatten the runway and the farm fields
	var rw := minf(_box_dist(p - RUNWAY, RUNWAY_HALF + Vector2(40, 40)), _box_dist(p - HANGAR, HANGAR_HALF))
	h = lerpf(10.0, h, smoothstep(0.0, 110.0, rw))
	h = lerpf(FARM_HEIGHT, h, smoothstep(170.0, 260.0, p.distance_to(FARM)))

	return lerpf(-28.0, h, land)


## Is this spot on the flat runway strip itself?
static func on_runway(x: float, z: float) -> bool:
	return _box_dist(Vector2(x, z) - RUNWAY, RUNWAY_HALF) <= 0.0


static func color(x: float, z: float, h: float, slope: float) -> Color:
	if h < 6.5 and Vector2(x, z).length() > coast_radius(x, z) - 250.0:
		return Color("f2d98a")                       # sand (coast only)
	if h > 200.0 and slope < 0.75:
		return Color("f4f7ff")                       # snow
	if slope > 0.55 or h > 150.0:
		return Color("9a96a3")                       # rock
	if p_in_forest(x, z):
		return Color("4fa83e")                       # dark forest floor
	return Color("7ccf5a").lerp(Color("9edc5f"), clampf((h - 10.0) / 60.0, 0.0, 1.0))


static func p_in_forest(x: float, z: float) -> bool:
	_ensure_noise()
	return Vector2(x, z).distance_to(FOREST) + _noise.get_noise_2d(x * 2.0, z * 2.0) * 60.0 < 230.0


static func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _box_dist(p: Vector2, half: Vector2) -> float:
	var q := p.abs() - half
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)
