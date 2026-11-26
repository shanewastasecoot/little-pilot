class_name Weather
extends Node3D
## Gentle weather (Phase 14, item 9). Every few minutes a soft grey rain
## cloud drifts slowly across near her, rain falling from it with a quiet
## hiss (no thunder, no lightning, the sky stays bright). Flying under it
## washes the plane's paint off (a splash: it's plain white) - only for now:
## her chosen colour is kept. Then a rainbow appears just ahead of her;
## flying through it brings the colour back with a sparkle. If she doesn't,
## the colour comes back by itself when the rainbow fades (and the D-pad
## still paints it any time).

const FIRST_AFTER := 180.0     # s of play before the first cloud
const EVERY := 360.0           # ... and between clouds
const CLOUD_RADIUS := 70.0     # how wide the rain is
const CLOUD_ABOVE := 135.0     # cloud height above the ground (at least)
const DRIFT := 4.0             # m/s, gentle
const LIFE := 160.0            # s until it has drifted past and gone
const FADE := 6.0
const RAINBOW_TIME := 60.0
const WASHED := Color("f4f4f4")
const BANDS := ["ff3b3b", "ff8c42", "ffd23f", "4cc06a", "3f8cff", "5b4bdb", "9b5de5"]

var main: Node
## (Tests) seconds until the next cloud.
var countdown := FIRST_AFTER
var cloud: Node3D
var rain: CPUParticles3D
var rainbow: Node3D
var rainbow_radius := 80.0
## Her paint has been washed off (until the rainbow, or it fades).
var washed := false
var _age := 0.0
var _drift := Vector3.ZERO
var _washed_this_cloud := false
var _rainbow_age := 0.0
var _last_side := 0.0
var _sound: AudioStreamPlayer3D
## (Graphics G1) The cloud's shape and the raindrop, made once while the
## game loads, not in the frame a cloud turns up (that was a 36 ms frame).
var _cloud_mesh: Mesh
var _cloud_mat: Material
var _drop: QuadMesh


func _ready() -> void:
	_build_parts()
	# Draw one of each, out of sight under the sea, for a couple of frames
	# so the graphics card has its shaders ready before the first cloud.
	var warm := Node3D.new()
	warm.name = "WarmUp"
	add_child(warm)
	warm.top_level = true
	warm.global_position = Vector3(0, -400, 0)
	warm.scale = Vector3.ONE * 0.01
	warm.add_child(_cloud_instance())
	var r := CPUParticles3D.new()
	r.amount = 1
	r.mesh = _drop
	warm.add_child(r)
	for i in 3:
		await get_tree().process_frame
	warm.queue_free()


func _cloud_instance() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "CloudShape"
	mi.mesh = _cloud_mesh
	mi.material_override = _cloud_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _build_parts() -> void:
	# A soft grey, puffy cloud (a few overlapping balls, merged into one).
	var tmp := Node3D.new()
	for b: Array in [[Vector3(0, 0, 0), 34.0], [Vector3(30, -4, 8), 26.0], [Vector3(-28, -3, -6), 28.0],
			[Vector3(8, 10, -20), 24.0], [Vector3(-10, 6, 24), 22.0], [Vector3(40, -2, -18), 18.0], [Vector3(-42, -6, 16), 18.0]]:
		var ball := BuildKit.add(tmp, BuildKit.sphere(b[1], 12), "c3cbd4", b[0])
		ball.scale = Vector3(1.0, 0.62, 1.0)
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	MeshMerge.merge_children(tmp)
	for c in tmp.get_children():
		if c is MeshInstance3D and not c.is_queued_for_deletion():
			_cloud_mesh = (c as MeshInstance3D).mesh
			_cloud_mat = (c as MeshInstance3D).material_override
	tmp.free()
	_drop = QuadMesh.new()
	_drop.size = Vector2(0.18, 3.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	m.albedo_color = Color(0.85, 0.92, 1.0, 0.55)
	_drop.material = m
	Sfx.get_loop("amb_rain")  # (loaded now, not when the first cloud arrives)


func _physics_process(delta: float) -> void:
	if main == null:
		return
	if cloud == null:
		if main._playing() and main.state != main.State.INDOORS:
			countdown -= delta
			if countdown <= 0.0:
				countdown = EVERY
				spawn_cloud()
	else:
		_age += delta
		cloud.global_position += _drift * delta
		var k := clampf(minf(_age / FADE, (LIFE - _age) / FADE), 0.0, 1.0)
		cloud.scale = Vector3.ONE * lerpf(0.05, 1.0, smoothstep(0.0, 1.0, k))
		rain.emitting = k > 0.6
		_sound.volume_db = linear_to_db(maxf(k, 0.001)) - 4.0
		if _age >= LIFE:
			cloud.queue_free()
			cloud = null
		elif not _washed_this_cloud and k > 0.6 and main._in_plane():
			var p: Vector3 = main.aircraft.global_position
			if Vector2(p.x - cloud.global_position.x, p.z - cloud.global_position.z).length() < CLOUD_RADIUS and p.y < cloud.global_position.y:
				wash()
	if rainbow:
		_rainbow_age += delta
		var plane: Node3D = main.aircraft
		var l := rainbow.to_local(plane.global_position)
		var side := signf(l.z)
		if washed and _last_side != 0.0 and side != _last_side and Vector2(l.x, l.y).length() < rainbow_radius and main._in_plane():
			restore(true)
		_last_side = side
		if _rainbow_age >= RAINBOW_TIME:
			if washed:
				restore(false)
			_fade_rainbow()


## A rain cloud upwind of her, drifting across where she is.
func spawn_cloud() -> void:
	if cloud:
		return
	StallDetector.note("rain cloud")
	var at: Vector3 = main.aircraft.global_position if main._in_plane() else main.walker.global_position
	var a := randf() * TAU
	_drift = Vector3(cos(a), 0.0, sin(a)) * DRIFT
	var side := Vector3(-sin(a), 0.0, cos(a)) * randf_range(-60.0, 60.0)
	var c := at - _drift.normalized() * DRIFT * LIFE * 0.35 + side
	var ground := maxf(DeliveryManager.ground_at(c.x, c.z), 0.0)
	c.y = maxf(ground + CLOUD_ABOVE, at.y + 50.0)
	cloud = Node3D.new()
	cloud.name = "RainCloud"
	add_child(cloud)
	cloud.top_level = true
	cloud.global_position = c
	cloud.scale = Vector3.ONE * 0.05
	# A soft grey, puffy cloud (made once, in _build_parts).
	if _cloud_mesh == null:
		_build_parts()
	cloud.add_child(_cloud_instance())
	# The rain: light streaks falling from its base.
	rain = CPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 700
	var fall := c.y - ground - 10.0
	rain.lifetime = fall / 42.0
	rain.position = Vector3(0, -14, 0)
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(CLOUD_RADIUS * 0.8, 2.0, CLOUD_RADIUS * 0.8)
	rain.direction = Vector3.DOWN
	rain.spread = 2.0
	rain.gravity = Vector3.ZERO
	rain.initial_velocity_min = 40.0
	rain.initial_velocity_max = 44.0
	rain.mesh = _drop
	rain.visibility_aabb = AABB(Vector3(-CLOUD_RADIUS, -fall - 20.0, -CLOUD_RADIUS), Vector3(CLOUD_RADIUS * 2.0, fall + 40.0, CLOUD_RADIUS * 2.0))
	cloud.add_child(rain)
	# A soft shower hiss under it (never thunder).
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = Sfx.get_loop("amb_rain")
	_sound.unit_size = 60.0
	_sound.max_distance = 450.0
	_sound.position = Vector3(0, -fall * 0.6, 0)
	_sound.volume_db = -40.0
	cloud.add_child(_sound)
	_sound.play()
	_age = 0.0
	_washed_this_cloud = false


## Under the rain in the plane: the paint washes off (for now).
func wash() -> void:
	_washed_this_cloud = true
	washed = true
	var plane: Aircraft = main.aircraft
	plane.visuals.set_paint(WASHED)
	Sfx.play("splash", 1.4)
	var drops := PickupBurst.new(40, 9.0, [Color.WHITE, Color("cfe9ff"), Color("9fd8ff")])
	drops.gravity = Vector3(0, -14, 0)
	drops.position = plane.global_position  # (set before adding: Weather sits at the origin)
	add_child(drops)
	WorldEvents.send("washed", plane.global_position)
	_spawn_rainbow()


## A rainbow just ahead of her, tall enough to fly under its arch.
func _spawn_rainbow() -> void:
	if rainbow:
		rainbow.queue_free()
	var plane: Aircraft = main.aircraft
	var fwd := Vector3(-sin(plane.heading), 0.0, -cos(plane.heading))
	var at := plane.global_position + fwd * 260.0
	var ground := maxf(DeliveryManager.ground_at(at.x, at.z), 0.0)
	rainbow_radius = clampf(plane.global_position.y - ground + 40.0, 70.0, 170.0)
	rainbow = Node3D.new()
	rainbow.name = "AfterRainbow"
	add_child(rainbow)
	rainbow.top_level = true
	rainbow.global_position = Vector3(at.x, ground, at.z)
	rainbow.rotation.y = plane.heading  # its opening faces her
	var band := rainbow_radius * 0.05
	for i in BANDS.size():
		var inner := rainbow_radius - (i + 1) * band
		var torus := TorusMesh.new()
		torus.inner_radius = inner
		torus.outer_radius = inner + band
		torus.rings = 48
		torus.ring_segments = 8
		var mi := MeshInstance3D.new()
		mi.mesh = torus
		var mat := BuildKit.mat(BANDS[i], true).duplicate() as StandardMaterial3D
		mat.emission_energy_multiplier = 0.6
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.rotation_degrees = Vector3(90, 0, 0)  # stand the ring up across her path
		rainbow.add_child(mi)
	rainbow.scale = Vector3.ONE * 0.05
	create_tween().tween_property(rainbow, "scale", Vector3.ONE, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_rainbow_age = 0.0
	_last_side = 0.0
	Sfx.play("chime", 1.2, -6.0)


## Her colour back (through the rainbow: with a sparkle).
func restore(sparkle: bool) -> void:
	washed = false
	var plane: Aircraft = main.aircraft
	plane.visuals.set_paint(Paint.color(SaveManager.get_paint(plane.stats.id, plane.stats.default_paint)))
	if sparkle:
		Sfx.play("fanfare", 1.1, -4.0)
		var colours: Array[Color] = []
		for h in BANDS:
			colours.append(Color(h))
		var s := PickupBurst.new(60, 14.0, colours)
		s.position = plane.global_position
		add_child(s)
		_rainbow_age = maxf(_rainbow_age, RAINBOW_TIME - 4.0)  # it fades soon after


func _fade_rainbow() -> void:
	var r := rainbow
	rainbow = null
	var tw := create_tween()
	tw.tween_property(r, "scale", Vector3.ONE * 0.05, 1.5)
	tw.tween_callback(r.queue_free)
