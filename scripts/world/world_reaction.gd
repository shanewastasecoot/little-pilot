class_name WorldReaction
extends Node
## Makes something react when the plane (or she) does something near it
## (WorldEvents, Phase 6). Adding a reaction is one line in the thing's
## build(), e.g.
##
##   WorldReaction.add(self, 160.0, ["honk", "low_pass"], 4.0, _scatter)
##
## calls `_scatter(kind, where)` whenever a honk or low pass happens within
## 160 m (flat distance) of it, at most every 4 s.

var radius := 150.0
var kinds: Array = ["honk"]
var cooldown := 3.0
var react: Callable
## Measure from this node (defaults to the parent).
var centre: Node3D
var _cool := 0.0
## How many times it has reacted (tests).
var count := 0


static func add(parent: Node3D, r: float, what: Array, every: float, callback: Callable) -> WorldReaction:
	var wr := WorldReaction.new()
	wr.name = "Reaction"
	wr.radius = r
	wr.kinds = what
	wr.cooldown = every
	wr.react = callback
	parent.add_child(wr)
	return wr


func _ready() -> void:
	if centre == null:
		centre = get_parent() as Node3D
	WorldEvents.happened.connect(_on_event)


func _process(delta: float) -> void:
	_cool = maxf(_cool - delta, 0.0)


func _on_event(kind: String, where: Vector3, _info: Dictionary) -> void:
	if _cool > 0.0 or not kind in kinds or centre == null or not centre.is_inside_tree():
		return
	if not WorldEvents.near(centre.global_position, where, radius):
		return
	_cool = cooldown
	count += 1
	react.call(kind, where)
