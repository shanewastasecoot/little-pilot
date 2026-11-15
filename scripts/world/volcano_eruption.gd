class_name VolcanoEruption
extends Node3D
## Volcano eruption effect built from three GPUParticles3D layers:
##   Fire   - glowing lava bombs flung up out of the crater, arcing back down
##   Smoke  - a tall billowing ash column that drifts with the wind
##   Ash    - dark flakes falling around the mountain
## plus a pulsing lava glow and a rumble.
##
## Control it from code (erupt(), stop()) or animate the exported
## `erupting` / `intensity` properties from an AnimationPlayer.
## Put this node at the crater floor; `lava_material` is the crater pool.

signal eruption_started
signal eruption_stopped

@export var erupting := false:
	set(v):
		if v == erupting:
			return
		erupting = v
		_update_emission()
		if is_inside_tree():
			(eruption_started if v else eruption_stopped).emit()
			if v:
				Sfx.play_at("rumble", global_position, 0.8, 6.0)
## 0..1 how violent the eruption is (scales particle rates and glow).
@export_range(0.0, 1.0) var intensity := 1.0:
	set(v):
		intensity = v
		_update_emission()
@export var fire_amount := 220
@export var smoke_amount := 90
@export var ash_amount := 220
## Lava pool glow: quiet level and peak while erupting.
@export var glow_idle := 2.2
@export var glow_erupting := 6.0
@export var lava_material: StandardMaterial3D
@export var rumble_interval := 3.5

var fire: GPUParticles3D
var smoke: GPUParticles3D
var ash: GPUParticles3D
var _t := 0.0
var _rumble_left := 0.0
var _stop_timer := -1.0


func _ready() -> void:
	fire = _make_fire()
	smoke = _make_smoke()
	ash = _make_ash()
	for p in [fire, smoke, ash]:
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
	_update_emission()


## Start erupting. duration < 0 erupts until stop() is called.
func erupt(duration: float = -1.0, strength: float = 1.0) -> void:
	intensity = strength
	erupting = true
	_stop_timer = duration


func stop() -> void:
	erupting = false
	_stop_timer = -1.0


func _process(delta: float) -> void:
	delta = minf(delta, 0.1)
	_t += delta
	if _stop_timer > 0.0:
		_stop_timer -= delta
		if _stop_timer <= 0.0:
			stop()
	if lava_material:
		var peak := lerpf(glow_idle, glow_erupting, intensity) if erupting else glow_idle
		var flicker := sin(_t * (9.0 if erupting else 2.0)) * (1.2 if erupting else 0.4)
		lava_material.emission_energy_multiplier = lerpf(lava_material.emission_energy_multiplier, peak + flicker, 1.0 - exp(-6.0 * delta))
	if erupting:
		_rumble_left -= delta
		if _rumble_left <= 0.0:
			_rumble_left = rumble_interval * randf_range(0.7, 1.3)
			Sfx.play_at("rumble", global_position, randf_range(0.7, 0.9), 4.0 * intensity)


func _update_emission() -> void:
	if fire == null:
		return
	fire.emitting = erupting
	ash.emitting = erupting
	smoke.emitting = true  # always a lazy plume; thick while erupting
	fire.amount_ratio = intensity
	ash.amount_ratio = intensity
	smoke.amount_ratio = 1.0 if erupting else 0.2
	(smoke.process_material as ParticleProcessMaterial).initial_velocity_min = 14.0 if erupting else 4.0
	(smoke.process_material as ParticleProcessMaterial).initial_velocity_max = 22.0 if erupting else 7.0


# --- Layers --------------------------------------------------------------------

func _make_fire() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 14.0
	pm.direction = Vector3.UP
	pm.spread = 28.0
	pm.initial_velocity_min = 55.0
	pm.initial_velocity_max = 95.0
	pm.gravity = Vector3(0, -30, 0)
	pm.scale_min = 0.7
	pm.scale_max = 1.6
	pm.color_ramp = _ramp([Color(1.0, 0.85, 0.2), Color(1.0, 0.4, 0.05), Color(0.85, 0.12, 0.04), Color(0.3, 0.08, 0.05, 0.0)])
	var p := GPUParticles3D.new()
	p.amount = fire_amount
	p.lifetime = 4.0
	p.process_material = pm
	p.draw_pass_1 = _quad(11.0, true)
	p.visibility_aabb = AABB(Vector3(-260, -60, -260), Vector3(520, 420, 520))
	return p


func _make_smoke() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 18.0
	pm.direction = Vector3.UP
	pm.spread = 10.0
	pm.initial_velocity_min = 14.0
	pm.initial_velocity_max = 22.0
	pm.gravity = Vector3(2.5, 1.5, 1.0)  # wind
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	pm.scale_min = 0.8
	pm.scale_max = 1.4
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.35))
	grow.add_point(Vector2(1, 1.8))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	pm.scale_curve = grow_tex
	pm.color_ramp = _ramp([Color(0.25, 0.2, 0.2, 0.0), Color(0.3, 0.26, 0.27, 0.95), Color(0.48, 0.45, 0.5, 0.8), Color(0.7, 0.7, 0.75, 0.0)])
	var p := GPUParticles3D.new()
	p.amount = smoke_amount
	p.lifetime = 16.0
	p.preprocess = 16.0
	p.process_material = pm
	p.draw_pass_1 = _quad(60.0, false)
	p.visibility_aabb = AABB(Vector3(-200, -20, -200), Vector3(600, 700, 600))
	return p


func _make_ash() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(260, 10, 260)
	pm.direction = Vector3.DOWN
	pm.spread = 15.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 8.0
	pm.gravity = Vector3(1.5, -6.0, 0.8)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.color_ramp = _ramp([Color(0.2, 0.18, 0.18, 0.0), Color(0.22, 0.2, 0.2, 0.9), Color(0.3, 0.28, 0.28, 0.0)])
	var p := GPUParticles3D.new()
	p.amount = ash_amount
	p.lifetime = 9.0
	p.position.y = 220.0
	p.process_material = pm
	p.draw_pass_1 = _quad(1.6, false)
	p.visibility_aabb = AABB(Vector3(-300, -300, -300), Vector3(600, 340, 600))
	return p


static func _ramp(colors: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array()
	g.colors = PackedColorArray()
	for i in colors.size():
		g.add_point(float(i) / (colors.size() - 1), colors[i])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


## Soft round billboard (glow = harder edge for lava bombs, softer for smoke).
## Normal alpha blending keeps colours saturated against a bright sky.
static func _quad(size: float, glow: bool) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.5 if glow else 0.35, Color(1, 1, 1, 0.9 if glow else 0.7))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	m.albedo_texture = tex
	q.material = m
	return q
