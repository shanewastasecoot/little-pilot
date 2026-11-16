extends Node3D
## Game flow: Title -> Plane Select -> Flying <-> Paused.
## The world is always live: on the title and plane-select screens the plane
## circles on autopilot behind the menus, so it's flying within seconds.

enum State { TITLE, SELECT, FLYING, PAUSED }

## Seconds without input before the stick hint appears.
const IDLE_HINT_DELAY := 10.0

## No input for this long while flying = nobody's playing (the Deck was put
## down): stop counting playtime until they touch it again.
const AWAY_TIME := 120.0

## Gentle circle flown behind the menus.
const AUTOPILOT_STICK := Vector2(0.3, 0.0)

var state: State = State.TITLE
var _idle_time := 0.0
## City celebration: countdown seconds left (> 0), or -1 when idle.
const CITY_COUNTDOWN := 30.0
const FIREWORKS_TIME := 25.0
var _party_countdown := -1.0
var _city: Node3D
var _fireworks: CityFireworks
var _settings: SettingsPanel
## Seconds from a crash to the screen fading, and the fade time each way.
const CRASH_HOLD := 1.3
const CRASH_FADE := 0.45
var _fade: ColorRect
var _respawning := false
var _dragon: Dragon

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
	aircraft.crashes = SaveManager.crashes
	aircraft.park(map.runway_start(), map.spawn_heading())
	chase_camera.snap_to_target()
	aircraft.crashed.connect(_on_crashed)
	SaveManager.settings_changed.connect(func(): aircraft.crashes = SaveManager.crashes)
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 40
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(1, 1, 1, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(_fade)
	hud.bind(stars)
	stars.all_collected.connect(_on_all_stars)
	stars.city_party_due.connect(_on_city_party_due)
	for l in get_tree().get_nodes_in_group("landmarks"):
		if l is CityDistrict:
			_city = l
	if _city:
		_fireworks = CityFireworks.new()
		_city.add_child(_fireworks)
		_fireworks.show_finished.connect(hud.hide_city_pointer)
		_city.growth.building_opened.connect(hud.show_news)
	for l in get_tree().get_nodes_in_group("landmarks"):
		l.discovered.connect(_on_landmark_discovered)
	_dragon = get_tree().get_first_node_in_group("dragon") as Dragon
	if _dragon:
		_dragon.plane_hit.connect(func(_where, _fire): aircraft.explode())

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
	aircraft.ground_controls = player_flying
	aircraft.input.override_throttle = 0.0
	get_tree().paused = state == State.PAUSED
	Music.set_mood("flight" if player_flying else "menu")
	_idle_time = 0.0
	hud.show_idle_hint(false, true)
	aircraft.get_node("FlightAudio").level = 1.0 if player_flying else 0.4


func _process(delta: float) -> void:
	_update_city_party(delta)
	_idle_time += delta
	if state == State.FLYING and _idle_time < AWAY_TIME:
		SaveManager.add_playtime(delta)
	# Waiting on the runway: show the hint straight away so they know to go.
	var waiting := aircraft.mode == Aircraft.Mode.PARKED
	hud.show_idle_hint(state == State.FLYING and (waiting or _idle_time > IDLE_HINT_DELAY))
	_update_dragon_warning()


## Edge glow and arrow while the dragon is hunting the plane.
func _update_dragon_warning() -> void:
	var hunting := _dragon != null and _dragon.visible and state == State.FLYING \
			and (_dragon.state == Dragon.State.HUNT or _dragon.state == Dragon.State.BREATHE) \
			and aircraft.mode == Aircraft.Mode.FLYING
	if not hunting:
		hud.set_dragon_warning(false)
		return
	var cam := chase_camera.cam
	var to := _dragon.global_position - cam.global_position
	var fwd := -cam.global_basis.z
	var flat_fwd := Vector2(fwd.x, fwd.z).normalized()
	var flat_to := Vector2(to.x, to.z).normalized()
	var angle := flat_fwd.angle_to(flat_to)
	var closeness := clampf(1.0 - to.length() / 450.0, 0.0, 1.0)
	hud.set_dragon_warning(true, angle, closeness, _dragon.state == Dragon.State.BREATHE)


func _input(event: InputEvent) -> void:
	# Any real input resets the idle timer (stick past its dead zone counts).
	if event is InputEventJoypadMotion:
		if absf(event.axis_value) > 0.3:
			_idle_time = 0.0
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventScreenTouch:
		_idle_time = 0.0


func _on_city_party_due() -> void:
	# One celebration at a time; extra 30s during a show are ignored.
	if _city == null or _party_countdown > 0.0 or _fireworks.running:
		return
	_party_countdown = CITY_COUNTDOWN
	Sfx.play("jingle", 1.2)


func _update_city_party(delta: float) -> void:
	if _city == null or (_party_countdown <= 0.0 and not _fireworks.running):
		return
	if _party_countdown > 0.0:
		_party_countdown -= delta
		if _party_countdown <= 0.0:
			_party_countdown = -1.0
			_fireworks.start(FIREWORKS_TIME)
			Sfx.play("fanfare")
	# Arrow: direction to the city relative to where the camera is looking.
	var cam := chase_camera.cam
	var to_city := _city.global_position - cam.global_position
	var local := cam.global_basis.inverse() * to_city
	var angle := atan2(local.x, -local.z)
	var secs := ceili(_party_countdown) if _party_countdown > 0.0 else -1
	hud.show_city_pointer(angle, secs)


func _open_settings() -> void:
	pause_menu.hide()
	_settings.show()


func _unhandled_input(event: InputEvent) -> void:
	if state == State.FLYING and event.is_action_pressed("paint_next"):
		aircraft.cycle_paint(1)
		get_viewport().set_input_as_handled()
		return
	if state == State.FLYING and event.is_action_pressed("paint_prev"):
		aircraft.cycle_paint(-1)
		get_viewport().set_input_as_handled()
		return
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


## Bonk! A puff and some stars (or a splash), a moment to see it, then a
## quick white fade and back to the runway, ready to take off again. Stars
## and everything else are kept: crashing never takes anything away.
func _on_crashed(where: Vector3, into_water: bool) -> void:
	if _respawning:
		return
	_respawning = true
	# Effects a little towards the camera so walls don't hide them.
	where += (chase_camera.cam.global_position - where).normalized() * 4.0
	if aircraft.exploded:
		_explosion(where)
	elif into_water:
		Sfx.play("splash", 1.0)
		var splash := PickupBurst.new(60, 14.0, [Color.WHITE, Color("bfe9ff"), Color("7fd3ff")])
		splash.gravity = Vector3(0, -16, 0)
		splash.scale_amount_min = 0.8
		splash.scale_amount_max = 1.6
		splash.position = where  # set before adding (main sits at the origin)
		add_child(splash)
	else:
		Sfx.play("boom", 1.5, -6.0)
		Sfx.play("pop", 0.6)
		var puff := PickupBurst.new(40, 10.0, [Color("d9d9d9"), Color("ffffff"), Color("b0b0b0")])
		puff.scale_amount_min = 1.2  # big soft smoke balls
		puff.scale_amount_max = 2.4
		puff.lifetime = 1.4
		puff.position = where
		add_child(puff)
		var dizzy := PickupBurst.new(14, 8.0, [Color("ffd23f"), Color("fff27a")])
		dizzy.scale_amount_min = 0.6
		dizzy.scale_amount_max = 1.0
		dizzy.position = where + Vector3.UP * 3.0
		add_child(dizzy)
	await get_tree().create_timer(CRASH_HOLD, false).timeout
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, CRASH_FADE)
	await tw.finished
	aircraft.park(map.runway_start(), map.spawn_heading())
	chase_camera.snap_to_target()
	if _dragon:
		_dragon.forgive(12.0)  # a fresh start: it leaves you alone for a bit
	tw = create_tween()
	tw.tween_property(_fade, "color:a", 0.0, CRASH_FADE)
	_respawning = false


## The dragon got the plane: a fireball, smoke, bits of plane flying off
## in its paint colour, and an orange flash.
func _explosion(where: Vector3) -> void:
	Sfx.play("explode", 1.0, 2.0)
	var paint := Paint.color(SaveManager.get_paint(aircraft.stats.id, aircraft.stats.default_paint))
	var fire := PickupBurst.new(70, 22.0, [Color(2.0, 1.8, 1.2), Color("ffb02e"), Color("ff5a1f"), Color("8a2a10")]).keep_scale()
	fire.scale_amount_min = 2.5
	fire.scale_amount_max = 5.0
	fire.lifetime = 1.1
	fire.gravity = Vector3(0, 4, 0)
	fire.position = where
	add_child(fire)
	var smoke := PickupBurst.new(40, 9.0, [Color("555555"), Color("333333"), Color("777777")]).keep_scale()
	smoke.scale_amount_min = 3.0
	smoke.scale_amount_max = 6.0
	smoke.lifetime = 2.2
	smoke.gravity = Vector3(0, 3, 0)
	smoke.position = where
	add_child(smoke)
	var bits := PickupBurst.new(26, 30.0, [paint, paint.darkened(0.3), Color("dddddd")]).keep_scale()
	bits.gravity = Vector3(0, -22, 0)
	bits.scale_amount_min = 1.2
	bits.scale_amount_max = 2.4
	bits.lifetime = 1.6
	bits.position = where
	add_child(bits)
	var flash := create_tween()
	_fade.color = Color(1.0, 0.6, 0.2, 0.0)
	flash.tween_property(_fade, "color:a", 0.55, 0.06)
	flash.tween_property(_fade, "color:a", 0.0, 0.35)
	await flash.finished
	_fade.color = Color(1, 1, 1, 0)


func _on_landmark_discovered(_landmark: Landmark) -> void:
	hud.celebrate_discovery()


func _on_all_stars() -> void:
	# Fireworks around the plane.
	var colors: Array[Color] = [Color("ffd23f"), Color("ff5a5f"), Color("4cc06a"), Color("4aa8ff"), Color("9b5de5")]
	for i in 6:
		var burst := PickupBurst.new(60, 22.0, colors)
		var a := TAU * i / 6.0
		burst.position = aircraft.global_position + Vector3(cos(a) * 12.0, 6.0 + (i % 2) * 6.0, sin(a) * 12.0)
		add_child(burst)
		await get_tree().create_timer(0.2, false).timeout
