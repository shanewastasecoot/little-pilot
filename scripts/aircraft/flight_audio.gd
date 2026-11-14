class_name FlightAudio
extends Node
## Continuous flight sounds: engine (pitch follows speed, per aircraft) and
## wind (louder with speed). Lives on the Aircraft; pauses with the game.

## 0..1 overall level, lowered by main.gd behind menus.
var level: float = 1.0

var _engine := AudioStreamPlayer.new()
var _wind := AudioStreamPlayer.new()
var _aircraft: Aircraft
var _engine_id := ""


func _ready() -> void:
	_aircraft = get_parent() as Aircraft
	for p in [_engine, _wind]:
		p.bus = GameSettings.BUS_SFX
		p.volume_db = -60.0
		add_child(p)
	_wind.stream = Sfx.get_loop("wind")
	_wind.play()


func _process(delta: float) -> void:
	if _aircraft == null or _aircraft.stats == null:
		return
	var stats := _aircraft.stats
	var id := "jet_engine" if stats.id == "jet" else "prop_engine"
	if id != _engine_id:
		_engine_id = id
		_engine.stream = Sfx.get_loop(id)
		_engine.play()
	var speed_ratio := _aircraft.speed / stats.cruise_speed  # ~0.65 .. 1.5
	var k := 1.0 - exp(-6.0 * delta)
	_engine.pitch_scale = lerpf(_engine.pitch_scale, clampf(0.55 + speed_ratio * 0.5, 0.5, 1.6), k)
	_engine.volume_db = lerpf(_engine.volume_db, linear_to_db(maxf(0.22 * level, 0.0001)) + _aircraft.boost_amount * 3.0, k)
	var wind := clampf((speed_ratio - 0.5) * 0.35, 0.02, 0.5) * level
	_wind.volume_db = lerpf(_wind.volume_db, linear_to_db(maxf(wind, 0.0001)), k)
	_wind.pitch_scale = lerpf(_wind.pitch_scale, 0.8 + speed_ratio * 0.3, k)
