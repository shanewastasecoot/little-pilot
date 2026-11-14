class_name SettingsPanel
extends CanvasLayer
## Parent settings, opened from the pause menu (gear button):
## music volume, sound volume and a battery saver (30 FPS cap).
## B / Esc or the back arrow closes it. Changes save automatically.

signal closed

var _music: VolumeBar
var _sounds: VolumeBar
var _battery: BigButton


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.12, 0.25, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 34)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(col)

	_music = VolumeBar.new()
	_music.icon_type = UiIcon.Icon.MUSIC
	_music.color = Color("9b5de5")
	_music.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_music.changed.connect(SaveManager.set_music_volume)
	col.add_child(_music)

	_sounds = VolumeBar.new()
	_sounds.icon_type = UiIcon.Icon.SPEAKER
	_sounds.color = Color("4aa8ff")
	_sounds.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_sounds.changed.connect(SaveManager.set_sfx_volume)
	col.add_child(_sounds)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 50)
	col.add_child(row)
	var back := BigButton.new()
	back.icon_type = UiIcon.Icon.ARROW_LEFT
	back.base_color = Color("8a94a6")
	back.button_size = Vector2(130, 130)
	back.pressed.connect(_close)
	row.add_child(back)
	_battery = BigButton.new()
	_battery.icon_type = UiIcon.Icon.BATTERY
	_battery.button_size = Vector2(130, 130)
	_battery.toggle_mode = true
	_battery.toggled.connect(_on_battery)
	row.add_child(_battery)

	visibility_changed.connect(_on_visibility_changed)
	hide()


func _on_visibility_changed() -> void:
	if not visible:
		return
	_music.set_value(SaveManager.music_volume)
	_sounds.set_value(SaveManager.sfx_volume)
	_battery.set_pressed_no_signal(SaveManager.battery_saver)
	_tint_battery()
	_music.grab_focus.call_deferred()


func _on_battery(on: bool) -> void:
	SaveManager.set_battery_saver(on)
	_tint_battery()


func _tint_battery() -> void:
	# Green when saving battery, grey when off.
	var c := Color("4cc06a") if SaveManager.battery_saver else Color("8a94a6")
	_battery.add_theme_stylebox_override("normal", _battery._style(c, Color(0, 0, 0, 0)))
	_battery.add_theme_stylebox_override("hover", _battery._style(c.lightened(0.1), Color(0, 0, 0, 0)))
	_battery.add_theme_stylebox_override("pressed", _battery._style(c, Color(0, 0, 0, 0)))


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	Sfx.play("ui_back")
	hide()
	closed.emit()
