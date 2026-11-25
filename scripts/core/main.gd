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

enum State { TITLE, SELECT, FLYING, PAUSED, LANDED, CHARACTER_CREATE, ON_FOOT, INDOORS, SAILING }

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
## The moment under the sea after a splash (inside the crash's pause).
var underwater: UnderwaterView
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
const PLANE_FAR := 30.0
const PLANE_CALL_HOLD := 1.0
var plane_beacon: DeliveryBeacon
## Her room's colour chooser (opened with Y at a PaintStation).
var colour_menu: ColourMenu
## The hat shop's chooser (Y at its mirror).
var hat_menu: HatMenu
## The instrument panel in the cockpit view (Phase 9).
var gauges: CockpitGauges
## Her house: the landmark outside, the inside (built once, the first time
## you go in, by BuildingGenerator from resources/buildings/her_house.json),
## the indoor camera and lighting.
const HOUSE_DATA := "res://resources/buildings/her_house.json"
const INDOOR_ENV := "res://resources/environment/indoor.tres"
## The inside is built high above the map (nothing else is up there).
const INTERIOR_HEIGHT := 2000.0
var house: HerHouse
## The inside you're in (or were last in), and every inside built so far
## (by building id; built the first time you go in, kept after).
var interior: Interior
var interiors := {}
## The building you went into (her house, a post office...).
var building: Node3D
var indoor_camera: IndoorCamera
var _outdoor_env: Environment
var _doorway_busy := false
## Y pressed while the plane was still rolling: get out as soon as it stops
## (forgotten if it takes off again or she pushes on).
var exit_queued := false
var ground_dust: GroundDust
var sky_writer: SkyWriter
## Follow-the-leader (Phase 14): a friendly plane invites her to follow it.
var leader: FollowLeader
## Today's summary for the parent (pause menu, Phase 14).
var summary: SummaryScreen
var today_tracker: TodayTracker
## The sticker book and its pictures (Phase 14); LB takes a postcard.
var spotter: Spotter
## Sailing (Phase 14): a dock on every major island and her own sail boat.
var docks: Array[Dock] = []
var boat: SailBoat
var sail_camera: SailCamera
var book: StickerBook
## The game last stopped with her inside: start outside the front door.
var _start_at_house := false
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
	add_to_group("game_main")
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
	_start_at_house = SaveManager.house_inside
	if _start_at_house:
		SaveManager.set_house_inside(false)
	for l in get_tree().get_nodes_in_group("landmarks"):
		if l is HerHouse:
			house = l
			house.door_entered.connect(func(): if state == State.ON_FOOT: enter_house())
	_door.body_entered.connect(func(b): if b == walker: _near_plane = true)
	_door.body_exited.connect(func(b): if b == walker: _near_plane = false)
	SaveManager.settings_changed.connect(func(): aircraft.crashes = SaveManager.crashes)
	colour_menu = ColourMenu.new()
	colour_menu.name = "ColourMenu"
	hud.add_child(colour_menu)
	colour_menu.chosen.connect(_on_colour_chosen)
	colour_menu.cancelled.connect(func(): _hold_walker(false))
	gauges = CockpitGauges.new()
	gauges.name = "CockpitGauges"
	hud.add_child(gauges)
	hud.move_child(gauges, 0)  # under the HUD's own pictures
	hat_menu = HatMenu.new()
	hat_menu.name = "HatMenu"
	hud.add_child(hat_menu)
	hat_menu.preview = func(id: String): walker.model.set_hat(id)
	hat_menu.chosen.connect(_on_hat_chosen)
	hat_menu.cancelled.connect(func():
		_hold_walker(false)
		indoor_camera.close_up = false)
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 40
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(1, 1, 1, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(_fade)
	underwater = UnderwaterView.new()
	underwater.name = "Underwater"
	fade_layer.add_child(underwater)
	fade_layer.move_child(underwater, _fade.get_index())  # under the white fade
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
	# Bench toggles (Phase 8): only when given on the command line.
	var we := map.find_children("*", "WorldEnvironment", true, false)
	BenchToggles.apply(get_viewport(), (we[0] as WorldEnvironment).environment if not we.is_empty() else null)
	# A local playtest diary, debug builds only, when asked (--record-playtest).
	PlaytestRecorder.maybe_start(self)
	# Today's diary and its page for the parent (Phase 14).
	today_tracker = TodayTracker.new()
	today_tracker.name = "TodayTracker"
	today_tracker.main = self
	add_child(today_tracker)
	summary = SummaryScreen.new()
	summary.name = "Summary"
	add_child(summary)
	pause_menu.today_requested.connect(func(): Sfx.play("ui_confirm"); summary.open())
	spotter = Spotter.new()
	spotter.name = "Spotter"
	spotter.main = self
	spotter.flash = _fade
	add_child(spotter)
	book = StickerBook.new()
	book.name = "StickerBook"
	book.spotter = spotter
	add_child(book)
	pause_menu.book_requested.connect(func(): book.open())
	for i in Dock.SPOTS.size():
		var d := Dock.make(i)
		map.add_child(d)
		docks.append(d)
	boat = SailBoat.new()
	map.add_child(boat)
	boat.docks = docks
	boat.moor(docks[clampi(SaveManager.boat_dock, 0, docks.size() - 1)])
	boat.berthed.connect(_on_boat_berthed)
	sail_camera = SailCamera.new()
	sail_camera.name = "SailCamera"
	sail_camera.target = boat
	add_child(sail_camera)
	leader = FollowLeader.new()
	leader.main = self
	add_child(leader)
	# Sky-writing (Phase 14): hold RB while flying.
	sky_writer = SkyWriter.new()
	sky_writer.name = "SkyWriter"
	sky_writer.aircraft = aircraft
	add_child(sky_writer)
	# Dust off the grass: the plane's take-off roll, her running.
	ground_dust = GroundDust.new()
	ground_dust.name = "GroundDust"
	ground_dust.aircraft = aircraft
	ground_dust.walker = walker
	add_child(ground_dust)
	# The post offices' front doors: walk in.
	for po in delivery.post_offices:
		po.door_entered.connect(func(): if state == State.ON_FOOT: enter_building(po))
	# The hat shop by the airport.
	for hs in get_tree().get_nodes_in_group("hat_shops"):
		hs.door_entered.connect(func(): if state == State.ON_FOOT: enter_building(hs))

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
	return state == State.FLYING or state == State.LANDED or state == State.ON_FOOT or state == State.INDOORS \
			or state == State.SAILING


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
	var sailing := state == State.SAILING or (state == State.PAUSED and _play_state == State.SAILING)
	if indoors:
		indoor_camera.cam.make_current()
	elif on_foot:
		walk_camera.cam.make_current()
	elif sailing:
		sail_camera.cam.make_current()
		_near_plane = false
	else:
		chase_camera.cam.make_current()
		_near_plane = false
	if not _playing():
		hud.set_prompt("")
	if not on_foot:
		hud.show_foot_hints(false)  # (A jump / B run are for walking only)
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
	if exit_queued:
		if not _in_plane() or aircraft.mode == Aircraft.Mode.FLYING or aircraft.mode == Aircraft.Mode.CRASHED \
				or aircraft.input.raw_throttle > 0.3:
			exit_queued = false
		elif _can_exit_plane():
			toggle_plane()
	if _can_exit_plane() or exit_queued:
		hud.set_prompt("exit")
	elif state == State.ON_FOOT and _near_plane:
		hud.set_prompt("enter")
	elif state == State.SAILING:
		hud.set_prompt("exit" if boat.driving and boat.dock_near() != null else "")
	elif dock_here() != null and not boat.berthing:
		hud.set_prompt("boat")
	elif state == State.ON_FOOT and plane_far():
		hud.set_prompt("call")
	elif state == State.INDOORS and interior and not colour_menu.is_open() and not hat_menu.is_open() and not interior.interaction_at(walker).is_empty():
		hud.set_prompt(interior.interaction_at(walker).kind)
	elif _playing():
		hud.set_prompt("")
	_update_plane_call(delta)
	_update_gauges()
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
	# LB while playing: a postcard for the sticker book.
	if event.is_action_pressed("tab_prev") and state in [State.FLYING, State.LANDED, State.ON_FOOT, State.INDOORS, State.SAILING] \
			and not colour_menu.is_open() and not hat_menu.is_open() and spotter.postcard():
		get_viewport().set_input_as_handled()
		return
	# X on foot (or indoors): a big cheer; nearby people cheer back.
	if event.is_action_pressed("trick") and cheer():
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and open_colour_menu():
		get_viewport().set_input_as_handled()
		return
	if state == State.SAILING and event.is_action_pressed("honk"):
		boat.toot()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and toggle_boat():
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
	var starting := state != State.PAUSED
	_enter(_play_state if state == State.PAUSED else State.FLYING)
	if starting and _start_at_house:
		_start_at_house = false
		start_outside_house()


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
## Is the plane in the middle of the hangar service?
func _service_busy() -> bool:
	for s in get_tree().get_nodes_in_group("hangar_service"):
		if s.busy:
			return true
	return false


func _can_exit_plane() -> bool:
	# (Afloat on the sea, there's nowhere to stand: stay in.)
	return _in_plane() and aircraft.mode == Aircraft.Mode.PARKED and aircraft.ground_controls and not aircraft.on_water()


## Y: get out of the parked plane, or back into it when beside it.
## Returns true if it did either.
func toggle_plane() -> bool:
	if _in_plane() and aircraft.mode == Aircraft.Mode.ROLLING and aircraft.ground_controls:
		# Still rolling: remember, and hop out the moment it stops.
		exit_queued = true
		Sfx.play("ui_confirm", 0.9, -6.0)
		return true
	if _service_busy():
		return true  # (being serviced in the hangar: out when it's done)
	if _can_exit_plane():
		exit_queued = false
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


## Y at the end of a pier: sail away (or, if her boat's moored at another
## island, call it: it sails in, tooting). Y while sailing near a dock: glide
## into the berth and step off onto the pier. True if it did something.
func toggle_boat() -> bool:
	if boat == null:
		return false
	if boat.berthing:
		return state == State.SAILING or dock_here() != null
	if state == State.SAILING:
		var near := boat.dock_near()
		if near == null:
			return false
		boat.berth(near)
		return true
	var d := dock_here()
	if d == null:
		return false
	if boat.dock != d:
		boat.come_to(d)
		SaveManager.set_boat_dock(d.index)
		return true
	Sfx.play("pop", 0.9)
	boat.board()
	sail_camera.snap()
	_enter(State.SAILING)
	hud.show_foot_hints(false)
	return true


## The dock whose pier end she's standing at (on foot), or null.
func dock_here() -> Dock:
	if state != State.ON_FOOT:
		return null
	for d: Dock in docks:
		if Dock.flat_dist(walker.global_position, d.board_point()) < Dock.BOARD_REACH \
				and absf(walker.global_position.y - d.global_position.y) < 2.0:
			return d
	return null


## Tied up at a dock: she steps off onto the pier (if she was sailing).
func _on_boat_berthed(d: Dock) -> void:
	SaveManager.set_boat_dock(d.index)
	if state != State.SAILING:
		return
	walker.place(d.step_off(), d.step_off_yaw())
	walk_camera.snap_to(d.step_off_yaw())
	_enter(State.ON_FOOT)
	hud.show_foot_hints(true)


## Walk in through her house's front door.
func enter_house() -> void:
	enter_building(house)


## A building's front door was walked into (city houses call this; they
## come and go as the city grows): in, if she's on foot.
func door_walked_into(b: Node3D) -> void:
	if state == State.ON_FOOT:
		enter_building(b)


## Walk in through a building's front door (her house, a post office): a
## quick fade, the outdoor world hidden and paused, and you're inside. Each
## inside is built the first time (BuildingGenerator, from the building's
## plan), high above the building, and kept.
func enter_building(b: Node3D) -> void:
	if _doorway_busy or b == null:
		return
	_doorway_busy = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, CRASH_FADE * 0.7)
	await tw.finished
	building = b
	var id: String = b.building_id()
	interior = interiors.get(id)
	if interior == null:
		var plan: Dictionary = b.interior_layout() if b.has_method("interior_layout") else BuildingGenerator.load_data(b.interior_data())
		interior = BuildingGenerator.build(plan)
		add_child(interior)
		interior.global_position = Vector3(b.global_position.x, INTERIOR_HEIGHT, b.global_position.z)
		interior.exit_reached.connect(func(): if state == State.INDOORS: exit_house())
		interiors[id] = interior
		if b == house:
			interior.paint_her_walls(SaveManager.house_wall)
			interior.colour_her_quilt(SaveManager.house_bed)
	for other: Interior in interiors.values():
		if other != interior:
			other.visible = false
			other.process_mode = Node.PROCESS_MODE_DISABLED
	indoor_camera.interior = interior
	_set_outdoors(false)
	if b == house:
		SaveManager.set_house_inside(true)
	walker.place(interior.entry_point(), interior.entry_yaw())
	interior.arrive()
	_enter(State.INDOORS)
	indoor_camera.snap_to(interior.entry_yaw())
	Sfx.play("pop", 1.0)
	tw = create_tween()
	tw.tween_property(_fade, "color:a", 0.0, CRASH_FADE * 0.7)
	await tw.finished
	_doorway_busy = false


## The game stopped while she was inside: start on foot outside the front
## door, the plane parked safely nearby.
func start_outside_house() -> void:
	if house == null:
		return
	var step := house.doorstep()
	var spot := PlaneCall.find_spot(aircraft, step + (step - house.global_position).normalized() * 30.0)
	if not spot.is_empty():
		aircraft.park(spot.pos, spot.yaw)
	_enter(State.LANDED)
	_place_walker()
	walker.place(Vector3(step.x, IslandShape.height(step.x, step.z) + 0.1, step.z), house.doorstep_yaw())
	_enter(State.ON_FOOT)
	walk_camera.snap_to(house.doorstep_yaw())


## Out through the front door: back on the building's doorstep (nothing
## standing on it), the world as you left it, the things inside tidied away.
func exit_house() -> void:
	if _doorway_busy or interior == null or state != State.INDOORS:
		return  # (only from inside)
	_doorway_busy = true
	var b: Node3D = building if building else house
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, CRASH_FADE * 0.7)
	await tw.finished
	_set_outdoors(true)
	SaveManager.set_house_inside(false)
	interior.reset()
	var step: Vector3 = b.doorstep()
	# The plane parked on the doorstep? Move it to a safe spot nearby first.
	if Vector2(aircraft.global_position.x - step.x, aircraft.global_position.z - step.z).length() < 16.0:
		var spot := PlaneCall.find_spot(aircraft, step + (step - b.global_position).normalized() * 30.0)
		if not spot.is_empty():
			aircraft.park(spot.pos, spot.yaw)
	walker.place(Vector3(step.x, _ground_at(step) + 0.1, step.z), b.doorstep_yaw())
	_enter(State.ON_FOOT)
	walk_camera.snap_to(b.doorstep_yaw())
	Sfx.play("pop", 0.9)
	tw = create_tween()
	tw.tween_property(_fade, "color:a", 0.0, CRASH_FADE * 0.7)
	await tw.finished
	_doorway_busy = false


## The ground's height under `p` (the island shape, or whatever's below, for
## doorsteps on other islands).
func _ground_at(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 40.0, p + Vector3.DOWN * 80.0, GameSettings.LAYER_WORLD)
	q.exclude = [aircraft.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return (hit.position as Vector3).y if not hit.is_empty() else IslandShape.height(p.x, p.z)


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
	var holding := far and not _calling and dock_here() == null and (override_call_hold or Input.is_action_pressed("interact"))
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
		# A moment later, a look under the sea (bubbles, fish, muffled).
		get_tree().create_timer(0.35, false).timeout.connect(func():
			if _respawning:
				underwater.dive(0.3))
	else:
		if _near_volcano(where):
			_lava_glow(where)
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
	underwater.surface()
	_fade.color = Color(1, 1, 1, 1)
	if _dragon:
		_dragon.forgive(12.0)  # a fresh start: it leaves you alone for a bit
	tw = create_tween()
	tw.tween_property(_fade, "color:a", 0.0, CRASH_FADE)
	_respawning = false


func _near_volcano(p: Vector3) -> bool:
	return Vector2(p.x - IslandShape.VOLCANO.x, p.z - IslandShape.VOLCANO.y).length() < IslandShape.VOLCANO_RADIUS


## Crashed on the volcano: a hot orange-red glow washes over the screen
## and fades, with glowing embers (inside the usual pause before the fade).
func _lava_glow(where: Vector3) -> void:
	var embers := PickupBurst.new(46, 16.0, [Color(2.2, 1.3, 0.5), Color("ff7b1c"), Color("c0261a")]).keep_scale()
	embers.scale_amount_min = 0.6
	embers.scale_amount_max = 1.4
	embers.lifetime = 1.3
	embers.gravity = Vector3(0, 4, 0)
	embers.position = where
	add_child(embers)
	Sfx.play("rumble", 1.1, -4.0)
	_fade.color = Color(1.0, 0.32, 0.08, 0.0)
	var glow := create_tween()
	glow.tween_property(_fade, "color:a", 0.5, 0.12)
	glow.tween_property(_fade, "color:a", 0.15, 0.35)
	glow.tween_property(_fade, "color:a", 0.38, 0.25)
	glow.tween_property(_fade, "color:a", 0.0, 0.4)
	glow.tween_callback(func(): _fade.color = Color(1, 1, 1, 0))


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


## Indoors, Y does what's here: at a paint station or the open fridge it
## opens the chooser; by a dining chair she sits down (and eats her meal if
## there's one at her place). True if it did something.
func open_colour_menu() -> bool:
	if state != State.INDOORS or interior == null or colour_menu.is_open() or hat_menu.is_open() or _doorway_busy:
		return false
	var here := interior.interaction_at(walker)
	if here.is_empty():
		return false
	match str(here.kind):
		"paint":
			var st: PaintStation = here.target
			var walls := st.kind == "walls"
			colour_menu.preview = func(i: int):
				if walls:
					interior.paint_her_walls(i)
				else:
					interior.colour_her_quilt(i)
			_hold_walker(true)
			hud.set_prompt("")
			colour_menu.open(st.kind, SaveManager.house_wall if walls else SaveManager.house_bed)
		"hat":
			# On the mirror's rug, turned round to face the camera (and the
			# camera in front of her) so she sees each hat on her face.
			var mirror: HatMirror = here.target
			var out_yaw := mirror.global_rotation.y
			walker.place(mirror.stand_point() + Vector3.UP * 0.1, out_yaw + PI)
			indoor_camera.snap_to(out_yaw)
			indoor_camera.close_up = true
			_hold_walker(true)
			hud.set_prompt("")
			hud.show_foot_hints(false)
			hat_menu.open(SaveManager.hat)
		"food":
			colour_menu.preview = func(_i: int): pass
			_hold_walker(true)
			hud.set_prompt("")
			colour_menu.open("meal", 0)
		"sit":
			var table: SettableTable = here.target
			var seat: int = here.seat
			hud.set_prompt("")
			walker.sit(table.seat_point(seat), table.seat_yaw(seat), table.stand_point(seat))
			if interior.family:
				interior.family.hold("seat%d" % seat, true)
				walker.stood_up.connect(func(): interior.family.hold("seat%d" % seat, false), CONNECT_ONE_SHOT)
			get_tree().create_timer(1.2, false).timeout.connect(func():
				if walker.sitting:
					table.eat_at(seat))
	return true


func _on_colour_chosen(i: int) -> void:
	_hold_walker(false)
	if colour_menu.kind == "meal":
		walker.model.set_carrying(true, ColourMenu.MEALS[i])
		var burst := PickupBurst.new(24, 7.0)
		burst.position = walker.global_position + Vector3.UP * 3.0
		add_child(burst)
		return
	var st := interior.station_near() if interior else null
	if colour_menu.kind == "walls":
		interior.paint_her_walls(i, true)
	else:
		interior.colour_her_quilt(i, true)
	if st:
		st.celebrate(i)


## A hat picked at the mirror: bought if it's new (the stars come out of
## her purse), then worn, everywhere, from now on.
func _on_hat_chosen(id: String) -> void:
	_hold_walker(false)
	# (A moment to see the new hat close up, then back over the walls.)
	get_tree().create_timer(1.8, false).timeout.connect(func(): indoor_camera.close_up = false)
	var bought := id != "" and not SaveManager.hats_owned.has(id)
	if id == "" or SaveManager.buy_hat(id):
		SaveManager.wear_hat(id)
	walker.model.set_hat(SaveManager.hat)
	if interior and not interior.hat_mirrors.is_empty():
		interior.hat_mirrors[0].celebrate()
	if bought:
		walker.model.cheer()


## The cockpit view's instruments: shown only there, while in the plane.
func _update_gauges() -> void:
	var on := _in_plane() and chase_camera.in_cockpit() and not _respawning
	gauges.visible = on
	if not on:
		return
	var below := 0.0
	var q := PhysicsRayQueryParameters3D.create(aircraft.global_position, aircraft.global_position + Vector3.DOWN * 2000.0, GameSettings.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		below = maxf((aircraft.global_position - (hit.position as Vector3)).y - aircraft.stats.ground_offset, 0.0)
	gauges.max_speed = aircraft.stats.cruise_speed * aircraft.stats.boost_multiplier * 1.15
	gauges.paint = Paint.color(SaveManager.get_paint(aircraft.stats.id, aircraft.stats.default_paint))
	gauges.feed(aircraft.speed, maxf(aircraft.global_position.y, below), aircraft.heading, aircraft.pitch, aircraft.visuals.rotation.z)


## She cheers (X on foot or indoors), arms up; outside, the world hears it
## (WorldEvents "cheer": townspeople and recipients nearby cheer back).
## True if she did.
func cheer() -> bool:
	if not state in [State.ON_FOOT, State.INDOORS] or colour_menu.is_open() or hat_menu.is_open():
		return false
	if not walker.is_on_floor() or walker.sitting or walker.lying or not walker.is_physics_processing():
		return false
	walker.model.cheer(1.6)
	Sfx.play("lala", randf_range(1.0, 1.1), -6.0)
	if state == State.ON_FOOT:
		WorldEvents.send("cheer", walker.global_position)
	return true


## Keep her standing still (while a menu is open).
func _hold_walker(on: bool) -> void:
	walker.set_physics_process(not on)
	if on:
		walker.velocity = Vector3.ZERO
		walker.model.animate(0.0, true, false, false)
