extends Node3D
## Game flow: Title -> Plane Select -> Flying <-> Landed <-> On foot, with
## Paused over any of them. A small state machine: _enter() is the only
## place that switches what's visible, who has the controls, which camera
## is live and what's paused.
##   FLYING   in the air, or rolling on the ground
##   LANDED   the plane has landed and parked somewhere; boost or push the
##            stick to take off again, or Y to get out
##   ON_FOOT  walking about (Walker + WalkCamera); the plane waits, parked.
##            Y near the plane gets back in.
##   INDOORS  inside her house (walked in through the front door): the
##            outdoor world is hidden and paused, the indoor camera and
##            lighting are on; out through the door puts you on the doorstep
##   CHARACTER_CREATE  making your character (first start, before choosing
##            a plane); from the pause menu it opens over PAUSED instead
## The world is always live: on the title and plane-select screens the plane
## circles on autopilot behind the menus, so it's flying within seconds.

enum State { TITLE, SELECT, FLYING, PAUSED, LANDED, CHARACTER_CREATE, ON_FOOT, INDOORS }

## Seconds without input before the stick hint appears.
const IDLE_HINT_DELAY := 10.0

## No input for this long while flying = nobody's playing (the Deck was put
## down): stop counting playtime until they touch it again.
const AWAY_TIME := 120.0

## Gentle circle flown behind the menus.
const AUTOPILOT_STICK := Vector2(0.3, 0.0)

var state: State = State.TITLE
## The play state to go back to after pausing (FLYING or LANDED).
var _play_state: State = State.FLYING
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
## On foot: the character, its camera, and the zone round the parked plane
## where Y gets back in.
var walker: Walker
var walk_camera: WalkCamera
var _door: Area3D
var _near_plane := false
const DOOR_RADIUS := 9.0
## On foot further than this from the plane: a beacon shows where it is,
## and holding Y for PLANE_CALL_HOLD seconds brings it over (PlaneCall).
const PLANE_FAR := 60.0
const PLANE_CALL_HOLD := 1.0
var plane_beacon: DeliveryBeacon
## Her house: the landmark outside, the inside (built once, the first time
## you go in, by BuildingGenerator from resources/buildings/her_house.json),
## the indoor camera and lighting.
const HOUSE_DATA := "res://resources/buildings/her_house.json"
const INDOOR_ENV := "res://resources/environment/indoor.tres"
## The inside is built high above the map (nothing else is up there).
const INTERIOR_HEIGHT := 2000.0
var house: HerHouse
var interior: Interior
var indoor_camera: IndoorCamera
var _outdoor_env: Environment
var _doorway_busy := false
var _call_hold := 0.0
var _calling := false
## Tests hold Y without a controller.
var override_call_hold := false

@onready var map: GameMap = $Map
@onready var aircraft: Aircraft = $Aircraft
@onready var chase_camera: ChaseCamera = $ChaseCamera
@onready var stars: StarManager = $StarManager
@onready var hud: Hud = $Hud
@onready var title: TitleScreen = $TitleScreen
@onready var plane_select: PlaneSelect = $PlaneSelect
@onready var pause_menu: PauseMenu = $PauseMenu
var character_screen: CharacterScreen
## The delivery game: post office, people, the parcel you carry.
var delivery: DeliveryManager


func _ready() -> void:
	aircraft.set_stats(AircraftCatalog.get_stats(SaveManager.selected_aircraft))
	aircraft.crashes = SaveManager.crashes
	aircraft.park(map.runway_start(), map.spawn_heading())
	chase_camera.snap_to_target()
	aircraft.crashed.connect(_on_crashed)
	aircraft.parked.connect(_on_parked)
	walker = Walker.new()
	walker.name = "Walker"
	add_child(walker)
	walk_camera = WalkCamera.new()
	walk_camera.name = "WalkCamera"
	walk_camera.target = walker
	add_child(walk_camera)
	_door = Area3D.new()
	_door.name = "Door"
	_door.collision_layer = 0
	_door.collision_mask = GameSettings.LAYER_PLAYER
	var door_shape := CollisionShape3D.new()
	door_shape.shape = SphereShape3D.new()
	(door_shape.shape as SphereShape3D).radius = DOOR_RADIUS
	_door.add_child(door_shape)
	aircraft.add_child(_door)
	plane_beacon = DeliveryBeacon.new()
	plane_beacon.name = "PlaneBeacon"
	plane_beacon.show_parcel = false
	plane_beacon.exact_colour = true
	map.add_child(plane_beacon)
	plane_beacon.colour = Color("f2f7ff")
	plane_beacon.hide()
	indoor_camera = IndoorCamera.new()
	indoor_camera.name = "IndoorCamera"
	indoor_camera.target = walker
	add_child(indoor_camera)
	for l in get_tree().get_nodes_in_group("landmarks"):
		if l is HerHouse:
			house = l
			house.door_entered.connect(func(): if state == State.ON_FOOT: enter_house())
	_door.body_entered.connect(func(b): if b == walker: _near_plane = true)
	_door.body_exited.connect(func(b): if b == walker: _near_plane = false)
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

	delivery = DeliveryManager.new()
	delivery.name = "Delivery"
	add_child(delivery)
	delivery.setup(self, map)

	character_screen = CharacterScreen.new()
	add_child(character_screen)
	character_screen.done.connect(_on_character_done)
	character_screen.back_requested.connect(_on_character_back)
	pause_menu.character_requested.connect(_open_character.bind(true))
	title.start_requested.connect(_on_start)
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


## The player is in the game world (not in a menu).
func _playing() -> bool:
	return state == State.FLYING or state == State.LANDED or state == State.ON_FOOT or state == State.INDOORS


## The player is in the plane (flying it or parked in it).
func _in_plane() -> bool:
	return state == State.FLYING or state == State.LANDED


func _enter(new_state: State) -> void:
	state = new_state
	if _playing():
		_play_state = state
	title.visible = state == State.TITLE
	plane_select.visible = state == State.SELECT
	if state != State.CHARACTER_CREATE and state != State.PAUSED:
		character_screen.hide()
	pause_menu.visible = state == State.PAUSED and not plane_select.visible and not character_screen.visible
	hud.visible = _playing() or state == State.PAUSED
	var player_flying := _in_plane()
	# On foot (also while paused from walking): the walker and its camera.
	var indoors := state == State.INDOORS or (state == State.PAUSED and _play_state == State.INDOORS)
	var on_foot := indoors or state == State.ON_FOOT or (state == State.PAUSED and _play_state == State.ON_FOOT)
	if walker.is_active() != on_foot:
		walker.set_active(on_foot)
	if indoors:
		indoor_camera.cam.make_current()
	elif on_foot:
		walk_camera.cam.make_current()
	else:
		chase_camera.cam.make_current()
		_near_plane = false
	if not _playing():
		hud.set_prompt("")
	aircraft.input.override_enabled = not player_flying
	aircraft.input.override_stick = Vector2.ZERO if _playing() else AUTOPILOT_STICK
	aircraft.ground_controls = player_flying
	aircraft.input.override_throttle = 0.0
	get_tree().paused = state == State.PAUSED
	Music.set_mood("flight" if _playing() else "menu")
	_idle_time = 0.0
	hud.show_idle_hint(false, true)
	aircraft.get_node("FlightAudio").level = 1.0 if player_flying else 0.4


func _process(delta: float) -> void:
	_update_city_party(delta)
	_idle_time += delta
	if _playing() and _idle_time < AWAY_TIME:
		SaveManager.add_playtime(delta)
	# Rolling again after a landing: back to flying.
	if state == State.LANDED and aircraft.mode != Aircraft.Mode.PARKED:
		_enter(State.FLYING)
	# Waiting on the runway: show the hint straight away so they know to go.
	var waiting := aircraft.mode == Aircraft.Mode.PARKED
	hud.show_idle_hint(_in_plane() and (waiting or _idle_time > IDLE_HINT_DELAY))
	# Y prompt: get out when parked in the plane, get in when beside it.
	if _can_exit_plane():
		hud.set_prompt("exit")
	elif state == State.ON_FOOT and _near_plane:
		hud.set_prompt("enter")
	elif state == State.ON_FOOT and plane_far():
		hud.set_prompt("call")
	elif _playing():
		hud.set_prompt("")
	_update_plane_call(delta)
	# Fell out of the world somehow: back beside the plane.
	if state == State.INDOORS and interior and walker.global_position.y < interior.global_position.y - 20.0:
		walker.place(interior.entry_point(), interior.entry_yaw())
	if state == State.ON_FOOT and walker.global_position.y < -30.0:
		_place_walker()
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
	if _in_plane() and event.is_action_pressed("paint_next"):
		aircraft.cycle_paint(1)
		get_viewport().set_input_as_handled()
		return
	if _in_plane() and event.is_action_pressed("paint_prev"):
		aircraft.cycle_paint(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and toggle_plane():
		get_viewport().set_input_as_handled()
		return
	if _playing() and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		Sfx.play("ui_move")
		_show_pause()


func _notification(what: int) -> void:
	# Steam button / overlay / alt-tab: pause so nothing is missed.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _playing():
		_show_pause()


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	# Controller unplugged or out of battery: pause until it's back.
	if not connected and _playing():
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
	# From the pause menu: back to whatever we were doing (maybe on foot).
	_enter(_play_state if state == State.PAUSED else State.FLYING)


func _show_pause() -> void:
	plane_select.hide()
	_settings.hide()
	_enter(State.PAUSED)


func _resume() -> void:
	_enter(_play_state)


## Start on the title: make your character first if you never have.
func _on_start() -> void:
	if SaveManager.char_made:
		_open_select()
	else:
		_open_character(false)


## The character screen: first start (from_pause false: B goes back to the
## title) or from the pause menu (B undoes and returns to the pause menu).
func _open_character(from_pause: bool) -> void:
	character_screen.open(true)
	if from_pause:
		pause_menu.hide()  # stay paused underneath
	else:
		_enter(State.CHARACTER_CREATE)


func _on_character_done() -> void:
	character_screen.hide()
	if state == State.PAUSED:
		pause_menu.show()
	else:
		_open_select()


func _on_character_back() -> void:
	character_screen.hide()
	if state == State.PAUSED:
		pause_menu.show()
	else:
		_enter(State.TITLE)


## Sitting in the parked plane with the controls: can get out.
func _can_exit_plane() -> bool:
	return _in_plane() and aircraft.mode == Aircraft.Mode.PARKED and aircraft.ground_controls


## Y: get out of the parked plane, or back into it when beside it.
## Returns true if it did either.
func toggle_plane() -> bool:
	if _can_exit_plane():
		if not _place_walker():
			return false  # nowhere to stand (shouldn't happen on landable ground)
		Sfx.play("pop", 1.2)
		walk_camera.snap_to(aircraft.heading)
		_enter(State.ON_FOOT)
		hud.show_foot_hints(true)
		return true
	if state == State.ON_FOOT and _near_plane:
		Sfx.play("pop", 0.9)
		aircraft.hold_until_release()
		chase_camera.snap_to_target()
		_enter(State.LANDED)
		hud.show_foot_hints(false)
		return true
	return false


## Walk in through the front door: a quick fade, the outdoor world hidden
## and paused, and you're in the hall.
func enter_house() -> void:
	if _doorway_busy or house == null:
		return
	_doorway_busy = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, CRASH_FADE * 0.7)
	await tw.finished
	if interior == null:
		interior = BuildingGenerator.build(BuildingGenerator.load_data(HOUSE_DATA))
		add_child(interior)
		interior.global_position = Vector3(house.global_position.x, INTERIOR_HEIGHT, house.global_position.z)
		interior.exit_reached.connect(func(): if state == State.INDOORS: exit_house())
		indoor_camera.interior = interior
	_set_outdoors(false)
	walker.place(interior.entry_point(), interior.entry_yaw())
	interior.arrive()
	_enter(State.INDOORS)
	indoor_camera.snap_to(interior.entry_yaw())
	Sfx.play("pop", 1.0)
	tw = create_tween()
	tw.tween_property(_fade, "color:a", 0.0, CRASH_FADE * 0.7)
	await tw.finished
	_doorway_busy = false


## Out through the front door: back on the doorstep (nothing standing on
## it), the world as you left it, the toys tidied away.
func exit_house() -> void:
	if _doorway_busy:
		return
	_doorway_busy = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, CRASH_FADE * 0.7)
	await tw.finished
	_set_outdoors(true)
	interior.reset()
	var step := house.doorstep()
	# The plane parked on the doorstep? Move it to a safe spot nearby first.
	if Vector2(aircraft.global_position.x - step.x, aircraft.global_position.z - step.z).length() < 16.0:
		var spot := PlaneCall.find_spot(aircraft, step + (step - house.global_position).normalized() * 30.0)
		if not spot.is_empty():
			aircraft.park(spot.pos, spot.yaw)
	walker.place(Vector3(step.x, IslandShape.height(step.x, step.z) + 0.1, step.z), house.doorstep_yaw())
	_enter(State.ON_FOOT)
	walk_camera.snap_to(house.doorstep_yaw())
	Sfx.play("pop", 0.9)
	tw = create_tween()
	tw.tween_property(_fade, "color:a", 0.0, CRASH_FADE * 0.7)
	await tw.finished
	_doorway_busy = false


## The outdoor world on (visible, running) or off (hidden and paused while
## you're inside), with outdoor or indoor lighting.
func _set_outdoors(on: bool) -> void:
	map.visible = on
	map.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	aircraft.visible = on
	aircraft.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	var we := map.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if we == null:
		for c in map.find_children("*", "WorldEnvironment", true, false):
			we = c
	if we:
		if not on:
			_outdoor_env = we.environment
			we.environment = load(INDOOR_ENV)
		elif _outdoor_env:
			we.environment = _outdoor_env
	if interior:
		interior.visible = not on
		interior.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT


## On foot, far from the plane?
func plane_far() -> bool:
	var a := walker.global_position
	var b := aircraft.global_position
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) > PLANE_FAR


## The plane's beacon (on foot and far away) and holding Y to call it.
func _update_plane_call(delta: float) -> void:
	var far := state == State.ON_FOOT and plane_far()
	plane_beacon.visible = far
	if far:
		plane_beacon.global_position = aircraft.global_position - Vector3.UP * aircraft.stats.ground_offset
	var holding := far and not _calling and (override_call_hold or Input.is_action_pressed("interact"))
	_call_hold = _call_hold + delta if holding else 0.0
	hud.set_prompt_hold(_call_hold / PLANE_CALL_HOLD)
	if _call_hold >= PLANE_CALL_HOLD:
		_call_hold = 0.0
		call_plane()


## Bring the parked plane to a safe spot near the walker: a quick fade and
## it's there. No safe spot nearby: a soft "nope" and it stays put (the
## beacon still shows where it is). Returns true if it moved.
func call_plane() -> bool:
	if state != State.ON_FOOT or _calling:
		return false
	var spot := PlaneCall.find_spot(aircraft, walker.global_position)
	if spot.is_empty():
		Sfx.play("pop", 0.5)
		return false
	_calling = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, CRASH_FADE)
	await tw.finished
	aircraft.park(spot.pos, spot.yaw)
	Sfx.play("whoosh", 0.8)
	tw = create_tween()
	tw.tween_property(_fade, "color:a", 0.0, CRASH_FADE)
	await tw.finished
	_calling = false
	return true


## Put the walker on the ground beside the plane. False if no spot is dry,
## on solid ground and not too far above or below the plane.
func _place_walker() -> bool:
	var space := get_world_3d().direct_space_state
	for spot in aircraft.exit_spots():
		var q := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 6.0, spot + Vector3.DOWN * 30.0, GameSettings.LAYER_WORLD)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var p: Vector3 = hit.position
		if p.y < Walker.SHORE_LEVEL or (hit.normal as Vector3).y < cos(deg_to_rad(Walker.MAX_SLOPE_DEG)):
			continue
		if absf(p.y - (aircraft.global_position.y - aircraft.stats.ground_offset)) > 5.0:
			continue
		walker.place(p + Vector3.UP * 0.05, aircraft.heading)
		return true
	return false


## The plane stopped and parked. After a landing that's the LANDED state
## (a little chime: well done!); the game parking it on the runway isn't.
func _on_parked(after_landing: bool) -> void:
	if after_landing and state == State.FLYING:
		Sfx.play("ding")
		_enter(State.LANDED)
	elif not after_landing and state == State.LANDED:
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
