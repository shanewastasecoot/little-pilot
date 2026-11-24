class_name AircraftVisuals
extends Node3D
## Cosmetic-only motion for an aircraft model: banking, propeller and honk hop.
## Never affects flight.

## Optional child spun according to speed (anywhere under the model).
@export var propeller: Node3D
## Radius of its spinning blur disc (model units).
@export var prop_radius: float = 1.15
## Ribbons shown while boosting (usually one per wingtip).
@export var boost_trails: Array[BoostTrail] = []
## Recolours the model's main colour for paint jobs (optional).
@export var recolor: ModelRecolor

## Seconds for one barrel roll.
const ROLL_TIME := 0.85
## The loop (Phase 14): purely visual like the barrel roll. The plane's real
## flight path, pitch limits and safety are unchanged; the model swings up
## and over in a circle ABOVE the path (never below it), big enough that it
## really travels backwards over the top, and lands back on the path.
const LOOP_TIME := 2.6
const LOOP_RADIUS := 9.0

var _blur: MeshInstance3D
var _blur_mat: StandardMaterial3D
var _bank: float = 0.0
var _honk_tween: Tween
var _roll: float = -1.0   # 0..1 while rolling, -1 when not
var _roll_dir: float = 1.0
var _loop: float = -1.0   # 0..1 while looping, -1 when not
## Size of the model in flight (AircraftStats.model_scale); honk hops around it.
## Nav lights and wingtip vapour (AircraftExtras).
var extras: AircraftExtras
## Trim colour and decal (Phase 13).
var livery: Livery

var base_scale: float = 1.0:
	set(v):
		base_scale = v
		scale = Vector3.ONE * v


func _ready() -> void:
	extras = AircraftExtras.new()
	extras.place_from(self, boost_trails)
	add_child(extras)
	livery = Livery.new()
	livery.name = "Livery"
	add_child(livery)


## Wear plane `stats`'s saved livery (trim colour and decal).
func show_livery(stats: AircraftStats) -> void:
	if livery == null:
		return
	livery.body = stats.livery_body
	livery.show_livery(SaveManager.get_decal(stats.id), Paint.color(SaveManager.get_trim(stats.id)))


## The pilot's eye in the world: the model's CockpitCameraMarker if it has
## one, else the aircraft's `cockpit_eye`.
func cockpit_point(stats: AircraftStats) -> Vector3:
	var m := find_child("CockpitCameraMarker", true, false) as Node3D
	return m.global_position if m else to_global(stats.cockpit_eye)


func update_visuals(turn: float, speed: float, stats: AircraftStats, delta: float, boost: float = 0.0, keep_rolling := false) -> void:
	if extras:
		extras.update(turn, speed, stats.cruise_speed, delta)
	for trail in boost_trails:
		trail.strength = maxf(boost, 0.8 if _roll >= 0.0 or _loop >= 0.0 else 0.0)  # trails corkscrew during rolls (and draw the loop)
	var target := -turn * deg_to_rad(stats.max_bank_deg)
	_bank = lerpf(_bank, target, 1.0 - exp(-stats.bank_response * delta))
	var roll_angle := 0.0
	var offset := Vector3.ZERO
	if _roll >= 0.0:
		_roll += delta / ROLL_TIME
		if _roll >= 1.0:
			if keep_rolling:
				_roll -= 1.0
				Sfx.play("whoosh", 1.6)
			else:
				_roll = -1.0
	if _roll >= 0.0:
		var p := smoothstep(0.0, 1.0, _roll)
		roll_angle = TAU * p * _roll_dir
		# A small corkscrew so it looks like a real barrel roll.
		offset = Vector3(-sin(p * TAU) * 1.2 * _roll_dir, (1.0 - cos(p * TAU)) * 0.6, 0)
	var loop_angle := 0.0
	if _loop >= 0.0:
		var was := _loop
		_loop += delta / LOOP_TIME
		if was < 0.5 and _loop >= 0.5:
			Sfx.play("whoosh", 1.3, -4.0)  # over the top
		if _loop >= 1.0:
			_loop = -1.0
		else:
			var a := TAU * smoothstep(0.0, 1.0, _loop)
			loop_angle = a
			offset += Vector3(0.0, LOOP_RADIUS * (1.0 - cos(a)), -LOOP_RADIUS * sin(a))
			_bank = lerpf(_bank, 0.0, 1.0 - exp(-8.0 * delta))  # wings level through the loop
	rotation.x = loop_angle
	rotation.z = _bank + roll_angle
	position = offset
	if propeller:
		propeller.rotate_z(speed * 1.5 * delta)
		_update_blur(speed)


## A soft translucent disc that fades in as the propeller speeds up, so it
## reads as a spinning prop instead of two flickering sticks.
func _update_blur(speed: float) -> void:
	if _blur == null:
		_blur_mat = StandardMaterial3D.new()
		_blur_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_blur_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_blur_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var disc := CylinderMesh.new()
		disc.top_radius = prop_radius
		disc.bottom_radius = prop_radius
		disc.height = 0.02
		disc.radial_segments = 32
		disc.rings = 1
		_blur = MeshInstance3D.new()
		_blur.mesh = disc
		_blur.material_override = _blur_mat
		_blur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_blur.rotation_degrees.x = 90.0
		_blur.position = to_local(propeller.global_position) if is_inside_tree() else propeller.position
		add_child(_blur)
	_blur_mat.albedo_color = Color(1.0, 1.0, 1.0, smoothstep(12.0, 45.0, speed) * 0.14)


## Start a loop (purely visual; see LOOP_TIME). False if busy with a trick.
func loop() -> bool:
	if _roll >= 0.0 or _loop >= 0.0:
		return false
	_loop = 0.0
	Sfx.play("whoosh", 1.1)
	return true


func is_looping() -> bool:
	return _loop >= 0.0


## How far up the model is during a loop (the chase camera rises part way
## with it, so the loop stays in the picture).
func loop_lift() -> float:
	return position.y if _loop >= 0.0 else 0.0


## Stop any trick at once, back on the flight path (crash, respawn).
func cancel_tricks() -> void:
	_roll = -1.0
	_loop = -1.0
	position = Vector3.ZERO
	rotation.x = 0.0


## Start a barrel roll (purely visual: the flight path is unchanged, so
## it's always safe). Rolls the way the plane is banking.
func barrel_roll() -> void:
	if _roll >= 0.0:
		return
	_roll = 0.0
	_roll_dir = -1.0 if _bank > 0.05 else 1.0
	Sfx.play("whoosh", 1.6)


func set_paint(c: Color) -> void:
	if recolor:
		recolor.apply(c)


## A happy little bounce. Sound is added in Phase 4.
func honk() -> void:
	if _honk_tween and _honk_tween.is_running():
		return  # mashing B just keeps the current hop going
	_honk_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_honk_tween.tween_property(self, "scale", Vector3.ONE * 1.25 * base_scale, 0.1)
	_honk_tween.tween_property(self, "scale", Vector3.ONE * base_scale, 0.25)
