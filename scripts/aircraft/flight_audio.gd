class_name FlightAudio
extends Node
## Continuous flight sounds, per aircraft:
##   engine  - pitch rises clearly with speed, a bit quieter when slow
##   boost   - extra layer that fades in while boosting (prop revs up,
##             jet afterburner roar)
##   wind    - louder and brighter with speed
## Lives on the Aircraft; pauses with the game.

## Linear volumes at cruise (before the SFX bus). Kept below the music.
const ENGINE_LEVEL := 0.2
const BOOST_LEVEL := 0.2
const WIND_LEVEL := 0.18

## 0..1 overall level, lowered by main.gd behind menus.
var level: float = 1.0

var _engine := AudioStreamPlayer.new()
var _boost := AudioStreamPlayer.new()
var _wind := AudioStreamPlayer.new()
var _aircraft: Aircraft
var _kind := ""


func _ready() -> void:
	_aircraft = get_parent() as Aircraft
	for p in [_engine, _boost, _wind]:
		p.bus = GameSettings.BUS_SFX
		p.volume_db = -80.0
		add_child(p)
	_wind.stream = Sfx.get_loop("wind")
	_wind.play()


func _process(delta: float) -> void:
	if _aircraft == null or _aircraft.stats == null:
		return
	var kind := "jet" if _aircraft.stats.id == "jet" else "prop"
	if kind != _kind:
		_kind = kind
		_engine.stream = Sfx.get_loop(kind + "_engine")
		_boost.stream = Sfx.get_loop(kind + "_boost")
		_engine.play()
		_boost.play()
	var ratio := _aircraft.speed / _aircraft.stats.cruise_speed  # ~0.65 slow, 1 cruise, 1.5 boost
	var boost := _aircraft.boost_amount
	var k := 1.0 - exp(-5.0 * delta)
	# Engine: ~0.8x pitch when slow, 1.0 at cruise, ~1.3x on full boost.
	_engine.pitch_scale = lerpf(_engine.pitch_scale, clampf(0.4 + 0.6 * ratio, 0.6, 1.5), k)
	_set_volume(_engine, ENGINE_LEVEL * clampf(0.6 + 0.4 * ratio, 0.5, 1.4), k)
	_boost.pitch_scale = lerpf(_boost.pitch_scale, 0.9 + 0.3 * boost, k)
	_set_volume(_boost, BOOST_LEVEL * boost, k)
	_wind.pitch_scale = lerpf(_wind.pitch_scale, 0.7 + 0.4 * ratio, k)
	_set_volume(_wind, WIND_LEVEL * clampf((ratio - 0.4) * 0.9, 0.05, 1.2), k)


func _set_volume(p: AudioStreamPlayer, linear: float, k: float) -> void:
	var target := linear_to_db(maxf(linear * level, 0.00001))
	p.volume_db = lerpf(p.volume_db, target, k)
