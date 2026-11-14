class_name FireworkBurst
extends CPUParticles3D
## One big firework: a sphere of glowing sparks that flies out ~150 m, hangs,
## droops and fades. Bright additive particles so it reads from far away.
## Set position before adding to the tree; frees itself when done.

static var _mesh: QuadMesh


func _init(color_a: Color, color_b: Color) -> void:
	one_shot = true
	explosiveness = 1.0
	amount = 160
	lifetime = 2.8
	emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = 3.0
	direction = Vector3.UP
	spread = 180.0
	initial_velocity_min = 105.0
	initial_velocity_max = 125.0
	damping_min = 34.0
	damping_max = 40.0
	gravity = Vector3(0, -5, 0)
	var size_curve := Curve.new()
	size_curve.add_point(Vector2(0.0, 1.0))
	size_curve.add_point(Vector2(0.7, 0.8))
	size_curve.add_point(Vector2(1.0, 0.2))
	scale_amount_curve = size_curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 0.92))
	ramp.set_color(1, Color(color_b.r, color_b.g, color_b.b, 0.0))
	ramp.add_point(0.08, color_a)
	ramp.add_point(0.6, color_b)
	ramp.add_point(0.85, Color(color_b.r, color_b.g, color_b.b, 0.8))
	color_ramp = ramp
	if _mesh == null:
		_mesh = QuadMesh.new()
		_mesh.size = Vector2(12, 12)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# Soft round spark instead of a square.
		var g := Gradient.new()
		g.set_color(0, Color.WHITE)
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.55, Color(1, 1, 1, 0.95))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 32
		tex.height = 32
		m.albedo_texture = tex
		m.no_depth_test = false
		_mesh.material = m
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	finished.connect(queue_free)


func _ready() -> void:
	emitting = true
