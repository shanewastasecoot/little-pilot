class_name Boat
extends Landmark
## A little tugboat chugging in a big loop off the south coast. Toots when
## discovered. Its discovery zone travels with it.

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
	BuildKit.add(_hull, BuildKit.box(Vector3(8, 3, 18)), "ff5a5f", Vector3(0, 1.0, 0))
	BuildKit.add(_hull, BuildKit.prism(Vector3(8, 6, 3)), "ff5a5f", Vector3(0, 1.0, -10.5), Vector3(-90, 0, 0))
	BuildKit.add(_hull, BuildKit.box(Vector3(6, 4, 7)), "ffffff", Vector3(0, 4.5, 2))
	BuildKit.add(_hull, BuildKit.cyl(1.1, 4), "ffd23f", Vector3(0, 8, 4))
	BuildKit.add(_hull, BuildKit.cyl(1.2, 0.6), "333333", Vector3(0, 10.2, 4))


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
	puff.position = Vector3(0, 11, 4)
