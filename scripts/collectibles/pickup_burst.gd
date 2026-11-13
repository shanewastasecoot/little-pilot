class_name PickupBurst
extends CPUParticles3D
## One-shot sparkle burst, frees itself when done.
## Pass a bigger `amount`/`spread_speed` for celebrations.

func _init(count: int = 24, speed: float = 9.0, colors: Array[Color] = [Color("fff27a"), Color("ffd23f"), Color("ffffff")]) -> void:
	one_shot = true
	explosiveness = 1.0
	amount = count
	lifetime = 0.9
	direction = Vector3.UP
	spread = 180.0
	initial_velocity_min = speed * 0.5
	initial_velocity_max = speed
	gravity = Vector3(0, -6, 0)
	damping_min = 2.0
	damping_max = 4.0
	scale_amount_min = 0.25
	scale_amount_max = 0.5
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	scale_amount_curve = curve
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array()
	grad.colors = PackedColorArray()
	for i in colors.size():
		grad.add_point(float(i) / maxf(colors.size() - 1, 1), colors[i])
	color_initial_ramp = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = mat
	mesh = quad
	finished.connect(queue_free)


func _ready() -> void:
	emitting = true
