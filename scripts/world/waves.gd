class_name Waves
extends RefCounted
## The sea's wave field, shared by the ocean shader and gameplay: boats ride
## it, the whale surfaces on it, the plane splashes on it. Keep WAVES in sync
## with the `gerstner` calls in shaders/ocean.gdshader (Ocean pushes them as
## uniforms, so this table is the single source of truth).

## direction x, direction z, steepness, wavelength (m), fade start, fade end
## (distance from the camera where the wave flattens out; 0 = never).
const WAVES := [
	[1.0, 0.35, 0.05, 170.0, 0.0, 0.0],
	[-0.4, 1.0, 0.04, 95.0, 0.0, 0.0],
	[0.7, -0.8, 0.035, 61.0, 0.0, 0.0],
	[0.2, 1.0, 0.11, 33.0, 300.0, 800.0],
	[1.0, -0.3, 0.09, 19.0, 120.0, 300.0],
	[-0.8, -0.5, 0.07, 11.0, 60.0, 150.0],
]
const SPEED := 0.6  # matches the shader's phase speed scale

## Wave clock (seconds). Advanced by Ocean; frozen while paused.
static var time := 0.0
## Camera position, for the same distance fade the shader uses.
static var camera := Vector3.ZERO
static var swell := 1.0


## Gerstner displacement of the sea surface point that rests at (x, z).
static func displacement(x: float, z: float) -> Vector3:
	var out := Vector3.ZERO
	var dist := Vector2(x - camera.x, z - camera.z).length()
	for w in WAVES:
		var d := Vector2(w[0], w[1]).normalized()
		var k: float = TAU / w[3]
		var c := sqrt(9.8 / k)
		var f := k * (d.dot(Vector2(x, z)) - c * time * SPEED)
		var q: float = w[2] * swell * _fade(dist, w[4], w[5])
		var a := q / k
		out += Vector3(d.x * a * cos(f), a * sin(f), d.y * a * cos(f))
	return out


## Sea surface height at world (x, z). Gerstner waves also shift points
## sideways, so one correction step finds the point that lands here.
static func height(x: float, z: float) -> float:
	var d := displacement(x, z)
	return displacement(x - d.x, z - d.z).y


## Float `hull` on the waves: its height and tilt follow the sea under it.
## `hull` is a child of a node at sea level; `length`/`beam` are the spans
## (m) sampled fore-aft (parent's Z) and sideways (parent's X).
static func ride(hull: Node3D, length: float, beam: float, offset: float, delta: float, sink := 1.0) -> void:
	var t: Transform3D = (hull.get_parent() as Node3D).global_transform
	var fore := t * Vector3(0, 0, -length * 0.5)
	var aft := t * Vector3(0, 0, length * 0.5)
	var port := t * Vector3(-beam * 0.5, 0, 0)
	var star := t * Vector3(beam * 0.5, 0, 0)
	var hf := height(fore.x, fore.z)
	var ha := height(aft.x, aft.z)
	var hp := height(port.x, port.z)
	var hs := height(star.x, star.z)
	var k := 1.0 - exp(-4.0 * delta)  # a little lag, like real weight
	hull.position.y = lerpf(hull.position.y, offset + (hf + ha + hp + hs) * 0.25 * sink, k)
	hull.rotation.x = lerp_angle(hull.rotation.x, atan2(hf - ha, length), k)
	hull.rotation.z = lerp_angle(hull.rotation.z, atan2(hs - hp, beam), k)


static func _fade(dist: float, start: float, end: float) -> float:
	if end <= 0.0:
		return 1.0
	return 1.0 - smoothstep(start, end, dist)


## Packs WAVES for the shader: two vec4 arrays.
static func shader_dirs() -> PackedVector4Array:
	var out := PackedVector4Array()
	for w in WAVES:
		out.append(Vector4(w[0], w[1], w[2], w[3]))
	return out


static func shader_fades() -> PackedVector2Array:
	var out := PackedVector2Array()
	for w in WAVES:
		out.append(Vector2(w[4], w[5]))
	return out
