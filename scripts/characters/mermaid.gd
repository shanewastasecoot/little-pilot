class_name Mermaid
extends Node3D
## A reusable mermaid built on a rigged, textured model (Mixamo skeleton).
## The AnimationPlayer's clips are bone-rotation tracks generated once from
## the pose tables below and shared by every mermaid; an AnimationTree state
## machine blends between them:
##   idle  - sitting, gentle breathing, head tilt and tail swish
##   wave  - raises her right arm and waves, turning to face `look_target`
## Call set_waving(true/false) (MermaidWatcher does this for you), or set the
## `waving` property from an AnimationPlayer. set_swimming() switches to a
## static diving pose for mermaids that leap out of the sea.
##
## Units: the scene is about 3 units long (head to tail tip) with the origin
## on the ground under her hips, so `scale` sets her size and `position` is
## where she sits.

const MODEL := "res://assets/environment/mermaid_hd.glb"
const SKELETON := "Sketchfab_model/Root/Armature_fix/Skeleton3D"
const MODEL_SCALE := 0.23
## Hips sit this far above the origin so the tail rests on the ground.
const SEAT_LIFT := 0.12
## Hip bone height/depth in model units (keeps the origin at her seat).
const HIP := Vector3(0.0133, 7.746, -0.125)
## Model-space height below which the texture is tail (for recolouring).
const TAIL_TOP := 6.9
## The model's own tail hue (orange).
const BASE_TAIL_HUE := 0.085

## Pose tables: bone -> Euler offset (radians) from the bone's rest pose.
## "sit" is the base every sitting clip is built on.
const SIT := {
	"LeftUpLeg": Vector3(1.55, 0.0, 0.3),
	"LeftLeg": Vector3(0.15, 0.0, 0.2),
	"LeftFoot": Vector3(0.35, 0.0, 0.0),
	"Spine": Vector3(-0.08, 0.0, 0.0),
	"LeftArm": Vector3(-0.25, 0.0, -0.55),
	"LeftForeArm": Vector3(0.0, -0.5, 0.0),
	"RightArm": Vector3(-0.25, 0.0, 0.55),
	"RightForeArm": Vector3(0.0, 0.5, 0.0),
}
const SWIM := {
	"LeftArm": Vector3(-2.6, 0.0, -0.25),
	"RightArm": Vector3(-2.6, 0.0, 0.25),
	"Head": Vector3(-0.3, 0.0, 0.0),
	"LeftLeg": Vector3(-0.15, 0.0, 0.0),
}
## Keyframes per clip: [time, {bone: offset added to SIT}].
const IDLE_KEYS := [
	[0.0, {"Spine1": Vector3(0.0, 0.0, 0.03), "Head": Vector3(0.0, 0.1, 0.08), "LeftLeg": Vector3(0.0, 0.0, 0.0), "LeftFoot": Vector3(0.0, 0.0, 0.0)}],
	[1.5, {"Spine1": Vector3(0.03, 0.0, -0.03), "Head": Vector3(0.05, -0.1, -0.06), "LeftLeg": Vector3(0.0, 0.0, 0.12), "LeftFoot": Vector3(0.35, 0.0, 0.0)}],
	[3.0, {"Spine1": Vector3(0.0, 0.0, 0.03), "Head": Vector3(0.0, 0.1, 0.08), "LeftLeg": Vector3(0.0, 0.0, 0.0), "LeftFoot": Vector3(0.0, 0.0, 0.0)}],
]
const WAVE_KEYS := [
	[0.0, {"RightArm": Vector3(-1.25, 0.0, 0.75), "RightForeArm": Vector3(0.0, 0.3, -0.25), "RightHand": Vector3(0.0, 0.0, 0.2), "Head": Vector3(0.0, 0.0, 0.1), "Spine1": Vector3(0.0, 0.0, 0.05)}],
	[0.35, {"RightArm": Vector3(-1.25, 0.0, 0.75), "RightForeArm": Vector3(0.0, 0.3, -1.05), "RightHand": Vector3(0.0, 0.0, -0.2), "Head": Vector3(0.0, 0.0, 0.1), "Spine1": Vector3(0.0, 0.0, 0.05)}],
	[0.7, {"RightArm": Vector3(-1.25, 0.0, 0.75), "RightForeArm": Vector3(0.0, 0.3, -0.25), "RightHand": Vector3(0.0, 0.0, 0.2), "Head": Vector3(0.0, 0.0, 0.1), "Spine1": Vector3(0.0, 0.0, 0.05)}],
]

const SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform float hue_shift = 0.0;
vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}
vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	vec3 col = tex.rgb;
	if (COLOR.r > 0.5 && hue_shift != 0.0) {
		vec3 hsv = rgb2hsv(col);
		if (hsv.y > 0.3) {
			hsv.x = fract(hsv.x + hue_shift);
			col = hsv2rgb(hsv);
		}
	}
	ALBEDO = col;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.75;
}
"""

static var _mesh: ArrayMesh
static var _library: AnimationLibrary
static var _shader: Shader
static var _materials := {}

@export var tail_color: Color = Color("ff7eb9")
## Turn to face this while waving (usually the player's plane).
@export var look_target: Node3D
@export var turn_speed := 2.5
@export var waving := false:
	set(v):
		waving = v
		_apply_state()

var _home_yaw := 0.0
var _playback: AnimationNodeStateMachinePlayback
var _skeleton: Skeleton3D
var _swimming := false

@onready var model: Node3D = $Model
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var anim_tree: AnimationTree = $AnimationTree


func _ready() -> void:
	var rig: Node3D = load(MODEL).instantiate()
	rig.name = "Rig"
	rig.scale = Vector3.ONE * MODEL_SCALE
	rig.position = -HIP * MODEL_SCALE + Vector3(0, SEAT_LIFT, 0)
	model.add_child(rig)
	# Only the mermaid herself: drop the sample backdrop, bubbles and clip.
	for n in ["Sketchfab_model/Root/back", "Sketchfab_model/Root/Armature_puz", "AnimationPlayer"]:
		var junk := rig.get_node_or_null(n)
		if junk:
			junk.free()
	_skeleton = rig.get_node(SKELETON)
	var mi: MeshInstance3D = _skeleton.get_node("mermaid_0")
	mi.mesh = _fixed_mesh(mi.mesh)
	mi.material_override = _material_for(tail_color)
	mi.visibility_range_end = 1400.0
	_skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE

	if _library == null:
		_library = _build_library(_skeleton)
	anim_player.add_animation_library("", _library)
	_apply_pose(SIT, {})
	_home_yaw = rotation.y
	_playback = anim_tree.get("parameters/playback")
	anim_tree.active = true
	# Stagger so a row of mermaids doesn't sway in lockstep.
	anim_tree.advance(randf() * 3.0)
	_apply_state()
	if _swimming:
		set_swimming()


func set_waving(on: bool) -> void:
	if on != waving:
		waving = on


## Pause all animation work when far away (MermaidWatcher calls this).
func set_active(on: bool) -> void:
	if _swimming or not is_node_ready():
		return
	anim_tree.active = on
	set_process(on)


## Static diving pose (arms forward, tail straight) for leaping mermaids.
## She lies along +Z (head first), belly down; no animation runs.
func set_swimming() -> void:
	_swimming = true
	if not is_node_ready():
		return  # applied in _ready
	anim_tree.active = false
	set_process(false)
	_apply_pose(SWIM, {})
	model.basis = Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))


func _apply_state() -> void:
	if _playback:
		_playback.travel("wave" if waving else "idle")


func _process(delta: float) -> void:
	var target_yaw := _home_yaw
	if waving and look_target:
		var to := look_target.global_position - global_position
		target_yaw = atan2(to.x, to.z)  # the model faces +Z
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


func _apply_pose(base: Dictionary, extra: Dictionary) -> void:
	for b in _skeleton.get_bone_count():
		_skeleton.set_bone_pose_rotation(b, _skeleton.get_bone_rest(b).basis.get_rotation_quaternion())
	for bone in _merge(base, extra):
		var i := _bone_index(_skeleton, bone)
		_skeleton.set_bone_pose_rotation(i, _pose_quat(_skeleton, i, _merge(base, extra)[bone]))


static func _merge(base: Dictionary, extra: Dictionary) -> Dictionary:
	var out := base.duplicate()
	for k in extra:
		out[k] = out.get(k, Vector3.ZERO) + extra[k]
	return out


static func _bone_index(sk: Skeleton3D, bone: String) -> int:
	return sk.find_bone("mixamorig_%s_Armature_fix" % bone)


static func _pose_quat(sk: Skeleton3D, i: int, offset: Vector3) -> Quaternion:
	return sk.get_bone_rest(i).basis.get_rotation_quaternion() * Quaternion.from_euler(offset)


## Bone tracks for "idle" and "wave", built from the key tables on top of SIT.
static func _build_library(sk: Skeleton3D) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", _clip(sk, IDLE_KEYS))
	lib.add_animation("wave", _clip(sk, WAVE_KEYS))
	return lib


static func _clip(sk: Skeleton3D, keys: Array) -> Animation:
	var anim := Animation.new()
	anim.length = keys[-1][0]
	anim.loop_mode = Animation.LOOP_LINEAR
	var bones := {}
	for bone in SIT:
		bones[bone] = true
	for k in keys:
		for bone in k[1]:
			bones[bone] = true
	for bone in bones:
		var i := _bone_index(sk, bone)
		var t := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(t, NodePath("Model/Rig/%s:%s" % [SKELETON, sk.get_bone_name(i)]))
		anim.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
		for k in keys:
			var off: Vector3 = SIT.get(bone, Vector3.ZERO) + k[1].get(bone, Vector3.ZERO)
			anim.rotation_track_insert_key(t, k[0], _pose_quat(sk, i, off))
	return anim


## The model's mesh with two skinning faults repaired (one unweighted vertex
## that collapses to the floor, and skirt vertices tied to the right thumb)
## plus a vertex-colour mask marking the tail for recolouring.
static func _fixed_mesh(src: Mesh) -> ArrayMesh:
	if _mesh:
		return _mesh
	var a := src.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var wts: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var per := bones.size() / v.size()
	for vi in v.size():
		var total := 0.0
		for j in per:
			total += wts[vi * per + j]
		var bad := total < 0.5 or (absf(v[vi].x) < 2.2 and v[vi].y < 7.0 and _has_far_bone(bones, wts, vi, per))
		if not bad:
			continue
		# Copy the weights of the nearest healthy vertex.
		var best := -1
		var best_d := INF
		for vj in v.size():
			if vj == vi or v[vj].distance_squared_to(v[vi]) >= best_d:
				continue
			var tj := 0.0
			for j in per:
				tj += wts[vj * per + j]
			if tj > 0.5 and not _has_far_bone(bones, wts, vj, per):
				best = vj
				best_d = v[vj].distance_squared_to(v[vi])
		if best >= 0:
			for j in per:
				bones[vi * per + j] = bones[best * per + j]
				wts[vi * per + j] = wts[best * per + j]
	a[Mesh.ARRAY_BONES] = bones
	a[Mesh.ARRAY_WEIGHTS] = wts
	var colors := PackedColorArray()
	colors.resize(v.size())
	for vi in v.size():
		colors[vi] = Color.WHITE if v[vi].y < TAIL_TOP else Color.BLACK
	a[Mesh.ARRAY_COLOR] = colors
	a[Mesh.ARRAY_CUSTOM0] = null  # unused extra channel (needs format flags)
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	_mesh.surface_set_material(0, src.surface_get_material(0))
	return _mesh


## True if the vertex leans on a hand bone (bind indices 12-56 are the hands
## and fingers in this rig; the bad skirt vertices use the right thumb).
static func _has_far_bone(bones: PackedInt32Array, wts: PackedFloat32Array, vi: int, per: int) -> bool:
	for j in per:
		var b := bones[vi * per + j]
		if wts[vi * per + j] > 0.01 and ((b >= 12 and b <= 32) or (b >= 36 and b <= 56)):
			return true
	return false


static func _material_for(tail: Color) -> ShaderMaterial:
	var shift := snappedf(wrapf(tail.h - BASE_TAIL_HUE, -0.5, 0.5), 0.01) if tail.s > 0.2 else 0.0
	if _materials.has(shift):
		return _materials[shift]
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var src: Mesh = _mesh
	var base := src.surface_get_material(0) as BaseMaterial3D
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("albedo_tex", base.albedo_texture)
	mat.set_shader_parameter("hue_shift", shift)
	_materials[shift] = mat
	return mat
