class_name Lighthouse
extends Landmark
## Red-and-white lighthouse (MaverickFX, CC0) on the rocky point with a
## sweeping light beam.
## The beam spins faster when discovered (with a foghorn).

const MODEL_SCALE := 3.75
## Lantern height for the beam (model lantern ~10.3 units up).
const LANTERN_Y := 10.3 * MODEL_SCALE

var _beam: Node3D
var _spin := 0.8


func _init() -> void:
	landmark_name = "Lighthouse"
	discovery_radius = 140.0
	discovery_sound = "foghorn"


func build() -> void:
	# Model (MaverickFX, CC0): ~12.8 units tall, off-centre in its file.
	AssetLib.place(self, "res://assets/environment/lighthouse.glb", Vector3(1.77, 0, 0.25) * MODEL_SCALE, MODEL_SCALE)
	BuildKit.collider(self, BuildKit.cyl_shape(6, 50), Vector3(0, 25, 0))
	BuildKit.push_volume(self, 24.0, 90.0)
	# Beam: two long translucent cones
	_beam = Node3D.new()
	_beam.position = Vector3(0, LANTERN_Y, 0)
	add_child(_beam)
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.albedo_color = Color(1, 0.95, 0.6, 0.25)
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side in [-1, 1]:
		var cone := MeshInstance3D.new()
		cone.mesh = BuildKit.cyl(0.4, 70, 9, 10)
		cone.material_override = beam_mat
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cone.position = Vector3(side * 35, 0, 0)
		cone.rotation_degrees = Vector3(0, 0, -90 * side)
		_beam.add_child(cone)
	# Rocks
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 9:
		var a := TAU * i / 9.0
		var path := "res://assets/environment/%s.glb" % ("rocks" if i % 2 == 0 else "rock")
		AssetLib.place(self, path, Vector3(cos(a) * 16, -1.0, sin(a) * 16), rng.randf_range(45.0, 70.0), rng.randf() * 360.0)


func _process(delta: float) -> void:
	_beam.rotate_y(_spin * delta)
	_spin = move_toward(_spin, 0.8, delta * 0.4)


func react() -> void:
	_spin = 5.0
