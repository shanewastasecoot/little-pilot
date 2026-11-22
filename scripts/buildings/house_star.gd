class_name HouseStar
extends Node3D
## The hidden star in her house: a spinning golden star tucked away in a
## corner. Walk into it for a sparkle, a chime and reward stars into the jar
## (not one of the 220 floating stars). It's back next time you come in.

signal found

const REWARD := 3
## How high it floats (small houses: lower, under the windows).
var height := 2.5

var _star: MeshInstance3D
var _t := 0.0
var _taken := false


func _ready() -> void:
	_star = MeshInstance3D.new()
	_star.mesh = StarMesh.build(1.4, 0.6, 0.5)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("ffd23f")
	m.emission_enabled = true
	m.emission = Color("ffb800")
	m.emission_energy_multiplier = 0.8
	_star.material_override = m
	_star.position.y = height
	add_child(_star)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = GameSettings.LAYER_PLAYER
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 2.2
	cs.shape = s
	cs.position.y = minf(2.0, height)
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(func(b): if b is Walker: take())


func is_taken() -> bool:
	return _taken


func take() -> void:
	if _taken:
		return
	_taken = true
	_star.visible = false
	var burst := PickupBurst.new(40, 10.0)
	burst.position = Vector3(0, 2.5, 0)
	add_child(burst)
	Sfx.play("chime", 1.5)
	Sfx.play("jingle")
	var main := get_tree().current_scene
	if main and main.get("stars") != null:
		main.stars.add_bonus(REWARD)
	found.emit()


func reset() -> void:
	_taken = false
	_star.visible = true


func _process(delta: float) -> void:
	if _taken:
		return
	_t += delta
	_star.rotation.y = _t * 2.0
	_star.position.y = height + sin(_t * 2.5) * 0.3
