class_name StarJar
extends Control
## A glass jar that fills with golden "star juice" as stars are collected.
## Shows progress without needing to read numbers.

var fill: float = 0.0          # shown fraction (animated)
var target_fill: float = 0.0   # real fraction


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not is_equal_approx(fill, target_fill):
		fill = move_toward(fill, target_fill, delta * 1.5)
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var body := Rect2(Vector2(w * 0.08, h * 0.16), Vector2(w * 0.84, h * 0.82))
	# Glass
	_rounded(body, Color(1, 1, 1, 0.35), w * 0.18)
	# Liquid
	if fill > 0.0:
		var fh := (body.size.y - 8.0) * fill
		_rounded(Rect2(body.position.x + 4, body.end.y - 4 - fh, body.size.x - 8, fh), Color("ffd23f"), w * 0.14)
		for i in int(fill * 6.0):
			var p := Vector2(body.position.x + body.size.x * (0.3 + 0.4 * ((i * 37) % 10) / 10.0), body.end.y - 12 - (fh - 16) * (i + 0.5) / 6.0)
			draw_colored_polygon(UiIcon.star_points(p, w * 0.1, w * 0.045), Color("fff6c4"))
	# Outline and lid
	_rounded_outline(body, Color.WHITE, w * 0.18)
	draw_rect(Rect2(Vector2(w * 0.2, 0), Vector2(w * 0.6, h * 0.14)), Color("c98b4b"))


func _rounded(r: Rect2, c: Color, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(int(radius))
	draw_style_box(sb, r)


func _rounded_outline(r: Rect2, c: Color, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = c
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(int(radius))
	draw_style_box(sb, r)
