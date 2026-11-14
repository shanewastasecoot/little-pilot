class_name CityPointer
extends Control
## Top-centre guide during a city celebration: a big arrow pointing towards
## the city (relative to where the camera looks) and the seconds left until
## the fireworks start in a bubble. Shows a sparkly star when they've begun.

var angle: float = 0.0      # radians, 0 = straight ahead, + = to the right
var seconds_left: int = 30
var fireworks_on := false
## Parent setting: hide the arrow (the countdown bubble still shows).
var show_arrow := true
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -110
	offset_right = 110
	offset_top = 18
	offset_bottom = 238


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var c := Vector2(110, 110)
	# Bubble with the countdown (or a star once the show is on).
	draw_circle(c, 52.0, Color(0.08, 0.15, 0.3, 0.55))
	draw_arc(c, 52.0, 0, TAU, 48, Color.WHITE, 5.0, true)
	if fireworks_on:
		var pulse := 1.0 + sin(_t * 8.0) * 0.12
		draw_colored_polygon(UiIcon.star_points(c, 38.0 * pulse, 17.0 * pulse, _t), Color("ffd23f"))
	else:
		var font := get_theme_default_font()
		var txt := str(seconds_left)
		var size := 52
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string_outline(font, c + Vector2(-w * 0.5, size * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 10, Color(0.1, 0.15, 0.3))
		draw_string(font, c + Vector2(-w * 0.5, size * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)
	if not show_arrow:
		return
	# Arrow orbiting the bubble, pointing at the city. Bobs to draw the eye.
	var dir := Vector2(sin(angle), -cos(angle))
	var bob := 6.0 + sin(_t * 6.0) * 5.0
	var tip := c + dir * (98.0 + bob)
	var base := c + dir * (64.0 + bob)
	var side := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([tip, base + side * 26.0, base + dir * 8.0, base - side * 26.0])
	draw_colored_polygon(pts, Color("ffd23f"))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0.1, 0.15, 0.3), 4.0, true)
