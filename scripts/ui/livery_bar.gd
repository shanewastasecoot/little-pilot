class_name LiveryBar
extends Control
## Under the planes on the plane-select screen (Phase 13), all pictures: the
## trim colour (with the X button) and the six decals in a row (with LB / RB):
## the one being worn is big with a white ring; ones not earned yet are grey
## with a little padlock and the stars they need. The basic colours are
## never locked.

var decal := "none"
var trim := Color.WHITE
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_for(d: String, t: Color) -> void:
	decal = d
	trim = t
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	var cy := s.y * 0.5
	# Trim colour, with the X button.
	var tx := 70.0
	_button(Vector2(tx - 40, cy), "X", Color("4aa8ff"))
	draw_circle(Vector2(tx + 20, cy), 26.0, Color.WHITE)
	draw_circle(Vector2(tx + 20, cy), 22.0, trim)
	# The decals, with LB and RB either side.
	var n := Livery.DECALS.size()
	var gap := 78.0
	var x0 := s.x * 0.5 - (n - 1) * gap * 0.5 + 40.0
	_button(Vector2(x0 - 70, cy), "LB", Color("8a94a6"))
	_button(Vector2(x0 + (n - 1) * gap + 70, cy), "RB", Color("8a94a6"))
	for i in n:
		var d: String = Livery.DECALS[i]
		var c := Vector2(x0 + i * gap, cy)
		var on := d == decal
		var open := Livery.unlocked(d)
		var r := 30.0 if on else 24.0
		if on:
			r += sin(_t * 6.0) * 2.0
			draw_circle(c, r + 6.0, Color.WHITE)
		draw_circle(c, r, Color("2a2c3a"))
		_decal_icon(d, c, r * 0.7, trim if open else Color(0.45, 0.47, 0.52))
		if not open:
			_padlock(c + Vector2(r * 0.55, r * 0.55), 9.0)
			var need := str(Livery.NEEDS[d])
			draw_colored_polygon(UiIcon.star_points(c + Vector2(-8, r + 16), 9.0, 4.0), Color("ffd23f"))
			draw_string(get_theme_default_font(), c + Vector2(4, r + 22), need, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)


func _decal_icon(d: String, c: Vector2, r: float, col: Color) -> void:
	match d:
		"none":
			draw_arc(c, r * 0.7, 0, TAU, 20, Color(1, 1, 1, 0.5), 3.0)
		"stripe":
			draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), col, r * 0.35)
		"checker":
			for i in 3:
				for j in 3:
					var sq := Rect2(c + Vector2(-r + i * r * 0.67, -r + j * r * 0.67), Vector2(r * 0.67, r * 0.67))
					draw_rect(sq, col if (i + j) % 2 == 0 else Color.WHITE)
		"rescue":
			draw_rect(Rect2(c + Vector2(-r * 0.3, -r), Vector2(r * 0.6, r * 2.0)), col)
		"letters":
			draw_string(get_theme_default_font(), c + Vector2(-r, r * 0.4), "AB", HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 1.2), col)
		"star":
			draw_colored_polygon(UiIcon.star_points(c, r, r * 0.45), Color("ffd23f") if col != Color(0.45, 0.47, 0.52) else col)


func _padlock(c: Vector2, s: float) -> void:
	draw_arc(c + Vector2(0, -s * 0.4), s * 0.55, PI, TAU, 10, Color.WHITE, 2.5)
	draw_rect(Rect2(c + Vector2(-s * 0.75, -s * 0.4), Vector2(s * 1.5, s * 1.2)), Color("ffd23f"))


func _button(c: Vector2, label: String, col: Color) -> void:
	draw_circle(c, 22.0, Color("1c1d26"))
	draw_arc(c, 22.0, 0, TAU, 24, col, 3.0)
	var w := get_theme_default_font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(get_theme_default_font(), c + Vector2(-w * 0.5, 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
