extends RefCounted

## Procedurally composed music, so the prototype needs no audio files (like sfx.gd).
##
## The title theme: eurobeat with a fantasy streak, in A minor (harmonic minor, for the
## E major chord's G#) at 156 BPM. A 16-bar loop over Am - F - G - E: a four-on-the-
## floor kick, offbeat hats, claps on 2 and 4, the eurobeat octave-bouncing bass, a
## soft choir-ish pad, harp-like arpeggios, and in the second half a detuned supersaw
## lead with the melody (and a clap fill leading back round).
##
## Rendering takes a few seconds in GDScript, so call title_theme() from a thread
## (title_screen.gd does); the result is cached.

const RATE := 22050
const BPM := 156.0
const STEP := 60.0 / BPM / 4.0 # A 16th note, in seconds.
const BARS := 16

# One chord per bar, repeating every 4 bars: [bass root (MIDI), pad chord tones].
const CHORDS := [
	[45, [57, 60, 64]], # Am
	[41, [53, 57, 60]], # F
	[43, [55, 59, 62]], # G
	[40, [56, 59, 64]], # E (G# from harmonic minor)
]
# The lead melody over 8 bars, in 8th notes: MIDI notes, HOLD to keep the previous
# note sounding, REST for silence.
const HOLD := -1
const REST := -2
const MELODY := [
	81, HOLD, 76, 81, 83, 84, 83, 81,
	84, HOLD, 81, 84, 86, 88, 86, 84,
	83, HOLD, 79, 83, 86, HOLD, 84, 83,
	80, HOLD, 76, 80, 83, HOLD, 80, 76,
	81, HOLD, 84, 88, 86, 84, 83, 84,
	81, HOLD, 77, 81, 84, HOLD, 81, 84,
	86, 84, 83, 81, 79, 81, 83, 86,
	88, HOLD, HOLD, 83, 80, HOLD, 76, REST,
]

static var _title: AudioStreamWAV
static var _length := 0
static var _rng := RandomNumberGenerator.new()


## The looping title theme (rendered on first call).
static func title_theme() -> AudioStreamWAV:
	if _title == null:
		_title = _render_title()
	return _title


static func _render_title() -> AudioStreamWAV:
	_rng.seed = 7
	_length = int(BARS * 16 * STEP * RATE)
	var mix := PackedFloat32Array()
	mix.resize(_length)
	for bar in BARS:
		var chord: Array = CHORDS[bar % 4]
		var bar_start := bar * 16
		var lead_section := bar >= 8
		# Drums.
		for beat in 4:
			_kick(mix, _at(bar_start + beat * 4))
			_hat(mix, _at(bar_start + beat * 4 + 2))
			if beat % 2 == 1:
				_clap(mix, _at(bar_start + beat * 4), 0.32)
		if bar == BARS - 1: # A fill into the loop point.
			for s in [12, 13, 14, 15]:
				_clap(mix, _at(bar_start + s), 0.14 + 0.05 * (s - 12))
		# Octave bass in 8ths.
		for eighth in 8:
			_bass(mix, _at(bar_start + eighth * 2), chord[0] + (12 if eighth % 2 == 1 else 0))
		# Pad, all bar.
		for tone in chord[1]:
			_pad(mix, _at(bar_start), 16 * STEP, tone)
		# Harp arpeggio up and down two octaves in 16ths (quieter under the lead).
		var tones: Array = chord[1]
		var arp := [tones[0], tones[1], tones[2], tones[0] + 12, tones[1] + 12, tones[2] + 12, tones[0] + 24, tones[2] + 12]
		for s in 16:
			_harp(mix, _at(bar_start + s), arp[s % 8] + 12, 0.07 if lead_section else 0.11)
	# The lead, over the second 8 bars.
	var i := 0
	while i < MELODY.size():
		var note: int = MELODY[i]
		var length := 1
		while i + length < MELODY.size() and MELODY[i + length] == HOLD:
			length += 1
		if note >= 0:
			_lead(mix, _at(8 * 16 + i * 2), length * 2 * STEP, note)
		i += length
	# Master: normalize, then a touch of saturation.
	var peak := 0.0
	for x in mix:
		peak = maxf(peak, absf(x))
	var data := PackedByteArray()
	data.resize(_length * 2)
	for j in _length:
		var x := tanh(mix[j] / peak * 1.3) / tanh(1.3) * 0.85
		data.encode_s16(j * 2, int(x * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = _length
	return wav


## The sample index of 16th step `step`.
static func _at(step: int) -> int:
	return int(step * STEP * RATE)


static func _hz(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


## Adds `value` at `index`, wrapping past the end so tails ring into the loop's start.
static func _put(mix: PackedFloat32Array, index: int, value: float) -> void:
	mix[index % _length] += value


static func _kick(mix: PackedFloat32Array, start: int) -> void:
	var phase := 0.0
	for i in int(0.22 * RATE):
		var t := float(i) / RATE
		phase += TAU * (45.0 + 110.0 * exp(-t * 30.0)) / RATE
		_put(mix, start + i, sin(phase) * exp(-t * 11.0) * 0.95)


static func _clap(mix: PackedFloat32Array, start: int, volume: float) -> void:
	var low := 0.0
	for i in int(0.16 * RATE):
		var t := float(i) / RATE
		var noise := _rng.randf_range(-1.0, 1.0)
		low += 0.45 * (noise - low)
		# Three quick bursts, like hands not quite together.
		var bursts := 1.0 if t > 0.02 or fmod(t, 0.007) < 0.004 else 0.3
		_put(mix, start + i, low * exp(-t * 20.0) * bursts * volume)


static func _hat(mix: PackedFloat32Array, start: int) -> void:
	var last := 0.0
	for i in int(0.05 * RATE):
		var t := float(i) / RATE
		var noise := _rng.randf_range(-1.0, 1.0)
		_put(mix, start + i, (noise - last) * exp(-t * 70.0) * 0.1)
		last = noise


## A plucky saw bass: a low-pass filter that snaps shut.
static func _bass(mix: PackedFloat32Array, start: int, note: int) -> void:
	var freq := _hz(note)
	var phase := 0.0
	var low := 0.0
	for i in int(STEP * 1.8 * RATE):
		var t := float(i) / RATE
		phase = fmod(phase + freq / RATE, 1.0)
		var saw := phase * 2.0 - 1.0
		low += (0.06 + 0.4 * exp(-t * 25.0)) * (saw - low)
		_put(mix, start + i, low * exp(-t * 5.0) * 0.32)


## A soft, breathy choir-like pad tone with a slow swell and a little vibrato.
static func _pad(mix: PackedFloat32Array, start: int, duration: float, note: int) -> void:
	var freq := _hz(note)
	var phase := 0.0
	var count := int(duration * RATE)
	for i in count:
		var t := float(i) / RATE
		phase += TAU * freq * (1.0 + 0.004 * sin(TAU * 5.0 * t)) / RATE
		var env := minf(t / 0.25, 1.0) * minf((duration - t) / 0.2, 1.0)
		_put(mix, start + i, (sin(phase) + 0.3 * sin(2.0 * phase) + 0.12 * sin(3.0 * phase)) * env * 0.045)


## A harp / bell pluck.
static func _harp(mix: PackedFloat32Array, start: int, note: int, volume: float) -> void:
	var freq := _hz(note)
	var w := TAU * freq / RATE
	for i in int(0.3 * RATE):
		var t := float(i) / RATE
		var x := sin(w * i) + 0.35 * sin(2.0 * w * i) * exp(-t * 8.0) + 0.15 * sin(3.01 * w * i) * exp(-t * 14.0)
		_put(mix, start + i, x * exp(-t * 9.0) * volume)


## The eurobeat lead: three detuned saws through a gentle low-pass, with vibrato on
## longer notes.
static func _lead(mix: PackedFloat32Array, start: int, duration: float, note: int) -> void:
	var freq := _hz(note)
	var phases := [0.0, 0.33, 0.66]
	var detune := [1.0, 1.006, 0.994]
	var low := 0.0
	var count := int((duration + 0.05) * RATE)
	for i in count:
		var t := float(i) / RATE
		var vibrato := 1.0 + (0.006 * sin(TAU * 6.0 * t) if t > 0.15 else 0.0)
		var saw := 0.0
		for v in 3:
			phases[v] = fmod(phases[v] + freq * detune[v] * vibrato / RATE, 1.0)
			saw += phases[v] * 2.0 - 1.0
		low += 0.3 * (saw / 3.0 - low)
		var env := minf(t / 0.005, 1.0) * (0.75 + 0.25 * exp(-t * 10.0))
		if t > duration:
			env *= maxf(1.0 - (t - duration) / 0.05, 0.0)
		_put(mix, start + i, low * env * 0.2)
