extends Node
## Tiny built-in sound synthesiser (autoload: Sfx).
## Generates friendly placeholder sounds at startup so every action has audio
## feedback before real sound assets arrive in Milestone 4.
## Usage: Sfx.play("chime", 1.2)

const RATE := 22050
const VOICES := 10

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	# [frequency Hz, start s, length s] notes; overlapping notes are mixed.
	_streams.chime = _synth([[1318.5, 0.0, 0.6]], 0.45, 6.0)
	_streams.ui_move = _synth([[880.0, 0.0, 0.07]], 0.35, 30.0)
	_streams.ui_confirm = _synth([[784.0, 0.0, 0.1], [1174.7, 0.08, 0.2]], 0.4, 12.0)
	_streams.ui_back = _synth([[659.3, 0.0, 0.1], [440.0, 0.08, 0.16]], 0.35, 14.0)
	_streams.honk = _synth([[440.0, 0.0, 0.14], [440.0, 0.2, 0.18]], 0.5, 4.0, true)
	_streams.jingle = _synth([[523.3, 0.0, 0.3], [659.3, 0.12, 0.3], [784.0, 0.24, 0.3], [1046.5, 0.36, 0.6]], 0.35, 5.0)
	_streams.fanfare = _synth([[523.3, 0.0, 0.25], [659.3, 0.15, 0.25], [784.0, 0.3, 0.25],
		[1046.5, 0.45, 0.35], [784.0, 0.7, 0.2], [1046.5, 0.85, 0.9], [1318.5, 0.85, 0.9]], 0.3, 3.5)
	_streams.pop = _synth([[600.0, 0.0, 0.12]], 0.4, 25.0, false, 2.5)


func play(sound: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not _streams.has(sound):
		push_warning("Unknown sound: %s" % sound)
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[sound]
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.volume_db = volume_db
	p.play()


## Builds a mono 16-bit AudioStreamWAV from a list of notes.
## decay: exponential fade speed per note. square: buzzier tone (honks).
## sweep: pitch glide multiplier over each note (1 = none).
func _synth(notes: Array, volume: float, decay: float, square := false, sweep := 1.0) -> AudioStreamWAV:
	var length := 0.0
	for n in notes:
		length = maxf(length, n[1] + n[2])
	var count := int(length * RATE) + 1
	var buf := PackedFloat32Array()
	buf.resize(count)
	for n in notes:
		var start := int(n[1] * RATE)
		var dur := int(n[2] * RATE)
		var phase := 0.0
		for i in dur:
			var t := float(i) / RATE
			var progress := float(i) / dur
			var freq: float = n[0] * lerpf(1.0, sweep, progress)
			phase += TAU * freq / RATE
			var s := sin(phase) + 0.3 * sin(phase * 2.0)
			if square:
				s = clampf(sin(phase) * 3.0, -1.0, 1.0) * 0.6 + 0.2 * sin(phase * 3.0)
			var attack := minf(1.0, t * 200.0)          # 5 ms fade-in, no clicks
			var release := minf(1.0, (dur - i) / 220.0)  # 10 ms fade-out
			buf[start + i] += s * exp(-decay * t) * attack * release
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		data.encode_s16(i * 2, int(clampf(buf[i] * volume, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
