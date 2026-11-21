class_name TvShow
extends Control
## The show on the house TVs (drawn in code, no text): three little
## scenes that take turns, each about 10 seconds:
##   0  a plane loops over the sea past puffy clouds, dolphins jump
##   1  a mermaid waves from a rock, bubbles rise, a fish swims by
##   2  a friendly dinosaur bobs along through the jungle, butterflies
## Drawn into a SubViewport by TVSet (only while the TV is on).

const SCENE_TIME := 10.0
var t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var scene := int(t / SCENE_TIME) % 3
	var st := fmod(t, SCENE_TIME)
	match scene:
		0: _plane_scene(w, h, st)
		1: _mermaid_scene(w, h, st)
		_: _dino_scene(w, h, st)
	# Soft fade between scenes.
	var edge := minf(st, SCENE_TIME - st)
	if edge < 0.4:
		draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 1.0 - edge / 0.4))


func _sky(w: float, h: float, top: Color, bottom: Color) -> void:
	var steps := 8
	for i in steps:
		draw_rect(Rect2(0, h * i / steps, w, h / steps + 1), top.lerp(bottom, float(i) / steps))


func _cloud(c: Vector2, s: float) -> void:
	for o in [Vector2(-1.2, 0.3), Vector2(0, 0), Vector2(1.1, 0.25), Vector2(0.5, 0.5), Vector2(-0.5, 0.55)]:
		draw_circle(c + o * 10.0 * s, 9.0 * s, Color.WHITE)


func _sea(w: float, h: float, y: float, st: float) -> void:
	draw_rect(Rect2(0, y, w, h - y), Color("3a8fd9"))
	for k in 6:
		var x := fmod(k * 60.0 + st * 20.0, w + 40.0) - 20.0
		draw_arc(Vector2(x, y + 12 + (k % 2) * 14), 10.0, PI * 1.1, PI * 1.9, 8, Color("bfe6ff"), 2.0)


func _plane_scene(w: float, h: float, st: float) -> void:
	_sky(w, h, Color("6fb7ff"), Color("cfe9ff"))
	draw_circle(Vector2(w * 0.85, h * 0.18), 16.0, Color("ffd23f"))
	for k in 3:
		_cloud(Vector2(fmod(k * 120.0 + st * 12.0, w + 80.0) - 40.0, 30.0 + k * 18.0), 1.0 + (k % 2) * 0.3)
	_sea(w, h, h * 0.72, st)
	# Dolphins arcing out of the water now and then.
	for k in 2:
		var phase := fmod(st * 0.8 + k * 1.7, 3.0)
		if phase < 1.0:
			var x := w * (0.25 + k * 0.45) + phase * 30.0
			var y := h * 0.72 - sin(phase * PI) * 22.0
			draw_circle(Vector2(x, y), 6.0, Color("5aa9e6"))
			draw_circle(Vector2(x + 6, y - 1), 4.0, Color("5aa9e6"))
	# The plane: across the screen with a loop in the middle.
	var f := st / SCENE_TIME
	var p := Vector2(-30 + f * (w + 60), h * 0.42)
	if f > 0.4 and f < 0.6:
		var a := (f - 0.4) / 0.2 * TAU
		p += Vector2(sin(a) * 25.0, -(1.0 - cos(a)) * 25.0)
	for k in 6:
		draw_circle(p - Vector2(10 + k * 9, 0), 3.0 + k * 0.6, Color(1, 1, 1, 0.8 - k * 0.12))
	draw_rect(Rect2(p - Vector2(14, 4), Vector2(28, 8)), Color("e63946"))
	draw_rect(Rect2(p - Vector2(3, 12), Vector2(8, 24)), Color("ffd23f"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-14, -4), p + Vector2(-20, -12), p + Vector2(-10, -4)]), Color("e63946"))
	draw_circle(p + Vector2(15, 0), 3.0, Color("333333"))


func _mermaid_scene(w: float, h: float, st: float) -> void:
	_sky(w, h, Color("7ecbff"), Color("e0f4ff"))
	_sea(w, h, h * 0.62, st)
	var rock := Vector2(w * 0.5, h * 0.7)
	draw_circle(rock, 34.0, Color("8a8f99"))
	draw_rect(Rect2(rock.x - 34, rock.y, 68, 30), Color("8a8f99"))
	# The mermaid sitting on the rock, waving.
	var body := rock + Vector2(0, -40)
	draw_colored_polygon(PackedVector2Array([body + Vector2(-8, 8), body + Vector2(8, 8), body + Vector2(26, 30), body + Vector2(-2, 22)]), Color("ff7eb9"))
	draw_colored_polygon(PackedVector2Array([body + Vector2(24, 28), body + Vector2(36, 20), body + Vector2(34, 36)]), Color("ff7eb9"))
	draw_rect(Rect2(body + Vector2(-6, -10), Vector2(12, 18)), Color("ffd1b3"))
	draw_circle(body + Vector2(0, -18), 9.0, Color("ffd1b3"))
	draw_circle(body + Vector2(-2, -22), 10.0, Color("ff8c42"))
	draw_rect(Rect2(body + Vector2(-12, -22), Vector2(6, 22)), Color("ff8c42"))
	draw_circle(body + Vector2(-3, -17), 1.5, Color("1c1a24"))
	draw_circle(body + Vector2(4, -17), 1.5, Color("1c1a24"))
	var wave := sin(st * 6.0) * 0.6
	var arm := body + Vector2(6, -6)
	draw_line(arm, arm + Vector2(cos(-1.2 + wave), sin(-1.2 + wave)) * 16.0, Color("ffd1b3"), 4.0)
	# Bubbles and a little fish.
	for k in 5:
		var y := fmod(h - st * 18.0 - k * 30.0, h * 0.4) + h * 0.6
		draw_arc(Vector2(w * 0.2 + k * 14.0, y), 3.0, 0, TAU, 10, Color.WHITE, 1.5)
	var fish := Vector2(fmod(st * 30.0, w + 40.0) - 20.0, h * 0.85)
	draw_circle(fish, 6.0, Color("ffd23f"))
	draw_colored_polygon(PackedVector2Array([fish + Vector2(-5, 0), fish + Vector2(-13, -5), fish + Vector2(-13, 5)]), Color("ffd23f"))


func _dino_scene(w: float, h: float, st: float) -> void:
	_sky(w, h, Color("8fd3ff"), Color("e8fff0"))
	for k in 4:
		draw_circle(Vector2(k * w / 3.0, h * 0.95), w * 0.25, Color("5cbf45") if k % 2 == 0 else Color("4aa83a"))
	draw_rect(Rect2(0, h * 0.8, w, h * 0.2), Color("5cbf45"))
	# Palm trees.
	for x in [w * 0.15, w * 0.85]:
		draw_rect(Rect2(x - 3, h * 0.45, 6, h * 0.38), Color("8b5a2b"))
		for a in [-0.6, 0.0, 0.6, PI - 0.6, PI]:
			draw_line(Vector2(x, h * 0.45), Vector2(x, h * 0.45) + Vector2(cos(a), sin(a) * 0.4 - 0.3) * 22.0, Color("2f9e44"), 5.0)
	# The dinosaur, bobbing along.
	var x := fmod(st * 28.0, w + 80.0) - 40.0
	var bob := absf(sin(st * 5.0)) * 4.0
	var b := Vector2(x, h * 0.72 - bob)
	draw_circle(b, 20.0, Color("ff9f1c"))
	draw_colored_polygon(PackedVector2Array([b + Vector2(-18, 0), b + Vector2(-42, 8), b + Vector2(-16, 12)]), Color("ff9f1c"))
	draw_rect(Rect2(b + Vector2(12, -34), Vector2(10, 28)), Color("ff9f1c"))
	draw_circle(b + Vector2(22, -36), 10.0, Color("ff9f1c"))
	draw_circle(b + Vector2(25, -38), 2.0, Color("1c1a24"))
	for k in 4:
		draw_colored_polygon(PackedVector2Array([b + Vector2(-14 + k * 8, -16), b + Vector2(-10 + k * 8, -26), b + Vector2(-6 + k * 8, -16)]), Color("4cc06a"))
	for s in [-1.0, 1.0]:
		draw_rect(Rect2(b + Vector2(-6 + s * 7, 14), Vector2(7, 10 + (bob if s > 0 else -bob) * 0.5)), Color("ff9f1c"))
	# Butterflies.
	for k in 2:
		var bp := Vector2(w * (0.3 + k * 0.4) + sin(st * 2.0 + k) * 20.0, h * 0.35 + cos(st * 3.0 + k) * 10.0)
		var flap := absf(sin(st * 12.0)) * 5.0 + 2.0
		draw_circle(bp + Vector2(-flap, 0), 4.0, Color("ff5fa2"))
		draw_circle(bp + Vector2(flap, 0), 4.0, Color("ff5fa2"))
