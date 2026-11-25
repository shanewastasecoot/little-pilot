class_name RainbowArch
extends Landmark
## A giant rainbow arching out of the sea. Fly through it for a party,
## every time (not just the first). Its lower half is hidden by the ocean.
## Spans north-south, so it faces planes flying east to Palm Island.

const RADIUS := 120.0
const BAND := 5.5
const COLORS := ["ff3b3b", "ff8c42", "ffd23f", "4cc06a", "3f8cff", "5b4bdb", "9b5de5"]

var _cooldown := 0.0
## Every star found (Phase 14): it sparkles for ever and flying through
## it sets off a fireworks show.
var golden := false
var show_fireworks: CityFireworks
var _sparkles: CPUParticles3D


func _init() -> void:
	landmark_name = "Rainbow"
	discovery_radius = RADIUS - BAND * 7.0
	discovery_sound = "fanfare"


func build() -> void:
	for i in COLORS.size():
		var inner := RADIUS - (i + 1) * BAND
		var torus := TorusMesh.new()
		torus.inner_radius = inner
		torus.outer_radius = inner + BAND
		torus.rings = 48
		torus.ring_segments = 8
		var mi := MeshInstance3D.new()
		mi.mesh = torus
		var m := BuildKit.mat(COLORS[i], true).duplicate()
		m.emission_energy_multiplier = 0.6
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.rotation_degrees = Vector3(0, 0, 90)  # stand the ring up, facing east-west
		add_child(mi)
	if SaveManager.all_stars:
		set_golden(true)


## Sparkling for ever: 220 twinkles round the arch (one for every star),
## and a fireworks show ready for each pass.
func set_golden(on: bool) -> void:
	golden = on
	if not on or _sparkles != null:
		return
	_sparkles = CPUParticles3D.new()
	_sparkles.name = "Sparkles"
	_sparkles.amount = 440  # (half are under the sea: 220 twinkle on the arch)
	_sparkles.lifetime = 2.4
	_sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_sparkles.emission_ring_axis = Vector3(1, 0, 0)  # the arch stands in the YZ plane
	_sparkles.emission_ring_radius = RADIUS - BAND * 0.5
	_sparkles.emission_ring_inner_radius = RADIUS - BAND * 7.5
	_sparkles.emission_ring_height = 16.0  # a layer either side of the bands, not hidden inside them
	_sparkles.direction = Vector3(0, 1, 0)
	_sparkles.spread = 180.0
	_sparkles.initial_velocity_min = 0.5
	_sparkles.initial_velocity_max = 2.0
	_sparkles.gravity = Vector3(0, -0.6, 0)
	_sparkles.scale_amount_min = 1.5
	_sparkles.scale_amount_max = 3.2
	var q := QuadMesh.new()
	q.size = Vector2(6.0, 6.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES  # (each sparkle faces the camera)
	m.vertex_color_use_as_albedo = true
	var puff := GradientTexture2D.new()
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	puff.gradient = g
	m.albedo_texture = puff
	q.material = m
	_sparkles.mesh = q
	# Solid gold and white (not added on top: against a bright daytime sky
	# added light hardly shows).
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.2, 0.0))
	ramp.add_point(0.25, Color(1.0, 0.85, 0.2, 1.0))
	ramp.add_point(0.6, Color(1.0, 1.0, 1.0, 1.0))
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	_sparkles.color_ramp = ramp
	_sparkles.visibility_aabb = AABB(Vector3(-20, -RADIUS - 10, -RADIUS - 10), Vector3(40, RADIUS * 2 + 20, RADIUS * 2 + 20))
	add_child(_sparkles)
	show_fireworks = CityFireworks.new()
	show_fireworks.name = "RainbowFireworks"
	add_child(show_fireworks)


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


## Celebrate every pass through the arch (with a short cooldown).
func _on_body_entered(body: Node3D) -> void:
	if not body is Aircraft or _cooldown > 0.0:
		return
	_cooldown = 6.0
	is_discovered = true
	Sfx.play(discovery_sound)
	react()
	if golden and show_fireworks and not show_fireworks.running:
		show_fireworks.start(10.0)  # (rockets high above, for a while)
		# And straight away, big bursts all round the arch.
		for k in 6:
			get_tree().create_timer(0.25 * k, false).timeout.connect(func():
				var a := PI * (0.15 + 0.7 * k / 5.0)
				var b := FireworkBurst.new(Color(COLORS[k % COLORS.size()]), Color(COLORS[(k + 3) % COLORS.size()]))
				b.position = Vector3(0, sin(a) * RADIUS * 1.15, cos(a) * RADIUS * 1.15)
				add_child(b)
				Sfx.play_at("boom", b.global_position, randf_range(0.9, 1.2), -4.0))
	discovered.emit(self)


func react() -> void:
	var colors: Array[Color] = []
	for hex in COLORS:
		colors.append(Color(hex))
	for k in 3:
		var burst := PickupBurst.new(40, 24.0, colors)
		burst.position = Vector3(0, 40 + k * 25, 0)
		add_child(burst)
