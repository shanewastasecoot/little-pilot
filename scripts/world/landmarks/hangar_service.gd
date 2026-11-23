class_name HangarService
extends Node3D
## The airport's service loop (Phase 13). Land, roll onto the big yellow pad
## in front of the hangar and stop: the doors slide open, the marshaller
## waves you in with his orange wands, the plane rolls inside, gets a wash
## (spray and bubbles) and fills up with fuel (the gauge on the pump fills),
## turns round and rolls back out onto the pad facing the runway, ready to
## go. No menus, nothing to get wrong, as often as she likes.
## A child of the Hangar, in its space (the door faces +Z).

signal started
signal finished

const PAD := Vector3(0, 0, 46)
const PAD_RADIUS := 8.0
const INSIDE := Vector3(0, 0, 2)
const STEP_DOORS := 1.6
const STEP_IN := 4.5
const STEP_WASH := 3.5
const STEP_FUEL := 3.2
const STEP_TURN := 2.2
const STEP_OUT := 4.5

var hangar: Hangar
var busy := false
## How many times she's been serviced (tests).
var count := 0
var fuel := 0.0
var _plane: Node3D
var _marshaller: CharacterModel
var _spray: Array[CPUParticles3D] = []
var _bubbles: CPUParticles3D
var _gauge: MeshInstance3D
var _hose: MeshInstance3D
var _cool := 0.0
## Ceiling lights inside, on only during a visit.
var _lights: Array[OmniLight3D] = []


func _ready() -> void:
	add_to_group("hangar_service")
	_build_pad()
	_build_marshaller()
	_build_wash()
	_build_pump()
	for side in [-1.0, 1.0]:
		var l := OmniLight3D.new()
		l.position = INSIDE + Vector3(side * 8.0, 13.0, 0)
		l.omni_range = 32.0
		l.light_energy = 2.2
		l.light_color = Color(1.0, 0.96, 0.88)
		l.visible = false
		add_child(l)
		_lights.append(l)


func _physics_process(delta: float) -> void:
	_cool = maxf(_cool - delta, 0.0)
	if busy:
		return
	if _plane == null:
		_plane = get_tree().get_first_node_in_group("aircraft") as Node3D
		if _plane == null:
			return
	var game := get_tree().get_first_node_in_group("game_main")
	# (In the plane: LANDED after a landing, FLYING when it stopped after
	# taxiing; either way it's parked on the pad.)
	if game == null or not game._in_plane() or _cool > 0.0:
		if hangar and hangar.doors_open() and not _plane_near_door():
			hangar.set_doors(false)
		return
	var local := to_local(_plane.global_position)
	if _plane.get("mode") == Aircraft.Mode.PARKED and Vector2(local.x - PAD.x, local.z - PAD.z).length() < PAD_RADIUS:
		run()


func _plane_near_door() -> bool:
	if _plane == null:
		return false
	var l := to_local(_plane.global_position)
	return absf(l.x) < 20.0 and l.z > -22.0 and l.z < 30.0


## The whole visit (the plane must be parked on the pad).
func run() -> void:
	if busy:
		return
	busy = true
	started.emit()
	var plane := _plane as Aircraft
	plane.input.override_enabled = true
	plane.input.override_stick = Vector2.ZERO
	plane.input.override_throttle = 0.0
	var off: float = plane.stats.ground_offset
	var start := to_local(plane.global_position) - Vector3.UP * off
	start.y = 0.0
	var into := _yaw_towards(start, INSIDE)
	# The doors open; the marshaller waves her in.
	hangar.set_doors(true)
	for l in _lights:
		l.visible = true
	_marshaller.play("Cheer")
	Sfx.play("whoosh", 0.6)
	await _move(plane, start, start, _yaw_of(plane), into, STEP_DOORS, off)
	# Roll inside.
	Sfx.play("pop", 0.7)
	await _move(plane, start, INSIDE, into, into, STEP_IN, off)
	_marshaller.play("Idle")
	# The wash: spray from both sides, bubbles everywhere.
	for s in _spray:
		s.emitting = true
	_bubbles.emitting = true
	Sfx.play("splash", 1.2)
	await get_tree().create_timer(STEP_WASH, false).timeout
	for s in _spray:
		s.emitting = false
	_bubbles.emitting = false
	var shine := PickupBurst.new(40, 10.0)
	shine.position = INSIDE + Vector3(0, 4, 0)
	add_child(shine)
	Sfx.play("chime", 1.4)
	# Fuel: the hose, the gauge fills up.
	_hose.visible = true
	fuel = 0.0
	var tw := create_tween()
	tw.tween_method(_set_fuel, 0.0, 1.0, STEP_FUEL)
	await tw.finished
	_hose.visible = false
	Sfx.play("ding", 1.0)
	# Turn round and roll back out onto the pad, facing the runway.
	var out_yaw := into + PI
	await _move(plane, INSIDE, INSIDE, into, out_yaw, STEP_TURN, off)
	_marshaller.play("Cheer")
	await _move(plane, INSIDE, PAD, out_yaw, out_yaw, STEP_OUT, off)
	_marshaller.play("Idle")
	plane.taxi_to(to_global(PAD), out_yaw + hangar.global_rotation.y)
	plane.input.override_enabled = false
	for l in _lights:
		l.visible = false
	count += 1
	busy = false
	_cool = 6.0  # (don't start again until she's moved off and back)
	finished.emit()


func _set_fuel(f: float) -> void:
	fuel = f
	_gauge.scale = Vector3(1, maxf(f, 0.02), 1)
	_gauge.position.y = 2.6 + f * 1.5 - 1.5


## Move the plane from `a` to `b` (local) turning from yaw `y0` to `y1`
## (local yaw) over `secs`, smoothly.
func _move(plane: Aircraft, a: Vector3, b: Vector3, y0: float, y1: float, secs: float, off: float) -> void:
	var t := 0.0
	while t < secs:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		var k := smoothstep(0.0, 1.0, clampf(t / secs, 0.0, 1.0))
		var p := a.lerp(b, k)
		plane.taxi_to(to_global(p), lerp_angle(y0, y1, k) + hangar.global_rotation.y)


func _yaw_of(plane: Aircraft) -> float:
	return plane.heading - hangar.global_rotation.y


## The aircraft's yaw (forward is -Z) facing from `a` to `b` (local).
static func _yaw_towards(a: Vector3, b: Vector3) -> float:
	var d := b - a
	return atan2(-d.x, -d.z)


func _build_pad() -> void:
	# A big yellow ring with a water drop and a fuel can painted inside.
	BuildKit.add(self, BuildKit.cyl(PAD_RADIUS, 0.06, -1.0, 40), "ffd23f", PAD + Vector3(0, 0.33, 0))
	BuildKit.add(self, BuildKit.cyl(PAD_RADIUS - 0.8, 0.07, -1.0, 40), "a8a298", PAD + Vector3(0, 0.34, 0))
	BuildKit.add(self, BuildKit.sphere(1.4, 12), "4aa8ff", PAD + Vector3(-2.2, 0.36, 0), Vector3.ZERO, Vector3(1, 0.06, 1))
	BuildKit.add(self, BuildKit.prism(Vector3(1.6, 0.06, 1.8)), "4aa8ff", PAD + Vector3(-2.2, 0.37, -1.6), Vector3(90, 0, 0))
	BuildKit.add(self, BuildKit.box(Vector3(2.2, 0.06, 2.8)), "e63946", PAD + Vector3(2.2, 0.36, 0.2))
	BuildKit.add(self, BuildKit.box(Vector3(0.5, 0.06, 1.2)), "e63946", PAD + Vector3(3.0, 0.36, -1.6))


func _build_marshaller() -> void:
	_marshaller = CharacterModel.new()
	_marshaller.look_override = OutfitData.make("marshaller", "Knight", {"r0c3": Color("ff8c2a"), "r0c7": Color("ffd23f"),
		"r1c0": Color("ff8c2a"), "r0c6": Color("1b1b2f"), "r1c2": Color("1b1b2f")}, [["Postie_Cap", "head"]], [])
	_marshaller.head_override = ["Rogue", {"r0c1": Color("3b2a20")}]
	add_child(_marshaller)
	_marshaller.position = Vector3(11.0, 0.3, 30.0)
	_marshaller.rotation.y = -0.6
	# Orange wands in both hands.
	for bone in ["handslot.l", "handslot.r"]:
		var skel := _marshaller.find_children("*", "Skeleton3D", true, false)
		if skel.is_empty() or (skel[0] as Skeleton3D).find_bone(bone) < 0:
			continue
		var att := BoneAttachment3D.new()
		att.bone_name = bone
		skel[0].add_child(att)
		var wand := BuildKit.add(att, BuildKit.cyl(0.08, 1.1, -1.0, 8), "ff7a1a", Vector3(0, 0.5, 0))
		wand.material_override = BuildKit.mat("ff7a1a", true)


func _build_wash() -> void:
	for side in [-1.0, 1.0]:
		var s := CPUParticles3D.new()
		s.emitting = false
		s.amount = 90
		s.lifetime = 0.9
		s.direction = Vector3(-side, -0.3, 0)
		s.spread = 18.0
		s.initial_velocity_min = 9.0
		s.initial_velocity_max = 13.0
		s.gravity = Vector3(0, -12, 0)
		s.scale_amount_min = 0.25
		s.scale_amount_max = 0.45
		s.color = Color(0.75, 0.9, 1.0, 0.8)
		var quad := QuadMesh.new()
		quad.size = Vector2(0.6, 0.6)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.vertex_color_use_as_albedo = true
		mat.albedo_texture = PickupBurst._soft_dot()
		quad.material = mat
		s.mesh = quad
		s.position = INSIDE + Vector3(side * 11.0, 6.0, 0)
		add_child(s)
		BuildKit.add(self, BuildKit.cyl(0.35, 1.2), "8a94a6", INSIDE + Vector3(side * 11.5, 6.0, 0), Vector3(0, 0, 90))
		_spray.append(s)
	_bubbles = CPUParticles3D.new()
	_bubbles.emitting = false
	_bubbles.amount = 60
	_bubbles.lifetime = 2.5
	_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_bubbles.emission_box_extents = Vector3(6, 2, 6)
	_bubbles.direction = Vector3.UP
	_bubbles.initial_velocity_min = 0.5
	_bubbles.initial_velocity_max = 1.5
	_bubbles.gravity = Vector3(0, 0.4, 0)
	_bubbles.scale_amount_min = 0.4
	_bubbles.scale_amount_max = 0.9
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(1, 1, 1, 0.55)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.metallic = 0.3
	bm.roughness = 0.1
	sphere.material = bm
	_bubbles.mesh = sphere
	_bubbles.position = INSIDE + Vector3(0, 2.5, 0)
	add_child(_bubbles)


func _build_pump() -> void:
	# A red fuel pump against the side wall with a gauge that fills up.
	var at := INSIDE + Vector3(-15.0, 0, 6.0)
	BuildKit.add(self, BuildKit.box(Vector3(2.0, 4.2, 1.6)), "e63946", at + Vector3(0, 2.1, 0))
	BuildKit.add(self, BuildKit.box(Vector3(1.4, 3.2, 0.2)), "1b1b2f", at + Vector3(0, 4.6, 0.9))
	_gauge = BuildKit.add(self, BuildKit.box(Vector3(1.0, 3.0, 0.1)), "43c463", at + Vector3(0, 2.6, 1.02))
	_gauge.material_override = BuildKit.mat("43c463", true)
	_gauge.position = at + Vector3(0, 1.15, 1.02)
	_gauge.scale = Vector3(1, 0.02, 1)
	_hose = BuildKit.add(self, BuildKit.cyl(0.18, 13.0, -1.0, 8), "1b1b2f", at.lerp(INSIDE, 0.5) + Vector3(0, 1.2, -3.0), Vector3(0, 0, 90))
	_hose.look_at_from_position(_hose.position, INSIDE + Vector3(0, 1.2, 0), Vector3.UP)
	_hose.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	_hose.visible = false
