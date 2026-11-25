class_name AircraftExtras
extends Node3D
## The little real-aircraft touches (Phase 9), on any model:
##   - wingtip vapour: thin white streams off the wingtips in hard, fast
##     turns (its own effect, separate from the rainbow boost trails)
## The wingtips are the model's Wingtip_L / Wingtip_R markers if it has
## them (docs/AIRCRAFT_MODELS.md), else its boost-trail markers.
## (The navigation-light dots that were here looked like stray red and
## green circles on the models, so they were removed.)

## Vapour: turning harder than this (0..1 of a full turn), faster than this
## much of cruise speed.
const VAPOUR_TURN := 0.6
const VAPOUR_SPEED := 1.05

var wingtip_l := Vector3(-2.6, 0.4, -0.4)
var wingtip_r := Vector3(2.6, 0.4, -0.4)
var tail := Vector3(0, 0.6, 2.4)
var top := Vector3(0, 1.2, 0.2)
var _vapour: Array[CPUParticles3D] = []
var _t := 0.0
## (Tests) whether the vapour is streaming.
var vapour_on := false


func _ready() -> void:
	name = "Extras"
	for p in [wingtip_l, wingtip_r]:
		var v := CPUParticles3D.new()
		v.emitting = false
		v.amount = 40
		v.lifetime = 0.7
		v.local_coords = false
		v.direction = Vector3(0, 0, 1)
		v.spread = 4.0
		v.initial_velocity_min = 0.5
		v.initial_velocity_max = 1.0
		v.gravity = Vector3.ZERO
		v.scale_amount_min = 0.25
		v.scale_amount_max = 0.4
		var curve := Curve.new()
		curve.add_point(Vector2(0, 1))
		curve.add_point(Vector2(1, 0))
		v.scale_amount_curve = curve
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 0.75))
		grad.set_color(1, Color(1, 1, 1, 0.0))
		v.color_ramp = grad
		var quad := QuadMesh.new()
		quad.size = Vector2(0.6, 0.6)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.vertex_color_use_as_albedo = true
		mat.albedo_texture = PickupBurst._soft_dot()
		quad.material = mat
		v.mesh = quad
		v.position = p
		add_child(v)
		_vapour.append(v)


## Use the model's markers for the wingtips (and guess the tail and top
## from them) before the extras are built.
func place_from(model: Node3D, trails: Array) -> void:
	var l := model.find_child("Wingtip_L", true, false) as Node3D
	var r := model.find_child("Wingtip_R", true, false) as Node3D
	if l and r:
		wingtip_l = model.to_local(l.global_position)
		wingtip_r = model.to_local(r.global_position)
	elif trails.size() >= 2:
		wingtip_l = (trails[0] as Node3D).position
		wingtip_r = (trails[1] as Node3D).position
	var span := absf(wingtip_r.x - wingtip_l.x)
	tail = Vector3(0, wingtip_l.y + span * 0.06, wingtip_l.z + span * 0.46)
	top = Vector3(0, wingtip_l.y + span * 0.17, wingtip_l.z + span * 0.08)
	for m in ["Tail_Light", "Beacon"]:
		var n := model.find_child(m, true, false) as Node3D
		if n:
			if m == "Tail_Light":
				tail = model.to_local(n.global_position)
			else:
				top = model.to_local(n.global_position)


## Each frame (AircraftVisuals): vapour in hard, fast turns.
func update(turn: float, speed: float, cruise: float, delta: float) -> void:
	_t += delta
	vapour_on = absf(turn) > VAPOUR_TURN and speed > cruise * VAPOUR_SPEED
	for v in _vapour:
		v.emitting = vapour_on
