class_name StickHint
extends Control
## Animated thumbstick (bottom centre) shown when nobody has touched the
## controls for a while: "push the stick to fly". Fades in and out.

var _t := 0.0
var _alpha := 0.0
var showing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -80
	offset_right = 80
	offset_top = -210
	offset_bottom = -50


## Hide instantly (menus/pause), without the fade.
func hide_now() -> void:
	showing = false
	_alpha = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	_alpha = move_toward(_alpha, 1.0 if showing else 0.0, delta * 2.0)
	if _alpha <= 0.0:
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	if _alpha <= 0.0:
		return
	var c := size * 0.5
	draw_circle(c, 70.0, Color(0, 0, 0, 0.3 * _alpha))
	draw_arc(c, 70.0, 0, TAU, 40, Color(1, 1, 1, 0.8 * _alpha), 5.0, true)
	# Knob traces a slow plus-shape: up, back, left, back, right...
	var phase := fmod(_t * 0.8, 4.0)
	var dirs := [Vector2.UP, Vector2.LEFT, Vector2.DOWN, Vector2.RIGHT]
	var d: Vector2 = dirs[int(phase)]
	var push := sin(fmod(phase, 1.0) * PI)
	draw_circle(c + d * 38.0 * push, 30.0, Color(1, 0.82, 0.25, _alpha))
	draw_circle(c + d * 38.0 * push, 30.0 * 0.55, Color(1, 0.9, 0.5, _alpha))
