class_name AircraftVisuals
extends Node3D
## Cosmetic-only motion for an aircraft model: banking, propeller and honk hop.
## Never affects flight.

## Optional child spun according to speed.
@export var propeller: Node3D
## Ribbons shown while boosting (usually one per wingtip).
@export var boost_trails: Array[BoostTrail] = []
## Recolours the model's main colour for paint jobs (optional).
@export var recolor: ModelRecolor

## Seconds for one barrel roll.
const ROLL_TIME := 0.85

var _blur: MeshInstance3D
var _blur_mat: StandardMaterial3D
var _bank: float = 0.0
var _honk_tween: Tween
var _roll: float = -1.0   # 0..1 while rolling, -1 when not
var _roll_dir: float = 1.0


func update_visuals(turn: float, speed: float, stats: AircraftStats, delta: float, boost: float = 0.0, keep_rolling := false) -> void:
	for trail in boost_trails:
		trail.strength = maxf(boost, 0.8 if _roll >= 0.0 else 0.0)  # trails corkscrew during rolls
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
		disc.top_radius = 1.15
		disc.bottom_radius = 1.15
		disc.height = 0.02
		disc.radial_segments = 32
		disc.rings = 1
		_blur = MeshInstance3D.new()
		_blur.mesh = disc
		_blur.material_override = _blur_mat
		_blur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_blur.rotation_degrees.x = 90.0
		_blur.position = propeller.position
		add_child(_blur)
	_blur_mat.albedo_color = Color(1.0, 1.0, 1.0, smoothstep(12.0, 45.0, speed) * 0.14)


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
	_honk_tween.tween_property(self, "scale", Vector3.ONE * 1.25, 0.1)
	_honk_tween.tween_property(self, "scale", Vector3.ONE, 0.25)
