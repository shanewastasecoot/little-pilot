class_name Airport
extends Landmark
## Spawn area: runway with markings, control tower, hangar and a windsock
## that flaps harder when discovered.

const TOWER_SCALE := 15.0  # ~60 m tall

var _sock: Node3D
var _flap_speed := 2.0
var _t := 0.0


func _init() -> void:
	landmark_name = "Airport"
	discovery_radius = 200.0
	discovery_sound = "ding"


func build() -> void:
	var half := IslandShape.RUNWAY_HALF
	BuildKit.add(self, BuildKit.box(Vector3(half.x * 2.0, 0.4, half.y * 2.0)), "55585f", Vector3(0, 0.2, 0))
	for i in 14:  # centre-line dashes
		BuildKit.add(self, BuildKit.box(Vector3(18, 0.1, 1.6)), "ffffff", Vector3(-half.x + 30 + i * 42, 0.45, 0))
	for side in [-1, 1]:  # threshold stripes
		for k in 6:
			BuildKit.add(self, BuildKit.box(Vector3(14, 0.1, 3)), "ffffff", Vector3(side * (half.x - 14), 0.45, -19 + k * 7.6))
	# Control tower
	var tower := Node3D.new()
	tower.position = Vector3(-120, 0, -70)
	add_child(tower)
	# Model (Poly by Google, CC-BY 3.0): ~3.95 units tall, base 2.28 below origin.
	AssetLib.place(tower, "res://assets/environment/control_tower.glb", Vector3(0, 2.28 * TOWER_SCALE, 0), TOWER_SCALE)
	BuildKit.collider(tower, BuildKit.cyl_shape(6, 4.0 * TOWER_SCALE), Vector3(0, 2.0 * TOWER_SCALE, 0))
	BuildKit.push_volume(tower, 28.0, 4.0 * TOWER_SCALE + 30.0)
	# Hangar (code-built), door facing the runway
	var hangar := Hangar.new()
	hangar.position = Vector3(110, 0, -105)
	add_child(hangar)
	# Windsock
	var pole := Node3D.new()
	pole.position = Vector3(-60, 0, 50)
	add_child(pole)
	BuildKit.add(pole, BuildKit.cyl(0.3, 10), "dddddd", Vector3(0, 5, 0))
	_sock = Node3D.new()
	_sock.position = Vector3(0, 9.6, 0)
	pole.add_child(_sock)
	BuildKit.add(_sock, BuildKit.cyl(1.0, 5, 0.5, 8), "ff8c42", Vector3(0, 0, 2.5), Vector3(90, 0, 0))


func _process(delta: float) -> void:
	_t += delta * _flap_speed
	_sock.rotation = Vector3(sin(_t * 3.0) * 0.12 - 0.15, sin(_t) * 0.6, 0)
	_flap_speed = move_toward(_flap_speed, 2.0, delta * 0.5)


func react() -> void:
	_flap_speed = 8.0
