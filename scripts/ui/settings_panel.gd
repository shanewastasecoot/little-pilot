class_name SettingsPanel
extends CanvasLayer
## Parent settings, opened from the pause menu (gear button):
## music volume, sound volume, a battery saver (30 FPS cap), whether the
## city-fireworks arrow is shown, whether the plane can crash, whether the
## dragon lives on the island and how tough it is (1-3 flames).
## Bottom row: how long they've played, "Restart the city" (press once and
## it turns orange; press again within a few seconds to really do it), the
## walking camera's speed (1-3 dots) and up/down direction (invert).
## B / Esc or the back arrow closes it. Changes save automatically.

signal closed

## Seconds the city-restart button stays armed after the first press.
const CITY_ARM_TIME := 4.0
const CITY_BLUE := Color("4aa8ff")
const CITY_ARMED := Color("ff9f1c")

var _music: VolumeBar
var _sounds: VolumeBar
var _battery: BigButton
var _arrow: BigButton
var _parcel_arrow: BigButton
var _crash: BigButton
var _dragon: BigButton
var _level: BigButton
var _city: BigButton
var _played: Label
var _city_armed := 0.0
var _cam_speed: BigButton
var _invert: BigButton
## Camera speeds for 1, 2, 3 dots.
const CAMERA_SPEEDS := [0.6, 1.0, 1.6]


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

	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 30)
	col.add_child(row2)
	var flown := UiIcon.new()
	flown.icon = UiIcon.Icon.PLANE
	flown.custom_minimum_size = Vector2(70, 70)
	row2.add_child(flown)
	_played = Label.new()
	_played.add_theme_font_size_override("font_size", 44)
	_played.add_theme_color_override("font_color", Color.WHITE)
	_played.add_theme_color_override("font_outline_color", Color(0.15, 0.2, 0.35))
	_played.add_theme_constant_override("outline_size", 10)
	_played.custom_minimum_size = Vector2(240, 0)
	row2.add_child(_played)
	_city = BigButton.new()
	_city.icon_type = UiIcon.Icon.CITY
	_city.button_size = Vector2(130, 130)
	_city.pressed.connect(_on_city_pressed)
	row2.add_child(_city)
	_cam_speed = BigButton.new()
	_cam_speed.icon_type = UiIcon.Icon.CAMERA
	_cam_speed.button_size = Vector2(130, 130)
	_cam_speed.pressed.connect(_on_cam_speed)
	row2.add_child(_cam_speed)
	_invert = BigButton.new()
	_invert.icon_type = UiIcon.Icon.INVERT_Y
	_invert.button_size = Vector2(130, 130)
	_invert.toggle_mode = true
	_invert.toggled.connect(func(on): SaveManager.set_invert_y(on); _tint_battery())
	row2.add_child(_invert)
	# The delivery arrow on or off (the picture of who it's for still shows).
	_parcel_arrow = BigButton.new()
	_parcel_arrow.icon_type = UiIcon.Icon.PARCEL
	_parcel_arrow.button_size = Vector2(130, 130)
	_parcel_arrow.toggle_mode = true
	_parcel_arrow.toggled.connect(func(on): SaveManager.set_delivery_arrow(on); _tint_battery())
	row2.add_child(_parcel_arrow)

	visibility_changed.connect(_on_visibility_changed)
	hide()


func _process(delta: float) -> void:
	if _city_armed > 0.0:
		_city_armed -= delta
		if _city_armed <= 0.0:
			_tint(_city, CITY_BLUE)


## First press arms it (orange), a second press within CITY_ARM_TIME
## restarts the city, so a stray tap never wipes hours of building.
func _on_city_pressed() -> void:
	if _city_armed > 0.0:
		_city_armed = 0.0
		SaveManager.reset_city()
		Sfx.play("ui_confirm")
		_tint(_city, Color("4cc06a"))
		create_tween().tween_callback(_tint.bind(_city, CITY_BLUE)).set_delay(0.8)
	else:
		_city_armed = CITY_ARM_TIME
		Sfx.play("ui_move")
		_tint(_city, CITY_ARMED)


func _on_visibility_changed() -> void:
	if not visible:
		return
	_music.set_value(SaveManager.music_volume)
	_sounds.set_value(SaveManager.sfx_volume)
	_battery.set_pressed_no_signal(SaveManager.battery_saver)
	_arrow.set_pressed_no_signal(SaveManager.city_arrow)
	_crash.set_pressed_no_signal(SaveManager.crashes)
	_dragon.set_pressed_no_signal(SaveManager.dragon)
	_played.text = SaveManager.format_duration(SaveManager.playtime)
	_invert.set_pressed_no_signal(SaveManager.invert_y)
	_parcel_arrow.set_pressed_no_signal(SaveManager.delivery_arrow)
	_city_armed = 0.0
	_tint(_city, CITY_BLUE)
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


func _tint(b: BigButton, c: Color) -> void:
	b.add_theme_stylebox_override("normal", b._style(c, Color(0, 0, 0, 0)))
	b.add_theme_stylebox_override("hover", b._style(c.lightened(0.1), Color(0, 0, 0, 0)))
	b.add_theme_stylebox_override("pressed", b._style(c, Color(0, 0, 0, 0)))


## Camera speed: one press steps slow -> normal -> fast (1-3 dots).
func _on_cam_speed() -> void:
	var i := CAMERA_SPEEDS.find(_nearest_speed())
	SaveManager.set_look_sensitivity(CAMERA_SPEEDS[(i + 1) % CAMERA_SPEEDS.size()])
	Sfx.play("ui_move", 0.9 + i * 0.15)
	_tint_battery()


func _nearest_speed() -> float:
	var best: float = CAMERA_SPEEDS[1]
	for v: float in CAMERA_SPEEDS:
		if absf(v - SaveManager.look_sensitivity) < absf(best - SaveManager.look_sensitivity):
			best = v
	return best


## Toggle buttons are green when on, grey when off.
func _tint_battery() -> void:
	_cam_speed._icon.pips = CAMERA_SPEEDS.find(_nearest_speed()) + 1
	_tint(_cam_speed, Color("4aa8ff"))
	for pair in [[_battery, SaveManager.battery_saver], [_arrow, SaveManager.city_arrow], [_crash, SaveManager.crashes], [_dragon, SaveManager.dragon],
			[_invert, SaveManager.invert_y], [_parcel_arrow, SaveManager.delivery_arrow]]:
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
