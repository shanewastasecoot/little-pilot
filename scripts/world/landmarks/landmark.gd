class_name Landmark
extends Node3D
## Base for island landmarks. Subclasses build their props in build() and
## animate a reaction in react(), called the first time the plane flies close.

signal discovered(landmark: Landmark)

@export var landmark_name: String = "Landmark"
@export var discovery_radius: float = 150.0
## Sfx name played on discovery (after the shared discovery jingle).
@export var discovery_sound: String = "ding"

var is_discovered: bool = false


func _ready() -> void:
	add_to_group("landmarks")
	build()
	limit_detail(self)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = GameSettings.LAYER_AIRCRAFT
	area.monitorable = false
	var shape := SphereShape3D.new()
	shape.radius = discovery_radius
	var cs := CollisionShape3D.new()
	cs.shape = shape
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if is_discovered or not body is Aircraft:
		return
	is_discovered = true
	Sfx.play(discovery_sound)
	react()
	discovered.emit(self)


## Build props. Called once from _ready().
func build() -> void:
	pass


## Discovery reaction (animation). Sound is handled by the base class.
func react() -> void:
	pass


## Small props (lights, fences, animals, little trees) only draw when the
## plane is near, and the tiniest cast no shadow: landmarks are visible from
## far away, and each prop costs a draw call per shadow cascade otherwise.
## Anything that already sets its own visibility range is left alone.
static func limit_detail(root: Node) -> void:
	for gi: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
		if gi.visibility_range_end > 0.0 or gi is MultiMeshInstance3D:
			continue
		var size := _world_size(gi, root)
		if size < 6.0:
			gi.visibility_range_end = 420.0
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif size < 30.0:
			gi.visibility_range_end = 750.0


static func _world_size(gi: GeometryInstance3D, root: Node) -> float:
	var xf := Transform3D.IDENTITY
	var cur: Node = gi
	while cur != root and cur is Node3D:
		xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	var box := xf * gi.get_aabb()
	return maxf(box.size.x, maxf(box.size.y, box.size.z))
