class_name Celebration
extends Control
## Full-screen, non-blocking party: a big star pops in the middle and little
## stars shoot outward. Never takes input; play continues underneath.

const COLORS: Array[Color] = [Color("ffd23f"), Color("ff5a5f"), Color("4cc06a"), Color("4aa8ff"), Color("9b5de5")]

var _t: float = -1.0
var _duration: float = 1.6
var _big: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func play(big: bool) -> void:
	_big = big
	_duration = 3.0 if big else 1.6
	_t = 0.0


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	if _t > _duration:
		_t = -1.0
	queue_redraw()


func _draw() -> void:
	if _t < 0.0:
		return
	var p := _t / _duration
	var c := size * 0.5
	var fade := 1.0 - smoothstep(0.7, 1.0, p)
	# Burst of small stars
	var n := 28 if _big else 14
	for i in n:
		var a := TAU * i / n + (0.4 if i % 2 else 0.0)
		var dist := ease(minf(p * 1.6, 1.0), 0.4) * size.y * (0.75 if _big else 0.45) * (0.7 + 0.3 * (i % 3) / 2.0)
		var col: Color = COLORS[i % COLORS.size()] if _big else COLORS[0]
		col.a = fade
		draw_colored_polygon(UiIcon.star_points(c + Vector2(cos(a), sin(a)) * dist, 22.0, 10.0, _t * 3.0), col)
	# Big centre star: pop in, wobble, shrink away
	var grow := ease(minf(p * 5.0, 1.0), -2.0) * (1.0 - smoothstep(0.6, 1.0, p))
	var r := size.y * (0.22 if _big else 0.14) * grow
	if r > 1.0:
		draw_colored_polygon(UiIcon.star_points(c, r, r * 0.45, sin(_t * 6.0) * 0.15), Color(1, 0.82, 0.25, fade))
