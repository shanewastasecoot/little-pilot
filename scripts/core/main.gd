extends Node3D
## Game flow: Title -> Plane Select -> Flying <-> Paused.
## The world is always live: on the title and plane-select screens the plane
## circles on autopilot behind the menus, so it's flying within seconds.

enum State { TITLE, SELECT, FLYING, PAUSED }

## Seconds without input before the stick hint appears.
const IDLE_HINT_DELAY := 10.0

## Gentle circle flown behind the menus.
const AUTOPILOT_STICK := Vector2(0.3, 0.0)

var state: State = State.TITLE
var _idle_time := 0.0
var _settings: SettingsPanel

@onready var map: GameMap = $Map
@onready var aircraft: Aircraft = $Aircraft
@onready var chase_camera: ChaseCamera = $ChaseCamera
@onready var stars: StarManager = $StarManager
@onready var hud: Hud = $Hud
@onready var title: TitleScreen = $TitleScreen
@onready var plane_select: PlaneSelect = $PlaneSelect
@onready var pause_menu: PauseMenu = $PauseMenu


func _ready() -> void:
	aircraft.set_stats(AircraftCatalog.get_stats(SaveManager.selected_aircraft))
	aircraft.teleport(map.spawn_position, map.spawn_heading())
	chase_camera.snap_to_target()
	hud.bind(stars)
	stars.all_collected.connect(_on_all_stars)
	for l in get_tree().get_nodes_in_group("landmarks"):
		l.discovered.connect(_on_landmark_discovered)

	title.start_requested.connect(_open_select)
	plane_select.confirmed.connect(_on_plane_confirmed)
	plane_select.back_requested.connect(_show_pause)
	pause_menu.resume_requested.connect(_resume)
	pause_menu.change_plane_requested.connect(_open_select)
	pause_menu.quit_requested.connect(_quit)
	_settings = SettingsPanel.new()
	add_child(_settings)
	pause_menu.settings_requested.connect(_open_settings)
	_settings.closed.connect(_show_pause)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_enter(State.TITLE)


func _enter(new_state: State) -> void:
	state = new_state
	title.visible = state == State.TITLE
	plane_select.visible = state == State.SELECT
	pause_menu.visible = state == State.PAUSED and not plane_select.visible
	hud.visible = state == State.FLYING or state == State.PAUSED
	var player_flying := state == State.FLYING
	aircraft.input.override_enabled = not player_flying
	aircraft.input.override_stick = Vector2.ZERO if player_flying else AUTOPILOT_STICK
	aircraft.input.override_throttle = 0.0
	get_tree().paused = state == State.PAUSED
	Music.set_mood("flight" if player_flying else "menu")
	_idle_time = 0.0
	hud.show_idle_hint(false, true)
	aircraft.get_node("FlightAudio").level = 1.0 if player_flying else 0.4


func _process(delta: float) -> void:
	_idle_time += delta
	hud.show_idle_hint(state == State.FLYING and _idle_time > IDLE_HINT_DELAY)


func _input(event: InputEvent) -> void:
	# Any real input resets the idle timer (stick past its dead zone counts).
	if event is InputEventJoypadMotion:
		if absf(event.axis_value) > 0.3:
			_idle_time = 0.0
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventScreenTouch:
		_idle_time = 0.0


func _open_settings() -> void:
	pause_menu.hide()
	_settings.show()


func _unhandled_input(event: InputEvent) -> void:
	if state == State.FLYING and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		Sfx.play("ui_move")
		_show_pause()


func _notification(what: int) -> void:
	# Steam button / overlay / alt-tab: pause so nothing is missed.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == State.FLYING:
		_show_pause()


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	# Controller unplugged or out of battery: pause until it's back.
	if not connected and state == State.FLYING:
		_show_pause()


func _open_select() -> void:
	var from_pause := state == State.PAUSED
	plane_select.open(aircraft.stats.id, from_pause)
	if from_pause:
		pause_menu.hide()  # stay paused underneath
	else:
		_enter(State.SELECT)


func _on_plane_confirmed(id: String) -> void:
	aircraft.set_stats(AircraftCatalog.get_stats(id))
	SaveManager.set_selected_aircraft(id)
	plane_select.hide()
	_enter(State.FLYING)


func _show_pause() -> void:
	plane_select.hide()
	_settings.hide()
	_enter(State.PAUSED)


func _resume() -> void:
	_enter(State.FLYING)


func _quit() -> void:
	SaveManager.save_now()
	get_tree().quit()


func _on_landmark_discovered(_landmark: Landmark) -> void:
	hud.celebrate_discovery()


func _on_all_stars() -> void:
	# Fireworks around the plane.
	var colors: Array[Color] = [Color("ffd23f"), Color("ff5a5f"), Color("4cc06a"), Color("4aa8ff"), Color("9b5de5")]
	for i in 6:
		var burst := PickupBurst.new(60, 22.0, colors)
		add_child(burst)
		var a := TAU * i / 6.0
		burst.global_position = aircraft.global_position + Vector3(cos(a) * 12.0, 6.0 + (i % 2) * 6.0, sin(a) * 12.0)
		await get_tree().create_timer(0.2, false).timeout
