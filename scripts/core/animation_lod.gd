class_name AnimationLod
extends Node
## Graphics G1: animations far from the camera are updated less often.
## Every AnimationPlayer / AnimationTree in the world (mermaids, dolphins,
## townspeople, farm animals, dinosaurs, the dragon) used to animate every
## frame wherever the camera was: 164 of them, about 1.5 ms a frame.
##
## - nearer than NEAR: every frame, as before (the engine does it).
## - out to FAR: every third frame, three frames' worth at a time (too far
##   to see the difference).
## - beyond FAR: paused where they are, and carried on when you come back.
##
## Nothing in the game waits for an animation to finish, so this only
## changes how often far-away poses are worked out. Picks up animations
## added later (characters rebuilt, houses entered) by itself.

const NEAR := 120.0
const FAR := 450.0
## How many animations get their distance re-checked each frame.
const CHECKS_PER_FRAME := 24

enum { FULL, THIRD, PAUSED }

## [mixer, its Node3D (for the distance), tier, unspent time]
var _list: Array = []
var _next := 0
var _frame := 0


func _ready() -> void:
	for m in get_tree().root.find_children("*", "AnimationMixer", true, false):
		_add(m)
	get_tree().node_added.connect(func(n: Node):
		if n is AnimationMixer:
			_add.call_deferred(n))


func _add(obj: Variant) -> void:
	# (Untyped: it may have been freed before this deferred call.)
	if not is_instance_valid(obj) or not obj is AnimationMixer:
		return
	var m: AnimationMixer = obj
	if not m.is_inside_tree():
		return
	for e in _list:
		if e[0] == m:
			return
	if m.callback_mode_process != AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE:
		return  # (physics or already manual: someone else drives it)
	var at: Node = m.get_parent()
	while at and not at is Node3D:
		at = at.get_parent()
	if at == null:
		return
	_list.append([m, at, FULL, 0.0])


## How many animations are in each tier (for the tests and the bench).
func counts() -> Array[int]:
	var c: Array[int] = [0, 0, 0]
	for e in _list:
		c[e[2]] += 1
	return c


func _process(delta: float) -> void:
	_frame += 1
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye := cam.global_position
	# Re-check a few distances each frame (round-robin).
	var i := 0
	while i < CHECKS_PER_FRAME and not _list.is_empty():
		_next = _next % _list.size()
		var e: Array = _list[_next]
		if not is_instance_valid(e[0]) or not is_instance_valid(e[1]) or not (e[0] as Node).is_inside_tree():
			if is_instance_valid(e[0]) and e[2] != FULL:
				(e[0] as AnimationMixer).callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
			_list.remove_at(_next)
			continue
		var d2 := ((e[1] as Node3D).global_position - eye).length_squared()
		var tier := FULL if d2 < NEAR * NEAR else (THIRD if d2 < FAR * FAR else PAUSED)
		if tier != e[2]:
			var m: AnimationMixer = e[0]
			if tier == FULL:
				m.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
				if e[3] > 0.0:
					m.advance(e[3])
			elif e[2] == FULL:
				m.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			e[2] = tier
			e[3] = 0.0
		_next += 1
		i += 1
	# Advance the every-third-frame ones (spread over the three frames).
	for k in _list.size():
		var e: Array = _list[k]
		if e[2] != THIRD:
			continue
		e[3] += delta
		if (k + _frame) % 3 == 0 and is_instance_valid(e[0]):
			(e[0] as AnimationMixer).advance(e[3])
			e[3] = 0.0
