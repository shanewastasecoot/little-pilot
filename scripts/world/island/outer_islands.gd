class_name OuterIslands
extends RefCounted
## Shapes for the outer ring of islands (map expansion 2): height and colour
## functions, one pair per island. Same conventions as IslandShape.

const ICE := Vector2(300, -3400)
const ICE_RADIUS := 430.0
const DINO := Vector2(2900, 2300)
const DINO_RADIUS := 480.0
const CASTLE := Vector2(-700, 3400)
const CASTLE_RADIUS := 400.0
const CASTLE_HILL := 70.0          # plateau height the castle stands on
const CASTLE_PLATEAU := 85.0       # plateau radius
const TOWN := Vector2(-3400, 500)
const TOWN_RADIUS := 440.0
const TOWN_HEIGHT := 9.0           # flat ground the town sits on

static var _noise: FastNoiseLite


static func _n() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 31
		_noise.frequency = 0.006
		_noise.fractal_octaves = 3
	return _noise


## 1 on land, 0 at sea, with a wobbly coastline. Shared by every island.
static func _land(p: Vector2, centre: Vector2, radius: float, seed_offset: float) -> float:
	var d := p.distance_to(centre)
	var a := atan2(p.y - centre.y, p.x - centre.x)
	var coast := radius + _n().get_noise_1d(a * 60.0 + seed_offset) * radius * 0.12
	return smoothstep(coast + 60.0, coast - 90.0, d)


# --- Ice Island: snowy rolling hills and one icy peak ------------------------

static func ice_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := p.distance_to(ICE)
	var h := 10.0 + 40.0 * smoothstep(ICE_RADIUS, 0.0, d) + _n().get_noise_2d(x, z) * 12.0
	h += 85.0 * pow(maxf(0.0, 1.0 - p.distance_to(ICE + Vector2(-90, -60)) / 170.0), 1.6)
	return lerpf(-25.0, h, _land(p, ICE, ICE_RADIUS, 100.0))


static func ice_color(_x: float, _z: float, h: float, slope: float) -> Color:
	if h < 5.0:
		return Color("dfe9f2")                       # icy shore
	if slope > 0.55:
		return Color("b9d4ea")                       # blue ice cliffs
	return Color("f7fbff").lerp(Color("e6f1fb"), clampf(slope * 2.0, 0.0, 1.0))


# --- Dino Island: lush jungle hills ------------------------------------------

static func dino_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := p.distance_to(DINO)
	var h := 12.0 + 30.0 * smoothstep(DINO_RADIUS, 0.0, d) + _n().get_noise_2d(x * 1.3, z * 1.3) * 22.0
	h += 60.0 * pow(maxf(0.0, 1.0 - p.distance_to(DINO + Vector2(150, -120)) / 150.0), 1.3)
	return lerpf(-25.0, h, _land(p, DINO, DINO_RADIUS, 200.0))


static func dino_color(_x: float, _z: float, h: float, slope: float) -> Color:
	if h < 6.5:
		return Color("e8cf86")
	if slope > 0.6:
		return Color("8a6d4e")                       # earthy cliffs
	return Color("3f9e3a").lerp(Color("5cbf45"), clampf((h - 10.0) / 50.0, 0.0, 1.0))


# --- Castle Island: a flat-topped hill for the castle ------------------------

static func castle_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := p.distance_to(CASTLE)
	var h := 10.0 + _n().get_noise_2d(x, z) * 8.0
	h = lerpf(CASTLE_HILL, h, smoothstep(CASTLE_PLATEAU, CASTLE_PLATEAU + 160.0, d))
	return lerpf(-25.0, h, _land(p, CASTLE, CASTLE_RADIUS, 300.0))


static func castle_color(_x: float, _z: float, h: float, slope: float) -> Color:
	if h < 6.5:
		return Color("f2d98a")
	if slope > 0.5:
		return Color("9a96a3")
	return Color("86d65a").lerp(Color("a3e06a"), clampf(h / CASTLE_HILL, 0.0, 1.0))


# --- Town Island: flat and grassy ---------------------------------------------

static func town_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := p.distance_to(TOWN)
	var h := lerpf(TOWN_HEIGHT, 14.0 + _n().get_noise_2d(x, z) * 10.0, smoothstep(220.0, 380.0, d))
	return lerpf(-25.0, h, _land(p, TOWN, TOWN_RADIUS, 400.0))


static func town_color(_x: float, _z: float, h: float, _slope: float) -> Color:
	if h < 6.5:
		return Color("f2d98a")
	return Color("7ccf5a")
