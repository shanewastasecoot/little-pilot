class_name StallDetector
extends Node
## Graphics Phase G0: watches every frame (debug builds and the benches).
## Any frame slower than STALL_MS is logged to user://bench/stalls.log with
## the time, the game state (flying, on foot, indoors, sailing, loading...)
## and what happened that frame: game events (WorldEvents), notes other
## systems leave (StallDetector.note: a building opening, a rain cloud,
## the dragon's fire, a character or an inside being built...) and how
## many shader pipelines compiled. `last_frame` holds the same record for
## the frame just finished (the bench's hitch log reads it).

const STALL_MS := 250.0
const LOG := "user://bench/stalls.log"

## The running detector (or null).
static var current: StallDetector
static var _notes: PackedStringArray = []

var main: Node
## The frame just finished: {ms, logic_ms (all the game's _process code),
## physics_ms (all its _physics_process code, every tick that frame),
## cpu_ms (render CPU), gpu_ms, compiles, notes, state}.
var last_frame := {}
var stalls := 0
var _last_us := 0
var _compiles := 0
var _proc_start := 0
var _proc_ms := 0.0
var _phys_start := 0
var _phys_ms := 0.0
var _phys_ms_frame := 0.0


## Marks the end of each frame's game code (runs after every other node).
class _End extends Node:
	var d: StallDetector
	func _ready() -> void:
		process_priority = 1000
		process_physics_priority = 1000
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _process(_delta: float) -> void:
		d._proc_ms = (Time.get_ticks_usec() - d._proc_start) / 1000.0
	func _physics_process(_delta: float) -> void:
		d._phys_ms += (Time.get_ticks_usec() - d._phys_start) / 1000.0


## Something worth knowing about happened this frame (cheap; safe to call
## even when no detector is running).
static func note(what: String) -> void:
	if _notes.size() < 32:
		_notes.append(what)


func _ready() -> void:
	name = "StallDetector"
	process_priority = -1000  # first each frame: it measures the frame before
	process_physics_priority = -1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	var end := _End.new()
	end.d = self
	add_child(end)
	current = self
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	WorldEvents.happened.connect(func(kind: String, _w: Vector3, _i: Dictionary): note(kind))
	_compiles = _compile_count()
	_last_us = Time.get_ticks_usec()


func _exit_tree() -> void:
	if current == self:
		current = null


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var ms := (now - _last_us) / 1000.0
	_last_us = now
	var c := _compile_count()
	var vp := get_viewport().get_viewport_rid()
	last_frame = {
		"ms": ms,
		"logic_ms": _proc_ms,
		"physics_ms": _phys_ms_frame,
		"cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu(),
		"gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(vp),
		"compiles": c - _compiles,
		"notes": _notes.duplicate(),
		"state": state_name(),
	}
	_compiles = c
	_notes.clear()
	_proc_start = Time.get_ticks_usec()
	_phys_ms_frame = _phys_ms
	_phys_ms = 0.0
	if ms > STALL_MS:
		stalls += 1
		_log(last_frame)


func _physics_process(_delta: float) -> void:
	_phys_start = Time.get_ticks_usec()


func state_name() -> String:
	if main == null or not is_instance_valid(main) or not main.is_node_ready():
		return "loading"
	return String(main.State.keys()[main.state]).to_lower()


func _log(f: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://bench"))
	var file := FileAccess.open(LOG, FileAccess.READ_WRITE) if FileAccess.file_exists(LOG) else FileAccess.open(LOG, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line("%s  %.0f ms  state=%s  logic %.1f ms  physics %.1f ms  render cpu %.1f ms  gpu %.1f ms  compiles %d  events: %s" % [
		Time.get_datetime_string_from_system(), f.ms, f.state, f.logic_ms, f.physics_ms, f.cpu_ms, f.gpu_ms, f.compiles,
		", ".join(f.notes) if not (f.notes as PackedStringArray).is_empty() else "-"])
	push_warning("Stall: %.0f ms (%s) %s" % [f.ms, f.state, ", ".join(f.notes)])


static func _compile_count() -> int:
	return int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)
		+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)
		+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION))
