class_name BenchToggles
extends RefCounted
## Bench toggles (Phase 8): change a render setting for one run, to measure
## what it costs. They never change the defaults or the save; with none
## given, nothing changes. Pass them after `--` on the command line, e.g.
##   ./dev.sh bench-render -- --bench-shadows=2048 --bench-glow=off
##
##   --bench-shadows=4096|2048        the sun's shadow map size (default 4096)
##   --bench-aa=msaa|ssaa|both|none   anti-aliasing (default: both = 2x MSAA + FXAA)
##              or parts joined by +: msaa2, msaa4, fxaa, smaa (G5), e.g.
##              --bench-aa=msaa2+smaa, --bench-aa=msaa4
##   --bench-shadow-filter=0..5       soft shadow filter quality (default 1, low)
##   --bench-refraction=on|off        the ocean's see-through refraction
##   --bench-far-waves=full|simple    simple: far-away waves fade out sooner
##   --bench-glow=on|off              the glow (bloom) on bright things
##   --bench-crowd=<metres>           how far away townspeople are drawn (300)

const KEYS := ["shadows", "shadow-filter", "aa", "refraction", "far-waves", "glow", "crowd"]


## The toggles given on the command line: {"shadows": "2048", ...}.
static func active() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bench-") and a.contains("="):
			var kv := a.trim_prefix("--bench-").split("=", true, 1)
			if kv[0] in KEYS:
				out[kv[0]] = kv[1]
	return out


static func value(key: String, default := "") -> String:
	return active().get(key, default)


## Apply the toggles that are about the whole screen (main.gd calls this
## once the world is built). The ocean and the crowd read theirs themselves.
static func apply(viewport: Viewport, env: Environment) -> void:
	var t := active()
	if t.is_empty():
		return
	if t.has("shadows"):
		RenderingServer.directional_shadow_atlas_set_size(int(t.shadows), true)
	if t.has("shadow-filter"):
		RenderingServer.directional_soft_shadow_filter_set_quality(int(t["shadow-filter"]))
	if t.has("aa"):
		var aa := aa_settings(t.aa)
		viewport.msaa_3d = aa[0]
		viewport.screen_space_aa = aa[1]
	if t.has("glow") and env:
		env.glow_enabled = t.glow != "off"
	print("Bench toggles: ", t)


## [msaa_3d, screen_space_aa] for an --bench-aa value (see the top).
static func aa_settings(v: String) -> Array:
	var legacy := {"msaa": "msaa2", "ssaa": "fxaa", "both": "msaa2+fxaa", "none": ""}
	var parts := Array(String(legacy.get(v, v)).split("+", false))
	var msaa := Viewport.MSAA_DISABLED
	if "msaa2" in parts:
		msaa = Viewport.MSAA_2X
	elif "msaa4" in parts:
		msaa = Viewport.MSAA_4X
	var ss := Viewport.SCREEN_SPACE_AA_DISABLED
	if "fxaa" in parts:
		ss = Viewport.SCREEN_SPACE_AA_FXAA
	elif "smaa" in parts:
		ss = Viewport.SCREEN_SPACE_AA_SMAA
	return [msaa, ss]
