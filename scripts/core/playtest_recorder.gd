class_name PlaytestRecorder
extends Node
## A local playtest diary (Phase 8, optional): debug builds only, and only
## when asked (`./dev.sh run -- --record-playtest`). It notes where the
## plane or she went (every few seconds), crashes, landings, take-offs,
## honks and landmarks found, and writes them to a JSON file on this
## computer (user://playtests/<date-time>.json) when the game closes or
## every minute. Nothing is ever sent anywhere: the game has no network
## code at all.

const EVERY := 3.0
const SAVE_EVERY := 60.0

var main: Node
var _log := {"started": "", "route": [], "events": [], "landmarks": []}
var _t := 0.0
var _save_t := 0.0
var _path := ""


## Make one if this run asked for it (debug builds only), else null.
static func maybe_start(game: Node) -> PlaytestRecorder:
	if not OS.is_debug_build() or not "--record-playtest" in OS.get_cmdline_user_args():
		return null
	var r := PlaytestRecorder.new()
	r.name = "PlaytestRecorder"
	r.main = game
	game.add_child(r)
	return r


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	_log.started = stamp
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://playtests"))
	_path = "user://playtests/%s.json" % stamp
	WorldEvents.happened.connect(func(kind: String, where: Vector3, info: Dictionary):
		if kind in ["crash", "landing", "takeoff", "honk", "cheer"]:
			_log.events.append({"t": _now(), "kind": kind, "at": _xz(where), "info": info}))
	for l in get_tree().get_nodes_in_group("landmarks"):
		if l.has_signal("discovered"):
			l.discovered.connect(func(lm): _log.landmarks.append({"t": _now(), "name": str(lm.get("landmark_name"))}))
	print("Recording this playtest to ", ProjectSettings.globalize_path(_path))


func _process(delta: float) -> void:
	_t += delta
	_save_t += delta
	if _t >= EVERY:
		_t = 0.0
		var who: Node3D = main.walker if main.state in [main.State.ON_FOOT, main.State.INDOORS] else main.aircraft
		_log.route.append({"t": _now(), "state": int(main.state), "at": _xz(who.global_position), "y": snappedf(who.global_position.y, 0.1)})
	if _save_t >= SAVE_EVERY:
		_save_t = 0.0
		save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		save()


func save() -> void:
	if _path == "":
		return
	var f := FileAccess.open(_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_log, " "))


func entries() -> int:
	return _log.route.size() + _log.events.size() + _log.landmarks.size()


func _now() -> float:
	return snappedf(Time.get_ticks_msec() / 1000.0, 0.1)


static func _xz(p: Vector3) -> Array:
	return [snappedf(p.x, 0.1), snappedf(p.z, 0.1)]
