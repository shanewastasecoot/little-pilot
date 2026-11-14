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
