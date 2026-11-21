class_name LightSwitch
extends Node3D
## A big light switch on a bedroom wall, by the door: walk up to it and the
## room's light goes off (the room dims), walk up again and it comes back
## on. Origin on the wall at switch height; the front faces +Z.

signal toggled(on: bool)

var light: OmniLight3D
## Materials of the room that darken when the light is off.
var materials: Array[StandardMaterial3D] = []
var on := true
var _colours: Array[Color] = []
var _lever: MeshInstance3D
var _armed := true


func _ready() -> void:
	var plate := BuildKit.add(self, BuildKit.box(Vector3(1.6, 2.2, 0.25)), "ffffff", Vector3(0, 0, 0.12))
	plate.material_override = BuildingGenerator._mat("ffffff")
	_lever = BuildKit.add(self, BuildKit.box(Vector3(0.6, 0.9, 0.35)), "ffd23f", Vector3(0, 0.35, 0.3))
	_lever.material_override = BuildingGenerator._mat("ffd23f")
	for m in materials:
		_colours.append(m.albedo_color)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = GameSettings.LAYER_PLAYER
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 2.4
	cs.shape = s
	cs.position = Vector3(0, -3.0, 1.5)
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(func(b): if b is Walker and _armed: _armed = false; set_on(not on))
	area.body_exited.connect(func(b): if b is Walker: _armed = true)


func set_on(value: bool) -> void:
	on = value
	if light:
		light.visible = on
	for i in materials.size():
		materials[i].albedo_color = _colours[i] if on else _colours[i].darkened(0.5)
	_lever.position.y = 0.35 if on else -0.35
	Sfx.play("ui_confirm" if on else "ui_back", 1.0, -4.0)
	toggled.emit(on)


func reset() -> void:
	if not on:
		set_on(true)
