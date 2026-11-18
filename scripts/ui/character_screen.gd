class_name CharacterScreen
extends CanvasLayer
## Make your character, without reading. Left: your character on a turntable
## (right stick spins it; left alone it turns slowly and waves). Right: two
## picture tabs (hair, outfit) and big picture tiles for the choices.
##   LB / RB (or up / down)        change tab
##   left / right (stick, D-pad)   pick on this tab: the character changes
##                                 straight away
##   A (or the green tick)         done: save and go on
##   B                             back (from the pause menu: undo changes)
## Tiles, tabs and the tick can be tapped too. Shown on first start and from
## the pause menu (person button).

signal done
signal back_requested

const TABS := 2  # hair, outfit
const TURN_SPEED := 2.6  # radians/s at full right stick

var tab := 0
## The choices being tried on: [hair 0..3, outfit 0..4].
var choice := [0, 0]
var allow_back := true

var _preview: CharacterModel
var _turntable: Node3D
var _tab_tiles: Array[CharacterTile] = []
var _tiles_box: HBoxContainer
var _tiles: Array[CharacterTile] = []
var _saved := ["M", 1, 1]
var _spin_t := 0.0


func _ready() -> void:
	layer = 16
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.2, 0.4, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	# Left: the character on a turntable.
	var view := SubViewportContainer.new()
	view.stretch = true
	view.anchor_right = 0.45
	view.anchor_bottom = 1.0
	view.offset_top = 30
	view.offset_bottom = -30
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(view)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_2X
	view.add_child(vp)
	_build_stage(vp)

	# Right: tabs, tiles, and the buttons.
	var right := VBoxContainer.new()
	right.anchor_left = 0.45
	right.anchor_right = 1.0
	right.anchor_bottom = 1.0
	right.offset_left = 10
	right.offset_right = -40
	right.offset_top = 60
	right.offset_bottom = -40
	right.add_theme_constant_override("separation", 46)
	root.add_child(right)

	var tabs_row := HBoxContainer.new()
	tabs_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs_row.add_theme_constant_override("separation", 18)
	right.add_child(tabs_row)
	tabs_row.add_child(_glyph(UiIcon.Icon.BUTTON_LB, Vector2(84, 84)))
	for i in TABS:
		var t := CharacterTile.new(CharacterTile.Kind.TAB, i + 1, Vector2(110, 110))
		t.pressed.connect(func(): _set_tab(i))
		tabs_row.add_child(t)
		_tab_tiles.append(t)
	tabs_row.add_child(_glyph(UiIcon.Icon.BUTTON_RB, Vector2(84, 84)))

	_tiles_box = HBoxContainer.new()
	_tiles_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_tiles_box.add_theme_constant_override("separation", 22)
	_tiles_box.custom_minimum_size = Vector2(0, 190)
	right.add_child(_tiles_box)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 30)
	right.add_child(buttons)
	var back := BigButton.new()
	back.icon_type = UiIcon.Icon.ARROW_LEFT
	back.base_color = Color("8a94a6")
	back.button_size = Vector2(110, 110)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_back)
	back.name = "Back"
	buttons.add_child(back)
	buttons.add_child(_glyph(UiIcon.Icon.BUTTON_B, Vector2(64, 64)))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(40, 0)
	buttons.add_child(spacer)
	buttons.add_child(_glyph(UiIcon.Icon.BUTTON_A, Vector2(64, 64)))
	var ok := BigButton.new()
	ok.icon_type = UiIcon.Icon.CHECK
	ok.base_color = Color("4cc06a")
	ok.button_size = Vector2(150, 150)
	ok.focus_mode = Control.FOCUS_NONE
	ok.pressed.connect(_confirm)
	buttons.add_child(ok)
	hide()


func _glyph(icon: UiIcon.Icon, s: Vector2) -> UiIcon:
	var g := UiIcon.new()
	g.icon = icon
	g.custom_minimum_size = s
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


func _build_stage(vp: SubViewport) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.88, 1.0)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	sun.light_energy = 1.1
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 2.8, 13.0)
	cam.rotation_degrees = Vector3(-4, 0, 0)
	cam.fov = 40
	vp.add_child(cam)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.2
	cyl.bottom_radius = 2.4
	cyl.height = 0.3
	disc.mesh = cyl
	disc.position.y = -0.15
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("ffd23f")
	disc.material_override = m
	vp.add_child(disc)
	_turntable = Node3D.new()
	_turntable.rotation.y = PI + 0.35  # facing the camera, a little turned
	vp.add_child(_turntable)
	_preview = (load("res://scenes/characters/player_character.tscn") as PackedScene).instantiate() as CharacterModel
	_turntable.add_child(_preview)


## Show the screen with the saved character. can_go_back: B returns
## (the pause menu; on first start it goes back to the title).
func open(can_go_back: bool) -> void:
	allow_back = can_go_back
	_saved = [SaveManager.char_body, SaveManager.char_hair, SaveManager.char_outfit]
	choice = [SaveManager.char_hair - 1, SaveManager.char_outfit - 1]
	_turntable.rotation.y = PI + 0.35
	show()
	_set_tab(0, true)
	_try_on()


## The look being tried on, as [body (kept from the save), hair 1..4,
## outfit 1..5].
func current_look() -> Array:
	return [SaveManager.char_body, choice[0] + 1, choice[1] + 1]


func preview() -> CharacterModel:
	return _preview


func _set_tab(i: int, quiet := false) -> void:
	tab = posmod(i, TABS)
	for k in TABS:
		_tab_tiles[k].selected = k == tab
	for t in _tiles:
		t.queue_free()
	_tiles.clear()
	var count := CharacterModel.HAIRS if tab == 0 else Outfits.count()
	var kind: CharacterTile.Kind = [CharacterTile.Kind.HAIR, CharacterTile.Kind.OUTFIT][tab]
	for k in count:
		var t := CharacterTile.new(kind, k, Vector2(124, 124) if count > 4 else Vector2(150, 150))
		t.pressed.connect(func(): _pick(k))
		_tiles_box.add_child(t)
		_tiles.append(t)
	_mark()
	if not quiet:
		Sfx.play("ui_move", 0.9 + tab * 0.15)


func _pick(i: int) -> void:
	var count := _tiles.size()
	i = posmod(i, count)
	if i == choice[tab]:
		return
	choice[tab] = i
	_mark()
	_try_on()
	Sfx.play("pop", 1.0 + i * 0.12)


func _mark() -> void:
	for k in _tiles.size():
		_tiles[k].selected = k == choice[tab]


func _try_on() -> void:
	var look := current_look()
	_preview.apply(look[0], look[1], look[2])
	# A little hop so the change is noticed.
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_turntable, "position:y", 0.35, 0.1)
	tw.tween_property(_turntable, "position:y", 0.0, 0.22)


func _confirm() -> void:
	var look := current_look()
	SaveManager.set_character(look[0], look[1], look[2])
	Sfx.play("ui_confirm")
	done.emit()


func _back() -> void:
	if not allow_back:
		return
	# Not saved: anything tried on is forgotten.
	_preview.apply(_saved[0], _saved[1], _saved[2])
	Sfx.play("ui_back")
	back_requested.emit()


func _process(delta: float) -> void:
	if not visible:
		return
	var spin := Input.get_axis("look_left", "look_right")
	if absf(spin) > 0.05:
		_turntable.rotation.y += spin * TURN_SPEED * delta
		_spin_t = 0.0
	else:
		_spin_t += delta
		# Left alone: a slow turntable, and a little wave now and then.
		if _spin_t > 1.5:
			_turntable.rotation.y += 0.35 * delta
		if fmod(_spin_t, 7.0) < delta and _spin_t > 3.0:
			_preview.wave()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("tab_next") or event.is_action_pressed("ui_down"):
		_set_tab(tab + 1)
	elif event.is_action_pressed("tab_prev") or event.is_action_pressed("ui_up"):
		_set_tab(tab - 1)
	elif event.is_action_pressed("ui_right"):
		_pick(choice[tab] + 1)
	elif event.is_action_pressed("ui_left"):
		_pick(choice[tab] - 1)
	elif event.is_action_pressed("ui_accept"):
		_confirm()
	elif event.is_action_pressed("ui_cancel"):
		_back()
	else:
		return
	get_viewport().set_input_as_handled()
