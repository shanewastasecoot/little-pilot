class_name ColourMenu
extends Control
## The colour chooser for her room (opened at a PaintStation with Y): six
## big paint blobs in a row with a wall or bed picture above. The stick (or
## D-pad) moves between them and the room shows each one straight away;
## A keeps it (sparkle, saved), B puts back what was there. No words.

signal chosen(index: int)
signal cancelled

const BLOB := 92.0
const GAP := 30.0
const STEP_DELAY := 0.28

var kind := "walls"
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
	index = clampi(current, 0, PaintStation.COLOURS.size() - 1)
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
	index = posmod(index + dir, PaintStation.COLOURS.size())
	Sfx.play("ui_move", 1.0 + index * 0.06)
	preview.call(index)
	queue_redraw()


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
