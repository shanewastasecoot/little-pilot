@tool
class_name UiIcon
extends Control
## Simple vector icons drawn in code, so menus need no text or image assets.
## Scales to the control's size.

enum Icon { STAR, PLAY, PLANE, QUIT, ARROW_LEFT, ARROW_RIGHT }

@export var icon: Icon = Icon.STAR:
	set(v):
		icon = v
		queue_redraw()
@export var color: Color = Color.WHITE:
	set(v):
		color = v
		queue_redraw()
@export var outline_color: Color = Color(0, 0, 0, 0.35)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
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


static func star_points(center: Vector2, outer: float, inner: float, rotation := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + TAU * i / 10.0 + rotation
		var r := outer if i % 2 == 0 else inner
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts
