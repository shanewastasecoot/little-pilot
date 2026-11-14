class_name VolcanoIsland
extends Landmark
## A friendly volcano (the cone is terrain): glowing lava pool in the
## crater and a lazy smoke plume. It rumbles and puffs when discovered.
## Node sits at the crater floor.

var _smoke: CPUParticles3D
var _lava_mat: StandardMaterial3D
var _t := 0.0


func _init() -> void:
	landmark_name = "Volcano"
	discovery_radius = 360.0
	discovery_sound = "rumble"


func build() -> void:
	_lava_mat = BuildKit.mat("ff6a1a", true).duplicate()
	_lava_mat.emission_energy_multiplier = 2.5
	var lava := MeshInstance3D.new()
	lava.mesh = BuildKit.cyl(IslandShape.CRATER_RADIUS * 0.75, 1.0, -1, 20)
	lava.material_override = _lava_mat
	lava.position.y = 4.0
	lava.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lava)
	_smoke = _make_smoke(10, 1.0)
	add_child(_smoke)
	# Rocks round the crater rim.
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for i in 10:
		var a := TAU * i / 10.0
		var p := IslandShape.VOLCANO + Vector2(cos(a), sin(a)) * IslandShape.CRATER_RADIUS * 1.4
		var y := IslandShape.volcano_height(p.x, p.y) - position.y
		AssetLib.place(self, "res://assets/environment/rocks.glb", Vector3(p.x - IslandShape.VOLCANO.x, y - 1.0, p.y - IslandShape.VOLCANO.y), rng.randf_range(40.0, 70.0), rng.randf() * 360.0)


func _make_smoke(count: int, speed: float) -> CPUParticles3D:
	var s := CPUParticles3D.new()
	s.amount = count
	s.lifetime = 14.0
	s.preprocess = 14.0
	s.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	s.emission_sphere_radius = 14.0
	s.direction = Vector3.UP
	s.spread = 12.0
	s.gravity = Vector3(1.5, 2.0, 0.6)  # drifts with the wind
	s.initial_velocity_min = 4.0 * speed
	s.initial_velocity_max = 7.0 * speed
	s.scale_amount_min = 1.0
	s.scale_amount_max = 1.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.6))
	s.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(0.75, 0.73, 0.78, 0.85))
	grad.set_color(1, Color(0.9, 0.9, 0.95, 0.0))
	s.color_ramp = grad
	var puff := SphereMesh.new()
	puff.radius = 14.0
	puff.height = 24.0
	puff.radial_segments = 8
	puff.rings = 4
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material = m
	s.mesh = puff
	s.position.y = 10.0
	return s


func _process(delta: float) -> void:
	_t += delta
	_lava_mat.emission_energy_multiplier = 2.2 + sin(_t * 2.0) * 0.5


func react() -> void:
	var puff := _make_smoke(16, 3.0)
	puff.one_shot = true
	puff.explosiveness = 0.9
	puff.preprocess = 0.0
	puff.lifetime = 6.0
	add_child(puff)
	puff.emitting = true
	puff.finished.connect(puff.queue_free)
	var sparks := PickupBurst.new(50, 30.0, [Color("ff6a1a"), Color("ffd23f"), Color("ff3b3b")])
	sparks.position.y = 8.0
	add_child(sparks)
