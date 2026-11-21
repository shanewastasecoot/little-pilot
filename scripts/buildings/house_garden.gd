class_name HouseGarden
extends Node3D
## What you see round the house while you're inside (the island itself
## isn't loaded indoors): a lawn with a garden path to the front door, a
## hedge with flower beds, trees, the beach and the sea out to the horizon,
## and clouds. All plain, unshadowed meshes, built once with the interior.
## Origin = the interior's origin (floor level 0).

const LAWN := "8fd16a"
const LAWN_DARK := "7ccf5a"
const HEDGE := "4f9e3c"
const PATH := "e9dcc3"
const SAND := "f2e2b1"
const SEA := "3f9be0"
const FLOWERS := ["ff7eb9", "ffd166", "ffffff", "b388ff", "ff8c42"]
const TREE_MODELS := {"res://assets/environment/tree_round.glb": 2.4, "res://assets/environment/pine.glb": 1.5}
const CLOUD_MODELS := ["res://assets/environment/cloud_a.glb", "res://assets/environment/cloud_b.glb"]

## The house's footprint on the plan and where the front door is.
var footprint := Rect2()
var front_door := Vector2.ZERO


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	var c := footprint.get_center()
	# The sea to the horizon, a sandy beach, then the lawn.
	_disc(Vector3(c.x, -6.0, c.y), 2400.0, 0.5, SEA, 48)
	_disc(Vector3(c.x, -2.2, c.y), 330.0, 2.0, SAND, 48)
	_disc(Vector3(c.x, -1.2, c.y), 300.0, 1.0, LAWN, 48)
	# Lighter patches of grass so the lawn isn't one flat colour.
	for i in 14:
		var a := rng.randf() * TAU
		var r := rng.randf_range(footprint.size.length() * 0.7, 240.0)
		_disc(Vector3(c.x + cos(a) * r, -1.15, c.y + sin(a) * r), rng.randf_range(14.0, 34.0), 1.0, LAWN_DARK if i % 2 else "b3df62", 20)
	# The garden path from the front door, straight out (+Z) and a little way.
	var path_len := 60.0
	_box(Vector3(front_door.x, -0.68, front_door.y + path_len * 0.5), Vector3(8.0, 1.0, path_len), PATH)
	for k in 8:
		var z := front_door.y + 6.0 + k * 7.0
		for side in [-1.0, 1.0]:
			_ball(Vector3(front_door.x + side * 6.0, 0.2, z), 0.9, FLOWERS[(k + int(side > 0)) % FLOWERS.size()])
	# A hedge round the garden with a gap for the path.
	var g := footprint.grow(22.0)
	var hedge_h := 4.0
	for e in [[Vector2(g.position.x, g.position.y), Vector2(g.end.x, g.position.y)],
			[Vector2(g.position.x, g.position.y), Vector2(g.position.x, g.end.y)],
			[Vector2(g.end.x, g.position.y), Vector2(g.end.x, g.end.y)]]:
		_hedge(e[0], e[1], hedge_h)
	_hedge(Vector2(g.position.x, g.end.y), Vector2(front_door.x - 7.0, g.end.y), hedge_h)
	_hedge(Vector2(front_door.x + 7.0, g.end.y), Vector2(g.end.x, g.end.y), hedge_h)
	# Flower beds along the house walls.
	for k in 26:
		var t := float(k) / 26.0
		var side := k % 4
		var p: Vector2
		match side:
			0: p = Vector2(lerpf(footprint.position.x, footprint.end.x, t), footprint.position.y - 3.0)
			1: p = Vector2(footprint.end.x + 3.0, lerpf(footprint.position.y, footprint.end.y, t))
			2: p = Vector2(lerpf(footprint.position.x, footprint.end.x, t), footprint.end.y + 3.0)
			_: p = Vector2(footprint.position.x - 3.0, lerpf(footprint.position.y, footprint.end.y, t))
		if p.distance_to(front_door) < 9.0:
			continue
		_ball(Vector3(p.x, 0.4, p.y), 1.3, "5fbf4b")
		_ball(Vector3(p.x, 1.3, p.y), 0.7, FLOWERS[k % FLOWERS.size()])
	# Trees: a ring outside the hedge, a few in the garden corners.
	var models := TREE_MODELS.keys()
	var spots: Array[Vector2] = []
	for k in 30:
		var a := TAU * k / 30.0 + rng.randf_range(-0.08, 0.08)
		var r := rng.randf_range(g.size.length() * 0.6, g.size.length() * 0.6 + 70.0)
		var p := c + Vector2(cos(a), sin(a)) * r
		if absf(p.x - front_door.x) < 14.0 and p.y > front_door.y:
			continue  # keep the path's view clear
		spots.append(p)
	for corner in [g.position + Vector2(8, 8), Vector2(g.end.x - 8, g.position.y + 8)]:
		spots.append(corner)
	for p in spots:
		var path: String = models[rng.randi() % models.size()]
		var tree: Node3D = (load(path) as PackedScene).instantiate()
		tree.scale = Vector3.ONE * float(TREE_MODELS[path]) * rng.randf_range(0.9, 1.3)
		tree.position = Vector3(p.x, -1.0, p.y)
		tree.rotation.y = rng.randf() * TAU
		add_child(tree)
	# Clouds drifting high over the garden.
	for k in 7:
		var cloud: Node3D = (load(CLOUD_MODELS[k % 2]) as PackedScene).instantiate()
		var a := rng.randf() * TAU
		var r := rng.randf_range(80.0, 320.0)
		cloud.position = Vector3(c.x + cos(a) * r, rng.randf_range(90.0, 150.0), c.y + sin(a) * r)
		cloud.scale = Vector3.ONE * rng.randf_range(8.0, 14.0)
		add_child(cloud)
	for gi: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _disc(at: Vector3, radius: float, height: float, hex: String, segs: int) -> void:
	BuildKit.add(self, BuildKit.cyl(radius, height, -1.0, segs), hex, at).material_override = BuildingGenerator._mat(hex)


func _box(at: Vector3, size: Vector3, hex: String) -> void:
	BuildKit.add(self, BuildKit.box(size), hex, at).material_override = BuildingGenerator._mat(hex)


func _ball(at: Vector3, radius: float, hex: String) -> void:
	BuildKit.add(self, BuildKit.sphere(radius, 8), hex, at).material_override = BuildingGenerator._mat(hex)


## A clipped hedge from a to b (on the plan), rounded on top.
func _hedge(a: Vector2, b: Vector2, h: float) -> void:
	var length := a.distance_to(b)
	if length < 1.0:
		return
	var mid := (a + b) * 0.5
	var along_x := absf(b.y - a.y) < 0.01
	var size := Vector3(length, h, 3.0) if along_x else Vector3(3.0, h, length)
	_box(Vector3(mid.x, h * 0.5 - 1.0, mid.y), size, HEDGE)
	var bumps := int(length / 4.0)
	for k in bumps:
		var p := a.lerp(b, (k + 0.5) / bumps)
		_ball(Vector3(p.x, h - 1.0, p.y), 1.9, HEDGE)
