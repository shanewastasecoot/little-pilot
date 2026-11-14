class_name Boat
extends Landmark
## A little sail boat (Quaternius CC0) cruising in a big loop off the south
## coast. Toots when discovered. Its discovery zone travels with it.

@export var loop_center: Vector3 = Vector3(250, 0, 1000)
@export var loop_radius: float = 160.0
@export var loop_speed: float = 0.05  # radians per second

var _angle := 0.0
var _hull: Node3D
var _t := 0.0


func _init() -> void:
	landmark_name = "Boat"
	discovery_radius = 110.0
	discovery_sound = "toot"


func build() -> void:
	_hull = Node3D.new()
	add_child(_hull)
	# Model faces -Z; the loop moves it sideways, so turn it to face travel.
	AssetLib.place(_hull, "res://assets/environment/sail_boat.glb", Vector3.ZERO, 22.0, 90.0)


func _process(delta: float) -> void:
	_t += delta
	_angle += loop_speed * delta
	position = loop_center + Vector3(cos(_angle), 0, sin(_angle)) * loop_radius
	rotation.y = -_angle + PI  # face along the loop
	_hull.rotation.z = sin(_t * 1.3) * 0.05
	_hull.position.y = sin(_t * 1.1) * 0.3


func react() -> void:
	var puff := PickupBurst.new(14, 4.0, [Color.WHITE, Color("dddddd")])
	puff.gravity = Vector3(0, 3, 0)
	_hull.add_child(puff)
	puff.position = Vector3(0, 16, 0)
