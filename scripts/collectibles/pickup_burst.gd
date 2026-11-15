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
	mat.albedo_texture = _soft_dot()  # round, soft-edged particles
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = mat
	mesh = quad
	finished.connect(queue_free)


## Make scale_amount_min/max actually size the particles (billboards drop
## the particle scale unless told to keep it). For big effects.
func keep_scale() -> PickupBurst:
	((mesh as QuadMesh).material as StandardMaterial3D).billboard_keep_scale = true
	return self


static var _dot: GradientTexture2D


## A shared white disc that fades out at the edge.
static func _soft_dot() -> GradientTexture2D:
	if _dot == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
		_dot = GradientTexture2D.new()
		_dot.gradient = g
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		_dot.width = 64
		_dot.height = 64
	return _dot


func _ready() -> void:
	emitting = true
