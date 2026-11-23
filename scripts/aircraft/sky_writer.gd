class_name SkyWriter
extends Node3D
## Sky-writing (Phase 14): hold RB while flying and the plane leaves a trail
## of smoke puffs in its paint colour that hangs in the sky for about a
## minute, slowly spreading and fading. RB is free while flying (it only
## changes tabs and decals on menu screens), so it never clashes with A
## (boost), B (honk), X (roll) or Y (get out).
##
## All the puffs are one MultiMesh (one draw call, up to MAX puffs); their
## fade is updated a few times a second, not every frame.

const MAX := 1300
const EVERY := 0.05
const LIFE := 60.0
const FADE := 12.0          # the last seconds fade out
const SIZE := 7.0
const GROW := 3.0           # grows to SIZE * (1 + GROW) by the end

var aircraft: Aircraft
var writing := false
var _mm: MultiMesh
var _born: PackedFloat32Array
var _colour: Array[Color] = []
var _next := 0
var _count := 0
var _t := 0.0
var _emit_t := 0.0
var _fade_t := 0.0
var _clock := 0.0


func _ready() -> void:
	top_level = true
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = PickupBurst._soft_dot()
	quad.material = mat
	_mm.mesh = quad
	_mm.instance_count = MAX
	_mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-6000, -100, -6000), Vector3(12000, 1500, 12000))
	add_child(mmi)
	_born.resize(MAX)
	_colour.resize(MAX)


func _process(delta: float) -> void:
	_clock += delta
	var held := Input.is_action_pressed("tab_next") and aircraft != null and not aircraft.input.override_enabled
	writing = aircraft != null and aircraft.mode == Aircraft.Mode.FLYING and (held or force)
	if writing:
		_emit_t -= delta
		if _emit_t <= 0.0:
			_emit_t = EVERY
			_puff()
	_fade_t -= delta
	if _fade_t <= 0.0:
		_fade_t = 0.25
		_refresh()


## (Tests) write as if RB were held.
var force := false


## How many puffs are in the sky.
func puffs() -> int:
	var n := 0
	for i in _count:
		if _clock - _born[i] < LIFE:
			n += 1
	return n


## (Tests) jump the clock forward.
func age(secs: float) -> void:
	_clock += secs
	_refresh()


func _puff() -> void:
	var back := aircraft.global_transform.basis.z * 3.5
	var p := aircraft.global_position + back + Vector3(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4), randf_range(-0.4, 0.4))
	var c := Paint.color(SaveManager.get_paint(aircraft.stats.id, aircraft.stats.default_paint)).lightened(0.25)
	_born[_next] = _clock
	_colour[_next] = c
	_mm.set_instance_transform(_next, Transform3D(Basis().scaled(Vector3.ONE * SIZE), p))
	_mm.set_instance_color(_next, c)
	_next = (_next + 1) % MAX
	_count = mini(_count + 1, MAX)
	_mm.visible_instance_count = _count


## Grow and fade every puff by its age.
func _refresh() -> void:
	for i in _count:
		var a := _clock - _born[i]
		var c := _colour[i]
		if a >= LIFE:
			c.a = 0.0
		else:
			c.a = 0.95 * clampf((LIFE - a) / FADE, 0.0, 1.0)
		_mm.set_instance_color(i, c)
		var xf := _mm.get_instance_transform(i)
		var s := SIZE * (1.0 + GROW * clampf(a / LIFE, 0.0, 1.0))
		_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), xf.origin))
