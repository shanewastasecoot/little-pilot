class_name CockpitGauges
extends Control
## The instrument panel in the cockpit view (Phase 9): a dark dashboard
## along the bottom of the screen with four round gauges, like a real light
## aircraft's:
##   airspeed       a needle round a dial (km/h)
##   attitude       the artificial horizon: blue sky and brown ground that
##                  tilt with the bank and slide with the pitch, a little
##                  orange aeroplane fixed in the middle
##   altimeter      a long needle (hundreds of metres) and a short one
##                  (thousands), and the height in a little window
##   heading        a compass rose that turns, N E S W, a lubber line on top
## main.gd shows it only in the cockpit view while flying and feeds it
## `feed(speed m/s, altitude m, heading rad, pitch rad, bank rad)`.

var speed := 0.0
var altitude := 0.0
var heading := 0.0
var pitch := 0.0
var bank := 0.0
var max_speed := 60.0
var paint := Color("ff5a5f")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func feed(spd: float, alt: float, hdg: float, p: float, b: float) -> void:
	speed = spd
	altitude = alt
	heading = hdg
	pitch = p
	bank = b
	queue_redraw()


func _draw() -> void:
	var s := size
	var h := clampf(s.y * 0.26, 150.0, 230.0)
	var top := s.y - h
	# The dashboard: dark, with a trim in the plane's paint colour.
	draw_rect(Rect2(0, top, s.x, h), Color(0.13, 0.14, 0.17))
	draw_rect(Rect2(0, top, s.x, 6), paint.darkened(0.2))
	var r := h * 0.38
	var y := top + h * 0.52
	var xs := [s.x * 0.2, s.x * 0.4, s.x * 0.6, s.x * 0.8]
	_airspeed(Vector2(xs[0], y), r)
	_attitude(Vector2(xs[1], y), r)
	_altimeter(Vector2(xs[2], y), r)
	_heading(Vector2(xs[3], y), r)


func _bezel(c: Vector2, r: float) -> void:
	draw_circle(c, r + 7.0, Color(0.32, 0.33, 0.36))
	draw_circle(c, r + 3.0, Color(0.05, 0.05, 0.06))
	draw_circle(c, r, Color(0.08, 0.09, 0.1))


func _ticks(c: Vector2, r: float, from: float, to: float, n: int, long_every: int) -> void:
	for i in n + 1:
		var a := lerpf(from, to, float(i) / n)
		var d := Vector2(cos(a), sin(a))
		var l := r * (0.18 if i % long_every == 0 else 0.09)
		draw_line(c + d * (r - l), c + d * (r - 3.0), Color(0.92, 0.92, 0.9), 3.0 if i % long_every == 0 else 1.5, true)


func _needle(c: Vector2, r: float, a: float, length: float, width: float, col := Color.WHITE) -> void:
	var d := Vector2(cos(a), sin(a))
	draw_line(c - d * r * 0.12, c + d * r * length, col, width, true)
	draw_circle(c, width * 1.3, Color(0.75, 0.75, 0.75))


func _airspeed(c: Vector2, r: float) -> void:
	_bezel(c, r)
	# A coloured arc like a real airspeed indicator: green normal, yellow fast.
	var from := deg_to_rad(135.0)
	var to := deg_to_rad(405.0)
	draw_arc(c, r * 0.82, lerpf(from, to, 0.2), lerpf(from, to, 0.7), 24, Color(0.2, 0.75, 0.3), r * 0.07)
	draw_arc(c, r * 0.82, lerpf(from, to, 0.7), lerpf(from, to, 0.9), 12, Color(0.95, 0.8, 0.2), r * 0.07)
	_ticks(c, r, from, to, 20, 4)
	var kmh := speed * 3.6
	_needle(c, r, lerpf(from, to, clampf(kmh / (max_speed * 3.6), 0.0, 1.0)), 0.8, 4.0)
	_label(c + Vector2(0, r * 0.42), "%d" % roundi(kmh), r * 0.24)
	_label(c + Vector2(0, -r * 0.35), "km/h", r * 0.15, Color(0.7, 0.7, 0.7))


func _attitude(c: Vector2, r: float) -> void:
	_bezel(c, r)
	# Sky and ground: the dial cut by the horizon line, which slides with
	# the pitch (nose up: the horizon drops) and turns with the bank.
	var shift := clampf(pitch / deg_to_rad(30.0), -1.0, 1.0) * r * 0.6
	var n := Vector2(0, 1).rotated(bank)        # towards the ground
	var p0 := c + n * shift                      # a point on the horizon
	var dial := PackedVector2Array()
	for i in 48:
		var a := TAU * float(i) / 48
		dial.append(c + Vector2(cos(a), sin(a)) * (r - 1.0))
	draw_colored_polygon(dial, Color(0.55, 0.36, 0.2))  # ground
	var sky := _clip_half(dial, p0, n)
	if sky.size() >= 3:
		draw_colored_polygon(sky, Color(0.25, 0.55, 0.95))
	var line_dir := Vector2(1, 0).rotated(bank)
	var half := sqrt(maxf(r * r - shift * shift, 0.0))
	if half > 1.0:
		draw_line(p0 - line_dir * half, p0 + line_dir * half, Color.WHITE, 2.5, true)
	# Pitch ladder (every 10 degrees).
	for k in [-2, -1, 1, 2]:
		var mid: Vector2 = p0 - n * (float(k) * r * 0.2)
		var w: float = r * (0.22 if absi(k) == 1 else 0.32)
		if (mid - c).length() < r * 0.78:
			draw_line(mid - line_dir * w, mid + line_dir * w, Color(1, 1, 1, 0.8), 1.5, true)
	# The little aeroplane, fixed.
	var o := Color(1.0, 0.6, 0.1)
	draw_line(c + Vector2(-r * 0.55, 0), c + Vector2(-r * 0.18, 0), o, 5.0, true)
	draw_line(c + Vector2(r * 0.18, 0), c + Vector2(r * 0.55, 0), o, 5.0, true)
	draw_circle(c, 5.0, o)
	# Bank pointer at the top.
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.92).rotated(bank), c + Vector2(-7, -r * 0.78).rotated(bank),
		c + Vector2(7, -r * 0.78).rotated(bank)]), Color.WHITE)


## The part of polygon `poly` on the sky side of the line through `p0`
## (normal `n` points to the ground side).
static func _clip_half(poly: PackedVector2Array, p0: Vector2, n: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var da := (a - p0).dot(n)
		var db := (b - p0).dot(n)
		if da <= 0.0:
			out.append(a)
		if da * db < 0.0:
			out.append(a + (b - a) * (da / (da - db)))
	return out


func _altimeter(c: Vector2, r: float) -> void:
	_bezel(c, r)
	_ticks(c, r, -PI * 0.5, PI * 1.5, 10, 1)
	for i in 10:
		var a := -PI * 0.5 + TAU * i / 10.0
		_label(c + Vector2(cos(a), sin(a)) * r * 0.66, str(i), r * 0.17)
	var hundreds := fposmod(altitude, 1000.0) / 1000.0
	var thousands := fposmod(altitude, 10000.0) / 10000.0
	_needle(c, r, -PI * 0.5 + TAU * thousands, 0.45, 6.0)
	_needle(c, r, -PI * 0.5 + TAU * hundreds, 0.82, 3.5)
	draw_rect(Rect2(c + Vector2(-r * 0.32, r * 0.22), Vector2(r * 0.64, r * 0.26)), Color(0.02, 0.02, 0.02))
	_label(c + Vector2(0, r * 0.36), "%d m" % roundi(altitude), r * 0.18)


func _heading(c: Vector2, r: float) -> void:
	_bezel(c, r)
	# The rose turns so the plane's heading is at the top. heading is the
	# game's yaw (0 = facing -Z = north), turning left is positive.
	var rot := heading
	for i in 36:
		var a := -PI * 0.5 + deg_to_rad(i * 10.0) + rot
		var d := Vector2(cos(a), sin(a))
		var l := r * (0.16 if i % 3 == 0 else 0.08)
		draw_line(c + d * (r - l), c + d * (r - 3.0), Color(0.92, 0.92, 0.9), 2.5 if i % 3 == 0 else 1.2, true)
	for k in 4:
		var a := -PI * 0.5 + deg_to_rad(k * 90.0) + rot
		_label(c + Vector2(cos(a), sin(a)) * r * 0.62, ["N", "E", "S", "W"][k], r * 0.24, Color(1.0, 0.75, 0.2) if k == 0 else Color.WHITE)
	# A little plane in the middle, and the lubber line at the top.
	var w := Color(1.0, 0.6, 0.1)
	draw_line(c + Vector2(0, -r * 0.3), c + Vector2(0, r * 0.3), w, 4.0, true)
	draw_line(c + Vector2(-r * 0.28, -r * 0.05), c + Vector2(r * 0.28, -r * 0.05), w, 4.0, true)
	draw_line(c + Vector2(-r * 0.12, r * 0.25), c + Vector2(r * 0.12, r * 0.25), w, 3.0, true)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r + 2), c + Vector2(-7, -r - 10), c + Vector2(7, -r - 10)]), w)


func _label(at: Vector2, text: String, px: float, col := Color.WHITE) -> void:
	var font := get_theme_default_font()
	var fs := int(px)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, at + Vector2(-w * 0.5, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
