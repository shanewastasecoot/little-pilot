class_name UnderwaterView
extends Control
## The moment under the sea after the plane splashes in (Phase 6): the
## screen goes soft blue with light rays from the surface, bubbles wobble up
## and a few fish swim by, and the sound goes muffled. It plays inside the
## crash's usual pause before the white fade (main.gd), so getting back to
## the runway takes no longer than before. Drawn, no textures.

var _t := 0.0
var _on := false
var _bubbles: Array[Vector3] = []   # x, y (0..1 of the screen), size
var _fish: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false


## Sink in over `fade_in` seconds (and muffle the sound).
func dive(fade_in := 0.35) -> void:
	_t = 0.0
	_on = true
	visible = true
	_bubbles.clear()
	for i in 34:
		_bubbles.append(Vector3(randf(), randf_range(0.6, 1.3), randf_range(5.0, 18.0)))
	_fish.clear()
	for i in 4:
		var left := i % 2 == 0
		_fish.append({"x": randf_range(0.0, 0.25) if left else randf_range(0.75, 1.0), "y": randf_range(0.3, 0.8),
			"dir": 1.0 if left else -1.0, "speed": randf_range(0.3, 0.45), "size": randf_range(34.0, 56.0), "delay": i * 0.1})
	create_tween().tween_property(self, "modulate:a", 1.0, fade_in)
	GameSettings.set_muffled(true)


## Back up (instantly: the white fade is covering the screen).
func surface() -> void:
	_on = false
	modulate.a = 0.0
	visible = false
	GameSettings.set_muffled(false)


func is_diving() -> bool:
	return _on


func _process(delta: float) -> void:
	if not _on:
		return
	_t += delta
	for i in _bubbles.size():
		var b := _bubbles[i]
		b.y -= delta * (0.25 + b.z * 0.02)
		if b.y < -0.05:
			b.y = 1.1
		_bubbles[i] = b
	for f in _fish:
		if _t > f.delay:
			f.x += f.dir * f.speed * delta
	queue_redraw()


func _draw() -> void:
	var s := size
	# Deep blue below, lighter towards the surface.
	var top := Color(0.35, 0.72, 0.9, 0.92)
	var bottom := Color(0.05, 0.25, 0.5, 0.95)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	# Light rays slanting down from the surface, gently swaying.
	for k in 5:
		var x := s.x * (0.12 + k * 0.2) + sin(_t * 0.8 + k) * 30.0
		draw_colored_polygon(PackedVector2Array([Vector2(x - 30, 0), Vector2(x + 30, 0), Vector2(x + 140, s.y), Vector2(x + 40, s.y)]),
			Color(1, 1, 1, 0.06))
	# Fish silhouettes.
	for f in _fish:
		var p := Vector2(f.x * s.x, f.y * s.y + sin(_t * 3.0 + f.size) * 6.0)
		var z: float = f.size
		var d: float = f.dir
		var c := Color(0.03, 0.15, 0.32, 0.75)
		draw_set_transform(p, 0.0, Vector2(1.0, 0.55))
		draw_circle(Vector2.ZERO, z * 0.6, c)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var wag := sin(_t * 9.0 + z) * z * 0.12
		draw_colored_polygon(PackedVector2Array([p - Vector2(d * z * 0.45, 0), p - Vector2(d * z * 1.0, z * 0.38 + wag),
			p - Vector2(d * z * 1.0, -z * 0.38 + wag)]), c)
	# Bubbles: rings with a shine.
	for b in _bubbles:
		var p := Vector2(b.x * s.x + sin(_t * 4.0 + b.z) * 8.0, b.y * s.y)
		draw_arc(p, b.z, 0.0, TAU, 16, Color(1, 1, 1, 0.55), 2.0)
		draw_circle(p + Vector2(-b.z * 0.35, -b.z * 0.35), b.z * 0.22, Color(1, 1, 1, 0.5))
