class_name FlightSafety
extends Node
## Keeps the plane safe. It never reads input. Every physics tick it:
##   1. evaluate(): works out limits that gently steer the plane
##      (pitch_floor, pitch_ceiling, turn_bias).
##   2. enforce(): applies hard limits after movement, so the plane can't
##      get through the ground, water, ceiling or world edge even if
##      smoothing fails.

## Results of evaluate(), read by the aircraft controller.
var pitch_floor_deg: float = -90.0
var pitch_ceiling_deg: float = 90.0
## -1..1, positive = turn right. Blended over the player's turn input.
var turn_bias: float = 0.0
## Escape route when the predicted path is blocked: the turn (-1..1) to use
## and how strongly (0..1) it overrides everything else.
var turn_override: float = 0.0
var turn_override_weight: float = 0.0
## Last measured height above ground/water (for the debug HUD).
var clearance: float = INF

## Fallback limits used when the map has no WorldBounds node.
var boundary_center: Vector3 = Vector3.ZERO
var boundary_radius: float = 500.0
var boundary_band: float = 120.0
var ceiling_height: float = 120.0
var ceiling_band: float = 25.0

## Plane radius plus breathing room used when sweeping the predicted path.
const SWEEP_RADIUS := 4.0

var stats: AircraftStats
var _body: CharacterBody3D
var _sweep_shape := SphereShape3D.new()
var _sensor: Area3D


func setup(body: CharacterBody3D, aircraft_stats: AircraftStats, sensor: Area3D) -> void:
	_body = body
	stats = aircraft_stats
	_sweep_shape.radius = SWEEP_RADIUS
	_sensor = sensor
	var bounds := get_tree().get_first_node_in_group("world_bounds")
	if bounds:
		boundary_center = bounds.global_position
		boundary_radius = bounds.radius
		boundary_band = bounds.edge_band
		ceiling_height = bounds.ceiling
		ceiling_band = bounds.ceiling_band


## current_turn: the turn command (-1..1, + = right) the plane is flying with,
## so look-ahead follows the curve it's actually on, not a straight line.
func evaluate(pos: Vector3, velocity: Vector3, current_turn: float = 0.0) -> void:
	var speed := maxf(velocity.length(), 1.0)
	var forward := velocity / speed
	var flat_forward := Vector3(forward.x, 0.0, forward.z).normalized()
	var right := flat_forward.cross(Vector3.UP)
	var lookahead := speed * stats.lookahead_time

	pitch_floor_deg = -stats.max_pitch_deg
	pitch_ceiling_deg = stats.max_pitch_deg
	turn_bias = 0.0
	turn_override_weight = 0.0

	var path := _predict_path(pos, velocity, _yaw_rate(current_turn))
	_avoid_ground(pos, path)
	_avoid_obstacles_ahead(pos, velocity, path, current_turn, lookahead)
	_avoid_ceiling(pos)
	_steer_from_push_volumes(pos, flat_forward, right)
	_steer_from_boundary(pos, flat_forward, right)

	turn_bias = clampf(turn_bias, -1.0, 1.0)
	# The ground always wins over the ceiling.
	pitch_ceiling_deg = maxf(pitch_ceiling_deg, pitch_floor_deg)


func enforce() -> void:
	var pos := _body.global_position
	# Hard floor above ground and water.
	var ground := _ground_height_at(pos, 30.0)
	if ground != -INF and pos.y < ground + stats.min_clearance:
		pos.y = ground + stats.min_clearance
	# Hard ceiling.
	pos.y = minf(pos.y, ceiling_height)
	# Hard world edge.
	var flat := Vector3(pos.x - boundary_center.x, 0.0, pos.z - boundary_center.z)
	if flat.length() > boundary_radius:
		flat = flat.normalized() * boundary_radius
		pos.x = boundary_center.x + flat.x
		pos.z = boundary_center.z + flat.z
	if pos != _body.global_position:
		_body.global_position = pos


# --- Soft systems -----------------------------------------------------------

func _avoid_ground(pos: Vector3, path: PackedVector3Array) -> void:
	var here := _ground_height_at(pos, 1.0)
	clearance = pos.y - here if here != -INF else INF
	var worst := clearance
	# Terrain under each predicted point (including descent if diving).
	for p in path:
		var g := _ground_height_at(Vector3(p.x, pos.y, p.z), 60.0)
		if g != -INF:
			worst = minf(worst, p.y - g)
	if worst >= stats.safe_clearance:
		return
	var t := 1.0 - clampf((worst - stats.min_clearance) / (stats.safe_clearance - stats.min_clearance), 0.0, 1.0)
	t = smoothstep(0.0, 1.0, t)
	pitch_floor_deg = maxf(pitch_floor_deg, lerpf(-stats.max_pitch_deg, stats.max_rescue_pitch_deg, t))


func _avoid_obstacles_ahead(pos: Vector3, velocity: Vector3, path: PackedVector3Array, current_turn: float, lookahead: float) -> void:
	# Already within the safety margin of a wall? (Sweeps can't see shapes
	# they start inside, so check this first.) Steer straight away from it.
	var near := _overlap(pos)
	if not near.is_empty() and near.normal.y < 0.6:
		var flat_v := Vector3(velocity.x, 0.0, velocity.z).normalized()
		var side: float = near.normal.dot(flat_v.cross(Vector3.UP))
		turn_override = signf(side) if absf(side) > 0.05 else signf(-current_turn + 0.001)
		turn_override_weight = 1.0
		return
	var hit := _first_hit(pos, path)
	if hit.is_empty():
		return
	var urgency := clampf(1.0 - hit.travelled / lookahead, 0.0, 1.0)
	var normal: Vector3 = hit.normal
	# Anything ahead means climb a little; slopes mean climb a lot.
	var climb := lerpf(0.0, stats.max_rescue_pitch_deg, urgency * (0.5 + 0.5 * clampf(normal.y * 2.0, 0.0, 1.0)))
	pitch_floor_deg = maxf(pitch_floor_deg, climb)
	if normal.y >= 0.6:
		return  # gentle slope: climbing is enough
	# Wall or pillar: try straightening out, or turning either way, and take
	# the route that stays clear longest (ties go to the smallest change).
	var best_turn := current_turn
	var best_dist: float = hit.travelled
	for candidate: float in [0.0, -1.0, 1.0]:
		var h := _first_hit(pos, _predict_path(pos, velocity, _yaw_rate(candidate)))
		var dist: float = lookahead * 1.01 if h.is_empty() else h.travelled
		if dist > best_dist + 0.5:
			best_dist = dist
			best_turn = candidate
	# Hold the best route even when we're already on it; otherwise the stick
	# would pull the plane straight back into the obstacle next frame.
	turn_override = best_turn
	turn_override_weight = clampf(urgency * 1.8, 0.0, 1.0)


## First world hit along a predicted path, with distance travelled to it.
## Sweeps a sphere (plane size + margin), so near misses count as hits.
func _first_hit(pos: Vector3, path: PackedVector3Array) -> Dictionary:
	var from := pos
	var travelled := 0.0
	for p in path:
		var hit := _sweep(from, p)
		if not hit.is_empty():
			hit.travelled = travelled + from.distance_to(hit.position)
			return hit
		travelled += from.distance_to(p)
		from = p
	return {}


func _yaw_rate(turn: float) -> float:
	return -turn * deg_to_rad(stats.turn_rate_deg)


func _avoid_ceiling(pos: Vector3) -> void:
	var start := ceiling_height - ceiling_band
	if pos.y <= start:
		return
	var t := clampf((pos.y - start) / ceiling_band, 0.0, 1.0)
	pitch_ceiling_deg = lerpf(stats.max_pitch_deg, -4.0, t)


func _steer_from_push_volumes(pos: Vector3, flat_forward: Vector3, right: Vector3) -> void:
	if _sensor == null:
		return
	for area in _sensor.get_overlapping_areas():
		if not area.has_method("push_strength_at"):
			continue
		var strength: float = area.push_strength_at(pos)
		if strength <= 0.0:
			continue
		var away := Vector3(pos.x - area.global_position.x, 0.0, pos.z - area.global_position.z).normalized()
		# Already heading away? Ease off.
		var facing := clampf(1.0 - flat_forward.dot(away), 0.0, 1.0)
		var side := away.dot(right)
		var dir := signf(side) if absf(side) > 0.05 else 1.0
		turn_bias += dir * strength * facing


func _steer_from_boundary(pos: Vector3, flat_forward: Vector3, right: Vector3) -> void:
	var flat := Vector3(pos.x - boundary_center.x, 0.0, pos.z - boundary_center.z)
	var d := flat.length()
	var start := boundary_radius - boundary_band
	if d <= start:
		return
	var t := clampf((d - start) / boundary_band, 0.0, 1.0)
	var to_center := -flat / d
	var facing := clampf(1.0 - flat_forward.dot(to_center), 0.0, 1.0)
	var side := to_center.dot(right)
	var dir := signf(side) if absf(side) > 0.1 else 1.0
	turn_bias += dir * clampf(t * 1.5, 0.0, 1.0) * clampf(facing * 2.0, 0.0, 1.0)


# --- Helpers ----------------------------------------------------------------

## Points along the arc the plane will fly over the look-ahead time,
## assuming the current turn rate and (downward) climb rate continue.
func _predict_path(pos: Vector3, velocity: Vector3, yaw_rate: float) -> PackedVector3Array:
	# One point per ~15 degrees of turn (min 4), so chords of a tight
	# circle don't cut inside it and miss things on the outside.
	var steps := clampi(ceili(absf(yaw_rate) * stats.lookahead_time / deg_to_rad(15.0)), 4, 12)
	var path := PackedVector3Array()
	var dt := stats.lookahead_time / steps
	var v := velocity
	v.y = minf(v.y, 0.0)  # only worry about descending
	var rot := Basis(Vector3.UP, yaw_rate * dt)
	var p := pos
	for i in steps:
		v = rot * v
		p += v * dt
		path.append(p)
	return path


## Height of the world surface below pos, casting from `above` metres up.
## Returns -INF if nothing is below.
func _ground_height_at(pos: Vector3, above: float) -> float:
	var hit := _ray(pos + Vector3.UP * above, pos + Vector3.DOWN * 1000.0)
	return hit.position.y if not hit.is_empty() else -INF


func _sweep(from: Vector3, to: Vector3) -> Dictionary:
	var space := _body.get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _sweep_shape
	params.transform = Transform3D(Basis.IDENTITY, from)
	params.motion = to - from
	params.collision_mask = GameSettings.LAYER_WORLD
	params.exclude = [_body.get_rid()]
	var fractions := space.cast_motion(params)
	if fractions.is_empty() or fractions[1] >= 1.0:
		return {}
	var at := from + params.motion * fractions[1]
	params.transform.origin = at
	params.motion = Vector3.ZERO
	var rest := space.get_rest_info(params)
	return {
		position = rest.get("point", at),
		normal = rest.get("normal", -params.motion.normalized()),
	}


## Nearest world surface within SWEEP_RADIUS of pos (point + normal), or {}.
func _overlap(pos: Vector3) -> Dictionary:
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _sweep_shape
	params.transform = Transform3D(Basis.IDENTITY, pos)
	params.collision_mask = GameSettings.LAYER_WORLD
	params.exclude = [_body.get_rid()]
	return _body.get_world_3d().direct_space_state.get_rest_info(params)


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, GameSettings.LAYER_WORLD)
	query.exclude = [_body.get_rid()]
	return _body.get_world_3d().direct_space_state.intersect_ray(query)
