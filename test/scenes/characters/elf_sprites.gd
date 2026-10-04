extends RefCounted

## Ilyra's body sprites: a tall elven arch-mage in purple and green. Long emerald hair
## and pointed ears, a big crooked witch's hat with a green band and gold buckle, a
## fitted purple bodice with green trim over a curvy figure, a flared purple skirt,
## dark leggings and green boots, long purple gloves, and a staff with a crescent
## fork cradling a floating orb that glows when she casts. Her cape is the shared
## cape layer (player_cloak.gd, style "elf").
##
## Same rig and frame layout as the others (player_sprites.gd's skeleton maths and
## drawing helpers): 64x64 frames facing right, feet on row 59, shown at
## ORIGIN_OFFSET; her head turns with her spine (see dogood_sprites.gd).
##
## Secondary motion ("jiggle physics"): after each animation's poses are made, damped
## springs are run over them (_secondary): her bust, the hat's floppy tip, the ends of
## her hair, her skirt hem and the floating orb each lag behind the motion of what
## they hang from, overshoot and settle. Looping animations are run round several
## times so they loop seamlessly. The results go into the poses (bust, hat_lag,
## hair_lag, skirt_lag, orb_lag) before they're drawn.
##
## Pose keys: the Saint's hip, lean, torso, front_foot / back_foot, front_hand /
## back_hand, front_elbow / back_elbow ("up"), arm_in_front, mirror; plus
##   staff: angle (degrees, 0 forward, -90 up) from her front hand to the orb end
##   two_hands: her back hand grips the staff too
##   glow: 0..1, the orb's glow
##   orb_bob: px the orb floats up
##   head_tilt: degrees her head tips forward (+) or back (-)
##   eyes: "open" (default), "closed" or "wink";  mouth: "smile" (default), "open", "shout"
##   skirt_lift / hair_lift: 0..1, blown up by falling (or a spin)
##   hat_sway / hair_sway: px of gentle idle sway on top of the springs

const P = preload("res://scenes/player_sprites.gd")

const SIZE := 64
const ORIGIN_OFFSET := P.ORIGIN_OFFSET
const HIP := P.HIP
const BACK_ANKLE := P.BACK_ANKLE
const FRONT_ANKLE := P.FRONT_ANKLE
const THIGH := 8.4
const SHIN := 8.6
const TORSO := 11.5
const UPPER_ARM := 6.6
const FOREARM := 6.4
const STAFF_BACK := 7.0 # Shaft behind her hand.
const STAFF_FRONT := 16.0 # Shaft ahead of it, to the fork.
const ORB_OUT := 19.5 # The orb floats this far along the staff.
const SELF_CLOAKED := []

const OUTLINE := Color(0.08, 0.04, 0.1)
const SKIN := Color(0.98, 0.86, 0.78)
const SKIN_SHADE := Color(0.86, 0.68, 0.62)
const SKIN_DEEP := Color(0.7, 0.5, 0.48)
const BLUSH := Color(0.98, 0.62, 0.66)
const LIPS := Color(0.74, 0.3, 0.5)
const HAIR := Color(0.14, 0.62, 0.42)
const HAIR_LIGHT := Color(0.4, 0.86, 0.6)
const HAIR_DARK := Color(0.07, 0.38, 0.26)
const EYE_WHITE := Color(0.98, 0.98, 0.96)
const IRIS := Color(0.3, 0.86, 0.5)
const PUPIL := Color(0.05, 0.2, 0.12)
const LASH := Color(0.1, 0.06, 0.14)
const PURPLE := Color(0.46, 0.2, 0.66)
const PURPLE_LIGHT := Color(0.66, 0.38, 0.86)
const PURPLE_DARK := Color(0.28, 0.1, 0.42)
const PURPLE_DEEP := Color(0.18, 0.06, 0.28)
const GREEN := Color(0.3, 0.84, 0.46)
const GREEN_DARK := Color(0.12, 0.5, 0.28)
const GOLD := Color(0.98, 0.82, 0.32)
const LEGGINGS := Color(0.2, 0.12, 0.26)
const LEGGINGS_SHADE := Color(0.13, 0.07, 0.18)
const BOOT := Color(0.16, 0.5, 0.3)
const BOOT_DARK := Color(0.09, 0.32, 0.18)
const WOOD := Color(0.46, 0.3, 0.18)
const WOOD_LIGHT := Color(0.62, 0.44, 0.28)
const ORB := Color(0.45, 1.0, 0.62)
const ORB_CORE := Color(0.78, 0.45, 1.0)
const GLOW := Color(0.55, 1.0, 0.7)

# Springs for the secondary motion: [frequency (Hz), damping ratio, max offset (px)].
const SPRINGS := {
	"bust": [4.5, 0.22, 1.6],
	"hat_lag": [2.4, 0.3, 4.5],
	"hair_lag": [1.8, 0.4, 5.0],
	"skirt_lag": [3.0, 0.35, 3.0],
	"orb_lag": [3.6, 0.35, 3.5],
}

static var _frames: SpriteFrames
static var _anchors := {}


static func frames() -> SpriteFrames:
	if _frames == null:
		_frames = SpriteFrames.new()
		_frames.remove_animation(&"default")
		var animations := _animations()
		for anim in animations:
			var spec: Array = animations[anim]
			spec[2] = spec[2].map(func(pose: Dictionary) -> Dictionary: return pose.duplicate()) # (Poses are shared.)
			_secondary(spec[2], spec[0], spec[1])
			_frames.add_animation(anim)
			_frames.set_animation_speed(anim, spec[0])
			_frames.set_animation_loop(anim, spec[1])
			var anchors: Array[Vector2] = []
			for pose in spec[2]:
				_frames.add_frame(anim, ImageTexture.create_from_image(draw(pose)))
				anchors.append(_cape_anchor(pose))
			_anchors[StringName(anim)] = anchors
	return _frames


static func anchor(animation: StringName, frame: int) -> Vector2:
	frames()
	var anchors: Array = _anchors.get(animation, [])
	if anchors.is_empty():
		return Vector2.ZERO
	return anchors[clampi(frame, 0, anchors.size() - 1)]


static func cape_visible(_animation: StringName, _frame: int) -> bool:
	return true


static func _keys(keys: Array, count: int) -> Array:
	return P._keyframes(keys, count)


static func _with(base: Dictionary, extra: Dictionary) -> Dictionary:
	return P._with(base, extra)


static func _mix(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	return P._lerp_pose(a, b, t)


# --- Animations ------------------------------------------------------------

static func _animations() -> Dictionary:
	var anims := {}
	# Her stance: weight on the back hip, staff planted upright at her side, the other
	# hand resting on her hip.
	var stance := {"hip": Vector2(0, 1), "lean": 2.0, "front_foot": Vector2(3, 0), "back_foot": Vector2(-4, 0),
		"front_hand": Vector2(4, 4), "staff": -84.0, "back_hand": Vector2(-3, 7)}

	# Idle: slow breaths, a little sway of the hips, the orb bobbing on its own.
	var idle := []
	for i in 16:
		var p := TAU * i / 16.0
		var b := (1.0 - cos(p)) * 0.5
		idle.append(_with(stance, {"hip": Vector2(0.6 * sin(p), 1.0 + b * 0.9), "torso": (1.0 - b) * 0.8,
			"orb_bob": 1.0 + sin(p * 2.0) * 1.0, "glow": 0.15 + 0.1 * sin(p), "head_tilt": -2.0 + sin(p) * 2.0,
			"hat_sway": sin(p) * 1.4, "hair_sway": sin(p - 0.6) * 1.2}))
	anims["idle"] = [8.0, true, idle]

	# Run: leaning in, staff trailing low behind, one hand clamped on her hat brim.
	var run := []
	for i in P.RUN_FRAMES:
		var t := float(i) / P.RUN_FRAMES
		run.append({"lean": 14.0, "hip": Vector2(1, 2.5 + 1.2 * cos(TAU * 2.0 * (t - 0.1))),
			"front_foot": P._run_foot(t) + Vector2(-2, 0), "back_foot": P._run_foot(fmod(t + 0.5, 1.0)) + Vector2(2, 0),
			"front_hand": Vector2(2.0 - 4.0 * cos(TAU * t), 7), "staff": 165.0 + 8.0 * cos(TAU * t),
			"back_hand": Vector2(3, -12), "back_elbow": "up", "arm_in_front": true, "hair_lift": 0.4})
	anims["run"] = [P.RUN_FPS, true, run]

	# Jump: knees up, holding her hat on, staff thrust up.
	var jump := []
	for i in 6:
		var s := sin(TAU * i / 6.0)
		jump.append({"hip": Vector2(0, -2), "lean": -6.0 + s, "front_foot": Vector2(4, -9.0 + s), "back_foot": Vector2(-2, -6.0 - s),
			"front_hand": Vector2(6, -7), "front_elbow": "up", "staff": -60.0 + s * 6.0,
			"back_hand": Vector2(2, -12), "back_elbow": "up", "arm_in_front": true, "skirt_lift": 0.3, "eyes": "closed" if i == 2 else "open"})
	anims["jump"] = [12.0, true, jump]

	# Fall: the skirt and hair blown up, one hand on her hat.
	var fall := []
	for i in 8:
		var p := TAU * i / 8.0
		fall.append({"lean": -4.0 + sin(p), "hip": Vector2(0, -1), "front_hand": Vector2(9, -3.0 + sin(p)), "front_elbow": "up",
			"staff": -30.0 + sin(p) * 5.0, "back_hand": Vector2(2, -12), "back_elbow": "up", "arm_in_front": true,
			"front_foot": Vector2(2.0 + sin(p), -3.0 - cos(p)), "back_foot": Vector2(-3.0 - sin(p), -1.0),
			"skirt_lift": 0.9, "hair_lift": 0.9, "mouth": "open"})
	anims["fall"] = [10.0, true, fall]

	var land := []
	for d in [0.0, 5.0, 8.0, 8.5, 7.0, 4.0, 2.0, 0.5]:
		land.append(_with(stance, {"hip": Vector2(0, 1.0 + d), "lean": 2.0 + d * 2.2, "front_foot": Vector2(5, 0), "back_foot": Vector2(-5, 0),
			"front_hand": Vector2(6, 3.0 + d * 0.3), "staff": -70.0 + d * 3.0, "back_hand": Vector2(3, 6)}))
	anims["land"] = [16.0, false, land]

	anims["reel"] = [12.0, false, _keys([
		{"hip": Vector2(-1, 3), "lean": -26.0, "head_tilt": -12.0, "front_hand": Vector2(6, -8), "front_elbow": "up",
			"staff": -120.0, "back_hand": Vector2(-8, -3), "front_foot": Vector2(4, 0), "back_foot": Vector2(-6, 0),
			"eyes": "closed", "mouth": "open", "hair_lift": 0.6},
		{"hip": Vector2(-1, 3), "lean": -12.0, "front_hand": Vector2(7, -1), "staff": -100.0, "back_hand": Vector2(-7, 3),
			"front_foot": Vector2(4, 0), "back_foot": Vector2(-6, 0), "mouth": "open"},
		stance,
	], 5)]

	anims["charge"] = [6.0, true, [_with(stance, {"glow": 0.8})]]
	anims["intro"] = [20.0, false, _intro(stance)]
	anims["dash"] = [20.0, false, _blink(stance)]

	# --- Combo moves ---
	anims["jab"] = [24.0, false, _jab(stance)]
	anims["homerun"] = [24.0, false, _homerun(stance)]
	anims["meteor"] = [20.0, false, _meteor()]
	anims["cast_fireball"] = [20.0, false, _cast_fireball(stance)]
	anims["cast_cloud"] = [20.0, false, _cast_cloud(stance)]
	anims["cast_snare"] = [20.0, false, _cast_snare(stance)]
	anims["cast_well"] = [20.0, false, _cast_well(stance)]
	# --- Real-time attacks ---
	anims["staff_swing"] = [26.0, false, _staff_swing(stance)]
	anims["arcane_bolt"] = [22.0, false, _arcane_bolt(stance)]
	return anims


## The Stagger Break intro (26 frames): she twirls the staff round in front of her,
## plants it with a pop of the hip, tips her hat brim and winks as the orb flares.
static func _intro(stance: Dictionary) -> Array:
	var frames := []
	for i in 9: # A full twirl of the staff.
		var t := float(i) / 8.0
		frames.append(_with(stance, {"front_hand": Vector2(7, 1), "staff": -84.0 + 360.0 * t, "lean": 6.0,
			"hip": Vector2(0, 2), "back_hand": Vector2(-3, 7), "glow": 0.3 + 0.4 * t, "hair_lift": 0.25}))
	var plant := _with(stance, {"hip": Vector2(-1, 2), "lean": -2.0, "front_hand": Vector2(5, 3), "staff": -88.0, "glow": 0.9})
	frames.append_array(_keys([frames[-1], plant, plant], 4))
	var tip := _with(plant, {"back_hand": Vector2(5, -11), "back_elbow": "up", "arm_in_front": true, "head_tilt": 6.0, "glow": 1.0})
	frames.append_array(_keys([plant, tip], 4))
	for i in 9:
		frames.append(_with(tip, {"eyes": "wink" if i >= 2 and i <= 6 else "open", "glow": 1.0 - i * 0.07,
			"back_hand": Vector2(5, -11) if i < 6 else Vector2(1, 2), "back_elbow": "up" if i < 6 else ""}))
	return frames


## Blink (her dash): a crouch, a flash-stretch forward, and a hop back up.
static func _blink(stance: Dictionary) -> Array:
	return _keys([
		_with(stance, {"hip": Vector2(0, 4), "lean": 16.0, "staff": -40.0, "glow": 0.5}),
		{"hip": Vector2(2, 3), "lean": 34.0, "front_foot": Vector2(10, 0), "back_foot": Vector2(-12, -2),
			"front_hand": Vector2(9, 2), "staff": 0.0, "back_hand": Vector2(-8, 3), "glow": 1.0, "hair_lift": 0.8, "skirt_lift": 0.6},
		_with(stance, {"hip": Vector2(0, 2), "lean": 8.0, "glow": 0.4}),
	], 6)


## Staff Jab (8 frames): the orb end snaps forward and back.
static func _jab(stance: Dictionary) -> Array:
	var cock := _with(stance, {"hip": Vector2(0, 2), "lean": -4.0, "front_hand": Vector2(0, 2), "staff": -10.0, "back_hand": Vector2(-2, 3), "two_hands": true})
	var thrust := {"hip": Vector2(2, 3), "lean": 18.0, "front_foot": Vector2(7, 0), "back_foot": Vector2(-6, 0),
		"front_hand": Vector2(9, 1), "staff": -4.0, "two_hands": true, "glow": 0.4, "mouth": "open"}
	return [cock, _mix(cock, thrust, 0.5), thrust, thrust, _mix(thrust, stance, 0.3), _mix(thrust, stance, 0.6), _mix(thrust, stance, 0.85), stance]


## Home Run Swing (14 frames, ~0.6 s): she winds the staff back over her shoulder,
## coils, and swings it all the way through like a bat, spinning on the follow-through.
static func _homerun(stance: Dictionary) -> Array:
	var coil := {"hip": Vector2(-1, 3), "lean": -10.0, "head_tilt": 6.0, "front_foot": Vector2(6, -2), "back_foot": Vector2(-6, 0),
		"front_hand": Vector2(-4, -4), "front_elbow": "up", "staff": -160.0, "two_hands": true, "mouth": "smile"}
	var swing_a := {"hip": Vector2(1, 4), "lean": 6.0, "front_foot": Vector2(8, 0), "back_foot": Vector2(-6, 0),
		"front_hand": Vector2(4, -2), "staff": -100.0, "two_hands": true, "mouth": "shout"}
	var contact := {"hip": Vector2(2, 4), "lean": 22.0, "front_foot": Vector2(9, 0), "back_foot": Vector2(-6, 0),
		"front_hand": Vector2(9, 2), "staff": -8.0, "two_hands": true, "mouth": "shout", "glow": 0.6}
	var through := {"hip": Vector2(2, 3), "lean": 18.0, "front_foot": Vector2(9, 0), "back_foot": Vector2(-4, -1),
		"front_hand": Vector2(6, 4), "staff": 60.0, "two_hands": true, "hair_lift": 0.7, "skirt_lift": 0.5}
	var wrap := {"hip": Vector2(1, 2), "lean": 6.0, "front_foot": Vector2(7, 0), "back_foot": Vector2(-3, 0),
		"front_hand": Vector2(-2, 1), "staff": 150.0, "two_hands": true, "hair_lift": 0.5, "eyes": "closed"}
	var frames := _keys([stance, coil, coil], 4)
	frames.append_array([swing_a, contact, contact, through])
	frames.append_array(_keys([through, wrap, wrap], 4))
	frames.append_array(_keys([wrap, stance], 3))
	return frames


## Meteor Staff (12 frames, 0.6 s): a forward somersault with the staff overhead,
## then a slam straight down, skirt and hair streaming up.
static func _meteor() -> Array:
	var tuck := {"hip": Vector2(0, -3), "lean": -30.0, "front_foot": Vector2(5, -10), "back_foot": Vector2(2, -9),
		"front_hand": Vector2(3, -12), "front_elbow": "up", "staff": -110.0, "two_hands": true, "hair_lift": 0.5}
	var flip := {"hip": Vector2(0, -3), "lean": 40.0, "front_foot": Vector2(-3, -12), "back_foot": Vector2(-6, -10),
		"front_hand": Vector2(6, -10), "front_elbow": "up", "staff": -60.0, "two_hands": true, "skirt_lift": 0.6, "hair_lift": 0.8}
	var slam := {"hip": Vector2(0, -2), "lean": 34.0, "front_foot": Vector2(-2, -8), "back_foot": Vector2(-8, -11),
		"front_hand": Vector2(9, 5), "staff": 78.0, "two_hands": true, "skirt_lift": 1.0, "hair_lift": 1.0, "glow": 0.8, "mouth": "shout"}
	return _keys([tuck, flip, slam], 6) + [slam, slam, slam, slam, slam, slam]


## Fireball (12 frames, 0.6 s): drawing the staff back two-handed, then thrusting the
## blazing orb out as the fireball leaves it.
static func _cast_fireball(stance: Dictionary) -> Array:
	var draw_back := {"hip": Vector2(-1, 2), "lean": -8.0, "front_foot": Vector2(5, 0), "back_foot": Vector2(-6, 0),
		"front_hand": Vector2(-4, 0), "staff": -150.0, "two_hands": true, "glow": 0.5, "head_tilt": 4.0}
	var thrust := {"hip": Vector2(2, 3), "lean": 18.0, "front_foot": Vector2(8, 0), "back_foot": Vector2(-6, 0),
		"front_hand": Vector2(9, -1), "staff": -6.0, "two_hands": true, "glow": 1.0, "mouth": "shout", "hair_lift": 0.4}
	var frames := _keys([stance, draw_back, _with(draw_back, {"glow": 0.8})], 5)
	frames.append_array([thrust, thrust, _with(thrust, {"glow": 0.8})])
	frames.append_array(_keys([_with(thrust, {"glow": 0.6}), stance], 4))
	return frames


## Stormcloud (14 frames, 0.7 s): the staff thrust high overhead in both hands,
## circling the sky, her face turned up.
static func _cast_cloud(stance: Dictionary) -> Array:
	var raise := {"hip": Vector2(0, 0), "lean": -8.0, "head_tilt": -14.0, "front_foot": Vector2(4, 0), "back_foot": Vector2(-5, 0),
		"front_hand": Vector2(3, -8), "front_elbow": "up", "arm_in_front": true, "staff": -88.0, "two_hands": true, "glow": 0.6}
	var frames := _keys([stance, raise], 4)
	for i in 7:
		frames.append(_with(raise, {"staff": -88.0 + 24.0 * sin(TAU * i / 7.0), "glow": 0.7 + 0.3 * sin(PI * i / 6.0),
			"front_hand": Vector2(3.0 + 2.0 * sin(TAU * i / 7.0), -8), "mouth": "open" if i > 3 else "smile"}))
	frames.append_array(_keys([raise, stance], 3))
	return frames


## Verdant Snare (12 frames, 0.6 s): a twirl, then the staff's butt driven into the
## ground in a low crouch.
static func _cast_snare(stance: Dictionary) -> Array:
	var lift := _with(stance, {"hip": Vector2(0, -1), "front_hand": Vector2(5, -6), "front_elbow": "up", "staff": -96.0, "glow": 0.5})
	var stab := {"hip": Vector2(1, 7), "lean": 22.0, "front_foot": Vector2(8, 0), "back_foot": Vector2(-7, 0),
		"front_hand": Vector2(8, 6), "staff": -82.0, "back_hand": Vector2(5, 4), "glow": 1.0, "mouth": "open", "skirt_lift": 0.3}
	var frames := _keys([stance, lift, lift], 4)
	frames.append_array([stab, stab, _with(stab, {"glow": 0.8}), _with(stab, {"glow": 0.7})])
	frames.append_array(_keys([stab, stance], 4))
	return frames


## Gravity Well (14 frames, 0.7 s): the staff held level in both hands, pushed out
## and twisted as the vortex opens.
static func _cast_well(stance: Dictionary) -> Array:
	var hold := {"hip": Vector2(0, 2), "lean": 6.0, "front_foot": Vector2(6, 0), "back_foot": Vector2(-6, 0),
		"front_hand": Vector2(7, -3), "staff": -20.0, "two_hands": true, "glow": 0.6}
	var frames := _keys([stance, hold], 4)
	for i in 6:
		frames.append(_with(hold, {"staff": -20.0 + 40.0 * sin(PI * i / 5.0), "lean": 10.0, "front_hand": Vector2(9, -3),
			"glow": 0.8 + 0.2 * sin(PI * i / 5.0), "mouth": "open", "hair_lift": 0.3}))
	frames.append_array(_keys([hold, stance], 4))
	return frames


## Staff Swing (10 frames, ~0.4 s): a quick backhanded sweep at chest height.
static func _staff_swing(stance: Dictionary) -> Array:
	var back := _with(stance, {"lean": -4.0, "front_hand": Vector2(-3, -2), "staff": -150.0, "two_hands": true})
	var hit := {"hip": Vector2(2, 3), "lean": 16.0, "front_foot": Vector2(7, 0), "back_foot": Vector2(-6, 0),
		"front_hand": Vector2(8, 1), "staff": 10.0, "two_hands": true, "mouth": "open"}
	var frames := _keys([stance, back], 3)
	frames.append_array([_mix(back, hit, 0.5), hit, _with(hit, {"staff": 40.0})])
	frames.append_array(_keys([_with(hit, {"staff": 50.0}), stance], 5))
	return frames


## Arcane Bolt (10 frames, ~0.45 s): the staff pointed level, the orb flaring as the
## bolt leaves it.
static func _arcane_bolt(stance: Dictionary) -> Array:
	var aim := {"hip": Vector2(0, 2), "lean": 6.0, "front_foot": Vector2(5, 0), "back_foot": Vector2(-6, 0),
		"front_hand": Vector2(8, -2), "staff": -6.0, "back_hand": Vector2(-3, 6), "glow": 0.5}
	var frames := _keys([stance, aim], 3)
	frames.append_array([_with(aim, {"glow": 1.0, "lean": 2.0, "mouth": "open"}), _with(aim, {"glow": 1.0, "lean": 0.0}), _with(aim, {"glow": 0.7})])
	frames.append_array(_keys([aim, stance], 5))
	return frames


# --- Secondary motion -------------------------------------------------------------

## Runs damped springs over an animation's poses: each tracked part lags behind the
## motion of what it hangs from (its anchor's acceleration pushes it the other way),
## then springs back, overshooting a little. Writes the offsets into the poses.
static func _secondary(poses: Array, fps: float, loops: bool) -> void:
	var count := poses.size()
	if count == 0:
		return
	var anchors := {} # spring -> Array of anchor positions, per frame
	for key in SPRINGS:
		anchors[key] = []
	for pose in poses:
		var b := _bones(pose)
		anchors.bust.append(b.neck - b.up * 3.5 + b.side * 4.5)
		anchors.hat_lag.append(b.neck + b.up * 10.0)
		anchors.hair_lag.append(b.neck + b.up * 3.0 - b.side * 3.0)
		anchors.skirt_lag.append(b.hip)
		anchors.orb_lag.append(_orb_base(b, pose))
	var dt := 1.0 / fps
	var substeps := 6
	var h := dt / substeps
	for key in SPRINGS:
		var spec: Array = SPRINGS[key]
		var w: float = TAU * spec[0]
		var k := w * w
		var c: float = 2.0 * spec[1] * w
		var offset := Vector2.ZERO
		var velocity := Vector2.ZERO
		var points: Array = anchors[key]
		var passes := 3 if loops else 1
		for pass_i in passes:
			for i in count:
				var prev: Vector2 = points[posmod(i - 1, count)] if (loops or i > 0) else points[0]
				var prev2: Vector2 = points[posmod(i - 2, count)] if (loops or i > 1) else prev
				var accel: Vector2 = ((points[i] - prev) - (prev - prev2)) / (dt * dt)
				for s in substeps:
					var a := -k * offset - c * velocity - accel
					velocity += a * h
					offset += velocity * h
				offset = offset.limit_length(spec[2])
				if pass_i == passes - 1:
					poses[i][key] = offset


# --- The body ------------------------------------------------------------------

static func draw(pose: Dictionary) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var b := _bones(pose)
	var in_front: bool = pose.get("arm_in_front", false)
	var raised: bool = b.front_hand.y < b.neck.y and not in_front
	_hair_back(img, b, pose)
	if not in_front and not pose.get("two_hands", false):
		_arm(img, b.back_shoulder, b.back_hand, pose.get("back_elbow", ""), true)
	_leg(img, b.hip, b.back_ankle, true)
	_leg(img, b.hip, b.front_ankle, false)
	_skirt(img, b, pose)
	_torso(img, b, pose)
	if raised:
		_staff(img, b, pose)
		_arm(img, b.front_shoulder, b.front_hand, pose.get("front_elbow", ""), false)
	_head(img, b, pose)
	if in_front and not pose.get("two_hands", false):
		_arm(img, b.back_shoulder, b.back_hand, pose.get("back_elbow", ""), true)
	if not raised:
		_staff(img, b, pose)
		if pose.get("two_hands", false):
			_arm(img, b.back_shoulder, b.back_hand, pose.get("back_elbow", ""), true)
		_arm(img, b.front_shoulder, b.front_hand, pose.get("front_elbow", ""), false)
	elif pose.get("two_hands", false):
		_arm(img, b.back_shoulder, b.back_hand, pose.get("back_elbow", ""), true)
	P._outline(img, OUTLINE)
	_orb(img, b, pose) # After the outline: it glows, unoutlined.
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
		"front_shoulder": neck + side * 1.6 - up * 1.4,
		"back_shoulder": neck - side * 1.6 - up * 1.4,
		"front_ankle": FRONT_ANKLE + pose.get("front_foot", Vector2.ZERO),
		"back_ankle": BACK_ANKLE + pose.get("back_foot", Vector2.ZERO),
	}
	b.front_hand = b.front_shoulder + pose.get("front_hand", Vector2(1, 11))
	b.back_hand = b.back_shoulder + pose.get("back_hand", Vector2(-1, 11))
	if pose.get("two_hands", false):
		var dir := Vector2.from_angle(deg_to_rad(pose.get("staff", -84.0)))
		b.back_hand = b.front_hand - dir * 4.0
	return b


static func _cape_anchor(pose: Dictionary) -> Vector2:
	var b := _bones(pose)
	return b.neck - b.side * 2.5 + b.up * 0.5 - Vector2(SIZE, SIZE) / 2.0


static func _orb_base(b: Dictionary, pose: Dictionary) -> Vector2:
	var dir := Vector2.from_angle(deg_to_rad(pose.get("staff", -84.0)))
	var hand: Vector2 = b.front_hand
	return hand + dir * ORB_OUT + Vector2(0, -pose.get("orb_bob", 0.0))


## Long emerald hair falling down her back from under the hat, swinging (hair_lag)
## and blown up (hair_lift).
static func _hair_back(img: Image, b: Dictionary, pose: Dictionary) -> void:
	var neck: Vector2 = b.neck
	var up: Vector2 = b.up
	var side: Vector2 = b.side
	var lag: Vector2 = pose.get("hair_lag", Vector2.ZERO) + Vector2(pose.get("hair_sway", 0.0), 0)
	var lift: float = pose.get("hair_lift", 0.0)
	var root := neck + up * 6.0 - side * 2.5
	for k in 5:
		var spread := -1.0 - k * 0.7
		var fall := (Vector2(0, 1).lerp(-side, 0.3 + lift * 0.6)).normalized()
		var mid := root + side * spread + fall * 7.0 + lag * 0.5
		var end := root + side * (spread - 1.0 - lift * 3.0) + fall * (14.0 - k * 1.0 - lift * 3.0) + lag
		var color := HAIR_LIGHT if k == 1 else (HAIR_DARK if k == 4 else HAIR)
		P._thick_line(img, root + side * spread * 0.5, mid, 1.4 - k * 0.1, color)
		P._thick_line(img, mid, end, 1.1 - k * 0.1, color)


## A slender leg in dark leggings and a tall green boot with a gold buckle and a
## pointed toe.
static func _leg(img: Image, hip: Vector2, ankle: Vector2, back: bool) -> void:
	var knee := P._joint(hip, ankle, THIGH, SHIN, "forward")
	var foot := knee + (ankle - knee).limit_length(SHIN)
	P._thick_line(img, hip, knee, 1.6, LEGGINGS_SHADE if back else LEGGINGS)
	var shin := (foot - knee).normalized()
	var toe := Vector2(shin.y, -shin.x)
	var boot_top := knee + shin * 1.5
	P._thick_line(img, boot_top, foot, 1.4, BOOT_DARK if back else BOOT)
	P._thick_line(img, boot_top - shin.orthogonal() * 0.0, boot_top + shin * 0.6, 1.7, BOOT_DARK)
	P._thick_line(img, foot, foot + toe * 3.6 + shin * -0.6, 0.9, BOOT_DARK if back else BOOT)
	var buckle := knee + shin * 4.5 + toe * 1.2
	P._put(img, int(round(buckle.x)), int(round(buckle.y)), GOLD)


## The flared skirt: hanging from her hips (half along her body, half straight
## down), its hem lagging (skirt_lag) and lifting in a fall (skirt_lift), with a green
## hem and a slit at the front.
static func _skirt(img: Image, b: Dictionary, pose: Dictionary) -> void:
	var hip: Vector2 = b.hip
	var up: Vector2 = b.up
	var side: Vector2 = b.side
	var lag: Vector2 = pose.get("skirt_lag", Vector2.ZERO)
	var lift: float = pose.get("skirt_lift", 0.0)
	var down := (-up).lerp(Vector2.DOWN, 0.5).normalized()
	var length := 10.0 - lift * 3.0
	var waist := hip + up * 2.0
	var hem_back := hip - side * (6.0 + lift * 2.5) + down * length + lag + Vector2(0, -lift * 3.0)
	var hem_front := hip + side * (6.0 + lift * 2.5) + down * (length - 1.5) + lag + Vector2(0, -lift * 3.0)
	var hem_mid := (hem_back + hem_front) / 2.0 + down * 1.5
	P._fill_polygon(img, [waist - side * 4.0, waist + side * 3.6, hem_front, hem_mid, hem_back], PURPLE)
	P._fill_polygon(img, [waist - side * 4.0, waist - side * 1.2, hem_mid, hem_back], PURPLE_DARK)
	# Folds, the green hem and the front slit.
	P._thick_line(img, waist + side * 0.5, hem_mid + side * 1.5, 0.3, PURPLE_DARK)
	P._thick_line(img, hem_back, hem_mid, 0.6, GREEN)
	P._thick_line(img, hem_mid, hem_front, 0.6, GREEN)
	P._thick_line(img, waist + side * 3.0 - up * 3.0, hem_front - side * 0.5, 0.4, PURPLE_DEEP)


## A fitted bodice over a curvy figure: hips, a narrow waist with a green sash and a
## gold clasp, and a full bust (offset by the bust spring) with a highlight on top,
## a shadow underneath, and green trim round a modest neckline with a gem.
static func _torso(img: Image, b: Dictionary, pose: Dictionary) -> void:
	var hip: Vector2 = b.hip
	var neck: Vector2 = b.neck
	var side: Vector2 = b.side
	var up: Vector2 = b.up
	var jiggle: Vector2 = pose.get("bust", Vector2.ZERO)
	var waist := hip + up * 4.0
	var under := neck - up * 5.2 + side * 2.6
	var front := neck - up * 3.6 + side * 6.0 + jiggle
	var top := neck - up * 1.6 + side * 4.2 + jiggle * 0.5
	P._fill_polygon(img, [hip - side * 4.2, hip + side * 3.8, waist + side * 2.6, under, front, top,
		neck + side * 2.4, neck - side * 2.6, neck - up * 3.0 - side * 3.2, waist - side * 2.8], PURPLE)
	# Shade down her back; the bust's highlight and the shadow beneath it.
	P._fill_polygon(img, [hip - side * 4.2, waist - side * 2.8, neck - up * 3.0 - side * 3.2, neck - side * 2.6,
		neck - side * 1.0, waist - side * 1.2], PURPLE_DARK)
	var crest := (top + front) / 2.0
	P._disc(img, crest - side * 0.6 + up * 0.4, 0.9, PURPLE_LIGHT)
	P._thick_line(img, under + side * 0.3, front - up * 0.6 - side * 0.4, 0.5, PURPLE_DARK)
	# Neckline: a little skin above the bodice, the green trim along it, and a gem.
	P._fill_polygon(img, [neck + side * 2.4, top, neck - up * 1.4 + side * 1.8], SKIN)
	P._thick_line(img, neck - up * 1.4 + side * 1.8, top, 0.4, GREEN)
	var gem := neck - up * 2.0 + side * 3.0 + jiggle * 0.5
	P._put(img, int(round(gem.x)), int(round(gem.y)), GOLD)
	# Sash and clasp.
	P._thick_line(img, waist - side * 2.8, waist + side * 2.6, 0.8, GREEN)
	P._thick_line(img, waist - side * 2.8 - up * 0.8, waist + side * 2.6 - up * 0.8, 0.3, GREEN_DARK)
	var clasp := waist + side * 2.2
	P._put(img, int(round(clasp.x)), int(round(clasp.y)), GOLD)
	# A green sash end hanging behind.
	P._thick_line(img, waist - side * 2.6, waist - side * 3.6 + Vector2(0, 5) + pose.get("skirt_lag", Vector2.ZERO), 0.5, GREEN_DARK)


## A slender arm: bare shoulder and upper arm, a long purple glove with a green cuff.
static func _arm(img: Image, shoulder: Vector2, target: Vector2, elbow_mode: String, back: bool) -> void:
	var elbow := P._joint(shoulder, target, UPPER_ARM, FOREARM, "up" if elbow_mode == "up" else "down")
	var hand := elbow + (target - elbow).limit_length(FOREARM)
	var skin := SKIN_SHADE if back else SKIN
	P._disc(img, shoulder, 1.5, skin)
	P._thick_line(img, shoulder, elbow, 1.2, skin)
	P._thick_line(img, elbow, hand, 1.1, PURPLE_DARK if back else PURPLE)
	var cuff := elbow + (hand - elbow) * 0.2
	P._disc(img, cuff, 1.2, GREEN_DARK if back else GREEN)
	P._disc(img, hand, 1.0, PURPLE_DARK if back else PURPLE_LIGHT)


## The staff: a wooden shaft through her hand, a gold-bound crescent fork at the top
## (the orb itself is drawn after the outline, see _orb).
static func _staff(img: Image, b: Dictionary, pose: Dictionary) -> void:
	var dir := Vector2.from_angle(deg_to_rad(pose.get("staff", -84.0)))
	var normal := dir.orthogonal()
	var hand: Vector2 = b.front_hand
	var butt := hand - dir * STAFF_BACK
	var fork := hand + dir * STAFF_FRONT
	P._thick_line(img, butt, fork, 0.7, WOOD)
	P._thick_line(img, hand + dir * 3.0 + normal * 0.3, fork - dir * 2.0 + normal * 0.3, 0.2, WOOD_LIGHT)
	P._put(img, int(round(butt.x)), int(round(butt.y)), GOLD)
	var band := fork - dir * 1.0
	P._disc(img, band, 0.9, GOLD)
	for s in [1.0, -1.0]:
		var prong: Vector2 = fork + normal * s * 2.4 + dir * 2.2
		P._thick_line(img, band, prong, 0.4, GREEN_DARK)
		P._put(img, int(round(prong.x)), int(round(prong.y)), GREEN)


## The floating orb, with a halo while it glows (and rays when it blazes).
static func _orb(img: Image, b: Dictionary, pose: Dictionary) -> void:
	var glow: float = pose.get("glow", 0.0)
	var center: Vector2 = _orb_base(b, pose) + pose.get("orb_lag", Vector2.ZERO)
	if glow > 0.05:
		_soft_disc(img, center, 2.2 + glow * 3.0, Color(GLOW, 0.25 * glow))
		_soft_disc(img, center, 2.2 + glow * 1.6, Color(GLOW, 0.35 * glow))
	if glow > 0.7:
		for a in 4:
			var ray := Vector2.from_angle(a * PI / 2.0 + PI / 4.0)
			for r in [4.0, 5.0, 6.0]:
				var p: Vector2 = center + ray * r * (0.6 + glow * 0.5)
				_blend(img, int(round(p.x)), int(round(p.y)), Color(GLOW, 0.5 * glow))
	P._disc(img, center, 2.0, ORB if glow < 0.5 else ORB.lightened(0.4))
	P._disc(img, center + Vector2(0.3, 0.3), 0.9, ORB_CORE if glow < 0.8 else Color(1, 1, 1))
	P._put(img, int(round(center.x - 1.0)), int(round(center.y - 1.0)), Color(1, 1, 1))


## Her head (turned with her spine plus head_tilt): an oval face with a pointed
## chin, a big green eye with lashes, a blush, painted lips, emerald bangs, a long
## pointed ear sweeping back, and the big hat.
static func _head(img: Image, b: Dictionary, pose: Dictionary) -> void:
	var angle := deg_to_rad(pose.get("lean", 0.0) + pose.get("head_tilt", 0.0))
	var hu := Vector2(sin(angle), -cos(angle))
	var hs := Vector2(cos(angle), sin(angle))
	var neck: Vector2 = b.neck
	var spine_up: Vector2 = b.up
	var c: Vector2 = neck + spine_up * 1.2 + hu * 4.4 + hs * 0.8
	P._thick_line(img, neck - spine_up * 0.5, neck + spine_up * 1.4 + hu * 1.0, 1.1, SKIN_SHADE)
	var put := func(a: float, v: float, color: Color) -> void:
		var p := Vector2i((c + hs * a + hu * v).floor())
		P._put(img, p.x, p.y, color)
	# Face and hair.
	for y in range(int(c.y) - 8, int(c.y) + 9):
		for x in range(int(c.x) - 8, int(c.x) + 9):
			var d: Vector2 = Vector2(x + 0.5, y + 0.5) - c
			var a: float = d.dot(hs)
			var v: float = d.dot(hu)
			var face: bool = (a / 4.1) * (a / 4.1) + (v / 4.8) * (v / 4.8) <= 1.0
			var chin: bool = a > 0.0 and a < 3.6 and v < -2.0 and v > -5.0 - a * 0.3 and a < 3.6 + (v + 2.0) * 0.5
			if not (face or chin):
				continue
			var color := SKIN
			if a < -0.8 or v > 2.6 - maxf(a - 1.0, 0.0) * 0.6:
				color = HAIR_LIGHT if int(a * 1.5 + v) % 3 == 0 else HAIR # Bangs and the back of her head.
			elif a < 0.2:
				color = SKIN_SHADE
			P._put(img, x, y, color)
	# The ear: long and pointed, sweeping up and back out through her hair.
	for t in 9:
		var u := t / 8.0
		put.call(-0.6 - u * 6.4, -0.4 + u * 2.4, SKIN if t < 8 else SKIN_SHADE)
		if t < 7:
			put.call(-0.6 - u * 5.4, -1.4 + u * 2.4, SKIN_SHADE)
			put.call(-1.2 - u * 4.0, 0.0 + u * 1.6, SKIN_DEEP if t > 1 else SKIN)
	# A stray lock over the forehead.
	put.call(2.6, 2.0, HAIR)
	put.call(3.0, 1.4, HAIR_DARK)
	# The eye: big, green, with lashes; or closed, or winking.
	match pose.get("eyes", "open"):
		"open":
			put.call(2.0, 0.6, EYE_WHITE)
			put.call(2.8, 0.6, IRIS)
			put.call(2.8, -0.2, IRIS)
			put.call(2.0, -0.2, PUPIL)
			put.call(1.6, 1.4, LASH)
			put.call(2.6, 1.4, LASH)
			put.call(3.4, 1.6, LASH)
		_: # Closed (and a wink, seen from this side).
			put.call(1.8, 0.2, LASH)
			put.call(2.6, 0.0, LASH)
			put.call(3.4, 0.4, LASH)
	put.call(2.2, -1.4, BLUSH)
	# A small nose, and lips.
	put.call(4.3, -0.6, SKIN)
	put.call(4.0, -1.2, SKIN_SHADE)
	match pose.get("mouth", "smile"):
		"open", "shout":
			put.call(3.2, -2.4, LIPS)
			put.call(3.2, -3.0, Color(0.35, 0.1, 0.2))
			put.call(3.8, -2.6, LIPS)
		_:
			put.call(3.2, -2.4, LIPS)
			put.call(3.8, -2.2, LIPS)
	_hat(img, c, hu, hs, pose)


## The big hat: a wide brim, a green band with a gold buckle, and a tall cone that
## bends back at a crooked angle, its floppy tip lagging behind (hat_lag).
static func _hat(img: Image, c: Vector2, hu: Vector2, hs: Vector2, pose: Dictionary) -> void:
	var tilt := deg_to_rad(pose.get("hat_tilt", -8.0))
	var up := hu.rotated(tilt)
	var fwd := hs.rotated(tilt)
	var lag: Vector2 = pose.get("hat_lag", Vector2.ZERO)
	var brim_c := c + hu * 3.4 - hs * 0.4
	# Cone: up from the brim, kinking back, the tip drooping behind.
	var base_l := brim_c - fwd * 4.6 + up * 0.6
	var base_r := brim_c + fwd * 4.2 + up * 0.6
	var mid := brim_c + up * 7.5 - fwd * 1.8 + lag * 0.4
	var bend := brim_c + up * 10.5 - fwd * 4.0 + lag * 0.7
	var tip: Vector2 = bend - fwd * (4.5 + pose.get("hat_sway", 0.0)) - up * 2.0 + lag
	P._fill_polygon(img, [base_l, mid - fwd * 2.4, bend - fwd * 1.0, tip, bend + fwd * 0.8 + up * 0.6, mid + fwd * 2.2, base_r], PURPLE)
	P._fill_polygon(img, [base_l, mid - fwd * 2.4, bend - fwd * 1.0, tip, mid - fwd * 0.4], PURPLE_DARK)
	P._thick_line(img, bend + fwd * 0.3, mid + fwd * 1.6, 0.3, PURPLE_LIGHT)
	P._put(img, int(round(tip.x)), int(round(tip.y)), GOLD) # A little star on the tip.
	# Band and buckle.
	P._thick_line(img, base_l + up * 0.8, base_r + up * 0.8, 0.8, GREEN)
	var buckle := brim_c + fwd * 2.0 + up * 1.4
	P._put(img, int(round(buckle.x)), int(round(buckle.y)), GOLD)
	# The brim: wide and thin, drooping a little at both ends.
	var brim := []
	var under := []
	for i in 11:
		var t := (i / 10.0) * 2.0 - 1.0
		var droop := t * t * 1.4
		brim.append(brim_c + fwd * t * 9.5 - up * droop + up * 0.7)
		under.append(brim_c + fwd * t * 9.5 - up * droop - up * 0.9)
	under.reverse()
	P._fill_polygon(img, brim + under, PURPLE)
	for i in range(1, under.size() - 1):
		P._put(img, int(round(under[i].x)), int(round(under[i].y)), PURPLE_DEEP)


# --- Helpers -----------------------------------------------------------------------

static func _blend(img: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < SIZE and y >= 0 and y < SIZE:
		img.set_pixel(x, y, img.get_pixel(x, y).blend(color))


static func _soft_disc(img: Image, center: Vector2, radius: float, color: Color) -> void:
	for y in range(int(floor(center.y - radius)), int(ceil(center.y + radius)) + 1):
		for x in range(int(floor(center.x - radius)), int(ceil(center.x + radius)) + 1):
			if Vector2(x + 0.5, y + 0.5).distance_to(center) <= radius:
				_blend(img, x, y, color)
