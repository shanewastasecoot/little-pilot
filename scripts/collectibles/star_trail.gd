@tool
class_name StarTrail
extends Path3D
## Places stars evenly along this path. Draw the curve in the editor and set
## `star_count`; the stars appear automatically (also in the editor).

@export_range(1, 50) var star_count: int = 5:
	set(value):
		star_count = value
		_rebuild()

var _star_scene: PackedScene = preload("res://scenes/collectibles/star.tscn")


func _ready() -> void:
	if not curve_changed.is_connected(_rebuild):
		curve_changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree() or curve == null:
		return
	for c in get_children():
		if c.has_meta("from_trail"):
			c.free()
	var length := curve.get_baked_length()
	for i in star_count:
		var t := 0.0 if star_count == 1 else length * i / (star_count - 1)
		var star: Node3D
		if Engine.is_editor_hint():
			# Lightweight marker in the editor (scripts don't run there).
			var mi := MeshInstance3D.new()
			mi.mesh = StarMesh.get_mesh()
			star = mi
		else:
			star = _star_scene.instantiate()
		star.set_meta("from_trail", true)
		star.position = curve.sample_baked(t)
		add_child(star)
