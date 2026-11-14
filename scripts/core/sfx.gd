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
		p.bus = GameSettings.BUS_SFX
		add_child(p)
		_players.append(p)
	# [frequency Hz, start s, length s] notes; overlapping notes are mixed.
	_streams.chime = _synth([[1318.5, 0.0, 0.6]], 0.45, 6.0)
	_streams.ui_move = _synth([[880.0, 0.0, 0.07]], 0.35, 30.0)
	_streams.ui_confirm = _synth([[784.0, 0.0, 0.1], [1174.7, 0.08, 0.2]], 0.4, 12.0)
	_streams.ui_back = _synth([[659.3, 0.0, 0.1], [440.0, 0.08, 0.16]], 0.35, 14.0)
	_streams.honk = _synth([[440.0, 0.0, 0.14], [440.0, 0.2, 0.18]], 0.4, 4.0, true)
	_streams.jingle = _synth([[523.3, 0.0, 0.3], [659.3, 0.12, 0.3], [784.0, 0.24, 0.3], [1046.5, 0.36, 0.6]], 0.35, 5.0)
	_streams.fanfare = _synth([[523.3, 0.0, 0.25], [659.3, 0.15, 0.25], [784.0, 0.3, 0.25],
		[1046.5, 0.45, 0.35], [784.0, 0.7, 0.2], [1046.5, 0.85, 0.9], [1318.5, 0.85, 0.9]], 0.3, 3.5)
	# Landmark discoveries
	_streams.ding = _synth([[1046.5, 0.0, 0.5], [1568.0, 0.12, 0.7]], 0.4, 4.0)
	_streams.echo = _synth([[659.3, 0.0, 0.25], [523.3, 0.22, 0.4], [659.3, 0.7, 0.25], [523.3, 0.92, 0.4], [659.3, 1.4, 0.25], [523.3, 1.62, 0.4]], 0.35, 3.0)
	_streams.foghorn = _synth([[110.0, 0.0, 1.2], [116.5, 0.0, 1.2]], 0.55, 1.2, true)
	_streams.whoosh = _synth([[300.0, 0.0, 0.9]], 0.35, 2.5, false, 3.0)
	_streams.moo = _synth([[180.0, 0.0, 0.9]], 0.5, 1.5, true, 0.7)
	_streams.chirp = _synth([[2200.0, 0.0, 0.08], [2600.0, 0.12, 0.08], [2400.0, 0.3, 0.08], [2900.0, 0.42, 0.1]], 0.3, 10.0, false, 1.3)
	_streams.toot = _synth([[294.0, 0.0, 0.3], [294.0, 0.4, 0.7]], 0.5, 1.5, true)
	_streams.splash = _synth([[200.0, 0.0, 0.5]], 0.4, 5.0, false, 0.3)
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


## Seamless looping streams for continuous sounds (engines, wind).
## Built on demand and cached.
func get_loop(loop_name: String) -> AudioStreamWAV:
	var key := "loop_" + loop_name
	if not _streams.has(key):
		match loop_name:
			"prop_engine": _streams[key] = _engine_loop(80.0, true)
			"jet_engine": _streams[key] = _engine_loop(55.0, false)
			"wind": _streams[key] = _noise_loop(0.06, 2.0)
	return _streams[key]


## Buzzy propeller (putt-putt) or smooth turbine hum. One second long, with
## a whole number of cycles so the loop point is seamless.
func _engine_loop(freq: float, prop: bool) -> AudioStreamWAV:
	var count := RATE
	var buf := PackedFloat32Array()
	buf.resize(count)
	var noise := _noise_buffer(count, 0.15)
	for i in count:
		var ph := TAU * freq * i / RATE
		var s: float
		if prop:
			s = 0.5 * sin(ph) + 0.3 * sin(ph * 2.0) + 0.2 * sin(ph * 3.0) + 0.12 * sin(ph * 5.0)
			s *= 0.75 + 0.25 * sin(TAU * 20.0 * i / RATE)  # blade "putt"
		else:
			s = 0.35 * sin(ph) + 0.15 * sin(ph * 2.0) + noise[i] * 1.6
		buf[i] = s * 0.5
	return _to_wav(buf, true)


## Soft filtered noise (wind). `smooth` is a one-pole low-pass factor.
func _noise_loop(smooth: float, seconds: float) -> AudioStreamWAV:
	var buf := _noise_buffer(int(seconds * RATE), smooth)
	for i in buf.size():
		buf[i] *= 3.0
	return _to_wav(buf, true)


func _noise_buffer(count: int, smooth: float) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var buf := PackedFloat32Array()
	buf.resize(count)
	var v := 0.0
	for pass_i in 2:  # second pass makes the end flow into the start
		for i in count:
			v = lerpf(v, rng.randf_range(-1.0, 1.0), smooth)
			buf[i] = v
	return buf


func _to_wav(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = buf.size()
	return wav


## Public access to the synth (used by Music).
func synth(notes: Array, volume: float, decay: float, square := false, sweep := 1.0) -> AudioStreamWAV:
	return _synth(notes, volume, decay, square, sweep)


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
