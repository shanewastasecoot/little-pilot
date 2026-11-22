class_name ColourMenu
extends Control
## The chooser opened with Y (no words, all pictures):
##   "walls" / "quilt"  at a PaintStation in her room: six big paint blobs
##          with a wall or bed picture above; the room shows each one
##          straight away; A keeps it, B puts back what was there
##   "meal"  at the kitchen fridge: three meals drawn big (pizza, chicken
##          fingers, breakfast); A takes one out to carry, B closes
## The stick (or D-pad) moves between them.

signal chosen(index: int)
signal cancelled

const BLOB := 92.0
const GAP := 30.0
const STEP_DELAY := 0.28

var kind := "walls"
## The meals at the fridge (CharacterLook props), in menu order.
const MEALS := ["Meal_Pizza", "Meal_Chicken", "Meal_Breakfast"]
var index := 0
var _start := 0
var _cool := 0.0
var _open := false
var _t := 0.0
## Called with the index whenever the highlighted colour changes.
var preview := func(_i: int) -> void: pass


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func is_open() -> bool:
	return _open


func open(what: String, current: int) -> void:
	kind = what
	_start = current
	index = clampi(current, 0, count() - 1)
	_open = true
	_cool = 0.25  # don't take the Y that opened it as anything else
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)
	Sfx.play("ui_confirm", 1.1, -4.0)
	preview.call(index)


## Move the highlight by `dir` (wraps round).
func move(dir: int) -> void:
	if not _open:
		return
	index = posmod(index + dir, count())
	Sfx.play("ui_move", 1.0 + index * 0.06)
	preview.call(index)
	queue_redraw()


## How many choices.
func count() -> int:
	return MEALS.size() if kind == "meal" else PaintStation.COLOURS.size()


func confirm() -> void:
	if not _open:
		return
	_close()
	Sfx.play("chime", 1.3)
	chosen.emit(index)


func cancel() -> void:
	if not _open:
		return
	_close()
	Sfx.play("ui_back")
	preview.call(_start)  # -1: back to how it was built
	cancelled.emit()


func _close() -> void:
	_open = false
	create_tween().tween_property(self, "modulate:a", 0.0, 0.15).finished.connect(func(): if not _open: visible = false)


func _process(delta: float) -> void:
	if not _open:
		return
	_t += delta
	queue_redraw()
	_cool -= delta
	if _cool > 0.0:
		return
	var x := Input.get_axis("move_left", "move_right")
	if Input.is_action_pressed("ui_left"):
		x = -1.0
	elif Input.is_action_pressed("ui_right"):
		x = 1.0
	if absf(x) > 0.5:
		move(1 if x > 0.0 else -1)
		_cool = STEP_DELAY
	elif Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept"):
		confirm()
	elif Input.is_action_just_pressed("sprint") or Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("interact"):
		cancel()


func _draw() -> void:
	if kind == "meal":
		_draw_meals()
		return
	var n := PaintStation.COLOURS.size()
	var width := n * BLOB + (n - 1) * GAP
	var panel := Rect2(size.x * 0.5 - width * 0.5 - 40.0, size.y * 0.62 - 150.0, width + 80.0, 300.0)
	draw_style_box(_panel_style(), panel)
	# What's being coloured: a wall with a window, or a bed.
	var top := Vector2(size.x * 0.5, panel.position.y + 62.0)
	var col: Color = PaintStation.COLOURS[index]
	if kind == "walls":
		draw_rect(Rect2(top - Vector2(70, 40), Vector2(140, 80)), col.lightened(0.35))
		draw_rect(Rect2(top - Vector2(70, 40), Vector2(140, 80)), Color(1, 1, 1, 0.9), false, 4.0)
		draw_rect(Rect2(top - Vector2(22, 22), Vector2(44, 40)), Color("dff4ff"))
		draw_rect(Rect2(top - Vector2(22, 22), Vector2(44, 40)), Color.WHITE, false, 4.0)
	else:
		draw_rect(Rect2(top + Vector2(-80, -6), Vector2(160, 34)), Color("b07a4a"))
		draw_rect(Rect2(top + Vector2(-80, -40), Vector2(16, 70)), Color("b07a4a"))
		draw_rect(Rect2(top + Vector2(-60, -18), Vector2(136, 20)), col)
		draw_rect(Rect2(top + Vector2(-62, -26), Vector2(34, 14)), Color.WHITE)
	# The paint blobs, the chosen one bigger with a bouncing ring.
	var y := panel.position.y + 200.0
	for i in n:
		var c := Vector2(size.x * 0.5 - width * 0.5 + BLOB * 0.5 + i * (BLOB + GAP), y)
		var r := BLOB * (0.5 if i == index else 0.4)
		if i == index:
			r += sin(_t * 6.0) * 3.0
			draw_circle(c, r + 12.0, Color.WHITE)
		draw_circle(c, r, PaintStation.COLOURS[i])
		draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.18, Color(1, 1, 1, 0.6))
	# A and B hints: tick to keep, cross to put back.
	_button_hint(Vector2(panel.end.x - 70.0, panel.position.y + 50.0), Color("43c463"), true)
	_button_hint(Vector2(panel.position.x + 70.0, panel.position.y + 50.0), Color("ff5d5d"), false)


func _button_hint(c: Vector2, col: Color, tick: bool) -> void:
	draw_circle(c, 30.0, Color("1c1d26"))
	draw_arc(c, 30.0, 0.0, TAU, 32, Color.WHITE, 3.0)
	if tick:
		draw_polyline(PackedVector2Array([c + Vector2(-13, 0), c + Vector2(-3, 11), c + Vector2(14, -10)]), col, 6.0, true)
	else:
		draw_line(c + Vector2(-11, -11), c + Vector2(11, 11), col, 6.0, true)
		draw_line(c + Vector2(11, -11), c + Vector2(-11, 11), col, 6.0, true)


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.13, 0.2, 0.82)
	sb.set_corner_radius_all(36)
	return sb


# --- Meals -------------------------------------------------------------------------

func _draw_meals() -> void:
	var size_m := 150.0
	var gap := 50.0
	var n := MEALS.size()
	var width := n * size_m + (n - 1) * gap
	var panel := Rect2(size.x * 0.5 - width * 0.5 - 40.0, size.y * 0.62 - 150.0, width + 80.0, 300.0)
	draw_style_box(_panel_style(), panel)
	var y := panel.position.y + 170.0
	for i in n:
		var c := Vector2(size.x * 0.5 - width * 0.5 + size_m * 0.5 + i * (size_m + gap), y)
		var s := 1.0 + (0.12 + sin(_t * 6.0) * 0.03 if i == index else 0.0)
		if i == index:
			draw_circle(c, size_m * 0.56 * s + 10.0, Color.WHITE)
		draw_circle(c, size_m * 0.56 * s, Color("2a2c3a"))
		match i:
			0: _pizza(c, size_m * 0.45 * s)
			1: _chicken(c, size_m * 0.45 * s)
			_: _breakfast(c, size_m * 0.45 * s)
	_button_hint(Vector2(panel.end.x - 70.0, panel.position.y + 50.0), Color("43c463"), true)
	_button_hint(Vector2(panel.position.x + 70.0, panel.position.y + 50.0), Color("ff5d5d"), false)


func _plate(c: Vector2, r: float) -> void:
	draw_circle(c, r, Color("e8edf2"))
	draw_circle(c, r * 0.8, Color.WHITE)


func _pizza(c: Vector2, r: float) -> void:
	draw_circle(c, r, Color("e3a857"))
	draw_circle(c, r * 0.84, Color("e8562a"))
	draw_circle(c, r * 0.78, Color("ffd35c"))
	for k in 7:
		var a := TAU * k / 7.0 + 0.3
		var d := r * (0.45 if k % 2 == 0 else 0.25)
		draw_circle(c + Vector2(cos(a), sin(a)) * d, r * 0.12, Color("d93a2b"))
	for k in 4:
		var a := TAU * k / 4.0 + 0.8
		draw_line(c, c + Vector2(cos(a), sin(a)) * r * 0.82, Color("e3a857"), 2.0)


func _chicken(c: Vector2, r: float) -> void:
	_plate(c, r)
	for k in 4:
		var a := -0.5 + k * 0.32
		var mid := c + Vector2(-r * 0.12 + k * r * 0.14, r * 0.05)
		var d := Vector2(cos(a + 1.2), sin(a + 1.2)) * r * 0.32
		draw_line(mid - d, mid + d, Color("c97a22"), r * 0.24)
		draw_line(mid - d, mid + d, Color("e9a23b"), r * 0.18)
		draw_circle(mid - d, r * 0.09, Color("e9a23b"))
		draw_circle(mid + d, r * 0.09, Color("e9a23b"))
	draw_circle(c + Vector2(-r * 0.45, -r * 0.3), r * 0.16, Color("d62828"))


func _breakfast(c: Vector2, r: float) -> void:
	_plate(c, r)
	# Two fried eggs.
	for e in [Vector2(-0.35, -0.25), Vector2(0.05, -0.42)]:
		var p: Vector2 = c + e * r
		draw_circle(p, r * 0.22, Color.WHITE)
		draw_arc(p, r * 0.22, 0.0, TAU, 20, Color("dfe3ea"), 1.5)
		draw_circle(p, r * 0.09, Color("ffc21a"))
	# Bacon.
	for k in 2:
		var pts := PackedVector2Array()
		for i in 7:
			pts.append(c + Vector2(-0.55 + i * 0.12, 0.15 + k * 0.17 + sin(i * 1.6) * 0.04) * r)
		draw_polyline(pts, Color("b5442c"), r * 0.1, true)
	# A stack of pancakes with butter.
	var pc := c + Vector2(0.38, 0.12) * r
	for k in 3:
		draw_set_transform(pc + Vector2(0, -k * r * 0.1), 0.0, Vector2(1.0, 0.55))
		draw_circle(Vector2.ZERO, r * 0.28, Color("c9893f"))
		draw_circle(Vector2(0, -r * 0.04), r * 0.26, Color("e8b864"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(pc + Vector2(-r * 0.07, -r * 0.36), Vector2(r * 0.14, r * 0.1)), Color("fff1a8"))
