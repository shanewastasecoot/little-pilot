class_name TitleScreen
extends CanvasLayer
## Logo and one big Play button over the live world. Any button starts.

signal start_requested

var _play: BigButton
var _logo: Label
var _t := 0.0


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_logo = Label.new()
	_logo.text = "Little Pilot"
	_logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_logo.add_theme_font_size_override("font_size", 110)
	_logo.add_theme_color_override("font_color", Color("ffd23f"))
	_logo.add_theme_color_override("font_outline_color", Color("ff5a5f"))
	_logo.add_theme_constant_override("outline_size", 28)
	_logo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_logo.position = Vector2(-500, 90)
	_logo.size = Vector2(1000, 160)
	_logo.pivot_offset = _logo.size * 0.5
	root.add_child(_logo)

	_play = BigButton.new()
	_play.icon_type = UiIcon.Icon.PLAY
	_play.base_color = Color("4cc06a")
	_play.button_size = Vector2(220, 220)
	_play.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_play.position = Vector2(-110, 40)
	_play.pressed.connect(_start)
	root.add_child(_play)
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if visible:
		_play.grab_focus.call_deferred()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_logo.rotation = sin(_t * 1.5) * 0.03
	_play.scale = Vector2.ONE * (1.12 + sin(_t * 4.0) * 0.06)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	# Any button or key starts (sticks and the system buttons don't).
	var any_button := (event is InputEventJoypadButton or event is InputEventKey) and event.is_pressed() and not event.is_echo()
	if any_button:
		get_viewport().set_input_as_handled()
		Sfx.play("ui_confirm")
		_start()


func _start() -> void:
	if visible:
		start_requested.emit()
