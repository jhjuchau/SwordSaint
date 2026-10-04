extends RefCounted

## Dogood's body sprites: a barrel-chested, shirtless wrestler-statesman. Bald on top
## with long grey-brown hair down the back, little round gold spectacles (which glint),
## a gold championship belt, red tights with knee pads, black laced boots and taped
## wrists. His red cape is the shared cape layer (player_cloak.gd, style "dogood").
##
## Same rig and frame layout as the Sword Saint (player_sprites.gd, whose skeleton
## maths and drawing helpers this reuses): 64x64 frames facing right, feet on row 59,
## shown at ORIGIN_OFFSET. Unlike the Saint's, his head is drawn in its own rotated
## frame, so it turns with his spine when he arches, bridges or lies on his back.
##
## Pose keys: the Saint's hip, lean, torso, front_foot / back_foot, front_hand /
## back_hand, front_elbow / back_elbow ("up"), arm_in_front, mirror; plus
##   front_grip / back_grip: "fist" (default), "chop" (flat open hand) or "open"
##   head_tilt: degrees the head tips forward (+) or back (-) from the spine
##   face: "calm" (default), "grit" (teeth bared) or "shout"
##   glint: the spectacles flash

const P = preload("res://scenes/player_sprites.gd")

const SIZE := 64
const ORIGIN_OFFSET := P.ORIGIN_OFFSET
const HIP := P.HIP
const BACK_ANKLE := P.BACK_ANKLE
const FRONT_ANKLE := P.FRONT_ANKLE
const THIGH := 8.0
const SHIN := 8.2
const TORSO := 12.5
const UPPER_ARM := 7.2
const FOREARM := 7.0
const SELF_CLOAKED := []

const OUTLINE := P.OUTLINE
const SKIN := Color(0.93, 0.74, 0.6)
const SKIN_LIGHT := Color(1.0, 0.86, 0.74)
const SKIN_SHADE := Color(0.78, 0.56, 0.44)
const SKIN_DEEP := Color(0.62, 0.42, 0.33)
const HAIR := Color(0.6, 0.52, 0.44)
const HAIR_LIGHT := Color(0.76, 0.7, 0.62)
const BROW := Color(0.5, 0.44, 0.38)
const EYE := Color(0.1, 0.08, 0.1)
const LENS := Color(0.78, 0.92, 1.0)
const RIM := Color(0.9, 0.72, 0.28)
const MOUTH := Color(0.42, 0.14, 0.14)
const TEETH := Color(0.98, 0.97, 0.92)
const TIGHTS := Color(0.82, 0.12, 0.12)
const TIGHTS_SHADE := Color(0.58, 0.07, 0.08)
const STRIPE := Color(0.98, 0.84, 0.32)
const BELT := Color(0.88, 0.7, 0.22)
const BELT_LIGHT := Color(1.0, 0.92, 0.55)
const PAD := Color(0.16, 0.16, 0.2)
const BOOT := Color(0.09, 0.08, 0.1)
const LACE := Color(0.92, 0.92, 0.9)
const TAPE := Color(0.96, 0.95, 0.9)
const GLINT := Color(1, 1, 1)

static var _frames: SpriteFrames
static var _anchors := {}
static var _cape_shown := {} # animation -> Array of bools: false while he's lying or bridging.


static func frames() -> SpriteFrames:
	if _frames == null:
		_frames = SpriteFrames.new()
		_frames.remove_animation(&"default")
		var animations := _animations()
		for anim in animations:
			var spec: Array = animations[anim]
			_frames.add_animation(anim)
			_frames.set_animation_speed(anim, spec[0])
			_frames.set_animation_loop(anim, spec[1])
			var anchors: Array[Vector2] = []
			var shown: Array[bool] = []
			for pose in spec[2]:
				_frames.add_frame(anim, ImageTexture.create_from_image(draw(pose)))
				anchors.append(_cape_anchor(pose))
				shown.append(absf(pose.get("lean", 0.0)) < 70.0) # Hanging "down" would go through the floor.
			_anchors[StringName(anim)] = anchors
			_cape_shown[StringName(anim)] = shown
	return _frames


## Where the cape hangs from (the back of his neck) on `frame` of `animation`,
## relative to the sprite's origin, facing right.
static func anchor(animation: StringName, frame: int) -> Vector2:
	frames()
	var anchors: Array = _anchors.get(animation, [])
	if anchors.is_empty():
		return Vector2.ZERO
	return anchors[clampi(frame, 0, anchors.size() - 1)]


## Whether the cape layer shows on `frame` of `animation`.
static func cape_visible(animation: StringName, frame: int) -> bool:
	frames()
	var shown: Array = _cape_shown.get(animation, [])
	return shown.is_empty() or shown[clampi(frame, 0, shown.size() - 1)]


static func _keys(keys: Array, count: int) -> Array:
	return P._keyframes(keys, count)


static func _with(base: Dictionary, extra: Dictionary) -> Dictionary:
	return P._with(base, extra)


static func _mix(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	return P._lerp_pose(a, b, t)


# --- Animations ------------------------------------------------------------

## name -> [frames per second, loops, poses]
static func _animations() -> Dictionary:
	var anims := {}
	# His ready stance: a wide, low base, chest forward, fists up and loose.
	var stance := {"hip": Vector2(0, 2), "lean": 8.0, "front_foot": Vector2(5, 0), "back_foot": Vector2(-6, 0),
		"front_hand": Vector2(6, 1), "back_hand": Vector2(5, 4)}

	# Idle: big slow breaths, the chest swelling and the shoulders rolling.
	var idle := []
	for i in 12:
		var b := (1.0 - cos(TAU * i / 12.0)) * 0.5
		idle.append(_with(stance, {"hip": Vector2(0, 2.0 + b * 1.4), "torso": (1.0 - b) * 1.2, "lean": 8.0 - b * 2.0,
			"front_hand": Vector2(6, 1.0 + b * 1.2), "back_hand": Vector2(5, 4.0 + b * 0.8)}))
	anims["idle"] = [6.0, true, idle]

	# Run: a heavy, pounding charge, arms pumping with bent elbows.
	var run := []
	for i in P.RUN_FRAMES:
		var t := float(i) / P.RUN_FRAMES
		var pump := cos(TAU * t)
		run.append({"lean": 18.0, "hip": Vector2(2, 3.5 + 1.5 * cos(TAU * 2.0 * (t - 0.1))),
			"front_foot": P._run_foot(t) + Vector2(-2, 0), "back_foot": P._run_foot(fmod(t + 0.5, 1.0)) + Vector2(2, 0),
			"front_hand": Vector2(3.0 - 6.0 * pump, 3.0 - 3.0 * pump), "back_hand": Vector2(-1.0 + 6.0 * pump, 3.0 + 3.0 * pump)})
	anims["run"] = [P.RUN_FPS, true, run]

	# Jump: knees tucked, one fist thrown up to the sky.
	var jump := []
	for i in 4:
		var s := sin(TAU * i / 4.0)
		jump.append({"hip": Vector2(0, -2), "lean": -4.0 + s, "front_foot": Vector2(4, -8.0 + s), "back_foot": Vector2(-3, -6.0 - s),
			"front_hand": Vector2(5, -12.0 - s * 0.5), "front_elbow": "up", "arm_in_front": true,
			"back_hand": Vector2(-7, -3.0 + s), "back_elbow": "up"})
	anims["jump"] = [10.0, true, jump]

	# Fall: arms spread wide, legs bicycling.
	var fall := []
	for i in 8:
		var p := TAU * i / 8.0
		fall.append({"lean": -6.0 + sin(p), "hip": Vector2(0, -1),
			"front_hand": Vector2(10.0, -6.0 + sin(p)), "front_elbow": "up", "front_grip": "open",
			"back_hand": Vector2(-9.0, -7.0 - sin(p)), "back_elbow": "up", "back_grip": "open",
			"front_foot": Vector2(3.0 + sin(p) * 2.0, -4.0 - cos(p) * 2.0), "back_foot": Vector2(-3.0 - sin(p) * 2.0, -2.0 + cos(p))})
	anims["fall"] = [10.0, true, fall]

	# Land: a heavy, ground-shaking squat and back up.
	var land := []
	for d in [0.0, 5.0, 9.0, 10.0, 9.0, 6.0, 3.0, 1.0]:
		land.append(_with(stance, {"hip": Vector2(0, 2.0 + d), "lean": 8.0 + d * 2.0,
			"front_foot": Vector2(6, 0), "back_foot": Vector2(-7, 0),
			"front_hand": Vector2(7.0 + d * 0.3, 3.0 + d * 0.4), "back_hand": Vector2(6.0, 6.0 + d * 0.3)}))
	anims["land"] = [16.0, false, land]

	anims["reel"] = [12.0, false, _keys([
		{"hip": Vector2(-1, 3), "lean": -28.0, "head_tilt": -15.0, "front_hand": Vector2(6, -10), "front_elbow": "up",
			"front_grip": "open", "back_hand": Vector2(-9, -4), "back_grip": "open", "front_foot": Vector2(5, 0), "back_foot": Vector2(-6, 0), "face": "grit"},
		{"hip": Vector2(-1, 4), "lean": -16.0, "front_hand": Vector2(8, -3), "back_hand": Vector2(-8, 2),
			"front_foot": Vector2(5, 0), "back_foot": Vector2(-7, 0), "face": "grit"},
		_with(stance, {"hip": Vector2(0, 3)}),
	], 5)]

	# Dash: a lowered shoulder charge.
	anims["dash"] = [10.0, false, [
		{"lean": 30.0, "hip": Vector2(2, 4), "front_foot": Vector2(10, 0), "back_foot": Vector2(-10, 0),
			"front_hand": Vector2(3, 5), "back_hand": Vector2(-6, 4), "head_tilt": 10.0, "face": "grit"},
		{"lean": 32.0, "hip": Vector2(2, 5), "front_foot": Vector2(10, 0), "back_foot": Vector2(-11, -1),
			"front_hand": Vector2(3, 6), "back_hand": Vector2(-7, 4), "head_tilt": 10.0, "face": "grit"},
	]]

	anims["intro"] = [20.0, false, _intro(stance)]
	anims["charge"] = [6.0, true, [_with(stance, {"hip": Vector2(0, 4), "face": "grit"})]]

	# --- Combo moves ---
	anims["grab"] = [24.0, false, _keys([
		_with(stance, {"lean": 4.0, "front_hand": Vector2(4, 2), "back_hand": Vector2(3, 5)}),
		{"hip": Vector2(2, 5), "lean": 26.0, "front_foot": Vector2(10, 0), "back_foot": Vector2(-10, 0),
			"front_hand": Vector2(11, -2), "front_grip": "open", "back_hand": Vector2(12, 1), "back_grip": "open",
			"arm_in_front": true, "face": "grit"},
		{"hip": Vector2(2, 4), "lean": 20.0, "front_foot": Vector2(9, 0), "back_foot": Vector2(-9, 0),
			"front_hand": Vector2(9, -3), "front_grip": "open", "back_hand": Vector2(10, 0), "back_grip": "open",
			"arm_in_front": true, "face": "grit"},
	], 8)]

	var chop_wind := {"hip": Vector2(0, 2), "lean": -12.0, "head_tilt": -6.0, "front_foot": Vector2(4, 0), "back_foot": Vector2(-6, 0),
		"front_hand": Vector2(-7, -10), "front_elbow": "up", "front_grip": "chop", "back_hand": Vector2(7, 2)}
	var chop_hit := {"hip": Vector2(2, 4), "lean": 24.0, "head_tilt": 6.0, "front_foot": Vector2(9, 0), "back_foot": Vector2(-8, 0),
		"front_hand": Vector2(12, 2), "front_grip": "chop", "back_hand": Vector2(-6, 4), "face": "shout"}
	anims["chop"] = [25.0, false, [chop_wind, chop_wind, _mix(chop_wind, chop_hit, 0.5), chop_hit,
		_with(chop_hit, {"lean": 28.0, "front_hand": Vector2(10, 7)}), _with(chop_hit, {"lean": 27.0, "front_hand": Vector2(9, 8)}),
		_mix(chop_hit, stance, 0.4), _mix(chop_hit, stance, 0.7), stance, stance]]

	anims["suplex"] = [20.0, false, _suplex()]
	anims["ddt"] = [20.0, false, _ddt()]
	anims["dropkick"] = [20.0, false, _dropkick()]
	anims["kite"] = [20.0, false, _kite()]

	# --- "Why do you fight!?" ---
	var hold := {"hip": Vector2(0, 2), "lean": -4.0, "torso": 1.0, "front_foot": Vector2(7, 0), "back_foot": Vector2(-8, 0),
		"front_hand": Vector2(5, 7), "back_hand": Vector2(-4, 7), "face": "grit"}
	anims["why_enter"] = [20.0, false, _keys([
		stance,
		{"hip": Vector2(0, 5), "lean": 14.0, "front_foot": Vector2(7, 0), "back_foot": Vector2(-8, 0),
			"front_hand": Vector2(5, -1), "arm_in_front": true, "back_hand": Vector2(4, 1), "face": "grit"},
		{"hip": Vector2(0, 0), "lean": -10.0, "torso": 1.5, "front_foot": Vector2(7, 0), "back_foot": Vector2(-8, 0),
			"front_hand": Vector2(3, -16), "front_elbow": "up", "arm_in_front": true, "back_hand": Vector2(-5, 6), "face": "shout"},
		{"hip": Vector2(0, 0), "lean": -12.0, "torso": 1.5, "front_foot": Vector2(7, 0), "back_foot": Vector2(-8, 0),
			"front_hand": Vector2(3, -16), "front_elbow": "up", "arm_in_front": true, "back_hand": Vector2(-5, 6), "face": "shout", "glint": true},
		hold,
	], 14)]
	var why_hold := []
	for i in 4:
		var b := (1.0 - cos(TAU * i / 4.0)) * 0.5
		why_hold.append(_with(hold, {"torso": 0.6 + b * 0.8, "hip": Vector2(0, 2.0 + b * 0.6), "glint": i == 0}))
	anims["why_hold"] = [4.0, true, why_hold]
	anims["liberty"] = [20.0, false, _liberty()]
	anims["countrymen"] = [30.0, false, _countrymen()]
	anims["future"] = [20.0, false, _future()]

	# --- Real-time attacks (see player.gd's DOGOOD_ATTACKS for their timing) ---
	anims["big_boot"] = [20.0, false, _big_boot(stance)]
	anims["headbutt"] = [20.0, false, _headbutt(stance)]
	anims["flash_chop"] = [22.0, false, _flash_chop(stance)]
	return anims


## The Stagger Break intro (24 frames): fists drop to his sides, he slams them
## together in front of his chest, then rises into a double-biceps flex, chest out,
## and his spectacles flash.
static func _intro(stance: Dictionary) -> Array:
	var low := {"hip": Vector2(0, 4), "lean": 6.0, "front_foot": Vector2(6, 0), "back_foot": Vector2(-7, 0),
		"front_hand": Vector2(3, 10), "back_hand": Vector2(-2, 10)}
	var clap := {"hip": Vector2(0, 5), "lean": 14.0, "front_foot": Vector2(6, 0), "back_foot": Vector2(-7, 0),
		"front_hand": Vector2(8, 2), "back_hand": Vector2(9, 3), "arm_in_front": true, "face": "grit"}
	var flex := {"hip": Vector2(0, 1), "lean": -6.0, "torso": 1.6, "front_foot": Vector2(7, 0), "back_foot": Vector2(-8, 0),
		"front_hand": Vector2(4, -9), "front_elbow": "up", "back_hand": Vector2(-4, -9), "back_elbow": "up", "face": "grit"}
	var frames := _keys([stance, low], 4)
	frames.append_array(_keys([low, clap, clap], 4))
	frames.append_array(_keys([clap, _with(flex, {"torso": 2.2, "hip": Vector2(0, 0)}), flex], 6))
	for i in 10:
		var pulse := 0.5 + 0.5 * sin(i * 1.3)
		frames.append(_with(flex, {"torso": 1.3 + pulse * 0.6, "glint": i >= 3 and i <= 5}))
	return frames


## German Suplex (20 frames, 1 s): waist lock, lift, arch over backward into a high
## bridge, holding it through the slam, then rolling back up to his feet.
static func _suplex() -> Array:
	var lock := {"hip": Vector2(0, 4), "lean": 20.0, "front_foot": Vector2(7, 0), "back_foot": Vector2(-6, 0),
		"front_hand": Vector2(10, 3), "front_grip": "open", "back_hand": Vector2(11, 4), "back_grip": "open", "arm_in_front": true, "face": "grit"}
	var lift := {"hip": Vector2(0, 7), "lean": 2.0, "front_foot": Vector2(6, 0), "back_foot": Vector2(-5, 0),
		"front_hand": Vector2(6, -5), "back_hand": Vector2(7, -4), "arm_in_front": true, "face": "shout"}
	var arch := {"hip": Vector2(3, 6), "lean": -55.0, "head_tilt": -20.0, "front_foot": Vector2(6, 0), "back_foot": Vector2(1, 0),
		"front_hand": Vector2(-2, -13), "front_elbow": "up", "back_hand": Vector2(-1, -12), "back_elbow": "up", "arm_in_front": true, "face": "shout"}
	var bridge := {"hip": Vector2(5, 1), "lean": -115.0, "head_tilt": -10.0, "front_foot": Vector2(5, 0), "back_foot": Vector2(1, 0),
		"front_hand": Vector2(-12, 3), "back_hand": Vector2(-11, 5), "arm_in_front": true, "face": "grit"}
	var sit_up := {"hip": Vector2(2, 12), "lean": -40.0, "front_foot": Vector2(9, 0), "back_foot": Vector2(5, 0),
		"front_hand": Vector2(-6, 8), "back_hand": Vector2(-7, 9)}
	var crouch := {"hip": Vector2(0, 7), "lean": 18.0, "front_foot": Vector2(6, 0), "back_foot": Vector2(-6, 0),
		"front_hand": Vector2(6, 6), "back_hand": Vector2(4, 8)}
	var frames := _keys([lock, lock, lift], 5)
	frames.append_array(_keys([_mix(lift, arch, 0.4), arch, _mix(arch, bridge, 0.6), bridge], 5))
	frames.append_array([bridge, bridge, _with(bridge, {"hip": Vector2(5, 2)}), bridge])
	frames.append_array(_keys([sit_up, crouch, _with(crouch, {"hip": Vector2(0, 3), "lean": 10.0})], 6))
	return frames


## Flying DDT (16 frames, 0.8 s): crouch, leap, hook the head under his arm at the
## top, then fall backward, driving it into the floor, and land flat on his back.
static func _ddt() -> Array:
	var crouch := {"hip": Vector2(0, 7), "lean": 22.0, "front_foot": Vector2(6, 0), "back_foot": Vector2(-6, 0),
		"front_hand": Vector2(-6, 5), "back_hand": Vector2(-8, 3), "face": "grit"}
	var leap := {"hip": Vector2(0, -3), "lean": 12.0, "front_foot": Vector2(6, -8), "back_foot": Vector2(-6, -3),
		"front_hand": Vector2(10, -7), "front_elbow": "up", "back_hand": Vector2(4, -2), "face": "shout"}
	var hook := {"hip": Vector2(0, -3), "lean": -8.0, "front_foot": Vector2(5, -9), "back_foot": Vector2(-2, -7),
		"front_hand": Vector2(7, -2), "arm_in_front": true, "back_hand": Vector2(8, 0), "face": "grit"}
	var drop := {"hip": Vector2(0, 3), "lean": -65.0, "head_tilt": 15.0, "front_foot": Vector2(10, -8), "back_foot": Vector2(7, -5),
		"front_hand": Vector2(5, -5), "arm_in_front": true, "back_hand": Vector2(6, -3), "face": "grit"}
	var flat := {"hip": Vector2(2, 12), "lean": -92.0, "head_tilt": 10.0, "front_foot": Vector2(13, 0), "back_foot": Vector2(10, 0),
		"front_hand": Vector2(-4, 4), "back_hand": Vector2(-6, 6)}
	var frames := _keys([crouch, crouch, leap], 4)
	frames.append_array(_keys([leap, hook, hook], 3))
	frames.append_array(_keys([hook, drop, _with(flat, {"hip": Vector2(2, 11), "front_foot": Vector2(12, -5)})], 4))
	frames.append_array([flat, flat, _with(flat, {"front_foot": Vector2(12, -2)}), flat, flat])
	return frames


## Dropkick (16 frames, 0.8 s): a hop, both boots thrust out with his body flat in
## the air, a fall onto his back, and a kip-up.
static func _dropkick() -> Array:
	var load := {"hip": Vector2(0, 6), "lean": 16.0, "front_foot": Vector2(5, 0), "back_foot": Vector2(-6, 0),
		"front_hand": Vector2(-5, 4), "back_hand": Vector2(-7, 3), "face": "grit"}
	var tuck := {"hip": Vector2(0, -5), "lean": -25.0, "front_foot": Vector2(6, -11), "back_foot": Vector2(4, -13),
		"front_hand": Vector2(-3, -6), "front_elbow": "up", "back_hand": Vector2(-6, -4), "face": "shout"}
	var kick := {"hip": Vector2(-2, -6), "lean": -82.0, "head_tilt": 20.0, "front_foot": Vector2(22, -24), "back_foot": Vector2(21, -20),
		"front_hand": Vector2(-3, 6), "back_hand": Vector2(-1, 8), "face": "shout"}
	var falling := {"hip": Vector2(-2, 4), "lean": -88.0, "head_tilt": 15.0, "front_foot": Vector2(16, -12), "back_foot": Vector2(14, -9),
		"front_hand": Vector2(-2, 7), "back_hand": Vector2(0, 8)}
	var back := {"hip": Vector2(0, 12), "lean": -95.0, "head_tilt": 10.0, "front_foot": Vector2(12, -2), "back_foot": Vector2(10, 0),
		"front_hand": Vector2(-3, 5), "back_hand": Vector2(-5, 6)}
	var kip := {"hip": Vector2(0, 10), "lean": -105.0, "head_tilt": 20.0, "front_foot": Vector2(-1, -14), "back_foot": Vector2(-3, -12),
		"front_hand": Vector2(-5, -5), "front_elbow": "up", "back_hand": Vector2(-6, -4), "back_elbow": "up"}
	var spring := {"hip": Vector2(0, 6), "lean": 14.0, "front_foot": Vector2(6, 0), "back_foot": Vector2(-6, 0),
		"front_hand": Vector2(6, 2), "back_hand": Vector2(4, 4), "face": "grit"}
	var frames := _keys([load, tuck], 3)
	frames.append_array([kick, kick, kick])
	frames.append_array(_keys([kick, falling, back], 4))
	frames.append_array([back, kip, kip])
	frames.append_array(_keys([spring, _with(spring, {"hip": Vector2(0, 2), "lean": 8.0})], 3))
	return frames


## Kite (12 frames, 0.6 s): crouching with the kite low behind him, he heaves it up
## into the storm and stands holding the string high.
static func _kite() -> Array:
	var low := {"hip": Vector2(0, 5), "lean": 14.0, "front_foot": Vector2(5, 0), "back_foot": Vector2(-6, 0),
		"front_hand": Vector2(-7, 5), "front_grip": "open", "back_hand": Vector2(-3, 6)}
	var heave := {"hip": Vector2(0, -1), "lean": -20.0, "front_foot": Vector2(4, 0), "back_foot": Vector2(-7, -2),
		"front_hand": Vector2(4, -15), "front_elbow": "up", "arm_in_front": true, "front_grip": "open",
		"back_hand": Vector2(7, 1), "face": "shout"}
	var holding := {"hip": Vector2(0, 2), "lean": -4.0, "front_foot": Vector2(5, 0), "back_foot": Vector2(-6, 0),
		"front_hand": Vector2(4, -12), "front_elbow": "up", "arm_in_front": true, "back_hand": Vector2(-3, 6)}
	var frames := _keys([low, low, heave], 5)
	frames.append_array(_keys([heave, holding], 4))
	frames.append_array([_with(holding, {"glint": true}), holding, holding])
	return frames


## For Liberty! (14 frames, 0.7 s): crouching low, fist cocked by his hip, he
## explodes upward into a leaping uppercut lariat.
static func _liberty() -> Array:
	var coil := {"hip": Vector2(0, 9), "lean": 24.0, "front_foot": Vector2(7, 0), "back_foot": Vector2(-7, 0),
		"front_hand": Vector2(2, 9), "back_hand": Vector2(7, 3), "face": "grit"}
	var rise := {"hip": Vector2(0, -2), "lean": -6.0, "front_foot": Vector2(3, -3), "back_foot": Vector2(-5, -6),
		"front_hand": Vector2(9, -9), "front_elbow": "up", "arm_in_front": true, "back_hand": Vector2(-7, 3), "face": "shout"}
	var top := {"hip": Vector2(0, -4), "lean": -14.0, "front_foot": Vector2(2, -5), "back_foot": Vector2(-4, -8),
		"front_hand": Vector2(4, -16), "front_elbow": "up", "arm_in_front": true, "back_hand": Vector2(-8, 1), "face": "shout", "glint": true}
	var land := {"hip": Vector2(0, 4), "lean": 4.0, "front_foot": Vector2(6, 0), "back_foot": Vector2(-7, 0),
		"front_hand": Vector2(5, -10), "front_elbow": "up", "arm_in_front": true, "back_hand": Vector2(-4, 6), "face": "grit"}
	var frames := _keys([coil, coil, _with(coil, {"hip": Vector2(0, 10)})], 4)
	frames.append_array(_keys([rise, top], 3))
	frames.append_array([top, top])
	frames.append_array(_keys([top, land, land], 5))
	return frames


## For my Countrymen! (12 frames, 0.4 s): a charging stride into a full-extension
## lariat, the arm whipping through and past.
static func _countrymen() -> Array:
	var stride_a := {"front_foot": Vector2(8, 0), "back_foot": Vector2(-8, -4)}
	var stride_b := {"front_foot": Vector2(-4, -4), "back_foot": Vector2(7, 0)}
	var charge := {"hip": Vector2(2, 3), "lean": 24.0, "front_hand": Vector2(-4, 3), "back_hand": Vector2(5, 4), "head_tilt": 6.0, "face": "grit"}
	var swing := {"hip": Vector2(3, 4), "lean": 28.0, "front_hand": Vector2(14, -3), "back_hand": Vector2(-7, 2), "face": "shout"}
	return [_with(stride_a, charge), _with(stride_b, charge), _with(stride_a, charge), _with(stride_b, charge),
		_with(stride_a, _mix(charge, swing, 0.5)), _with(stride_b, swing), _with(stride_b, swing),
		_with(stride_b, _with(swing, {"front_hand": Vector2(11, 3), "lean": 32.0})),
		_with(stride_b, _with(swing, {"front_hand": Vector2(8, 7), "lean": 30.0})),
		_with(stride_b, _with(swing, {"front_hand": Vector2(6, 8), "lean": 24.0, "face": "grit"})),
		_with(stride_b, _with(swing, {"front_hand": Vector2(6, 8), "lean": 20.0, "face": "grit"})),
		_with(stride_b, _with(swing, {"front_hand": Vector2(6, 8), "lean": 18.0, "face": "grit"}))]


## For the Future! (16 frames, 0.8 s): he grabs, scoops the enemy up over his head
## and falls back, hurling it far behind him, ending in a deep back-bend.
static func _future() -> Array:
	var grip := {"hip": Vector2(0, 5), "lean": 18.0, "front_foot": Vector2(7, 0), "back_foot": Vector2(-6, 0),
		"front_hand": Vector2(10, 4), "front_grip": "open", "back_hand": Vector2(11, 5), "back_grip": "open", "arm_in_front": true, "face": "grit"}
	var scoop := {"hip": Vector2(0, 8), "lean": 0.0, "front_foot": Vector2(6, 0), "back_foot": Vector2(-5, 0),
		"front_hand": Vector2(5, -6), "back_hand": Vector2(6, -5), "arm_in_front": true, "face": "shout"}
	var overhead := {"hip": Vector2(1, 4), "lean": -35.0, "head_tilt": -15.0, "front_foot": Vector2(6, 0), "back_foot": Vector2(-3, 0),
		"front_hand": Vector2(0, -15), "front_elbow": "up", "back_hand": Vector2(1, -14), "back_elbow": "up", "arm_in_front": true, "face": "shout"}
	var hurl := {"hip": Vector2(3, 6), "lean": -75.0, "head_tilt": -15.0, "front_foot": Vector2(7, 0), "back_foot": Vector2(1, 0),
		"front_hand": Vector2(-10, -10), "front_elbow": "up", "back_hand": Vector2(-9, -9), "back_elbow": "up", "arm_in_front": true,
		"front_grip": "open", "back_grip": "open", "face": "shout", "glint": true}
	var recover := {"hip": Vector2(0, 6), "lean": 10.0, "front_foot": Vector2(6, 0), "back_foot": Vector2(-6, 0),
		"front_hand": Vector2(5, 5), "back_hand": Vector2(3, 7), "face": "grit"}
	var frames := _keys([grip, grip, scoop], 4)
	frames.append_array(_keys([scoop, overhead, hurl], 5))
	frames.append_array([hurl, hurl])
	frames.append_array(_keys([hurl, recover, recover], 5))
	return frames


## Big Boot (14 frames, 0.7 s): Alex's standing heavy kick. A slow chamber, leaning
## back with the knee drawn up high, then the boot driven out flat at head height,
## held, and stamped back down.
static func _big_boot(stance: Dictionary) -> Array:
	var chamber := {"hip": Vector2(-1, 1), "lean": -14.0, "front_foot": Vector2(7, -16), "back_foot": Vector2(-3, 0),
		"front_hand": Vector2(-4, -2), "back_hand": Vector2(-8, 2), "face": "grit"}
	var boot := {"hip": Vector2(-2, 0), "lean": -24.0, "head_tilt": 8.0, "front_foot": Vector2(24, -28), "back_foot": Vector2(-3, 0),
		"front_hand": Vector2(-6, -4), "back_hand": Vector2(-9, 0), "front_grip": "open", "face": "shout"}
	var stamp := {"hip": Vector2(1, 4), "lean": 10.0, "front_foot": Vector2(10, 0), "back_foot": Vector2(-6, 0),
		"front_hand": Vector2(5, 3), "back_hand": Vector2(3, 5)}
	var frames := _keys([stance, chamber, _with(chamber, {"front_foot": Vector2(8, -18)})], 6)
	frames.append_array([boot, boot, _with(boot, {"front_foot": Vector2(22, -26)})])
	frames.append_array(_keys([_mix(boot, stamp, 0.4), stamp, stance], 5))
	return frames


## Headbutt (12 frames, 0.6 s): he grabs a fistful of the enemy, rears his head
## right back, and snaps it forward.
static func _headbutt(stance: Dictionary) -> Array:
	var rear := {"hip": Vector2(0, 2), "lean": -20.0, "head_tilt": -18.0, "front_foot": Vector2(5, 0), "back_foot": Vector2(-6, 0),
		"front_hand": Vector2(10, -2), "front_grip": "open", "back_hand": Vector2(9, 0), "back_grip": "open", "arm_in_front": true, "face": "grit"}
	var smash := {"hip": Vector2(2, 4), "lean": 32.0, "head_tilt": 22.0, "front_foot": Vector2(8, 0), "back_foot": Vector2(-7, 0),
		"front_hand": Vector2(7, 3), "front_grip": "open", "back_hand": Vector2(6, 5), "back_grip": "open", "arm_in_front": true, "face": "shout"}
	var frames := _keys([stance, rear, _with(rear, {"lean": -24.0})], 5)
	frames.append_array([smash, smash, _with(smash, {"lean": 30.0})])
	frames.append_array(_keys([smash, stance], 4))
	return frames


## Flash Chop (10 frames, 0.45 s): the hand snaps back, then lashes out flat in a
## quick, flashing chop (player.gd adds the flash).
static func _flash_chop(stance: Dictionary) -> Array:
	var cock := {"hip": Vector2(0, 3), "lean": -4.0, "front_foot": Vector2(5, 0), "back_foot": Vector2(-6, 0),
		"front_hand": Vector2(-5, -7), "front_elbow": "up", "front_grip": "chop", "back_hand": Vector2(5, 3)}
	var lash := {"hip": Vector2(2, 4), "lean": 18.0, "front_foot": Vector2(7, 0), "back_foot": Vector2(-7, 0),
		"front_hand": Vector2(13, -2), "front_grip": "chop", "back_hand": Vector2(-5, 4), "face": "shout"}
	var frames := _keys([stance, cock, cock], 4)
	frames.append_array([lash, _with(lash, {"front_hand": Vector2(12, 0)})])
	frames.append_array(_keys([_with(lash, {"front_hand": Vector2(10, 4)}), stance], 4))
	return frames


# --- The body ------------------------------------------------------------------

static func draw(pose: Dictionary) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var b := _bones(pose)
	var in_front: bool = pose.get("arm_in_front", false)
	var raised: bool = b.front_hand.y < b.neck.y and not in_front
	if not in_front:
		_arm(img, b.back_shoulder, b.back_hand, pose.get("back_elbow", ""), true, pose.get("back_grip", "fist"))
	_leg(img, b.hip, b.back_ankle, true)
	_torso(img, b)
	_leg(img, b.hip, b.front_ankle, false)
	if raised:
		_arm(img, b.front_shoulder, b.front_hand, pose.get("front_elbow", ""), false, pose.get("front_grip", "fist"))
	_head(img, b, pose)
	if in_front:
		_arm(img, b.back_shoulder, b.back_hand, pose.get("back_elbow", ""), true, pose.get("back_grip", "fist"))
	if not raised:
		_arm(img, b.front_shoulder, b.front_hand, pose.get("front_elbow", ""), false, pose.get("front_grip", "fist"))
	P._outline(img, OUTLINE)
	if pose.get("mirror", false):
		img.flip_x()
	return img


static func _bones(pose: Dictionary) -> Dictionary:
	var lean := deg_to_rad(pose.get("lean", 0.0))
	var up := Vector2(sin(lean), -cos(lean))
	var side := Vector2(cos(lean), sin(lean))
	var hip: Vector2 = HIP + pose.get("hip", Vector2.ZERO)
	var neck: Vector2 = hip + up * (TORSO + pose.get("torso", 0.0))
	var b := {
		"up": up, "side": side, "hip": hip, "neck": neck,
		"front_shoulder": neck + side * 2.2 - up * 1.6,
		"back_shoulder": neck - side * 2.2 - up * 1.6,
		"front_ankle": FRONT_ANKLE + pose.get("front_foot", Vector2.ZERO),
		"back_ankle": BACK_ANKLE + pose.get("back_foot", Vector2.ZERO),
	}
	b.front_hand = b.front_shoulder + pose.get("front_hand", Vector2(1, 11))
	b.back_hand = b.back_shoulder + pose.get("back_hand", Vector2(-1, 11))
	return b


static func _cape_anchor(pose: Dictionary) -> Vector2:
	var b := _bones(pose)
	return b.neck - b.side * 3.5 + b.up * 0.5 - Vector2(SIZE, SIZE) / 2.0


## A barrel chest and broad back, shaded down the back, with a pec line, abs and a
## little grey chest hair; red trunks and a gold belt at the waist.
static func _torso(img: Image, b: Dictionary) -> void:
	var hip: Vector2 = b.hip
	var neck: Vector2 = b.neck
	var side: Vector2 = b.side
	var up: Vector2 = b.up
	var chest := neck - up * 3.4
	var belly := hip + up * 4.5
	P._fill_polygon(img, [hip - side * 3.4, hip + side * 3.4, belly + side * 3.8, chest + side * 6.0,
		neck + side * 4.2, neck - side * 4.0, chest - side * 5.6, belly - side * 3.6], SKIN)
	# The back, in shade.
	P._fill_polygon(img, [hip - side * 3.4, belly - side * 3.6, chest - side * 5.6, neck - side * 4.0,
		neck - side * 1.8, chest - side * 2.6, hip - side * 1.6], SKIN_SHADE)
	# The pec's heavy underside, a highlight on the chest, abs, and chest hair.
	P._thick_line(img, chest - up * 1.8 + side * 0.5, chest - up * 1.2 + side * 5.8, 0.6, SKIN_SHADE)
	P._thick_line(img, chest - up * 2.4 + side * 1.5, chest - up * 2.0 + side * 5.2, 0.3, SKIN_DEEP)
	P._put(img, int(round(chest.x + side.x * 3.5 + up.x)), int(round(chest.y + side.y * 3.5 + up.y)), SKIN_LIGHT)
	for k in [2.5, 4.5]:
		var p: Vector2 = hip + up * k + side * 2.9
		P._put(img, int(round(p.x)), int(round(p.y)), SKIN_SHADE)
	for k in [Vector2(3.0, 0.6), Vector2(4.0, -0.4), Vector2(2.4, -1.0)]:
		var p: Vector2 = chest + side * k.x + up * k.y
		P._put(img, int(round(p.x)), int(round(p.y)), HAIR_LIGHT)
	# Trunks and belt.
	P._fill_polygon(img, [hip - side * 4.2 + up * 1.4, hip + side * 4.0 + up * 1.4,
		hip + side * 4.0 - up * 2.6, hip - side * 4.2 - up * 2.6], TIGHTS)
	P._thick_line(img, hip - side * 4.2 + up * 1.8, hip + side * 4.0 + up * 1.8, 0.7, BELT)
	var buckle := hip + side * 3.4 + up * 1.8
	P._disc(img, buckle, 0.9, BELT_LIGHT)


## A thick red leg with a gold stripe, a dark knee pad and a laced black boot whose
## toe points the way the foot faces (so kicks show the sole).
static func _leg(img: Image, hip: Vector2, ankle: Vector2, back: bool) -> void:
	var knee := P._joint(hip, ankle, THIGH, SHIN, "forward")
	var foot := knee + (ankle - knee).limit_length(SHIN)
	var red := TIGHTS_SHADE if back else TIGHTS
	P._thick_line(img, hip, knee, 2.1, red)
	P._thick_line(img, knee, foot, 1.7, red)
	if not back:
		var thigh_dir := (knee - hip).normalized()
		var stripe_side := thigh_dir.orthogonal() * -1.4
		P._thick_line(img, hip + stripe_side + thigh_dir, knee + stripe_side - thigh_dir, 0.3, STRIPE)
	P._disc(img, knee, 1.7, PAD)
	var shin := (foot - knee).normalized()
	var toe := Vector2(shin.y, -shin.x) # Perpendicular, toward the front.
	P._thick_line(img, foot - shin * 4.0, foot, 1.9, BOOT)
	P._thick_line(img, foot, foot + toe * 3.2, 1.2, BOOT)
	var lace := foot - shin * 2.2 + toe * 1.3
	P._put(img, int(round(lace.x)), int(round(lace.y)), LACE)
	var lace2 := foot - shin * 3.6 + toe * 1.3
	P._put(img, int(round(lace2.x)), int(round(lace2.y)), LACE)


## A heavy arm: a round shoulder, thick upper arm and forearm, white wrist tape, and
## a fist, a flat chopping hand or an open grabbing hand.
static func _arm(img: Image, shoulder: Vector2, target: Vector2, elbow_mode: String, back: bool, grip: String) -> void:
	var elbow := P._joint(shoulder, target, UPPER_ARM, FOREARM, "up" if elbow_mode == "up" else "down")
	var hand := elbow + (target - elbow).limit_length(FOREARM)
	var skin := SKIN_SHADE if back else SKIN
	# A darker edge first, so the arm reads against his chest.
	var edge := SKIN_DEEP if not back else Color(0.5, 0.33, 0.27)
	P._disc(img, shoulder, 3.2, edge)
	P._thick_line(img, shoulder, elbow, 2.8, edge)
	P._thick_line(img, elbow, hand, 2.4, edge)
	P._disc(img, shoulder, 2.5, skin)
	P._thick_line(img, shoulder, elbow, 2.0, skin)
	P._thick_line(img, elbow, hand, 1.6, skin)
	if not back:
		var bicep := shoulder.lerp(elbow, 0.5) + (elbow - shoulder).normalized().orthogonal() * -1.0
		P._put(img, int(round(bicep.x)), int(round(bicep.y)), SKIN_LIGHT)
	var dir := (hand - elbow).normalized()
	P._disc(img, hand - dir * 1.8, 1.5, TAPE)
	match grip:
		"chop":
			P._thick_line(img, hand, hand + dir * 3.5, 0.8, skin)
		"open":
			P._disc(img, hand, 1.4, skin)
			for turn in [0.7, -0.5]:
				var finger := hand + dir.rotated(turn) * 2.6
				P._put(img, int(round(finger.x)), int(round(finger.y)), SKIN_DEEP)
		_:
			P._disc(img, hand, 2.5, edge)
			P._disc(img, hand, 1.9, skin)
			var knuckle := hand + dir * 1.2
			P._put(img, int(round(knuckle.x)), int(round(knuckle.y)), SKIN_DEEP)


## His head, drawn in its own frame (turned with the spine plus head_tilt): a bald
## dome with a shine, long grey-brown hair falling down the back of his neck, a
## strong jaw, a big nose, bushy brows, and small round gold spectacles.
static func _head(img: Image, b: Dictionary, pose: Dictionary) -> void:
	var angle := deg_to_rad(pose.get("lean", 0.0) + pose.get("head_tilt", 0.0))
	var hu := Vector2(sin(angle), -cos(angle)) # Up, for the head.
	var hs := Vector2(cos(angle), sin(angle)) # Forward, for the head.
	var neck: Vector2 = b.neck
	var spine_up: Vector2 = b.up
	var c: Vector2 = neck + spine_up * 1.4 + hu * 4.6 + hs * 0.6
	# A thick neck.
	P._thick_line(img, neck - spine_up * 0.5, neck + spine_up * 1.5 + hu * 1.2, 2.4, SKIN_SHADE)
	# Hair falling down the back, behind everything else on the head.
	for k in 4:
		var top: Vector2 = c + hs * (-3.2 - k * 0.3) + hu * (1.0 - k * 0.6)
		P._thick_line(img, top, top + hu * -6.0 + hs * (-1.0 - k * 0.4), 0.8, HAIR if k % 2 == 0 else HAIR_LIGHT)
	# Skull and jaw.
	var at := func(a: float, v: float) -> Vector2i: return Vector2i((c + hs * a + hu * v).floor())
	for y in range(int(c.y) - 9, int(c.y) + 10):
		for x in range(int(c.x) - 9, int(c.x) + 10):
			var d: Vector2 = Vector2(x + 0.5, y + 0.5) - c
			var a: float = d.dot(hs)
			var v: float = d.dot(hu)
			var skull: bool = (a / 4.6) * (a / 4.6) + (v / 5.2) * (v / 5.2) <= 1.0
			var jaw: bool = a > -1.2 and a < 4.4 and v < -1.5 and v > -5.6
			if not (skull or jaw):
				continue
			var color := SKIN
			if a < -1.6 and v < 2.8:
				color = HAIR_LIGHT if int(v * 2.0) % 3 == 0 else HAIR # Hair round the back and sides.
			elif v > 3.0 and a < 1.5:
				color = SKIN_LIGHT # The shine on his bald dome.
			elif a < -0.4:
				color = SKIN_SHADE
			P._put(img, x, y, color)
	var put := func(a: float, v: float, color: Color) -> void:
		var p: Vector2i = at.call(a, v)
		P._put(img, p.x, p.y, color)
	# Ear.
	put.call(-0.6, -0.3, SKIN_DEEP)
	# Bushy brow; angry when shouting or gritting.
	var angry: bool = pose.get("face", "calm") != "calm"
	for a in [1.6, 2.6, 3.6]:
		put.call(a, 1.9 - (0.5 if angry and a > 3.0 else 0.0), BROW)
	# Spectacles: a little round lens over the eye, gold rims, and the arm back to the ear.
	var glint: bool = pose.get("glint", false)
	for p in [Vector2(2.4, 0.6), Vector2(3.4, 0.6), Vector2(2.4, -0.4), Vector2(3.4, -0.4)]:
		put.call(p.x, p.y, GLINT if glint else LENS)
	put.call(2.9, 0.4, EYE if not glint else LENS)
	for p in [Vector2(1.6, 0.1), Vector2(4.2, 0.1), Vector2(2.9, 1.3), Vector2(2.9, -1.1)]:
		put.call(p.x, p.y, RIM)
	for a in [0.2, 0.8]:
		put.call(a, 0.2, RIM)
	if glint:
		put.call(4.4, 1.8, GLINT)
		put.call(5.0, 2.4, GLINT)
	# A big nose past the profile, and a cheek line.
	put.call(4.9, -0.4, SKIN)
	put.call(5.2, -1.2, SKIN)
	put.call(4.5, -1.6, SKIN_SHADE)
	put.call(2.2, -1.4, SKIN_SHADE)
	# Mouth.
	match pose.get("face", "calm"):
		"shout":
			for p in [Vector2(2.8, -2.6), Vector2(3.8, -2.6), Vector2(2.8, -3.6), Vector2(3.8, -3.6)]:
				put.call(p.x, p.y, MOUTH)
			put.call(3.8, -2.4, TEETH)
		"grit":
			put.call(2.8, -2.6, TEETH)
			put.call(3.8, -2.6, TEETH)
			put.call(2.2, -2.6, SKIN_DEEP)
		_:
			put.call(2.8, -2.6, SKIN_DEEP)
			put.call(3.8, -2.4, SKIN_DEEP)
