extends SceneTree
## Loads every script (*.gd) and scene (*.tscn) in the project and reports
## any that fail to load (parse errors, missing files, broken references).
## Used by ./dev.sh check. Exit code 0 = all loaded, 1 = something failed.
##
## It loads them on the first frame, not in _initialize(), so the autoloads
## (SaveManager, Sfx...) already exist when game scripts that use them are
## compiled. This script itself names no game classes for the same reason.

const SKIP := ["res://.godot", "res://.git", "res://Storage"]

var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var files: Array[String] = []
	_collect("res://", files)
	var failed: Array[String] = []
	var scripts := 0
	var scenes := 0
	for path in files:
		var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		if path.ends_with(".gd"):
			scripts += 1
			if res == null or not (res as Script).can_instantiate():
				failed.append(path)
		else:
			scenes += 1
			if res == null:
				failed.append(path)
	print("SCRIPT CHECK: %d scripts, %d scenes loaded, %d failed" % [scripts, scenes, failed.size()])
	for f in failed:
		print("SCRIPT CHECK FAILED: ", f)
	quit(1 if failed.size() > 0 else 0)
	return false


func _collect(dir_path: String, out: Array[String]) -> void:
	if dir_path.trim_suffix("/") in SKIP:
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.include_hidden = false
	for f in dir.get_files():
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			out.append(dir_path.path_join(f))
	for d in dir.get_directories():
		_collect(dir_path.path_join(d), out)
