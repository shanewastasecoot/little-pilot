class_name PlaneSelect
extends CanvasLayer
## Choose a plane without reading: big spinning 3D models side by side.
## Left/right (stick, D-pad, arrows or tapping a plane) picks, A/Play confirms,
## B goes back when opened from the pause menu.

signal confirmed(id: String)
signal back_requested

var allow_back: bool = false
var selected: int = 0

var _ids: Array = AircraftCatalog.ids()
var _pedestals: Array[Node3D] = []
var _rings: Array[MeshInstance3D] = []
var _t := 0.0
var _confirm: BigButton


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.2, 0.4, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var view := SubViewportContainer.new()
	view.stretch = true
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.offset_bottom = -170
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(view)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_2X
	view.add_child(vp)
	_build_stage(vp)

	# Tap targets over each plane (touchscreen).
	for i in _ids.size():
		var tap := Button.new()
		tap.flat = true
		tap.focus_mode = Control.FOCUS_NONE
		tap.anchor_left = float(i) / _ids.size()
		tap.anchor_right = float(i + 1) / _ids.size()
		tap.anchor_bottom = 1.0
		tap.offset_bottom = -170
		tap.pressed.connect(_on_tap.bind(i))
		root.add_child(tap)

	for side in [-1, 1]:
		var arrow := UiIcon.new()
		arrow.icon = UiIcon.Icon.ARROW_LEFT if side < 0 else UiIcon.Icon.ARROW_RIGHT
		arrow.size = Vector2(70, 110)
		arrow.anchor_left = 0.0 if side < 0 else 1.0
		arrow.anchor_right = arrow.anchor_left
		arrow.anchor_top = 0.42
		arrow.anchor_bottom = 0.42
		arrow.position = Vector2(30 if side < 0 else -100, -55)
		root.add_child(arrow)

	_confirm = BigButton.new()
	_confirm.icon_type = UiIcon.Icon.PLAY
	_confirm.base_color = Color("4cc06a")
	_confirm.button_size = Vector2(150, 150)
	_confirm.focus_mode = Control.FOCUS_NONE
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_confirm.position = Vector2(-75, -165)
	_confirm.pressed.connect(_confirm_selection)
	root.add_child(_confirm)


func open(current_id: String, can_go_back: bool) -> void:
	allow_back = can_go_back
	selected = maxi(_ids.find(current_id), 0)
	show()
	_hop(selected)


func _build_stage(vp: SubViewport) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.85, 1.0)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 3.2, 11)
	cam.rotation_degrees = Vector3(-12, 0, 0)
	cam.fov = 50
	vp.add_child(cam)
	for i in _ids.size():
		var stats := AircraftCatalog.get_stats(_ids[i])
		var ped := Node3D.new()
		ped.position = Vector3((i - (_ids.size() - 1) * 0.5) * 7.0, 0, 0)
		vp.add_child(ped)
		var model: Node3D = stats.model_scene.instantiate()
		model.position.y = 1.6
		ped.add_child(model)
		var ring := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 2.8
		disc.bottom_radius = 2.8
		disc.height = 0.3
		ring.mesh = disc
		var mat := StandardMaterial3D.new()
		mat.albedo_color = stats.menu_color
		ring.material_override = mat
		ped.add_child(ring)
		_pedestals.append(ped)
		_rings.append(ring)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	for i in _pedestals.size():
		var ped := _pedestals[i]
		var on := i == selected
		var k := 1.0 - exp(-8.0 * delta)
		ped.scale = ped.scale.lerp(Vector3.ONE * (1.15 if on else 0.75), k)
		var model: Node3D = ped.get_child(0)
		if on:
			model.rotation.y += delta * 1.2
			model.position.y = 1.6 + sin(_t * 3.0) * 0.2
		else:
			model.rotation.y = lerp_angle(model.rotation.y, deg_to_rad(-35), k)
			model.position.y = lerpf(model.position.y, 1.4, k)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_left"):
		_select(selected - 1)
	elif event.is_action_pressed("ui_right"):
		_select(selected + 1)
	elif event.is_action_pressed("ui_accept"):
		_confirm_selection()
	elif event.is_action_pressed("ui_cancel") and allow_back:
		Sfx.play("ui_back")
		back_requested.emit()
	else:
		return
	get_viewport().set_input_as_handled()


func _on_tap(i: int) -> void:
	if i == selected:
		_confirm_selection()
	else:
		_select(i)


func _select(i: int) -> void:
	i = clampi(i, 0, _ids.size() - 1)
	if i == selected:
		return
	selected = i
	Sfx.play("ui_move", 1.0 + i * 0.25)
	_hop(i)


func _hop(i: int) -> void:
	var ring := _rings[i]
	ring.scale = Vector3(1.0, 1.0, 1.0)
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "scale", Vector3(1.25, 1.0, 1.25), 0.12)
	tw.tween_property(ring, "scale", Vector3.ONE, 0.25)


func _confirm_selection() -> void:
	Sfx.play("ui_confirm")
	confirmed.emit(_ids[selected])
