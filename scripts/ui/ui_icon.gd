@tool
class_name UiIcon
extends Control
## Simple vector icons drawn in code, so menus need no text or image assets.
## Scales to the control's size.

enum Icon { STAR, PLAY, PLANE, QUIT, ARROW_LEFT, ARROW_RIGHT, GEAR, MUSIC, SPEAKER, BATTERY, POINTER, CRASH, DRAGON, FLAME, CITY, BUTTON_Y, PERSON, BUTTON_A, BUTTON_B, BUTTON_LB, BUTTON_RB, CHECK, CAMERA, INVERT_Y, JUMP, RUN, PARCEL }

@export var icon: Icon = Icon.STAR:
	set(v):
		icon = v
		queue_redraw()
@export var color: Color = Color.WHITE:
	set(v):
		color = v
		queue_redraw()
@export var outline_color: Color = Color(0, 0, 0, 0.35)
## Small dots drawn under the icon (e.g. difficulty 1-3).
@export var pips: int = 0:
	set(v):
		pips = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	if pips > 0:
		_draw_pips(c, s)
		c.y -= s * 0.08
		s *= 0.82
	match icon:
		Icon.STAR:
			_poly(star_points(c, s * 0.5, s * 0.22))
		Icon.PLAY:
			_poly(PackedVector2Array([c + Vector2(-0.28, -0.36) * s, c + Vector2(0.38, 0) * s, c + Vector2(-0.28, 0.36) * s]))
		Icon.ARROW_LEFT:
			_poly(PackedVector2Array([c + Vector2(0.25, -0.4) * s, c + Vector2(-0.3, 0) * s, c + Vector2(0.25, 0.4) * s]))
		Icon.ARROW_RIGHT:
			_poly(PackedVector2Array([c + Vector2(-0.25, -0.4) * s, c + Vector2(0.3, 0) * s, c + Vector2(-0.25, 0.4) * s]))
		Icon.PLANE:
			_draw_plane(c, s)
		Icon.QUIT:
			_draw_power(c, s)
		Icon.GEAR:
			_draw_gear(c, s)
		Icon.POINTER:
			# Countdown bubble with the guiding arrow above it (like the HUD).
			draw_arc(c + Vector2(0, 0.12) * s, s * 0.26, 0, TAU, 32, color, s * 0.07, true)
			_poly(PackedVector2Array([c + Vector2(0, -0.46) * s, c + Vector2(0.2, -0.2) * s, c + Vector2(0, -0.26) * s, c + Vector2(-0.2, -0.2) * s]))
		Icon.DRAGON:
			# A dragon's head in profile (facing right): two swept-back horns,
			# spikes down the neck, open jaws and a puff of fire.
			_poly(PackedVector2Array([c + Vector2(-0.20, -0.16) * s, c + Vector2(-0.48, -0.40) * s, c + Vector2(-0.10, -0.24) * s]))
			_poly(PackedVector2Array([c + Vector2(-0.06, -0.21) * s, c + Vector2(-0.26, -0.50) * s, c + Vector2(0.04, -0.22) * s]))
			_poly(PackedVector2Array([c + Vector2(-0.33, 0.04) * s, c + Vector2(-0.46, 0.08) * s, c + Vector2(-0.32, 0.14) * s]))
			_poly(PackedVector2Array([c + Vector2(-0.31, 0.20) * s, c + Vector2(-0.44, 0.26) * s, c + Vector2(-0.30, 0.29) * s]))
			_poly(PackedVector2Array([c + Vector2(-0.30, 0.38) * s, c + Vector2(-0.34, 0.0) * s, c + Vector2(-0.24, -0.18) * s,
				c + Vector2(0.0, -0.25) * s, c + Vector2(0.28, -0.14) * s, c + Vector2(0.38, -0.04) * s, c + Vector2(0.34, 0.03) * s,
				c + Vector2(0.06, 0.06) * s, c + Vector2(0.30, 0.15) * s, c + Vector2(0.26, 0.22) * s, c + Vector2(-0.04, 0.22) * s,
				c + Vector2(-0.10, 0.42) * s]))
			draw_circle(c + Vector2(-0.05, -0.12) * s, s * 0.05, Color(0.15, 0.1, 0.1))
			draw_circle(c + Vector2(0.31, -0.08) * s, s * 0.02, Color(0.15, 0.1, 0.1))
			draw_colored_polygon(_burst(c + Vector2(0.44, 0.10) * s, s * 0.13, s * 0.06, 7), Color("ff7b2e"))
			draw_colored_polygon(_burst(c + Vector2(0.44, 0.10) * s, s * 0.07, s * 0.035, 7), Color("ffd23f"))
		Icon.FLAME:
			var outer := PackedVector2Array()
			var inner := PackedVector2Array()
			for p in [Vector2(0, -0.48), Vector2(0.10, -0.30), Vector2(0.24, -0.14), Vector2(0.31, 0.06), Vector2(0.27, 0.24),
					Vector2(0.12, 0.36), Vector2(-0.12, 0.36), Vector2(-0.27, 0.24), Vector2(-0.31, 0.06), Vector2(-0.24, -0.10),
					Vector2(-0.14, -0.04), Vector2(-0.12, -0.22)]:
				outer.append(c + p * s)
				inner.append(c + (p * 0.5 + Vector2(0, 0.17)) * s)
			_poly(outer)
			draw_colored_polygon(inner, Color(1, 1, 1, 0.45))
		Icon.CRASH:
			# A "bonk" burst with a little plane nosing into it.
			_poly(_burst(c + Vector2(0.14, -0.06) * s, s * 0.32, s * 0.17, 9))
			_poly(PackedVector2Array([c + Vector2(-0.46, 0.34) * s, c + Vector2(-0.04, 0.06) * s, c + Vector2(0.0, 0.14) * s, c + Vector2(-0.4, 0.42) * s]))
			_poly(PackedVector2Array([c + Vector2(-0.3, 0.14) * s, c + Vector2(-0.18, 0.24) * s, c + Vector2(-0.12, 0.42) * s, c + Vector2(-0.24, 0.32) * s]))
		Icon.MUSIC:
			draw_circle(c + Vector2(-0.18, 0.22) * s, s * 0.13, color)
			draw_circle(c + Vector2(0.24, 0.14) * s, s * 0.13, color)
			draw_line(c + Vector2(-0.06, 0.22) * s, c + Vector2(-0.06, -0.34) * s, color, s * 0.07)
			draw_line(c + Vector2(0.36, 0.14) * s, c + Vector2(0.36, -0.42) * s, color, s * 0.07)
			_poly(PackedVector2Array([c + Vector2(-0.09, -0.34) * s, c + Vector2(0.39, -0.46) * s, c + Vector2(0.39, -0.3) * s, c + Vector2(-0.09, -0.18) * s]))
		Icon.SPEAKER:
			_poly(PackedVector2Array([c + Vector2(-0.4, -0.13) * s, c + Vector2(-0.2, -0.13) * s, c + Vector2(0.05, -0.36) * s, c + Vector2(0.05, 0.36) * s, c + Vector2(-0.2, 0.13) * s, c + Vector2(-0.4, 0.13) * s]))
			for k in 2:
				draw_arc(c + Vector2(0.05, 0) * s, s * (0.18 + k * 0.15), -0.8, 0.8, 12, color, s * 0.06)
		Icon.CITY:
			# A little skyline: three towers with windows on a ground line.
			for t in [[-0.40, -0.12, 0.22], [-0.14, -0.42, 0.26], [0.16, -0.24, 0.24]]:
				var r := Rect2(c + Vector2(t[0], t[1]) * s, Vector2(t[2], 0.36 - t[1]) * s)
				_poly(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))
				var y: float = t[1] + 0.08
				while y < 0.28:
					for wx in [0.05, t[2] - 0.11]:
						draw_rect(Rect2(c + Vector2(t[0] + wx, y) * s, Vector2(0.06, 0.06) * s), Color(0, 0, 0, 0.3))
					y += 0.13
			draw_line(c + Vector2(-0.46, 0.37) * s, c + Vector2(0.46, 0.37) * s, color, s * 0.05)
		Icon.BUTTON_Y:
			# The Xbox-style Y button: a dark disc with a yellow Y (the Deck's
			# Y is in the same place).
			draw_circle(c, s * 0.46, Color(0.12, 0.13, 0.16))
			draw_arc(c, s * 0.46, 0, TAU, 40, Color(1, 1, 1, 0.85), s * 0.05, true)
			var yc := Color("ffd23f")
			var w := s * 0.11
			draw_line(c + Vector2(-0.19, -0.24) * s, c + Vector2(0, 0.0) * s, yc, w, true)
			draw_line(c + Vector2(0.19, -0.24) * s, c + Vector2(0, 0.0) * s, yc, w, true)
			draw_line(c + Vector2(0, -0.02) * s, c + Vector2(0, 0.27) * s, yc, w, true)
		Icon.BUTTON_A:
			_face_button(c, s, "A", Color("4cc06a"))
		Icon.BUTTON_B:
			_face_button(c, s, "B", Color("ff5a5f"))
		Icon.BUTTON_LB, Icon.BUTTON_RB:
			# A shoulder button: a dark rounded bar with LB / RB on it.
			var r := Rect2(c + Vector2(-0.46, -0.24) * s, Vector2(0.92, 0.48) * s)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.12, 0.13, 0.16)
			sb.border_color = Color(1, 1, 1, 0.85)
			sb.set_border_width_all(maxi(int(s * 0.04), 2))
			sb.set_corner_radius_all(int(s * 0.2))
			draw_style_box(sb, r)
			_letters(c, s * 0.34, "LB" if icon == Icon.BUTTON_LB else "RB", Color.WHITE)
		Icon.CAMERA:
			# A little camera (with speed pips drawn under it by `pips`).
			_poly(PackedVector2Array([c + Vector2(-0.38, -0.2) * s, c + Vector2(0.28, -0.2) * s, c + Vector2(0.28, 0.22) * s, c + Vector2(-0.38, 0.22) * s]))
			_poly(PackedVector2Array([c + Vector2(0.28, -0.06) * s, c + Vector2(0.44, -0.18) * s, c + Vector2(0.44, 0.2) * s, c + Vector2(0.28, 0.08) * s]))
			draw_circle(c + Vector2(-0.05, 0.01) * s, s * 0.12, Color(0, 0, 0, 0.35))
		Icon.INVERT_Y:
			# Camera body with an up/down arrow beside it.
			_poly(PackedVector2Array([c + Vector2(-0.42, -0.14) * s, c + Vector2(0.06, -0.14) * s, c + Vector2(0.06, 0.18) * s, c + Vector2(-0.42, 0.18) * s]))
			var ax := c + Vector2(0.28, 0) * s
			draw_line(ax + Vector2(0, -0.32) * s, ax + Vector2(0, 0.32) * s, color, s * 0.08, true)
			_poly(PackedVector2Array([ax + Vector2(0, -0.44) * s, ax + Vector2(0.13, -0.26) * s, ax + Vector2(-0.13, -0.26) * s]))
			_poly(PackedVector2Array([ax + Vector2(0, 0.44) * s, ax + Vector2(-0.13, 0.26) * s, ax + Vector2(0.13, 0.26) * s]))
		Icon.JUMP:
			_person(c + Vector2(0, 0.1) * s, s * 0.8, true)
			_poly(PackedVector2Array([c + Vector2(0, -0.48) * s, c + Vector2(0.16, -0.3) * s, c + Vector2(-0.16, -0.3) * s]))
		Icon.RUN:
			_person(c + Vector2(0.08, 0.02) * s, s * 0.9, false)
			for k in 3:
				var y := (-0.12 + k * 0.14) * s
				draw_line(c + Vector2(-0.46, y / s) * s, c + Vector2(-0.24, y / s) * s, color, s * 0.06, true)
		Icon.CHECK:
			draw_polyline(PackedVector2Array([c + Vector2(-0.3, 0.0) * s, c + Vector2(-0.08, 0.24) * s, c + Vector2(0.34, -0.26) * s]),
				color, s * 0.13, true)
		Icon.PERSON:
			# A little walking figure: head, body, arms and striding legs.
			draw_circle(c + Vector2(0.02, -0.34) * s, s * 0.12, color)
			var lw := s * 0.11
			draw_line(c + Vector2(0.02, -0.2) * s, c + Vector2(-0.02, 0.1) * s, color, lw * 1.3, true)
			draw_line(c + Vector2(0.0, -0.12) * s, c + Vector2(0.2, 0.02) * s, color, lw * 0.8, true)
			draw_line(c + Vector2(0.0, -0.12) * s, c + Vector2(-0.2, 0.0) * s, color, lw * 0.8, true)
			draw_line(c + Vector2(-0.02, 0.1) * s, c + Vector2(0.17, 0.42) * s, color, lw, true)
			draw_line(c + Vector2(-0.02, 0.1) * s, c + Vector2(-0.2, 0.42) * s, color, lw, true)
		Icon.PARCEL:
			# A parcel with a ribbon and bow, under a guiding arrow.
			var box := Rect2(c + Vector2(-0.3, -0.06) * s, Vector2(0.6, 0.44) * s)
			draw_rect(box, color, false, s * 0.07)
			draw_line(c + Vector2(0, -0.06) * s, c + Vector2(0, 0.38) * s, color, s * 0.07)
			draw_arc(c + Vector2(-0.09, -0.13) * s, s * 0.08, 0, TAU, 16, color, s * 0.05, true)
			draw_arc(c + Vector2(0.09, -0.13) * s, s * 0.08, 0, TAU, 16, color, s * 0.05, true)
			_poly(PackedVector2Array([c + Vector2(0, -0.5) * s, c + Vector2(0.16, -0.3) * s, c + Vector2(-0.16, -0.3) * s]))
		Icon.BATTERY:
			var body := Rect2(c + Vector2(-0.4, -0.2) * s, Vector2(0.72, 0.4) * s)
			draw_rect(body, color, false, s * 0.06)
			draw_rect(Rect2(c + Vector2(0.32, -0.08) * s, Vector2(0.08, 0.16) * s), color)
			draw_rect(Rect2(body.position + Vector2(0.07, 0.07) * s, Vector2(0.3, 0.26) * s), color)


## A stick figure; `arms_up` for jumping.
func _person(c: Vector2, s: float, arms_up: bool) -> void:
	draw_circle(c + Vector2(0.02, -0.34) * s, s * 0.12, color)
	var lw := s * 0.11
	draw_line(c + Vector2(0.02, -0.2) * s, c + Vector2(-0.02, 0.1) * s, color, lw * 1.3, true)
	var hand_y := -0.36 if arms_up else 0.02
	draw_line(c + Vector2(0.0, -0.12) * s, c + Vector2(0.22, hand_y) * s, color, lw * 0.8, true)
	draw_line(c + Vector2(0.0, -0.12) * s, c + Vector2(-0.22, hand_y if arms_up else 0.0) * s, color, lw * 0.8, true)
	draw_line(c + Vector2(-0.02, 0.1) * s, c + Vector2(0.17, 0.42) * s, color, lw, true)
	draw_line(c + Vector2(-0.02, 0.1) * s, c + Vector2(-0.2, 0.42) * s, color, lw, true)


## An Xbox-style face button: a dark disc with a coloured letter.
func _face_button(c: Vector2, s: float, letter: String, col: Color) -> void:
	draw_circle(c, s * 0.46, Color(0.12, 0.13, 0.16))
	draw_arc(c, s * 0.46, 0, TAU, 40, Color(1, 1, 1, 0.85), s * 0.05, true)
	_letters(c, s * 0.55, letter, col)


func _letters(c: Vector2, font_size: float, text: String, col: Color) -> void:
	var font := ThemeDB.fallback_font
	var fs := int(font_size)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, c + Vector2(-w * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_pips(c: Vector2, s: float) -> void:
	for k in pips:
		var x := (k - (pips - 1) * 0.5) * 0.22
		draw_circle(c + Vector2(x, 0.46) * s, s * 0.07, color)


func _burst(at: Vector2, outer: float, inner: float, points: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in points * 2:
		var a := TAU * k / (points * 2) - PI * 0.5
		out.append(at + Vector2(cos(a), sin(a)) * (outer if k % 2 == 0 else inner))
	return out


func _poly(points: PackedVector2Array) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_colored_polygon(points, color)
	draw_polyline(closed, outline_color, maxf(2.0, size.x * 0.03), true)


func _draw_plane(c: Vector2, s: float) -> void:
	# Side view, facing right.
	_poly(PackedVector2Array([c + Vector2(-0.30, -0.10) * s, c + Vector2(-0.42, -0.34) * s, c + Vector2(-0.30, -0.34) * s, c + Vector2(-0.16, -0.10) * s]))  # tail
	var body := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		body.append(c + Vector2(cos(a) * 0.42, sin(a) * 0.13) * s + Vector2(0, -0.02) * s)
	_poly(body)
	_poly(PackedVector2Array([c + Vector2(-0.08, 0.0) * s, c + Vector2(0.10, 0.0) * s, c + Vector2(-0.04, 0.30) * s, c + Vector2(-0.18, 0.30) * s]))  # wing
	draw_circle(c + Vector2(0.18, -0.06) * s, s * 0.06, Color(1, 1, 1, 0.9))  # window


func _draw_power(c: Vector2, s: float) -> void:
	var w := s * 0.11
	draw_arc(c + Vector2(0, 0.04) * s, s * 0.32, deg_to_rad(-60), deg_to_rad(240), 32, color, w, true)
	draw_line(c + Vector2(0, -0.42) * s, c + Vector2(0, -0.02) * s, color, w, true)


func _draw_gear(c: Vector2, s: float) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		var r := 0.42 if (i / 2) % 2 == 0 else 0.32
		pts.append(c + Vector2(cos(a), sin(a)) * r * s)
	_poly(pts)
	draw_circle(c, s * 0.13, Color(0, 0, 0, 0.35))


static func star_points(center: Vector2, outer: float, inner: float, rotation := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + TAU * i / 10.0 + rotation
		var r := outer if i % 2 == 0 else inner
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts
