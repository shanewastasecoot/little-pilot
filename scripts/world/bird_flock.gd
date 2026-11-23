class_name BirdFlock
extends Node3D
## A little flock of birds startled up out of the trees (a honk or a low
## pass over the forest): white V-shaped birds flapping up and away from
## where the noise was, then gone. Frees itself. Origin where they start.

const LIFE := 6.0

var count := 10
## They fly away from this point (world space).
var away_from := Vector3.ZERO
var _birds: Array[Dictionary] = []
var _t := 0.0
static var _mesh: ArrayMesh


func _ready() -> void:
	if _mesh == null:
		_mesh = _make_mesh()
	var out := global_position - away_from
	out.y = 0.0
	out = out.normalized() if out.length() > 0.1 else Vector3.FORWARD
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("f4f6fa")  # white, like gulls: seen against trees and sky
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = _mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(randf_range(-10, 10), randf_range(-2, 3), randf_range(-10, 10))
		mi.scale = Vector3.ONE * randf_range(2.6, 3.4)
		add_child(mi)
		var dir := (out.rotated(Vector3.UP, randf_range(-0.6, 0.6)) + Vector3.UP * randf_range(0.5, 0.9)).normalized()
		_birds.append({"node": mi, "vel": dir * randf_range(11.0, 16.0), "phase": randf() * TAU, "rate": randf_range(13.0, 17.0),
			"size": mi.scale.x})
	Sfx.play_at("chirp", global_position, randf_range(0.95, 1.1))


func _process(delta: float) -> void:
	_t += delta
	if _t > LIFE:
		queue_free()
		return
	for b in _birds:
		var mi: MeshInstance3D = b.node
		var v: Vector3 = b.vel
		v.y = maxf(v.y - delta * 1.2, 1.5)  # climbing less steeply as they go
		b.vel = v
		mi.position += v * delta
		mi.look_at(mi.global_position + v, Vector3.UP)
		# Flap: the wings (the mesh's sides) rise and fall.
		var flap := sin(_t * float(b.rate) + float(b.phase))
		var fade := clampf((LIFE - _t) / 1.5, 0.0, 1.0)
		var sz: float = b.size
		mi.scale = Vector3(sz * fade, sz * (1.0 + flap * 0.9), sz * fade)


## A bird seen from above: a body and two swept wings, a V. Flapping
## stretches the wing tips up and down (they're the only vertices off y=0).
static func _make_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [
		# left wing
		[Vector3(0, 0, -0.5), Vector3(-1.6, 0.4, 0.5), Vector3(0, 0, 0.4)],
		# right wing
		[Vector3(0, 0, -0.5), Vector3(0, 0, 0.4), Vector3(1.6, 0.4, 0.5)],
		# body
		[Vector3(0, 0.1, -0.8), Vector3(-0.15, 0, 0.6), Vector3(0.15, 0, 0.6)],
	]
	for tri in pts:
		st.set_normal(Vector3.UP)
		for p in tri:
			st.add_vertex(p)
	return st.commit()
