class_name PauseMenu
extends CanvasLayer
## Pause menu with three big picture buttons:
## Resume (green), Change Plane (blue), Quit (red, hold 2 s).
## B / Menu / Esc also resume.

signal resume_requested
signal change_plane_requested
signal quit_requested
signal settings_requested

var _resume: BigButton


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.15, 0.3, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 60)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(row)

	_resume = _button(row, UiIcon.Icon.PLAY, Color("4cc06a"), Vector2(230, 230))
	_resume.pressed.connect(func(): resume_requested.emit())
	var plane := _button(row, UiIcon.Icon.PLANE, Color("4aa8ff"), Vector2(200, 200))
	plane.pressed.connect(func(): change_plane_requested.emit())
	var quit := HoldButton.new()
	quit.icon_type = UiIcon.Icon.QUIT
	quit.base_color = Color("ff5a5f")
	quit.button_size = Vector2(150, 150)
	quit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	quit.held.connect(func(): quit_requested.emit())
	row.add_child(quit)
	# Parent settings: small grey gear in the corner.
	var gear := BigButton.new()
	gear.icon_type = UiIcon.Icon.GEAR
	gear.base_color = Color("8a94a6")
	gear.button_size = Vector2(100, 100)
	gear.position = Vector2(40, 40)  # top-left: clear of the star counter
	gear.pressed.connect(func(): settings_requested.emit())
	root.add_child(gear)
	_resume.focus_neighbor_top = _resume.get_path_to(gear)
	gear.focus_neighbor_bottom = gear.get_path_to(_resume)
	gear.focus_neighbor_right = gear.get_path_to(_resume)
	visibility_changed.connect(_on_visibility_changed)


func _button(parent: Node, icon_type: UiIcon.Icon, color: Color, size: Vector2) -> BigButton:
	var b := BigButton.new()
	b.icon_type = icon_type
	b.base_color = color
	b.button_size = size
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(b)
	return b


func _on_visibility_changed() -> void:
	if visible:
		_resume.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Sfx.play("ui_back")
		resume_requested.emit()
