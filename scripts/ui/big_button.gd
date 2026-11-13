class_name BigButton
extends Button
## Large, colourful icon button for small hands. Grows when focused,
## makes a sound on focus and press. Works with gamepad, keyboard and touch.

@export var icon_type: UiIcon.Icon = UiIcon.Icon.PLAY
@export var base_color: Color = Color("4cc06a")
@export var icon_color: Color = Color.WHITE
@export var button_size: Vector2 = Vector2(200, 200)

var _icon: UiIcon
var _tween: Tween


func _ready() -> void:
	custom_minimum_size = button_size
	pivot_offset = button_size * 0.5
	focus_mode = Control.FOCUS_ALL
	add_theme_stylebox_override("normal", _style(base_color, Color(0, 0, 0, 0)))
	add_theme_stylebox_override("hover", _style(base_color.lightened(0.1), Color(0, 0, 0, 0)))
	add_theme_stylebox_override("pressed", _style(base_color.darkened(0.15), Color.WHITE))
	add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), Color.WHITE))
	_icon = UiIcon.new()
	_icon.icon = icon_type
	_icon.color = icon_color
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = button_size.x * 0.2
	_icon.offset_top = button_size.y * 0.2
	_icon.offset_right = -button_size.x * 0.2
	_icon.offset_bottom = -button_size.y * 0.2
	add_child(_icon)
	focus_entered.connect(_on_focus.bind(true))
	focus_exited.connect(_on_focus.bind(false))
	pressed.connect(_on_pressed)


func _gui_input(event: InputEvent) -> void:
	# Only a mouse that actually moves takes focus; a parked pointer (the Deck
	# leaves one mid-screen) must not steal it from the gamepad.
	if event is InputEventMouseMotion and event.relative.length() > 2.0 and not has_focus():
		grab_focus()


func _on_focus(focused: bool) -> void:
	if focused and is_visible_in_tree():
		Sfx.play("ui_move")
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * (1.12 if focused else 1.0), 0.2)


func _on_pressed() -> void:
	Sfx.play("ui_confirm")


func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(button_size.y * 0.25))
	sb.set_border_width_all(8 if border.a > 0 else 0)
	sb.border_color = border
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 6 if fill.a > 0 else 0
	sb.shadow_offset = Vector2(0, 4)
	return sb
