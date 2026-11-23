class_name Credits
extends RefCounted
## Who made what (Phase 7). resources/credits.json is the one place credits
## are written down; CREDITS.md is made from it (`./dev.sh credits`, which
## runs tools/make_credits.tscn) and the in-game credits screen
## (CreditsScreen, from the parent settings) reads it. Edit the JSON, never
## CREDITS.md by hand: credits_test fails if the two differ.
##
## JSON: code (text), engine [{name, url, license}], rules [text],
## assets [{name, files [paths, folders end in /, globs ok], author,
## author_url?, license, license_url, sources [{label, url}], note?}],
## own_files [paths made by this project's own tools], changes (text),
## generated [text].

const PATH := "res://resources/credits.json"


static func data() -> Dictionary:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


## Does this licence need the author credited (CC-BY)?
static func needs_credit(license: String) -> bool:
	return license.begins_with("CC-BY")


## CREDITS.md, made from the JSON.
static func markdown(d: Dictionary = {}) -> String:
	if d.is_empty():
		d = data()
	var out := PackedStringArray()
	out.append("# Credits")
	out.append("")
	out.append("<!-- Made from resources/credits.json by `./dev.sh credits`. Edit the JSON, not this file. -->")
	out.append("")
	out.append("Every third-party asset is listed here (in `resources/credits.json`) **before** it is committed.")
	out.append("")
	out.append("## Code")
	out.append("")
	out.append(str(d.get("code", "")))
	out.append("")
	out.append("## Engine")
	out.append("")
	for e: Dictionary in d.get("engine", []):
		out.append("- [%s](%s) — %s" % [e.name, e.url, e.license])
	out.append("")
	out.append("## Licence rules")
	out.append("")
	for r in d.get("rules", []):
		out.append("- " + str(r))
	out.append("")
	out.append("## Third-party assets")
	out.append("")
	out.append("| Asset | File(s) | Author | Licence | Source |")
	out.append("|---|---|---|---|---|")
	for a: Dictionary in d.get("assets", []):
		var files := PackedStringArray()
		for f in a.get("files", []):
			files.append("`%s`" % f)
		var file_cell := ", ".join(files) + (" (%s)" % a.note if a.has("note") else "")
		var author := str(a.author) + (" ([%s](%s))" % [str(a.author_url).trim_prefix("https://").trim_prefix("www."), a.author_url] if a.has("author_url") else "")
		var lic := "[%s](%s)" % [a.license, a.license_url] if str(a.get("license_url", "")) != "" else str(a.license)
		var srcs := PackedStringArray()
		for s: Dictionary in a.get("sources", []):
			srcs.append("[%s](%s)" % [s.label, s.url])
		out.append("| %s | %s | %s | %s | %s |" % [a.name, file_cell, author, lic, ", ".join(srcs)])
	out.append("")
	out.append("CC0 assets need no credit; they're listed so their origin is recorded.")
	out.append("")
	out.append("Changes: " + str(d.get("changes", "")))
	out.append("")
	out.append("## Made by this project")
	out.append("")
	for g in d.get("generated", []):
		out.append("- " + str(g))
	out.append("- **Files made by the project's own tools** (no third-party licence): " +
			", ".join(PackedStringArray(d.get("own_files", []).map(func(f): return "`%s`" % f))) + ".")
	out.append("")
	return "\n".join(out)


## Plain lines for the in-game screen: [title, line, line...] per asset.
static func screen_lines(d: Dictionary = {}) -> Array[String]:
	if d.is_empty():
		d = data()
	var out: Array[String] = []
	for e: Dictionary in d.get("engine", []):
		out.append("%s — %s" % [e.name, e.license])
	for a: Dictionary in d.get("assets", []):
		var src := ""
		if not (a.get("sources", []) as Array).is_empty():
			src = " — " + str(a.sources[0].url).trim_prefix("https://")
		out.append("%s — %s — %s%s" % [_short(str(a.name)), a.author, a.license, src])
	return out


## The asset's name without the original title in quotes (shorter on screen).
static func _short(n: String) -> String:
	var i := n.find(" (\"")
	return n.substr(0, i) if i > 0 else n
