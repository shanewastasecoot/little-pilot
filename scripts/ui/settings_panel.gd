class_name SettingsPanel
extends CanvasLayer
## Parent settings, opened from the pause menu (gear button):
## music volume, sound volume, a battery saver (30 FPS cap), whether the
## city-fireworks arrow is shown, whether the plane can crash, whether the
## dragon lives on the island and how tough it is (1-3 flames).
## B / Esc or the back arrow closes it. Changes save automatically.

signal closed

var _music: VolumeBar
var _sounds: VolumeBar
var _battery: BigButton
var _arrow: BigButton
var _crash: BigButton
var _dragon: BigButton
var _level: BigButton


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
	row.add_theme_constant_override("separation", 30)
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
	_arrow = BigButton.new()
	_arrow.icon_type = UiIcon.Icon.POINTER
	_arrow.button_size = Vector2(130, 130)
	_arrow.toggle_mode = true
	_arrow.toggled.connect(_on_arrow)
	row.add_child(_arrow)
	_crash = BigButton.new()
	_crash.icon_type = UiIcon.Icon.CRASH
	_crash.button_size = Vector2(130, 130)
	_crash.toggle_mode = true
	_crash.toggled.connect(_on_crash)
	row.add_child(_crash)
	_dragon = BigButton.new()
	_dragon.icon_type = UiIcon.Icon.DRAGON
	_dragon.button_size = Vector2(130, 130)
	_dragon.toggle_mode = true
	_dragon.toggled.connect(_on_dragon)
	row.add_child(_dragon)
	# Difficulty: one press steps Easy -> Medium -> Hard (1, 2, 3 flames).
	_level = BigButton.new()
	_level.icon_type = UiIcon.Icon.FLAME
	_level.button_size = Vector2(130, 130)
	_level.pressed.connect(func(): SaveManager.set_dragon_level(SaveManager.dragon_level + 1); _tint_battery())
	row.add_child(_level)

	visibility_changed.connect(_on_visibility_changed)
	hide()


func _on_visibility_changed() -> void:
	if not visible:
		return
	_music.set_value(SaveManager.music_volume)
	_sounds.set_value(SaveManager.sfx_volume)
	_battery.set_pressed_no_signal(SaveManager.battery_saver)
	_arrow.set_pressed_no_signal(SaveManager.city_arrow)
	_crash.set_pressed_no_signal(SaveManager.crashes)
	_dragon.set_pressed_no_signal(SaveManager.dragon)
	_tint_battery()
	_music.grab_focus.call_deferred()


func _on_battery(on: bool) -> void:
	SaveManager.set_battery_saver(on)
	_tint_battery()


func _on_arrow(on: bool) -> void:
	SaveManager.set_city_arrow(on)
	_tint_battery()


func _on_dragon(on: bool) -> void:
	SaveManager.set_dragon(on)
	_tint_battery()


func _on_crash(on: bool) -> void:
	SaveManager.set_crashes(on)
	_tint_battery()


## Toggle buttons are green when on, grey when off.
func _tint_battery() -> void:
	for pair in [[_battery, SaveManager.battery_saver], [_arrow, SaveManager.city_arrow], [_crash, SaveManager.crashes], [_dragon, SaveManager.dragon]]:
		var b: BigButton = pair[0]
		var c := Color("4cc06a") if pair[1] else Color("8a94a6")
		b.add_theme_stylebox_override("normal", b._style(c, Color(0, 0, 0, 0)))
		b.add_theme_stylebox_override("hover", b._style(c.lightened(0.1), Color(0, 0, 0, 0)))
		b.add_theme_stylebox_override("pressed", b._style(c, Color(0, 0, 0, 0)))
	# Difficulty: green, orange, red with 1-3 dots; dim when the dragon is off.
	var lc: Color = [Color("4cc06a"), Color("ff9f1c"), Color("e63946")][SaveManager.dragon_level]
	if not SaveManager.dragon:
		lc = Color("8a94a6")
	_level._icon.pips = SaveManager.dragon_level + 1
	_level.add_theme_stylebox_override("normal", _level._style(lc, Color(0, 0, 0, 0)))
	_level.add_theme_stylebox_override("hover", _level._style(lc.lightened(0.1), Color(0, 0, 0, 0)))
	_level.add_theme_stylebox_override("pressed", _level._style(lc, Color(0, 0, 0, 0)))


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	Sfx.play("ui_back")
	hide()
	closed.emit()
