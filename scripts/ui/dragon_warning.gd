class_name DragonWarning
extends Control
## "The dragon is after you!" A pulsing red-orange glow round the screen
## edges and a flame-coloured arrow on the edge pointing at the dragon
## (relative to where the camera looks). Brighter and faster while it
## winds up its fire breath, so kids learn to turn away in time.

## Radians: 0 = dead ahead, + = to the right, PI = behind.
var angle := 0.0
## 0..1 how close the dragon is (1 = right on top of you).
var closeness := 0.0
var breathing := false
var _t := 0.0
var _strength := 0.0
var active := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_strength = move_toward(_strength, 1.0 if active else 0.0, delta * 2.5)
	visible = _strength > 0.01
	if visible:
		_t += delta * (9.0 if breathing else 4.5)
		queue_redraw()


func _draw() -> void:
	var s := size
	var pulse := 0.55 + 0.45 * sin(_t)
	var a := _strength * (0.25 + 0.35 * closeness + (0.3 if breathing else 0.0)) * pulse
	var hot := Color(1.0, 0.25, 0.1, a)
	var clear := Color(1.0, 0.25, 0.1, 0.0)
	var w := 70.0 + 50.0 * closeness
	# Edge glow: four gradient bands.
	_band(Rect2(0, 0, s.x, w), hot, clear, true)
	_band(Rect2(0, s.y - w, s.x, w), clear, hot, true)
	_band(Rect2(0, 0, w, s.y), hot, clear, false)
	_band(Rect2(s.x - w, 0, w, s.y), clear, hot, false)
	# Arrow on an ellipse round the screen centre, pointing at the dragon.
	var c := s * 0.5
	var dir := Vector2(sin(angle), -cos(angle))
	var p := c + Vector2(dir.x * (s.x * 0.5 - 90.0), dir.y * (s.y * 0.5 - 90.0))
	var size_k := 1.0 + 0.15 * pulse
	var tip := p + dir * 46.0 * size_k
	var side := Vector2(-dir.y, dir.x) * 34.0 * size_k
	var back := p - dir * 22.0 * size_k
	var col := Color(1.0, 0.45, 0.1, _strength)
	draw_colored_polygon(PackedVector2Array([tip, back + side, p - dir * 6.0, back - side]), col)
	draw_polyline(PackedVector2Array([tip, back + side, p - dir * 6.0, back - side, tip]), Color(1, 1, 0.8, _strength), 4.0, true)
	# A little flame above the arrow.
	var f := p - dir * 52.0
	for k in 3:
		var r := (16.0 - k * 4.0) * (1.0 + 0.2 * sin(_t * 2.0 + k))
		draw_circle(f + Vector2(0, -k * 9.0), r, [Color(1, 0.35, 0.1, _strength), Color(1, 0.65, 0.15, _strength), Color(1, 0.95, 0.5, _strength)][k])


func _band(r: Rect2, from: Color, to: Color, vertical: bool) -> void:
	var pts := PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)])
	var cols: PackedColorArray
	if vertical:
		cols = PackedColorArray([from, from, to, to])
	else:
		cols = PackedColorArray([from, to, to, from])
	draw_polygon(pts, cols)
