extends RefCounted

## Procedurally generated sound effects, so the prototype needs no audio files.
## Usage: `const Sfx = preload("res://scenes/audio/sfx.gd")`, then `Sfx.play(self, "hit")`.
## Each sound is synthesized once and cached.

const RATE := 32000
const REVERB_BUS := &"SfxReverb"

# name -> [volume_db, use_reverb]
const SOUNDS := {
	"swing": [-12.0, false],
	"hit": [-5.0, false],
	"heavy_hit": [0.0, false],
	"tp": [-8.0, true],
	"shatter": [-14.0, true],
	"ding": [-6.0, true],
	"heavy_slash": [0.0, false],
	"menu_cursor": [-16.0, false],
	"menu_confirm": [-12.0, false],
	"menu_cancel": [-13.0, false],
	"player_hit": [-3.0, false],
	"fireball": [-12.0, false],
	"fizzle": [-11.0, false],
	"thunder": [-10.0, true],
	"enemy_die": [-8.0, false],
	"rain": [-20.0, false], # A loop: play it with play_loop().
	"slam": [-4.0, false],
	"spike_tip": [-14.0, false],
	"spike": [-8.0, false],
	"lightning": [-3.0, true],
}

static var _cache := {}


static func play(context: Node, sound: String) -> void:
	var settings: Array = SOUNDS[sound]
	var player := AudioStreamPlayer.new()
	player.stream = _get_stream(sound)
	player.volume_db = settings[0]
	if settings[1]:
		player.bus = _reverb_bus()
	context.get_tree().current_scene.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func _get_stream(sound: String) -> AudioStreamWAV:
	if not _cache.has(sound):
		var samples: PackedFloat32Array
		match sound:
			"swing": samples = _swing()
			"hit": samples = _hit()
			"heavy_hit": samples = _heavy_hit()
			"tp": samples = _tp()
			"shatter": samples = _shatter()
			"ding": samples = _ding()
			"heavy_slash": samples = _heavy_slash()
			"menu_cursor": samples = _blips([[1760.0, 0.025]], 1.0)
			"menu_confirm": samples = _blips([[988.0, 0.05], [1319.0, 0.11]], 1.0)
			"menu_cancel": samples = _blips([[784.0, 0.06], [523.0, 0.11]], 0.55)
			"player_hit": samples = _player_hit()
			"fireball": samples = _fireball()
			"fizzle": samples = _fizzle()
			"thunder": samples = _thunder()
			"enemy_die": samples = _enemy_die()
			"rain": samples = _rain()
			"slam": samples = _slam()
			"spike_tip": samples = _spike_tip()
			"spike": samples = _spike()
			"lightning": samples = _lightning()
		_cache[sound] = _to_wav(samples)
	return _cache[sound]


## Plays a sound on a loop (e.g. rain) from a player added under `parent`, and
## returns the player so it can be stopped.
static func play_loop(parent: Node, sound: String) -> AudioStreamPlayer:
	var stream: AudioStreamWAV = _get_stream(sound).duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = SOUNDS[sound][0]
	parent.add_child(player)
	player.play()
	return player


## Creates (once) an audio bus with a reverb effect that feeds into Master.
static func _reverb_bus() -> StringName:
	if AudioServer.get_bus_index(REVERB_BUS) == -1:
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, REVERB_BUS)
		AudioServer.set_bus_send(index, &"Master")
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.75
		reverb.damping = 0.4
		reverb.wet = 0.35
		reverb.dry = 0.9
		AudioServer.add_bus_effect(index, reverb)
	return REVERB_BUS


# --- Synthesis -------------------------------------------------------------

## A short whoosh: noise through a low-pass filter whose cutoff swells and fades.
static func _swing() -> PackedFloat32Array:
	var rng := _rng(1)
	var samples := _silence(0.16)
	var filtered := 0.0
	for i in samples.size():
		var p := float(i) / samples.size()
		var swell := sin(PI * p)
		filtered += (0.04 + 0.3 * swell) * (rng.randf_range(-1.0, 1.0) - filtered)
		samples[i] = filtered * swell * swell * 1.6
	return samples


## A punchy thwack: a quick downward pitch drop with a noise click on top.
static func _hit() -> PackedFloat32Array:
	var rng := _rng(2)
	var samples := _silence(0.14)
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		phase += TAU * (70.0 + 150.0 * exp(-40.0 * t)) / RATE
		samples[i] = sin(phase) * exp(-25.0 * t) * 0.7
		samples[i] += rng.randf_range(-1.0, 1.0) * exp(-180.0 * t) * 0.5
	return samples


## A heavier, longer, slightly distorted impact for Downward Slash.
static func _heavy_hit() -> PackedFloat32Array:
	var rng := _rng(3)
	var samples := _silence(0.4)
	var phase := 0.0
	var rumble := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		phase += TAU * (40.0 + 120.0 * exp(-18.0 * t)) / RATE
		rumble += 0.08 * (rng.randf_range(-1.0, 1.0) - rumble)
		var x := sin(phase) * exp(-9.0 * t) * 1.0
		x += rng.randf_range(-1.0, 1.0) * exp(-70.0 * t) * 0.8
		x += rumble * exp(-12.0 * t) * 1.5
		samples[i] = tanh(x * 1.8) * 0.85
	return samples


## A short rising shimmer: gliding chime partials with a fast tremolo.
static func _tp() -> PackedFloat32Array:
	var rng := _rng(4)
	var samples := _silence(0.45)
	var partials := [660.0, 990.0, 1320.0, 1980.0]
	var phases := [0.0, 0.0, 0.0, 0.0]
	for i in samples.size():
		var t := float(i) / RATE
		var p := float(i) / samples.size()
		var envelope := minf(t / 0.03, 1.0) * pow(1.0 - p, 2.0)
		var tremolo := 0.75 + 0.25 * sin(TAU * 22.0 * t)
		var x := 0.0
		for k in partials.size():
			phases[k] += TAU * partials[k] * (1.0 + 0.5 * p) / RATE
			x += sin(phases[k]) / (k + 1.0)
		samples[i] = x * envelope * tremolo * 0.35
	# A few soft sparkles scattered across the sound.
	for sparkle in 8:
		var start := rng.randi_range(0, samples.size() / 2)
		var freq := rng.randf_range(3000.0, 5000.0)
		for i in range(start, mini(samples.size(), start + int(RATE * 0.08))):
			var t := float(i - start) / RATE
			samples[i] += sin(TAU * freq * t) * exp(-50.0 * t) * 0.08
	return samples


## A glass shatter: a thump and a noisy crack, then a spray of short high pings.
static func _shatter() -> PackedFloat32Array:
	var rng := _rng(7)
	var samples := _silence(0.8)
	var count := samples.size()
	for i in int(RATE * 0.2):
		var t := float(i) / RATE
		samples[i] += sin(TAU * 90.0 * t) * exp(-25.0 * t) * 0.6
	var crack_length := int(RATE * 0.08)
	for i in crack_length:
		var envelope := 1.0 - float(i) / crack_length
		samples[i] += rng.randf_range(-1.0, 1.0) * envelope * envelope * 0.7
	for shard in 45:
		var start := int(pow(rng.randf(), 2.0) * count * 0.55)
		var freq := rng.randf_range(2500.0, 8000.0)
		var decay := rng.randf_range(25.0, 60.0)
		var amp := rng.randf_range(0.08, 0.25)
		for i in range(start, mini(count, start + int(RATE * 0.15))):
			var t := float(i - start) / RATE
			samples[i] += sin(TAU * freq * t) * exp(-decay * t) * amp
	return samples


## A clear, bright bell: a high fundamental plus inharmonic overtones that die away faster.
static func _ding() -> PackedFloat32Array:
	var samples := _silence(0.9)
	var partials := [[1568.0, 1.0, 4.0], [1568.0 * 2.76, 0.4, 7.0], [1568.0 * 5.4, 0.2, 12.0]]
	for i in samples.size():
		var t := float(i) / RATE
		var x := 0.0
		for partial in partials:
			x += sin(TAU * partial[0] * t) * partial[1] * exp(-partial[2] * t)
		samples[i] = x * minf(t / 0.002, 1.0) * 0.3
	return samples


## The heavy impact plus a metallic ring and a sharp swish, for a big sword hit.
static func _heavy_slash() -> PackedFloat32Array:
	var rng := _rng(5)
	var samples := _heavy_hit()
	var ring := [820.0, 1310.0, 1975.0, 2840.0]
	var filtered := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		var x := samples[i]
		for freq in ring:
			x += sin(TAU * freq * t) * exp(-9.0 * t) * 0.1
		filtered += 0.5 * (rng.randf_range(-1.0, 1.0) - filtered)
		x += filtered * exp(-30.0 * t) * 0.5
		samples[i] = clampf(x, -1.0, 1.0)
	return samples


## Menu sounds in the style of old JRPGs: a sequence of short, slightly buzzy tones
## ([frequency, seconds] each). `fall_off` scales each successive tone's volume
## (below 1 for a decrescendo).
static func _blips(tones: Array, fall_off: float) -> PackedFloat32Array:
	var lengths: Array[int] = []
	var total := 0
	for tone in tones:
		lengths.append(int(RATE * tone[1]))
		total += lengths[-1]
	var samples := PackedFloat32Array()
	samples.resize(total)
	var start := 0
	var amp := 0.5
	for k in tones.size():
		var tone: Array = tones[k]
		var length := lengths[k]
		for i in length:
			var t := float(i) / RATE
			var envelope := minf(t / 0.003, 1.0) * exp(-6.0 * t / tone[1])
			var x := sin(TAU * tone[0] * t) + 0.3 * sin(TAU * tone[0] * 3.0 * t)
			samples[start + i] = x * envelope * amp
		start += length
		amp *= fall_off
	return samples


## A dull body thump with a short, rough grunt.
static func _player_hit() -> PackedFloat32Array:
	var rng := _rng(11)
	var samples := _silence(0.3)
	var phase := 0.0
	var rough := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		phase += TAU * (55.0 + 90.0 * exp(-30.0 * t)) / RATE
		var x := sin(phase) * exp(-14.0 * t) * 0.9
		rough += 0.3 * (rng.randf_range(-1.0, 1.0) - rough)
		x += rough * sin(TAU * 140.0 * t) * exp(-10.0 * t) * 0.6 # The grunt.
		samples[i] = tanh(x * 1.5)
	return samples


## A short crackling whoosh.
static func _fireball() -> PackedFloat32Array:
	var rng := _rng(12)
	var samples := _silence(0.25)
	var filtered := 0.0
	for i in samples.size():
		var p := float(i) / samples.size()
		filtered += (0.08 + 0.25 * p) * (rng.randf_range(-1.0, 1.0) - filtered)
		var crackle := rng.randf_range(-1.0, 1.0) if rng.randf() < 0.04 else 0.0
		samples[i] = (filtered * 1.4 + crackle * 0.4) * sin(PI * p)
	return samples


## A quick hiss that dies away.
static func _fizzle() -> PackedFloat32Array:
	var rng := _rng(13)
	var samples := _silence(0.35)
	var last := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		samples[i] = (noise - last) * exp(-9.0 * t) * 0.45 # High-passed: hissy.
		last = noise
	return samples


## Distant thunder: a muffled crack, then a long, deep rumble that rolls (swelling
## and easing off a few times) as it fades.
static func _thunder() -> PackedFloat32Array:
	var rng := _rng(14)
	var count := int(3.6 * RATE)
	var rumble := PackedFloat32Array()
	var crack := PackedFloat32Array()
	rumble.resize(count)
	crack.resize(count)
	var a := 0.0
	var b := 0.0
	var c := 0.0
	var k := 0.0
	var roll := 0.6
	var roll_target := 1.0
	for i in count:
		var t := float(i) / RATE
		# Three low-pass stages: only the deepest part of the noise is left.
		a += 0.01 * (rng.randf_range(-1.0, 1.0) - a)
		b += 0.025 * (a - b)
		c += 0.025 * (b - c)
		if i % int(0.3 * RATE) == 0:
			roll_target = rng.randf_range(0.3, 1.0)
		roll += 0.0003 * (roll_target - roll)
		rumble[i] = c * roll * minf(t / 0.3, 1.0) * exp(-0.8 * t)
		k += 0.12 * (rng.randf_range(-1.0, 1.0) - k) # Muffled: low-passed, not a hiss.
		crack[i] = k * exp(-22.0 * t)
	_normalize(rumble)
	_normalize(crack)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		samples[i] = tanh(1.8 * (rumble[i] * 0.9 + crack[i] * 0.25)) / tanh(1.8) # A little grit.
	return samples


static func _normalize(samples: PackedFloat32Array) -> void:
	var peak := 0.0
	for x in samples:
		peak = maxf(peak, absf(x))
	if peak > 0.0:
		for i in samples.size():
			samples[i] /= peak


## A mole slamming the ground: a deep thump with a rattle of dirt.
static func _slam() -> PackedFloat32Array:
	var rng := _rng(16)
	var samples := _silence(0.6)
	var phase := 0.0
	var dirt := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		phase += TAU * (32.0 + 70.0 * exp(-14.0 * t)) / RATE
		dirt += 0.06 * (rng.randf_range(-1.0, 1.0) - dirt)
		var x := sin(phase) * exp(-6.0 * t) * 1.2
		x += dirt * exp(-7.0 * t) * 2.5
		samples[i] = tanh(x * 1.6) * 0.9
	return samples


## Earth cracking as a spike's point pokes out: a few quiet, gritty ticks.
static func _spike_tip() -> PackedFloat32Array:
	var rng := _rng(17)
	var samples := _silence(0.18)
	var grit := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		grit += 0.3 * (rng.randf_range(-1.0, 1.0) - grit)
		var ticks := 1.0 if fmod(t, 0.045) < 0.006 else 0.25
		samples[i] = grit * ticks * exp(-10.0 * t) * 1.4
	return samples


## A spike bursting out of the ground: a crunchy crack with a low punch.
static func _spike() -> PackedFloat32Array:
	var rng := _rng(18)
	var samples := _silence(0.35)
	var phase := 0.0
	var crunch := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		phase += TAU * (60.0 + 160.0 * exp(-30.0 * t)) / RATE
		crunch += 0.35 * (rng.randf_range(-1.0, 1.0) - crunch)
		var x := sin(phase) * exp(-14.0 * t) * 0.9
		x += crunch * exp(-16.0 * t) * 1.6
		samples[i] = tanh(x * 1.5) * 0.85
	return samples


## A lightning strike up close: a split-second electric crackle, a huge crack, and
## a short, heavy rumble.
static func _lightning() -> PackedFloat32Array:
	var rng := _rng(19)
	var samples := _silence(1.4)
	var low := 0.0
	var lower := 0.0
	var last := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low += 0.03 * (noise - low)
		lower += 0.04 * (low - lower)
		var crackle := (noise - last) * (1.0 if rng.randf() < 0.3 else 0.0) * exp(-30.0 * t) * 0.8
		last = noise
		var crack := noise * exp(-18.0 * t) * 0.9
		var rumble := lower * 14.0 * minf(t / 0.05, 1.0) * exp(-2.8 * t)
		samples[i] = tanh((crackle + crack + rumble) * 1.6) * 0.9
	return samples


## A soft descending poof.
static func _enemy_die() -> PackedFloat32Array:
	var rng := _rng(15)
	var samples := _silence(0.45)
	var phase := 0.0
	var filtered := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		phase += TAU * (420.0 * exp(-5.0 * t) + 80.0) / RATE
		filtered += 0.15 * (rng.randf_range(-1.0, 1.0) - filtered)
		samples[i] = (sin(phase) * 0.5 + filtered * 0.8) * exp(-6.0 * t)
	return samples


## Two seconds of steady rain, built to loop seamlessly.
static func _rain() -> PackedFloat32Array:
	var rng := _rng(16)
	var samples := _silence(2.0)
	var filtered := 0.0
	for i in samples.size():
		filtered += 0.35 * (rng.randf_range(-1.0, 1.0) - filtered)
		var drop := rng.randf_range(-1.0, 1.0) * 0.6 if rng.randf() < 0.002 else 0.0
		samples[i] = filtered * 0.5 + drop
	return samples


static func _silence(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * seconds))
	return samples


## Seeded so every sound is identical from run to run.
static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
