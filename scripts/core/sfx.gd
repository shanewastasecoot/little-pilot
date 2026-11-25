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
	_streams.rumble = _synth([[55.0, 0.0, 1.6], [58.0, 0.0, 1.6], [82.0, 0.3, 1.2]], 0.55, 1.4, true, 0.8)
	_streams.tropical = _synth([[523.3, 0.0, 0.25], [659.3, 0.18, 0.25], [784.0, 0.36, 0.25], [659.3, 0.54, 0.25], [880.0, 0.72, 0.5]], 0.35, 4.0)
	_streams.bells = _synth([[1568.0, 0.0, 0.5], [1318.5, 0.15, 0.5], [1568.0, 0.3, 0.5], [2093.0, 0.45, 0.8]], 0.3, 4.0)
	_streams.rawr = _synth([[140.0, 0.0, 0.7], [95.0, 0.15, 0.6]], 0.5, 2.0, true, 0.6)
	_streams.lala = _synth([[784.0, 0.0, 0.3], [988.0, 0.25, 0.3], [1175.0, 0.5, 0.3], [988.0, 0.75, 0.3], [1318.5, 1.0, 0.6]], 0.3, 3.0, false, 1.02)
	_streams.boom = _synth([[70.0, 0.0, 0.9], [48.0, 0.0, 0.9]], 0.6, 4.5, true, 0.5)
	_streams.whistle = _synth([[900.0, 0.0, 0.8]], 0.18, 1.0, false, 2.2)
	_streams.pop = _synth([[600.0, 0.0, 0.12]], 0.4, 25.0, false, 2.5)
	# Each aircraft's own horn (AircraftStats.honk_sound).
	_streams.honk_prop = _synth([[523.3, 0.0, 0.12], [659.3, 0.0, 0.12], [523.3, 0.17, 0.16], [659.3, 0.17, 0.16]], 0.38, 5.0, true)
	_streams.honk_jet = _synth([[220.0, 0.0, 0.2], [277.2, 0.0, 0.2], [220.0, 0.26, 0.26], [277.2, 0.26, 0.26]], 0.42, 3.5, true)
	# Dragon
	_streams.roar = _roar()
	_streams.fire = _noise_burst(1.7, 0.09, 0.12, 0.7, 2)
	_streams.explode = _explosion()
	_use_files()


## Real recordings win (Phase 12): a sound file in assets/audio/ named like
## the sound (honk.ogg, chime.wav...) replaces the one made in code, so every
## Sfx.play() name keeps working and the made-in-code sound stays as the
## fallback. Loops look in assets/audio/loops/ (see get_loop).
const AUDIO_DIR := "res://assets/audio/"
## (Tests) which sounds came from files.
var from_files: Array[String] = []


func _use_files() -> void:
	for sound in _streams.keys():
		var f := _file_for(AUDIO_DIR + String(sound))
		if f:
			_streams[sound] = f
			from_files.append(String(sound))


## A sound file at `base` + .ogg / .wav / .mp3, or null.
static func _file_for(base: String) -> AudioStream:
	for ext in [".ogg", ".wav", ".mp3"]:
		if ResourceLoader.exists(base + ext):
			return load(base + ext) as AudioStream
	return null


## A big, growly dragon roar: a buzzy voice sliding down with vibrato over
## rough breathy noise, swelling in and fading out.
func _roar() -> AudioStreamWAV:
	var length := 1.9
	var count := int(length * RATE)
	var noise := _seamless_noise(count, 0.25, 41)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / RATE
		var k := t / length
		var freq := lerpf(150.0, 75.0, k) * (1.0 + 0.06 * sin(TAU * 7.0 * t))
		phase += TAU * freq / RATE
		var voice := clampf(sin(phase) * 2.5, -1.0, 1.0) * 0.5 + 0.3 * sin(phase * 0.5) + 0.2 * sin(phase * 3.0)
		var growl := 0.6 + 0.4 * sin(TAU * 31.0 * t)  # gravelly flutter
		var env := smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(length * 0.55, length, t))
		buf[i] = (voice * growl + noise[i] * 3.5) * env
	return _to_wav(_normalize(buf, 0.85), false)


## Rushing noise (fire breath, wind gusts): swells in, holds, fades.
func _noise_burst(length: float, smooth: float, attack: float, peak: float, seed: int) -> AudioStreamWAV:
	var count := int(length * RATE)
	var noise := _seamless_noise(count, smooth, seed)
	var buf := PackedFloat32Array()
	buf.resize(count)
	for i in count:
		var t := float(i) / RATE
		var env := smoothstep(0.0, attack, t) * (1.0 - smoothstep(length * 0.6, length, t))
		buf[i] = noise[i] * env * (0.8 + 0.2 * sin(TAU * 9.0 * t))
	return _to_wav(_normalize(buf, peak), false)


## Cartoon explosion: a sharp crack, a deep thump and crackly debris.
func _explosion() -> AudioStreamWAV:
	var length := 1.6
	var count := int(length * RATE)
	var rough := _seamless_noise(count, 0.5, 13)
	var deep := _seamless_noise(count, 0.03, 17)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / RATE
		phase += TAU * lerpf(90.0, 35.0, minf(t / 0.6, 1.0)) / RATE
		var crack := rough[i] * exp(-t * 14.0) * 1.5
		var thump := (sin(phase) * 0.8 + deep[i] * 10.0) * exp(-t * 3.0)
		var debris := rough[i] * 0.3 * exp(-t * 2.5) * float(sin(TAU * 13.0 * t + sin(t * 40.0)) > 0.6)
		buf[i] = (crack + thump + debris) * minf(1.0, t * 400.0)
	return _to_wav(_normalize(buf, 0.9), false)


## A sound that plays at a point in the world (louder when close).
func play_at(sound: String, where: Vector3, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not _streams.has(sound):
		return
	var p := AudioStreamPlayer3D.new()
	p.bus = GameSettings.BUS_SFX
	p.stream = _streams[sound]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.unit_size = 250.0
	p.max_distance = 4000.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	get_tree().root.add_child(p)
	p.global_position = where
	p.finished.connect(p.queue_free)
	p.play()


func play(sound: String, pitch: float = 1.0, volume_db: float = 0.0, bus: StringName = &"") -> void:
	if not _streams.has(sound):
		push_warning("Unknown sound: %s" % sound)
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.bus = bus if bus != &"" else GameSettings.BUS_SFX
	p.stream = _streams[sound]
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.volume_db = volume_db
	p.play()


## Seamless looping streams for continuous sounds (engines, wind).
## Built on demand and cached. All loops are 1-2 s long; tones use whole-
## number frequencies and noise is cross-faded at the loop point, so there
## is no click when they repeat.
func get_loop(loop_name: String) -> AudioStream:
	var key := "loop_" + loop_name
	if not _streams.has(key):
		var file := _file_for(AUDIO_DIR + "loops/" + loop_name)
		if file:
			if file is AudioStreamOggVorbis:
				(file as AudioStreamOggVorbis).loop = true
			elif file is AudioStreamWAV:
				(file as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			_streams[key] = file
			from_files.append(key)
			return file
		match loop_name:
			"prop_engine": _streams[key] = _prop_loop(44.0, 22.0, 0.35)
			"prop_boost": _streams[key] = _prop_loop(66.0, 33.0, 0.6)
			"jet_engine": _streams[key] = _jet_loop(0.18, 40.0, 0.06)
			"jet_boost": _streams[key] = _jet_loop(0.035, 30.0, 0.0)
			"wind": _streams[key] = _to_wav(_normalize(_seamless_noise(2 * RATE, 0.06, 7), 0.5), true)
			"amb_birds": _streams[key] = _birds_loop()
			"amb_city": _streams[key] = _murmur_loop()
			"amb_waves": _streams[key] = _waves_loop()
			"amb_rumble": _streams[key] = _to_wav(_normalize(_seamless_noise(4 * RATE, 0.012, 11), 0.7), true)
			"amb_wind": _streams[key] = _gust_loop()
			"amb_cave": _streams[key] = _cave_loop()
			"amb_rain": _streams[key] = _to_wav(_normalize(_seamless_noise(3 * RATE, 0.55, 23), 0.28), true)  # a soft shower hiss
	return _streams[key]


## Birdsong: little chirps (quick rising and falling whistles) scattered over
## a 6 s loop.
func _birds_loop() -> AudioStreamWAV:
	var count := 6 * RATE
	var buf := PackedFloat32Array()
	buf.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for c in 16:
		var start := rng.randi_range(0, count - RATE / 2)
		var f0 := rng.randf_range(2200.0, 3600.0)
		var notes := rng.randi_range(1, 3)
		for n in notes:
			var n_len := int(RATE * rng.randf_range(0.05, 0.11))
			var s0 := start + n * int(RATE * 0.13)
			var up := rng.randf() < 0.5
			for i in n_len:
				if s0 + i >= count:
					break
				var k := float(i) / n_len
				var f := f0 * (1.0 + (k if up else 1.0 - k) * 0.35)
				buf[s0 + i] += sin(TAU * f * float(i) / RATE) * sin(PI * k) * 0.5
	return _to_wav(_normalize(buf, 0.5), true)


## The city's murmur: soft, low noise rising and falling like voices and
## traffic far off.
func _murmur_loop() -> AudioStreamWAV:
	var count := 4 * RATE
	var noise := _seamless_noise(count, 0.05, 13)
	var buf := PackedFloat32Array()
	buf.resize(count)
	for i in count:
		var t := float(i) / count
		buf[i] = noise[i] * (0.7 + 0.3 * sin(TAU * t * 2.0) * sin(TAU * t * 3.0))
	return _to_wav(_normalize(buf, 0.6), true)


## Waves on the shore: a wash of noise swelling in and drawing back.
func _waves_loop() -> AudioStreamWAV:
	var count := 6 * RATE
	var noise := _seamless_noise(count, 0.25, 17)
	var buf := PackedFloat32Array()
	buf.resize(count)
	for i in count:
		var t := float(i) / count
		var swell := pow(0.5 + 0.5 * sin(TAU * t * 2.0 - PI * 0.5), 2.0)
		buf[i] = noise[i] * (0.15 + swell)
	return _to_wav(_normalize(buf, 0.6), true)


## Wind in the trees: airy noise with slow gusts.
func _gust_loop() -> AudioStreamWAV:
	var count := 6 * RATE
	var noise := _seamless_noise(count, 0.1, 19)
	var buf := PackedFloat32Array()
	buf.resize(count)
	for i in count:
		var t := float(i) / count
		buf[i] = noise[i] * (0.35 + 0.65 * pow(0.5 + 0.5 * sin(TAU * t + 1.0), 3.0))
	return _to_wav(_normalize(buf, 0.55), true)


## The dragon's cave: water dripping (bright plinks) and a slow, sleepy
## snore (a low rumble breathing in and out) in an 8 s loop.
func _cave_loop() -> AudioStreamWAV:
	var count := 8 * RATE
	var buf := PackedFloat32Array()
	buf.resize(count)
	var noise := _seamless_noise(count, 0.03, 23)
	for i in count:
		var t := float(i) / RATE
		var breath := maxf(sin(TAU * t / 4.0), 0.0)
		buf[i] = noise[i] * 3.0 * breath * breath + 0.15 * sin(TAU * 55.0 * t) * breath
	var rng := RandomNumberGenerator.new()
	rng.seed = 29
	for d in 7:
		var s0 := rng.randi_range(0, count - RATE / 4)
		var f := rng.randf_range(1200.0, 1900.0)
		for i in RATE / 5:
			var k := float(i) / (RATE / 5)
			buf[s0 + i] += sin(TAU * f * (1.0 + k * 0.6) * float(i) / RATE) * exp(-k * 9.0) * 0.6
	return _to_wav(_normalize(buf, 0.6), true)


## Piston engine: soft harmonic rumble at the firing rate, pulsed by the
## propeller blades ("wub-wub"), with a little air noise on top.
func _prop_loop(fire_hz: float, blade_hz: float, noise_amount: float) -> AudioStreamWAV:
	var count := RATE
	var noise := _seamless_noise(count, 0.12, 3)
	var buf := PackedFloat32Array()
	buf.resize(count)
	for i in count:
		var t := float(i) / RATE
		var s := 0.0
		for h in 4:
			s += [1.0, 0.55, 0.3, 0.15][h] * sin(TAU * fire_hz * (h + 1) * t + h * 0.7)
		s *= 0.6 + 0.4 * (0.5 + 0.5 * sin(TAU * blade_hz * t))
		buf[i] = s * 0.4 + noise[i] * noise_amount * 4.0
	return _to_wav(_normalize(buf, 0.8), true)


## Turbine: airy whoosh (filtered noise) over a low rumble and a faint whine.
## smooth: lower = darker, rumblier noise (afterburner).
func _jet_loop(smooth: float, rumble_hz: float, whine: float) -> AudioStreamWAV:
	var count := RATE
	var noise := _seamless_noise(count, smooth, 5)
	var buf := PackedFloat32Array()
	buf.resize(count)
	for i in count:
		var t := float(i) / RATE
		buf[i] = noise[i] * 3.0 + 0.3 * sin(TAU * rumble_hz * t) + whine * sin(TAU * 880.0 * t)
	return _to_wav(_normalize(buf, 0.8), true)


## Low-passed noise whose end cross-fades into its start (loops cleanly).
func _seamless_noise(count: int, smooth: float, seed: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var fade := RATE / 10
	var raw := PackedFloat32Array()
	raw.resize(count + fade)
	var v := 0.0
	for i in raw.size():
		v = lerpf(v, rng.randf_range(-1.0, 1.0), smooth)
		raw[i] = v
	var buf := raw.slice(0, count)
	for i in fade:
		var k := float(i) / fade
		buf[i] = lerpf(raw[count + i], raw[i], k)
	return buf


func _normalize(buf: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0001
	for x in buf:
		m = maxf(m, absf(x))
	for i in buf.size():
		buf[i] *= peak / m
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
