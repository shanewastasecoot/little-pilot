class_name Mermaid
extends Node3D
## A reusable mermaid. Builds her mesh from the low-poly model (body, a
## waving arm on its own shoulder pivot, and an optional fish friend),
## then drives an AnimationTree state machine with two states:
##   idle  - gentle sway and tail swish
##   wave  - raises her arm and waves, turning to face `look_target`
## Call set_waving(true/false) (MermaidWatcher does this for you), or set
## the `waving` property from an AnimationPlayer. To swap in another model,
## change MODEL and the part names below.

const MODEL := "res://assets/environment/mermaid.glb"
## Right arm + hand meshes in the model, and where the shoulder is.
const ARM_PARTS: PackedStringArray = ["group22092427", "group2108276498"]
const SHOULDER := Vector3(0.24, 0.28, 0.0)
## The little fish that swims with her in the original pose.
const FISH_PARTS: PackedStringArray = ["group1745740949"]
## Extra yaw (radians) if a swapped-in model doesn't face -Z.
const FACE_YAW := 0.0

@export var tail_color: Color = Color("ff7eb9")
@export var show_fish := false
## Turn to face this while waving (usually the player's plane).
@export var look_target: Node3D
@export var turn_speed := 2.5
@export var waving := false:
	set(v):
		waving = v
		_apply_state()

var _home_yaw := 0.0
var _playback: AnimationNodeStateMachinePlayback

@onready var body: MeshInstance3D = $Model/Body
@onready var arm: MeshInstance3D = $Model/ArmPivot/Arm
@onready var fish: MeshInstance3D = $Model/Fish
@onready var anim_tree: AnimationTree = $AnimationTree


func _ready() -> void:
	var skip := ARM_PARTS.duplicate()
	if not show_fish:
		skip.append_array(FISH_PARTS)
	body.mesh = AssetLib.merged_mesh(MODEL, 0.24, 0.08, tail_color, [], skip + FISH_PARTS)
	arm.mesh = AssetLib.merged_mesh(MODEL, -1.0, 0.0, Color.WHITE, ARM_PARTS, [], -SHOULDER)
	($Model/ArmPivot as Node3D).position = SHOULDER
	fish.visible = show_fish
	if show_fish:
		fish.mesh = AssetLib.merged_mesh(MODEL, -1.0, 0.0, Color.WHITE, FISH_PARTS)
	_home_yaw = rotation.y
	_playback = anim_tree.get("parameters/playback")
	# Stagger so a row of mermaids doesn't sway in lockstep.
	anim_tree.advance(randf() * 2.0)
	_apply_state()


func set_waving(on: bool) -> void:
	if on != waving:
		waving = on


## Pause all animation work when far away (MermaidWatcher calls this).
func set_active(on: bool) -> void:
	anim_tree.active = on
	set_process(on)


func _apply_state() -> void:
	if _playback:
		_playback.travel("wave" if waving else "idle")


func _process(delta: float) -> void:
	var target_yaw := _home_yaw
	if waving and look_target:
		var to := look_target.global_position - global_position
		target_yaw = atan2(-to.x, -to.z) + FACE_YAW  # the model faces -Z
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))
