class_name VolumeBar
extends Control
## Five chunky bars that light up for volume. Left/right (stick, D-pad,
## keys) or tapping a bar changes it. 0 bars = muted.

signal changed(value: float)

const STEPS := 5

@export var icon_type: UiIcon.Icon = UiIcon.Icon.SPEAKER
@export var color: Color = Color("4aa8ff")

var level: int = 3


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(520, 110)
	var icon := UiIcon.new()
	icon.icon = icon_type
	icon.position = Vector2(0, 10)
	icon.size = Vector2(90, 90)
	add_child(icon)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func set_value(v: float) -> void:
	level = roundi(clampf(v, 0.0, 1.0) * STEPS)
	queue_redraw()


func value() -> float:
	return float(level) / STEPS


func _gui_input(event: InputEvent) -> void:
	var before := level
	if event.is_action_pressed("ui_left"):
		level = maxi(level - 1, 0)
	elif event.is_action_pressed("ui_right"):
		level = mini(level + 1, STEPS)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()
		var x: float = event.position.x - 120.0
		level = clampi(ceili(x / 78.0), 0, STEPS)
	else:
		return
	accept_event()
	if level != before:
		Sfx.play("ui_move", 0.8 + level * 0.12)
		queue_redraw()
		changed.emit(value())


func _draw() -> void:
	if has_focus():
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = Color.WHITE
		sb.set_border_width_all(6)
		sb.set_corner_radius_all(24)
		draw_style_box(sb, Rect2(Vector2(-12, -6), size + Vector2(24, 12)))
	for i in STEPS:
		var h := 30.0 + i * 15.0
		var r := Rect2(Vector2(120 + i * 78, size.y - 10 - h), Vector2(60, h))
		draw_rect(r, color if i < level else Color(1, 1, 1, 0.25))
