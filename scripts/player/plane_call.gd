class_name PlaneCall
extends RefCounted
## Finds a safe place to bring the parked plane to, near someone on foot
## (hold Y far from the plane). Safe means the plane could have landed
## there itself: island terrain (not a roof), flat, clear of the sea
## (Aircraft.can_land_on), and the same under the whole plane; nothing but
## terrain within the plane's size (no buildings, trees with colliders,
## post offices, other landmarks); not on top of the person; and with a
## clear take-off run ahead (TAKEOFF_RUN m of flat, landable ground with
## nothing in the way), so it can fly off again from where it's put.

## Rings searched, nearest first (metres from the person); far out too, so
## there's nearly always somewhere (towns and hills have few flat, open
## spots close by). The beacon then shows where it came down.
const RINGS := [16.0, 22.0, 30.0, 40.0, 52.0, 66.0, 82.0, 100.0, 124.0, 150.0, 180.0, 215.0, 250.0]
const PER_RING := 16
## Far rings get more spots (they're longer).
const SPOT_SPACING := 9.0
## Clear space the plane needs round its centre (a bit over the wingspan's half).
const CLEAR_RADIUS := 10.0
## Every point under the plane within this height of the centre.
const MAX_STEP := 1.5
## The take-off run that must be clear ahead of the nose.
const TAKEOFF_RUN := 110.0
const RUN_STEP := 12.0
const RUN_MAX_RISE := 4.0
const RUN_CLEAR := 6.0


## {"pos": ground point, "yaw": heading} for the nearest safe spot, or {}
## if there isn't one nearby (then the plane stays where it is).
static func find_spot(aircraft: Aircraft, from: Vector3) -> Dictionary:
	var space := aircraft.get_world_3d().direct_space_state
	for r: float in RINGS:
		var count := maxi(PER_RING, int(TAU * r / SPOT_SPACING / 4.0))
		for k in count:
			var a := TAU * k / count + r * 0.13  # rings out of step
			var at := from + Vector3(cos(a), 0.0, sin(a)) * r
			var spot := check_spot(aircraft, space, at, from.y)
			if spot.is_empty():
				continue
			# A clear take-off run, trying the direction away from the person first.
			var away := Vector3(spot.pos.x - from.x, 0.0, spot.pos.z - from.z).normalized()
			for turn in [0.0, PI / 4.0, -PI / 4.0, PI / 2.0, -PI / 2.0, 3.0 * PI / 4.0, -3.0 * PI / 4.0]:
				var dir := away.rotated(Vector3.UP, turn)
				if clear_run(aircraft, space, spot.pos, dir):
					spot["yaw"] = atan2(-dir.x, -dir.z)
					return spot
	return {}


## The checks for one spot: {"pos": ground point} if safe, else {}.
static func check_spot(aircraft: Aircraft, space: PhysicsDirectSpaceState3D, at: Vector3, near_y: float) -> Dictionary:
	var centre := _ray(aircraft, space, at, near_y)
	if not aircraft.can_land_on(centre):
		return {}
	var c: Vector3 = centre.position
	if absf(c.y - near_y) > 12.0:
		return {}  # well above or below them (a cliff top, a valley)
	for k in 8:
		var a := TAU * k / 8.0
		var edge := _ray(aircraft, space, c + Vector3(cos(a), 0.0, sin(a)) * CLEAR_RADIUS, c.y)
		if not aircraft.can_land_on(edge) or absf((edge.position as Vector3).y - c.y) > MAX_STEP:
			return {}
	# Nothing solid but terrain in the space the plane would take up.
	var shape := SphereShape3D.new()
	shape.radius = CLEAR_RADIUS
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, c + Vector3.UP * (CLEAR_RADIUS + 0.5))
	q.collision_mask = GameSettings.LAYER_WORLD
	q.exclude = [aircraft.get_rid()]
	for hit in space.intersect_shape(q, 16):
		var body: Node = hit.collider
		if not body.is_in_group("terrain"):
			return {}
	return {"pos": c}


## Room to take off from `start` along `dir`: flat, landable ground all the
## way, no big rise, nothing standing in the way.
static func clear_run(aircraft: Aircraft, space: PhysicsDirectSpaceState3D, start: Vector3, dir: Vector3) -> bool:
	var shape := SphereShape3D.new()
	shape.radius = RUN_CLEAR
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = GameSettings.LAYER_WORLD
	q.exclude = [aircraft.get_rid()]
	var d := RUN_STEP
	while d <= TAKEOFF_RUN:
		var hit := _ray(aircraft, space, start + dir * d, start.y)
		if not aircraft.can_land_on(hit) or absf((hit.position as Vector3).y - start.y) > RUN_MAX_RISE:
			return false
		q.transform = Transform3D(Basis.IDENTITY, (hit.position as Vector3) + Vector3.UP * (RUN_CLEAR + 0.5))
		for h in space.intersect_shape(q, 8):
			if not (h.collider as Node).is_in_group("terrain"):
				return false
		d += RUN_STEP
	return true


static func _ray(aircraft: Aircraft, space: PhysicsDirectSpaceState3D, at: Vector3, near_y: float) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, near_y + 80.0, at.z), Vector3(at.x, near_y - 80.0, at.z), GameSettings.LAYER_WORLD)
	q.exclude = [aircraft.get_rid()]
	return space.intersect_ray(q)
