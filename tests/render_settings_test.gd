extends Node
## Graphics G5, smooth edges and shadows (the parent's pick, Nov 27):
##   edges    4x MSAA, no FXAA/SMAA blur on top
##   shadows  the high soft-shadow filter (no dotty shadow edges) and the
##            4096 shadow map
##   bench    the --bench-aa values still mean what they say
## Exit code 0 = pass, 1 = fail.

var _fails := 0


func _ready() -> void:
	var vp := get_tree().root
	_check("edges: 4x MSAA", ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d") == Viewport.MSAA_4X
		and vp.msaa_3d == Viewport.MSAA_4X)
	_check("no screen-space blur on top", ProjectSettings.get_setting("rendering/anti_aliasing/quality/screen_space_aa") == Viewport.SCREEN_SPACE_AA_DISABLED
		and vp.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED)
	_check("shadows: high soft filter (no dots)",
		ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality") == 3)
	_check("shadows: 4096 map", ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size") == 4096)
	_check("bench: msaa4 is 4x MSAA alone", BenchToggles.aa_settings("msaa4") == [Viewport.MSAA_4X, Viewport.SCREEN_SPACE_AA_DISABLED])
	_check("bench: msaa2+smaa", BenchToggles.aa_settings("msaa2+smaa") == [Viewport.MSAA_2X, Viewport.SCREEN_SPACE_AA_SMAA])
	_check("bench: both is the old 2x MSAA + FXAA", BenchToggles.aa_settings("both") == [Viewport.MSAA_2X, Viewport.SCREEN_SPACE_AA_FXAA])
	_check("bench: none is off", BenchToggles.aa_settings("none") == [Viewport.MSAA_DISABLED, Viewport.SCREEN_SPACE_AA_DISABLED])
	print("\nRENDER SETTINGS TEST %s" % ("PASSED" if _fails == 0 else "FAILED (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)


func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1
