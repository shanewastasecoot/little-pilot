class_name CharacterModel
extends Node3D
## The player's character, built in Blender (tools/blender/build_characters.py
## -> assets/characters/player/player.glb): one shared skeleton with two
## bodies, four hair styles and four outfits (each made for both bodies).
## apply() shows one body + one hair + the matching outfit and hides the
## rest. animate() picks Idle / Walk / Run / Jump from how the walker is
## moving and plays them at a speed that matches its feet to the ground.
## Origin at the feet; faces -Z like the walker. Scaled to storybook size.

const SCENE := "res://assets/characters/player/player.glb"
const BODIES := ["M", "F"]
const HAIRS := 4
const OUTFITS := 4
## The model is 1.85 m tall (toy proportions: big head, short legs): this
## makes it ~5 m like the townspeople.
const SCALE := Walker.HEIGHT / 1.85
## Ground speed (game m/s) at which each loop's feet don't slide.
## (Short toy legs: walk stride ~1.13 m per 0.83 s cycle and run ~1.6 m per
## 0.58 s at model scale, times SCALE.)
const WALK_NATURAL := 3.7
const RUN_NATURAL := 7.4
## Above this ground speed the walk becomes a run (sprint always runs).
const RUN_FROM := 7.5
const BLEND := 0.15

var body := "M"
var hair := 1
var outfit := 1
var anim := ""

var _model: Node3D
var _anim: AnimationPlayer


func _ready() -> void:
	_model = (load(SCENE) as PackedScene).instantiate()
	_model.scale = Vector3.ONE * SCALE
	_model.rotation.y = PI  # glTF faces +Z; the walker's forward is -Z
	add_child(_model)
	_anim = _model.find_children("*", "AnimationPlayer", true, false)[0]
	for a in ["Idle", "Walk", "Run"]:
		_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_anim.get_animation("Jump").loop_mode = Animation.LOOP_NONE
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mi.extra_cull_margin = 1.0  # limbs swing outside the rest pose
	apply(body, hair, outfit)
	play("Idle")


## Show this body (M/F), hair (1..4) and outfit (1..4). Bad values clamp.
func apply(new_body: String, new_hair: int, new_outfit: int) -> void:
	body = new_body if new_body in BODIES else "M"
	hair = clampi(new_hair, 1, HAIRS)
	outfit = clampi(new_outfit, 1, OUTFITS)
	if _model == null:
		return
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name)
		mi.visible = n == "Body_" + body or n == "Hair_%d" % hair or n == "Outfit_%d_%s" % [outfit, body]


## The parts that are showing (for tests): their names.
func visible_parts() -> Array[String]:
	var out: Array[String] = []
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		if mi.visible:
			out.append(String(mi.name))
	return out


## Pick the animation for this movement. speed: ground speed (m/s).
func animate(speed: float, on_floor: bool, rising: bool, sprinting: bool) -> void:
	if not on_floor:
		if anim != "Jump" and rising:
			play("Jump")
			_anim.speed_scale = 1.4
		elif anim != "Jump":
			play("Jump")
			_anim.seek(_anim.current_animation_length * 0.6, true)  # falling: tucked pose
		return
	if speed < 0.4:
		play("Idle")
		_anim.speed_scale = 1.0
	elif sprinting or speed > RUN_FROM:
		play("Run")
		_anim.speed_scale = clampf(speed / RUN_NATURAL, 0.6, 2.0)
	else:
		play("Walk")
		_anim.speed_scale = clampf(speed / WALK_NATURAL, 0.4, 1.9)


func play(name: String) -> void:
	if anim == name:
		return
	anim = name
	_anim.play(name, BLEND)
