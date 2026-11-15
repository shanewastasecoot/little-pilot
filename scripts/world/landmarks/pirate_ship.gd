class_name PirateShip
extends Landmark
## A friendly pirate ship sailing a huge loop between the outer islands.
## Its discovery zone and keep-away zone travel with it.

@export var loop_radius: float = 2550.0
@export var loop_speed: float = 0.004  # rad/s (~10 m/s)

var _angle := 2.6
var _hull: Node3D
var _t := 0.0


func _init() -> void:
	landmark_name = "Pirate Ship"
	discovery_radius = 170.0
	discovery_sound = "toot"


func build() -> void:
	_hull = Node3D.new()
	add_child(_hull)
	# Model's bow points along -X; turned to face the direction of travel
	# (this node's +Z, see _update).
	AssetLib.place(_hull, "res://assets/environment/pirate_ship.glb", Vector3(0, 1.61 * 3.5 - 2.5, 0), 3.5, 90.0)
	BuildKit.push_volume(self, 45.0, 70.0)
	_update()


func _process(delta: float) -> void:
	_t += delta
	_angle += loop_speed * delta
	_update()
	Waves.ride(_hull, 30.0, 14.0, 0.0, delta, 0.8)  # heavy ship: rides a bit calmer


func _update() -> void:
	position = Vector3(cos(_angle), 0, sin(_angle)) * loop_radius
	rotation.y = -_angle  # tangent to the loop


func react() -> void:
	for k in 3:
		var puff := PickupBurst.new(20, 10.0, [Color.WHITE, Color("dddddd")])
		puff.position = Vector3(0, 8, (k - 1) * 12.0)
		_hull.add_child(puff)
	var confetti := PickupBurst.new(50, 18.0, [Color("ffd23f"), Color("ff5a5f"), Color("4aa8ff")])
	confetti.position = Vector3(0, 45, 0)
	_hull.add_child(confetti)
