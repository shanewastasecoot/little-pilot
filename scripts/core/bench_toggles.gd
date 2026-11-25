class_name BenchToggles
extends RefCounted
## Bench toggles (Phase 8): change a render setting for one run, to measure
## what it costs. They never change the defaults or the save; with none
## given, nothing changes. Pass them after `--` on the command line, e.g.
##   ./dev.sh bench-render -- --bench-shadows=2048 --bench-glow=off
##
##   --bench-shadows=4096|2048        the sun's shadow map size (default 4096)
##   --bench-aa=msaa|ssaa|both|none   anti-aliasing (default: both)
##   --bench-refraction=on|off        the ocean's see-through refraction
##   --bench-far-waves=full|simple    simple: far-away waves fade out sooner
##   --bench-glow=on|off              the glow (bloom) on bright things
##   --bench-crowd=<metres>           how far away townspeople are drawn (300)

const KEYS := ["shadows", "aa", "refraction", "far-waves", "glow", "crowd"]


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
	if t.has("aa"):
		var msaa: bool = t.aa in ["msaa", "both"]
		var ssaa: bool = t.aa in ["ssaa", "both"]
		viewport.msaa_3d = Viewport.MSAA_2X if msaa else Viewport.MSAA_DISABLED
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if ssaa else Viewport.SCREEN_SPACE_AA_DISABLED
	if t.has("glow") and env:
		env.glow_enabled = t.glow != "off"
	print("Bench toggles: ", t)
