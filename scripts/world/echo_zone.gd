class_name EchoZone
extends Area3D
## Where a honk echoes (Phase 6): an invisible area that, while the plane is
## inside it, sends the honk through an audio bus with an echo or reverb
## (GameSettings makes the buses):
##   "HonkEcho"  the mountains: the honk comes back two or three times
##   "HonkCave"  the dragon's cave: a big, booming reverb
##   "HonkCity"  among the city's buildings: a short slap back
## Overlapping zones: the highest `echo_rank` wins (the cave inside the
## mountains). No new sound files: it's the same honk, through a bus.

var bus := &"HonkEcho"
var echo_rank := 0

static var _inside: Array[EchoZone] = []


## A box (size) or, with size.y <= 0, a sphere of radius size.x, at `at`.
static func make(bus_name: StringName, at: Vector3, size: Vector3, prio: int) -> EchoZone:
	var z := EchoZone.new()
	z.name = "Echo" + String(bus_name).trim_prefix("Honk")
	z.bus = bus_name
	z.echo_rank = prio
	z.position = at
	var cs := CollisionShape3D.new()
	if size.y <= 0.0:
		var s := SphereShape3D.new()
		s.radius = size.x
		cs.shape = s
	else:
		var b := BoxShape3D.new()
		b.size = size
		cs.shape = b
	z.add_child(cs)
	return z


func _ready() -> void:
	collision_layer = 0
	collision_mask = GameSettings.LAYER_AIRCRAFT
	monitorable = false
	body_entered.connect(func(b: Node3D):
		if b.is_in_group("aircraft") and not _inside.has(self):
			_inside.append(self))
	body_exited.connect(func(b: Node3D):
		if b.is_in_group("aircraft"):
			_inside.erase(self))
	tree_exiting.connect(func(): _inside.erase(self))


## The bus a honk should play through now (the plane's zone), or SFX.
static func honk_bus() -> StringName:
	var best: EchoZone = null
	for z in _inside:
		if is_instance_valid(z) and (best == null or z.echo_rank > best.echo_rank):
			best = z
	return best.bus if best else GameSettings.BUS_SFX
