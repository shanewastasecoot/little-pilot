class_name Shopkeeper
extends Node3D
## The person who runs a building (a KayKit character, e.g. the postie
## behind the post office counter). Idles at their spot; when Sophia comes
## near they turn to her and cheer, and on her very first visit to this kind
## of building they give her its sticker (SaveManager.stickers, shown big on
## the HUD). Origin on the floor; faces +Z (yaw) at home.

signal gave_sticker(id: String)

const NOTICE := 14.0
const TURN_RATE := 5.0
const GREET_EVERY := 25.0

var look: OutfitData
var head: Array = []
## The sticker for this kind of building ("post_office", ...).
var sticker := ""
var model: CharacterModel
var _home_yaw := 0.0
var _want_yaw := 0.0
var _cool := 0.0
var _player: Node3D
var _t := 0.0


func _ready() -> void:
	model = (load("res://scenes/characters/player_character.tscn") as PackedScene).instantiate() as CharacterModel
	model.look_override = look
	model.head_override = head
	add_child(model)
	# The model faces -Z at yaw 0 (like the walker); home is facing +Z.
	_home_yaw = PI
	_want_yaw = _home_yaw
	model.rotation.y = _home_yaw


func _physics_process(delta: float) -> void:
	_cool -= delta
	model.rotation.y = lerp_angle(model.rotation.y, _want_yaw, 1.0 - exp(-TURN_RATE * delta))
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.15
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player_focus") as Node3D
		return
	var to := _player.global_position - global_position
	to.y = 0.0
	if to.length() < NOTICE and absf(_player.global_position.y - global_position.y) < 4.0:
		_want_yaw = atan2(-to.x, -to.z)
		if _cool <= 0.0:
			greet()
	else:
		_want_yaw = _home_yaw


## A cheer (and the sticker the first time she's ever been in).
func greet() -> void:
	_cool = GREET_EVERY
	model.play("Cheer")
	get_tree().create_timer(2.4, false).timeout.connect(func(): model.play("Idle"))
	var hearts := PickupBurst.new(14, 6.0, [Color("ff5fa2"), Color("ff9ecb")])
	hearts.position = Vector3(0, 6.0, 0)
	add_child(hearts)
	if sticker != "" and SaveManager.add_sticker(sticker):
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_sticker"):
			hud.show_sticker(sticker)
		gave_sticker.emit(sticker)


func reset() -> void:
	_cool = 0.0
	_want_yaw = _home_yaw
