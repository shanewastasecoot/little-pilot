extends Node
## Generative background music (autoload: Music). No audio files needed.
## Two moods share one gentle chord loop (C - Am - F - G, pentatonic melody):
##   "menu"   slow and sparse, bass + soft bells
##   "flight" bouncier, adds a plucked arpeggio and more melody
## set_mood() crossfades between them over a couple of seconds.

const VOICES := 16
const C4 := 261.63
## Chord roots/tones in semitones from C, one chord per bar.
const CHORDS := [[0, 4, 7], [-3, 0, 4], [-7, -3, 0], [-5, -1, 2]]
const PENTATONIC := [0, 2, 4, 7, 9, 12, 14, 16]

var _inst: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _moods: Dictionary = {
	"menu": {bpm = 76.0, gain = 0.0, target = 0.0, time = 0.0, step = 0, melody = 0.3, arp = false, bass_steps = [0]},
	"flight": {bpm = 104.0, gain = 0.0, target = 0.0, time = 0.0, step = 0, melody = 0.45, arp = true, bass_steps = [0, 4]},
}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = GameSettings.BUS_MUSIC
		add_child(p)
		_players.append(p)
	# One sample per instrument at C; other notes use pitch_scale.
	_inst.bell = Sfx.synth([[C4 * 2.0, 0.0, 1.2]], 0.35, 3.2)
	_inst.pluck = Sfx.synth([[C4, 0.0, 0.45]], 0.25, 8.0)
	_inst.bass = Sfx.synth([[C4 * 0.25, 0.0, 1.4], [C4 * 0.5, 0.0, 1.4]], 0.45, 2.2)
	set_mood("menu", 0.0)


## Switch mood. fade: seconds for the crossfade.
func set_mood(mood: String, fade: float = 2.0) -> void:
	for key in _moods:
		var m: Dictionary = _moods[key]
		m.target = 1.0 if key == mood else 0.0
		if fade <= 0.0:
			m.gain = m.target
		m.fade = maxf(fade, 0.01)


func _process(delta: float) -> void:
	# After sleep/resume the first delta can be minutes long; never try to
	# "catch up" on missed notes.
	delta = minf(delta, 0.1)
	for key in _moods:
		var m: Dictionary = _moods[key]
		m.gain = move_toward(m.gain, m.target, delta / m.get("fade", 2.0))
		if m.gain <= 0.01:
			continue
		m.time += delta
		var step_len: float = 30.0 / m.bpm  # eighth notes
		while m.time >= step_len:
			m.time -= step_len
			_play_step(m)
			m.step += 1


func _play_step(m: Dictionary) -> void:
	var s: int = m.step % 8
	var bar: int = (m.step / 8) % CHORDS.size()
	var chord: Array = CHORDS[bar]
	var g: float = m.gain
	if s in m.bass_steps:
		_note("bass", chord[0], g * 0.9)
	if m.arp:
		var pattern := [0, 1, 2, 1, 0, 1, 2, 1]
		_note("pluck", chord[pattern[s]] + 12, g * 0.45)
	# Melody: chord tones on strong beats, pentatonic in between.
	_rng.seed = hash(m.step / 32) + s * 31 + bar * 7  # loops repeat a little
	if _rng.randf() < m.melody or s == 0:
		var pitch: int
		if s % 4 == 0:
			pitch = chord[_rng.randi() % 3] + 12
		else:
			pitch = PENTATONIC[_rng.randi() % PENTATONIC.size()]
		_note("bell", pitch, g * 0.7)


func _note(inst: String, semitones: int, gain: float) -> void:
	var p := _players[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	p.stream = _inst[inst]
	p.pitch_scale = pow(2.0, semitones / 12.0)
	p.volume_db = linear_to_db(maxf(gain, 0.0001))
	p.play()
