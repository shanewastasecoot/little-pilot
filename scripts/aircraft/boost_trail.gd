class_name BoostTrail
extends Node3D
## A fading ribbon that streams behind this point (put one on each wingtip).
## AircraftVisuals turns it on while boosting. The ribbon is drawn in world
## space and always faces the camera, so it reads well from the chase view.

@export var color_start: Color = Color(1, 1, 1, 0.85)
@export var color_end: Color = Color(1, 1, 1, 0.0)
## Optional rainbow (prop plane): hue shifts along the trail.
@export var rainbow: bool = false
@export var width: float = 0.35
## Seconds a point stays visible.
@export var lifetime: float = 0.6

## 0..1, set every frame by AircraftVisuals (fades the trail in/out).
var strength: float = 0.0

var _points: Array[Vector3] = []
var _ages: PackedFloat32Array = PackedFloat32Array()
var _mesh := ImmediateMesh.new()
var _instance := MeshInstance3D.new()

static var _material: StandardMaterial3D


func _ready() -> void:
	_instance.mesh = _mesh
	_instance.top_level = true  # vertices are world-space
	_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_instance.material_override = _get_material()
	add_child(_instance)


func _process(delta: float) -> void:
	_instance.global_transform = Transform3D.IDENTITY
	for i in _ages.size():
		_ages[i] += delta
	while _ages.size() > 0 and _ages[0] > lifetime:
		_points.pop_front()
		_ages.remove_at(0)
	if strength > 0.05:
		_points.append(global_position)
		_ages.append(lifetime * (1.0 - strength))  # weak boost = shorter trail
	_rebuild()


func _rebuild() -> void:
	_mesh.clear_surfaces()
	var n := _points.size()
	if n < 2:
		return
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else global_position + Vector3.UP * 10.0
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in n:
		var p := _points[i]
		var dir := (_points[mini(i + 1, n - 1)] - _points[maxi(i - 1, 0)]).normalized()
		var side := dir.cross(eye - p).normalized()
		var life := 1.0 - _ages[i] / lifetime  # 1 = newest
		var c := color_end.lerp(color_start, life)
		if rainbow:
			var tint := Color.from_hsv(fmod(float(i) / 25.0 + Time.get_ticks_msec() / 3000.0, 1.0), 0.75, 1.0)
			c = Color(tint.r, tint.g, tint.b, c.a)
		var w := width * life * life  # tapers to a point
		# Fade out near the camera so the trail never smears across the screen.
		c.a *= clampf((p.distance_to(eye) - 5.0) / 5.0, 0.0, 1.0)
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(p + side * w)
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(p - side * w)
	_mesh.surface_end()


static func _get_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.vertex_color_use_as_albedo = true
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _material
