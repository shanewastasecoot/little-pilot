class_name RainbowArch
extends Landmark
## A giant rainbow arching out of the sea. Fly through it for a party,
## every time (not just the first). Its lower half is hidden by the ocean.
## Spans north-south, so it faces planes flying east to Palm Island.

const RADIUS := 120.0
const BAND := 5.5
const COLORS := ["ff3b3b", "ff8c42", "ffd23f", "4cc06a", "3f8cff", "5b4bdb", "9b5de5"]

var _cooldown := 0.0


func _init() -> void:
	landmark_name = "Rainbow"
	discovery_radius = RADIUS - BAND * 7.0
	discovery_sound = "fanfare"


func build() -> void:
	for i in COLORS.size():
		var inner := RADIUS - (i + 1) * BAND
		var torus := TorusMesh.new()
		torus.inner_radius = inner
		torus.outer_radius = inner + BAND
		torus.rings = 48
		torus.ring_segments = 8
		var mi := MeshInstance3D.new()
		mi.mesh = torus
		var m := BuildKit.mat(COLORS[i], true).duplicate()
		m.emission_energy_multiplier = 0.6
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.rotation_degrees = Vector3(0, 0, 90)  # stand the ring up, facing east-west
		add_child(mi)


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


## Celebrate every pass through the arch (with a short cooldown).
func _on_body_entered(body: Node3D) -> void:
	if not body is Aircraft or _cooldown > 0.0:
		return
	_cooldown = 6.0
	is_discovered = true
	Sfx.play(discovery_sound)
	react()
	discovered.emit(self)


func react() -> void:
	var colors: Array[Color] = []
	for hex in COLORS:
		colors.append(Color(hex))
	for k in 3:
		var burst := PickupBurst.new(40, 24.0, colors)
		burst.position = Vector3(0, 40 + k * 25, 0)
		add_child(burst)
