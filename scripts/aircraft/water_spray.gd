class_name WaterSpray
extends CPUParticles3D
## A rooster tail of sea spray under the plane when it skims low over the
## water. Child of the aircraft; sits on the wave surface below it.

## Spray starts below this height above the waves (m), full at a third of it.
@export var max_height := 9.0

var _ray := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	top_level = true
	emitting = false
	amount = 70
	lifetime = 0.9
	local_coords = false
	direction = Vector3.UP
	spread = 35.0
	initial_velocity_min = 4.0
	initial_velocity_max = 9.0
	gravity = Vector3(0, -14, 0)
	damping_min = 1.0
	damping_max = 2.0
	emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = 1.2
	scale_amount_min = 1.0
	scale_amount_max = 2.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(0.3, 1))
	curve.add_point(Vector2(1, 0))
	scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.85))
	grad.set_color(1, Color(0.85, 0.95, 1, 0))
	color_ramp = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.8, 0.8)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = PickupBurst._soft_dot()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_keep_scale = true
	quad.material = mat
	mesh = quad
	_ray.collision_mask = GameSettings.LAYER_WORLD
	_ray.hit_from_inside = true


func _physics_process(_delta: float) -> void:
	var plane := get_parent() as Node3D
	var p := plane.global_position
	var sea := Waves.height(p.x, p.z)
	var h := p.y - sea
	var low := h < max_height * 0.8 and h > -1.0 and _over_water(p)
	emitting = low
	if low:
		var strength := clampf(1.0 - h / max_height, 0.0, 1.0) * 1.5
		initial_velocity_max = 5.0 + 8.0 * strength
		global_position = Vector3(p.x, sea + 0.3, p.z)


## True when the first thing straight below the plane is the sea.
func _over_water(p: Vector3) -> bool:
	_ray.from = p
	_ray.to = p + Vector3.DOWN * (max_height + 4.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(_ray)
	return hit.is_empty() or (hit.collider as Node).is_in_group("water")
