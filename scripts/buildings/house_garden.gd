class_name HouseGarden
extends Node3D
## Her house's garden, the same in two places so they match:
##   outdoor  round the real house on the island: a mown lawn, a white
##            picket fence round a big yard (a gate where the front path
##            goes out), flower beds along the walls, and a backyard to play
##            in: a swing set, a trampoline (bouncy) and a sandpit, trees in
##            the corners. Solid where it should be (fence, swings).
##   indoor   the view out of the windows while inside (the island isn't
##            loaded then): the same yard, plus a lawn, beach and the sea out
##            to the horizon, trees round it and clouds. Nothing solid.
## Origin = the floor plan's origin at ground level; the front door is on
## the plan's +Z side. Unshadowed, cheap meshes; fence posts in a MultiMesh.

const LAWN := "8fd16a"
const LAWN_DARK := "7ccf5a"
const PATH := "e9dcc3"
const SAND := "f2e2b1"
const SEA := "3f9be0"
const FENCE := "ffffff"
const FLOWERS := ["ff7eb9", "ffd166", "ffffff", "b388ff", "ff8c42"]
const TREE_MODELS := {"res://assets/environment/tree_round.glb": 2.4, "res://assets/environment/pine.glb": 1.5}
const CLOUD_MODELS := ["res://assets/environment/cloud_a.glb", "res://assets/environment/cloud_b.glb"]
## The yard round the house: this far out at the sides, front and back.
const YARD_SIDE := 25.0
const YARD_FRONT := 35.0
const YARD_BACK := 70.0
const FENCE_H := 3.2
const GATE := 14.0

var outdoor := false
## Outdoors: the ground's height at a point on the plan (the yard itself is
## flat at 0; beyond it the island slopes). Indoors everything's flat.
var ground_at: Callable = func(_x: float, _z: float) -> float: return 0.0
## The house's footprint on the plan and where the front door is.
var footprint := Rect2()
var front_door := Vector2.ZERO
var _mats := {}


## The fenced yard on the plan.
static func yard(fp: Rect2) -> Rect2:
	return Rect2(fp.position.x - YARD_SIDE, fp.position.y - YARD_BACK,
			fp.size.x + YARD_SIDE * 2.0, fp.size.y + YARD_FRONT + YARD_BACK)


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	var g := yard(footprint)
	var c := g.get_center()
	if not outdoor:
		# The sea to the horizon, a sandy beach, the lawn beyond the fence.
		_disc(Vector3(c.x, -6.0, c.y), 2400.0, 0.5, SEA, 48)
		_disc(Vector3(c.x, -2.2, c.y), 360.0, 2.0, SAND, 48)
		_disc(Vector3(c.x, -1.2, c.y), 330.0, 1.0, LAWN_DARK, 48)
		for i in 10:
			var a := rng.randf() * TAU
			var r := rng.randf_range(g.size.length() * 0.6, 280.0)
			_disc(Vector3(c.x + cos(a) * r, -1.15, c.y + sin(a) * r), rng.randf_range(14.0, 34.0), 1.0, "b3df62" if i % 2 else LAWN, 20)
	# The mown lawn inside the fence.
	_box(Vector3(c.x, 0.04 if outdoor else -1.3, c.y), Vector3(g.size.x, 0.1 if outdoor else 1.0, g.size.y), LAWN)
	# The path from the front door out through the gate, then on a little
	# way over the real ground (outdoors it follows the slope beyond the yard).
	var in_len := g.end.y - front_door.y
	_box(Vector3(front_door.x, 0.12, front_door.y + in_len * 0.5), Vector3(8.0, 0.12, in_len), PATH)
	var z0 := g.end.y
	for k in 10:
		var za := z0 + k * 4.0
		var zb := za + 4.0
		var ya := _ground(front_door.x, za) + 0.12
		var yb := _ground(front_door.x, zb) + 0.12
		var seg := _box(Vector3(front_door.x, (ya + yb) * 0.5, (za + zb) * 0.5), Vector3(8.0, 0.12, 4.15), PATH)
		seg.rotation.x = -atan2(yb - ya, 4.0)
	for k in int((g.end.y - front_door.y - 8.0) / 7.0):
		var z := front_door.y + 10.0 + k * 7.0
		for side in [-1.0, 1.0]:
			_ball(Vector3(front_door.x + side * 6.5, 0.6, z), 0.9, FLOWERS[(k + int(side > 0)) % FLOWERS.size()])
	_build_fence(g)
	_build_flower_beds()
	_build_backyard(g)
	_build_trees(g, rng)
	if not outdoor:
		for k in 7:
			var cloud: Node3D = (load(CLOUD_MODELS[k % 2]) as PackedScene).instantiate()
			var a := rng.randf() * TAU
			var r := rng.randf_range(80.0, 320.0)
			cloud.position = Vector3(c.x + cos(a) * r, rng.randf_range(90.0, 150.0), c.y + sin(a) * r)
			cloud.scale = Vector3.ONE * rng.randf_range(8.0, 14.0)
			add_child(cloud)
	MeshMerge.merge_children(self)  # one draw per colour
	for gi: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _mat(hex: String) -> StandardMaterial3D:
	if not _mats.has(hex):
		_mats[hex] = BuildingGenerator._mat(hex)
	return _mats[hex]


func _disc(at: Vector3, radius: float, height: float, hex: String, segs: int) -> void:
	BuildKit.add(self, BuildKit.cyl(radius, height, -1.0, segs), hex, at).material_override = _mat(hex)


func _box(at: Vector3, size: Vector3, hex: String) -> MeshInstance3D:
	var mi := BuildKit.add(self, BuildKit.box(size), hex, at)
	mi.material_override = _mat(hex)
	return mi


func _ball(at: Vector3, radius: float, hex: String) -> void:
	BuildKit.add(self, BuildKit.sphere(radius, 8), hex, at).material_override = _mat(hex)


func _ground(x: float, z: float) -> float:
	return float(ground_at.call(x, z)) if outdoor else 0.0


func _solid(size: Vector3, at: Vector3) -> void:
	if outdoor:
		BuildKit.collider(self, BuildKit.box_shape(size), at)


# --- The fence ------------------------------------------------------------------------

## A white picket fence round `g` with a gate gap at the front path.
func _build_fence(g: Rect2) -> void:
	var runs := [[Vector2(g.position.x, g.position.y), Vector2(g.end.x, g.position.y)],
		[Vector2(g.position.x, g.position.y), Vector2(g.position.x, g.end.y)],
		[Vector2(g.end.x, g.position.y), Vector2(g.end.x, g.end.y)],
		[Vector2(g.position.x, g.end.y), Vector2(front_door.x - GATE * 0.5, g.end.y)],
		[Vector2(front_door.x + GATE * 0.5, g.end.y), Vector2(g.end.x, g.end.y)]]
	var pickets: Array[Transform3D] = []
	for run in runs:
		var a: Vector2 = run[0]
		var b: Vector2 = run[1]
		var length := a.distance_to(b)
		if length < 1.0:
			continue
		var mid := (a + b) * 0.5
		var along_x := absf(b.y - a.y) < 0.01
		for y in [1.0, 2.4]:
			_box(Vector3(mid.x, y, mid.y), Vector3(length, 0.35, 0.25) if along_x else Vector3(0.25, 0.35, length), FENCE)
		_solid(Vector3(length, FENCE_H + 1.0, 0.6) if along_x else Vector3(0.6, FENCE_H + 1.0, length), Vector3(mid.x, (FENCE_H + 1.0) * 0.5, mid.y))
		var n := int(length / 1.1)
		for k in n + 1:
			var p := a.lerp(b, float(k) / maxf(n, 1))
			pickets.append(Transform3D(Basis.IDENTITY, Vector3(p.x, FENCE_H * 0.5, p.y)))
	# Gate posts, a bit taller with round tops.
	for s in [-1.0, 1.0]:
		var p: Vector2 = Vector2(front_door.x + s * GATE * 0.5, g.end.y)
		_box(Vector3(p.x, FENCE_H * 0.6, p.y), Vector3(0.7, FENCE_H * 1.2, 0.7), FENCE)
		_ball(Vector3(p.x, FENCE_H * 1.25, p.y), 0.5, FENCE)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var pm := PrismMesh.new()  # a pointy-topped picket
	pm.size = Vector3(0.5, FENCE_H, 0.2)
	mm.mesh = pm
	mm.instance_count = pickets.size()
	for i in pickets.size():
		mm.set_instance_transform(i, pickets[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat(FENCE)
	add_child(mmi)


# --- Flowers along the house ---------------------------------------------------------

func _build_flower_beds() -> void:
	var fp := footprint
	for side in 4:
		var count := int((fp.size.x if side % 2 == 0 else fp.size.y) / 6.0)
		for k in count:
			var t := (k + 0.5) / count
			var p: Vector2
			match side:
				0: p = Vector2(lerpf(fp.position.x, fp.end.x, t), fp.position.y - 3.5)
				1: p = Vector2(fp.end.x + 3.5, lerpf(fp.position.y, fp.end.y, t))
				2: p = Vector2(lerpf(fp.position.x, fp.end.x, t), fp.end.y + 3.5)
				_: p = Vector2(fp.position.x - 3.5, lerpf(fp.position.y, fp.end.y, t))
			if absf(p.x - front_door.x) < 12.0 and side == 2:
				continue  # the porch and path
			_ball(Vector3(p.x, 0.6, p.y), 1.3, "5fbf4b")
			_ball(Vector3(p.x, 1.6, p.y), 0.7, FLOWERS[(k + side) % FLOWERS.size()])


# --- The backyard ---------------------------------------------------------------------

## Behind the house (the plan's -Z side): swings, a trampoline, a sandpit.
func _build_backyard(g: Rect2) -> void:
	var back := (g.position.y + footprint.position.y) * 0.5
	var cx := footprint.get_center().x
	# The swing set: an A-frame each end, a top bar, two swings.
	var sw := Vector3(cx - 35.0, 0, back)
	var frame := "e63946"
	for s in [-1.0, 1.0]:
		for t in [-1.0, 1.0]:
			var leg := _box(sw + Vector3(s * 6.0, 4.0, t * 1.6), Vector3(0.5, 8.4, 0.5), frame)
			leg.rotation.x = -t * 0.38
	_box(sw + Vector3(0, 7.9, 0), Vector3(13.0, 0.6, 0.6), frame)
	for s in [-1.0, 1.0]:
		for r in [-0.9, 0.9]:
			_box(sw + Vector3(s * 3.0 + r, 5.0, 0), Vector3(0.12, 5.6, 0.12), "6b6b6b")
		_box(sw + Vector3(s * 3.0, 2.1, 0), Vector3(2.4, 0.3, 1.0), "ffd166" if s < 0 else "4aa8ff")
	_solid(Vector3(13.0, 8.0, 4.0), sw + Vector3(0, 4.0, 0))
	# The trampoline: jump on and it bounces you high.
	var tr := Vector3(cx + 5.0, 0, back - 5.0)
	_disc(tr + Vector3(0, 1.8, 0), 6.5, 0.4, "2b2d42", 32)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 6.4
	tm.outer_radius = 7.2
	rim.mesh = tm
	rim.position = tr + Vector3(0, 2.0, 0)
	rim.material_override = _mat("4aa8ff")
	add_child(rim)
	for k in 6:
		var a := TAU * k / 6.0
		_box(tr + Vector3(cos(a) * 6.8, 0.9, sin(a) * 6.8), Vector3(0.4, 1.8, 0.4), "6b6b6b")
	if outdoor:
		var bounce := StaticBody3D.new()
		bounce.collision_layer = GameSettings.LAYER_WORLD
		bounce.add_to_group("bouncy")
		var cs := CollisionShape3D.new()
		cs.shape = BuildKit.cyl_shape(7.0, 2.0)
		cs.position = tr + Vector3(0, 1.0, 0)
		bounce.add_child(cs)
		add_child(bounce)
	# The sandpit with a bucket.
	var sp := Vector3(cx + 40.0, 0, back + 4.0)
	_box(sp + Vector3(0, 0.5, 0), Vector3(14.0, 1.0, 10.0), "b98a5e")
	_box(sp + Vector3(0, 0.6, 0), Vector3(12.6, 1.0, 8.6), SAND)
	_disc(sp + Vector3(2.0, 1.6, 1.0), 0.8, 1.2, "ff5d5d", 12)
	_ball(sp + Vector3(-2.5, 1.3, -1.5), 1.2, SAND)


# --- Trees ----------------------------------------------------------------------------

func _build_trees(g: Rect2, rng: RandomNumberGenerator) -> void:
	var spots: Array[Vector2] = [g.position + Vector2(8, 8), Vector2(g.end.x - 8, g.position.y + 8),
		Vector2(g.position.x + 8, g.end.y - 10), Vector2(g.end.x - 8, g.end.y - 10)]
	if not outdoor:
		# Indoors, trees round the outside too (outdoors the island has its own).
		var c := g.get_center()
		for k in 26:
			var a := TAU * k / 26.0 + rng.randf_range(-0.08, 0.08)
			var r := rng.randf_range(g.size.length() * 0.55, g.size.length() * 0.55 + 70.0)
			var p := c + Vector2(cos(a), sin(a)) * r
			if absf(p.x - front_door.x) < 16.0 and p.y > g.end.y:
				continue  # keep the path's view clear
			spots.append(p)
	var models := TREE_MODELS.keys()
	for p in spots:
		var path: String = models[rng.randi() % models.size()]
		var tree: Node3D = (load(path) as PackedScene).instantiate()
		tree.scale = Vector3.ONE * float(TREE_MODELS[path]) * rng.randf_range(0.9, 1.3)
		tree.position = Vector3(p.x, 0.0 if outdoor else -1.0, p.y)
		tree.rotation.y = rng.randf() * TAU
		add_child(tree)
		_solid(Vector3(2.0, 10.0, 2.0), Vector3(p.x, 5.0, p.y))
