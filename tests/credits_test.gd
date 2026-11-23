extends Node
## Credits (Phase 7): resources/credits.json is the one source.
##   - every CC-BY asset has an author, a licence (with its link) and a
##     source URL
##   - every file it lists exists, and every model / baked file under
##     assets/ is listed (as a third-party asset or as the project's own)
##   - CREDITS.md is exactly what the JSON makes (./dev.sh credits)
##   - the in-game credits screen (from the parent settings) shows them all
## Exit code 0 = pass, 1 = fail.

var _fails := 0


func _ready() -> void:
	var d := Credits.data()
	_check("resources/credits.json loads, with assets", not d.is_empty() and (d.get("assets", []) as Array).size() > 20)
	# CC-BY: author, licence, source.
	var bad: Array[String] = []
	var cc_by := 0
	for a: Dictionary in d.get("assets", []):
		if Credits.needs_credit(str(a.get("license", ""))):
			cc_by += 1
			var srcs: Array = a.get("sources", [])
			if str(a.get("author", "")).strip_edges() == "" or not str(a.get("license_url", "")).begins_with("https://") \
					or srcs.is_empty() or not str(srcs[0].get("url", "")).begins_with("https://"):
				bad.append(str(a.get("name", "?")))
		if str(a.get("license", "")) == "" or (a.get("files", []) as Array).is_empty():
			bad.append(str(a.get("name", "?")) + " (no licence or files)")
	for b in bad:
		print("    incomplete: ", b)
	_check("every CC-BY asset (%d) has an author, a licence and a source URL" % cc_by, bad.is_empty() and cc_by > 0)
	# Files: listed ones exist; every model is listed.
	var listed: Array[String] = []
	for a: Dictionary in d.get("assets", []):
		for f in a.get("files", []):
			listed.append(str(f))
	for f in d.get("own_files", []):
		listed.append(str(f))
	var missing: Array[String] = []
	for l in listed:
		if l.contains("*"):
			if _glob(l).is_empty():
				missing.append(l)
		elif l.ends_with("/"):
			if not DirAccess.dir_exists_absolute("res://" + l):
				missing.append(l)
		elif not FileAccess.file_exists("res://" + l):
			missing.append(l)
	for m in missing:
		print("    missing: ", m)
	_check("every file the credits list exists", missing.is_empty())
	var unlisted: Array[String] = []
	for f in _files("res://assets", ["glb", "res"]):
		var rel := f.trim_prefix("res://")
		var ok := false
		for l in listed:
			if rel == l or (l.ends_with("/") and rel.begins_with(l)) or (l.contains("*") and rel.match(l)):
				ok = true
				break
		if not ok:
			unlisted.append(rel)
	for u in unlisted:
		print("    not credited: ", u)
	_check("every model and baked file under assets/ is credited", unlisted.is_empty())
	# CREDITS.md made from it.
	var md := FileAccess.get_file_as_string("res://CREDITS.md")
	_check("CREDITS.md is made from the JSON (./dev.sh credits), not edited by hand", md == Credits.markdown(d))
	_check("no stale \"(none yet)\" table", not md.contains("(none yet)"))
	# The screen.
	var screen := CreditsScreen.new()
	add_child(screen)
	await get_tree().process_frame
	_check("the credits screen lists the engine and every asset", screen.line_count() >= (d.assets as Array).size() + 2)
	screen.open()
	await get_tree().process_frame
	var opened := screen.visible
	screen.close()
	_check("it opens and closes", opened and not screen.visible)
	print("\nCREDITS TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _files(dir: String, exts: Array) -> Array[String]:
	var out: Array[String] = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	for sub in da.get_directories():
		out.append_array(_files(dir + "/" + sub, exts))
	for f in da.get_files():
		if f.get_extension() in exts:
			out.append(dir + "/" + f)
	return out


func _glob(pattern: String) -> Array[String]:
	var out: Array[String] = []
	var dir := "res://" + pattern.get_base_dir()
	var da := DirAccess.open(dir)
	if da == null:
		return out
	for f in da.get_files():
		if (pattern.get_base_dir() + "/" + f).match(pattern):
			out.append(f)
	return out


func _check(name: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", name])
	if not ok:
		_fails += 1
