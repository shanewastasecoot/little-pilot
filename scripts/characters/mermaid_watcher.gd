class_name MermaidWatcher
extends Node
## Makes a group of mermaids wave at the player's plane as it flies past.
## One cheap distance check for the whole group every CHECK_INTERVAL
## (no physics areas, no per-mermaid polling):
##   plane within wave_radius  -> those mermaids wave and turn to it
##   plane beyond sleep_radius -> the whole group stops animating

const CHECK_INTERVAL := 0.15

@export var wave_radius := 200.0
@export var sleep_radius := 1300.0

var mermaids: Array[Mermaid] = []
var _plane: Node3D
var _timer := 0.0
var _awake := true


func add(m: Mermaid) -> void:
	mermaids.append(m)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = CHECK_INTERVAL
	if _plane == null:
		_plane = get_tree().get_first_node_in_group("aircraft")
		if _plane == null:
			return
	var p := _plane.global_position
	var centre := (get_parent() as Node3D).global_position
	var awake := centre.distance_to(p) < sleep_radius
	if awake != _awake:
		_awake = awake
		for m in mermaids:
			m.set_active(awake)
	if not awake:
		return
	var r2 := wave_radius * wave_radius
	for m in mermaids:
		m.look_target = _plane
		m.set_waving(m.global_position.distance_squared_to(p) < r2)
