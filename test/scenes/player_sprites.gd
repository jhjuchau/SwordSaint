extends RefCounted

## The player character's body sprites, drawn in code from a simple skeleton: an
## older, greying swordsman with green eyes, in a hooded black robe with blue
## herringbone trim, a brown shirt, white pants, black shoes and a katana at his hip.
## The long tail of his robe is a separate layer (player_cloak.gd), drawn behind the
## body and driven by momentum, except in animations listed in SELF_CLOAKED, which
## draw their own.
##
## Frames are 64x64, facing right (the game flips them for left), feet on row 59, and
## sit on the player at ORIGIN_OFFSET so the feet touch y = 0.
## Usage: `PlayerSprites.frames()` -> SpriteFrames (built once, then cached), and
## `PlayerSprites.anchor(animation, frame)` -> where the cloak hangs from.
##
## A pose is a dictionary (all keys optional; see DEFAULTS):
##   hip:          offset of the hips (y > 0 crouches; the knees bend to match)
##   lean:         spine angle in degrees (forward > 0)
##   front_foot / back_foot:  ankle offsets from standing (y < 0 lifts the foot)
##   front_hand / back_hand:  hand position relative to that shoulder
##   front_elbow / back_elbow: "up" to bend the elbow upward (default down)
##   blade:        katana angle in degrees when drawn (0 forward, -90 up, 90 down)
##   two_hands:    the back hand also grips the hilt
##   on_hilt:      the front hand rests on the sheathed katana's hilt
##   open_hand:    the front hand is open (no sword)
##   arm_in_front: draw raised arms in front of the head (default: behind it)
##   aura:         alpha of a pale blue glow (charging)
##   torso:        extra spine length (breathing in stretches him)
##   hand_to_hilt: 0..1, how far the front hand has risen to the sheathed hilt
##   back_on_sheath: the back hand holds the sheath at the waist
##   head_front:   turn the face to the camera (value: 0 eyes open, 1 half, 2 closed)
##   cape:         "hang" or "held" draws a cape in the frame itself (for SELF_CLOAKED
##                 animations): hanging down his back, or held out in the front hand
##   mirror:       draws the pose facing the other way (turned away)
##   flip:         draws the tucked forward-flip ball at this rotation instead
##   front:        draws him seen at 45 degrees toward the screen instead (see
##                 _draw_front for its own keys)

const SIZE := 64
const ORIGIN_OFFSET := Vector2(0, -28)
const HIP := Vector2(32, 41)
const BACK_ANKLE := Vector2(30, 57)
const FRONT_ANKLE := Vector2(34, 57)
const THIGH := 8.0
const SHIN := 8.2
const TORSO := 12.0
const UPPER_ARM := 7.0
const FOREARM := 7.0
const BLADE_LENGTH := 18.0
const DEFAULTS := {
	"hip": Vector2.ZERO, "lean": 0.0,
	"front_foot": Vector2.ZERO, "back_foot": Vector2.ZERO,
	"front_hand": Vector2(1, 11), "back_hand": Vector2(-1, 11),
}

# The Iai stance: front knee deeply bent, back leg straight and far behind, chest low
# and angled, hand on the hilt, eyes closed and face turned to the camera.
const IAI := {"hip": Vector2(0, 9), "lean": 35.0, "front_foot": Vector2(10, 0), "back_foot": Vector2(-15, 0),
	"front_hand": Vector2(5, 9), "hand_to_hilt": 1.0, "back_on_sheath": true, "head_front": 2}
## Scale the Summit's cut, in degrees (0 forward, -90 up, -180 behind). Keep it matching
## the move's reach_line in combat_manager.gd and the "summit" streak in slash_sprite.gd.
const SUMMIT_ANGLE := -127.5

# The run cycle, timed to the player's running speed (player.gd's SPEED).
const RUN_SPEED := 250.0
const RUN_FRAMES := 16
const RUN_FPS := 48.0 # One cycle (two steps) every 1/3 s.
const CONTACT := 0.2 # Fraction of the cycle each foot spends planted.

## Animations that draw the cloak themselves; the cloak layer hides during them.
const SELF_CLOAKED := [&"jump", &"meditate"]
const LASH := Color(0.25, 0.18, 0.16)

# Palette.
const OUTLINE := Color(0.05, 0.04, 0.07)
const SKIN := Color(0.96, 0.8, 0.68)
const SKIN_SHADE := Color(0.83, 0.64, 0.53)
const EYE_WHITE := Color(0.96, 0.96, 0.92)
const EYE_GREEN := Color(0.3, 0.82, 0.38)
const EYE_GREEN_DARK := Color(0.12, 0.52, 0.22)
const PUPIL := Color(0.04, 0.12, 0.06)
const HAIR_GREY := Color(0.6, 0.6, 0.6)
const HAIR_LIGHT := Color(0.84, 0.84, 0.82)
const HAIR_DARK := Color(0.4, 0.38, 0.37)
const BEARD := Color(0.72, 0.72, 0.7)
const ROBE := Color(0.11, 0.11, 0.14)
const ROBE_SHADE := Color(0.06, 0.06, 0.08)
const ROBE_LIGHT := Color(0.3, 0.3, 0.38)
const TRIM := [Color(0.42, 0.66, 1.0), Color(0.24, 0.43, 0.88), Color(0.12, 0.22, 0.58)]
const SHIRT := Color(0.56, 0.36, 0.2)
const PANTS := Color(0.95, 0.95, 0.92)
const PANTS_SHADE := Color(0.74, 0.74, 0.77)
const SHOES := Color(0.07, 0.07, 0.08)
const SHEATH := Color(0.55, 0.16, 0.12) # Red lacquer.
const GOLD := Color(0.86, 0.72, 0.3)
const HILT := Color(0.28, 0.28, 0.34)
const BLADE := Color(0.82, 0.86, 0.92)
const BLADE_EDGE := Color(1.0, 1.0, 1.0)
const AURA := Color(0.55, 0.85, 1.0)

static var _frames: SpriteFrames
static var _anchors := {} # animation -> Array of cloak anchors, one per frame


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
			for pose in spec[2]:
				_frames.add_frame(anim, ImageTexture.create_from_image(draw(pose)))
				anchors.append(_cloak_anchor(pose))
			_anchors[StringName(anim)] = anchors
	return _frames


## Whether the cloak layer shows on `frame` of `animation` (not while the animation
## draws its own).
static func cape_visible(animation: StringName, _frame: int) -> bool:
	return not SELF_CLOAKED.has(animation)


## Where the cloak hangs from on `frame` of `animation`, relative to the sprite's
## origin, for a right-facing player (negate x when facing left).
static func anchor(animation: StringName, frame: int) -> Vector2:
	frames()
	var anchors: Array = _anchors.get(animation, [])
	if anchors.is_empty():
		return Vector2.ZERO
	return anchors[clampi(frame, 0, anchors.size() - 1)]


# --- Animations ------------------------------------------------------------

## name -> [frames per second, loops, poses]
static func _animations() -> Dictionary:
	var anims := {}

	# Idle: breathing as a gentle vertical squash and stretch. Breathing in, the spine
	# lengthens; breathing out, the knees slowly bend and he settles. Hand on the hilt.
	var idle := []
	for i in 12:
		var b := (1.0 - cos(TAU * i / 12.0)) * 0.5 # 0 = full breath in, 1 = out.
		idle.append({"hip": Vector2(0, b * 1.6), "torso": (1.0 - b) * 1.0, "lean": 3.0, "on_hilt": true,
			"back_hand": Vector2(-2, 10.0 - b * 0.6), "back_foot": Vector2(-1, 0), "front_foot": Vector2(2, 0)})
	anims["idle"] = [6.0, true, idle]

	# Run: a sprint, leaning well forward. Each foot is planted for a short contact
	# phase, sliding back at exactly the player's running speed (so it doesn't skate),
	# then kicks up behind and swings forward; both feet are briefly off the ground
	# between steps. The body dips at each footfall.
	var run := []
	for i in RUN_FRAMES:
		var t := float(i) / RUN_FRAMES
		var front := _run_foot(t)
		var back := _run_foot(fmod(t + 0.5, 1.0))
		run.append({"lean": 30.0, "hip": Vector2(2, 3.0 + 1.2 * cos(TAU * 2.0 * (t - 0.1))),
			"front_foot": front + Vector2(-2, 0), "back_foot": back + Vector2(2, 0),
			"front_hand": Vector2(2.0 - 5.0 * cos(TAU * t), 7), "back_hand": Vector2(-2.0 + 5.0 * cos(TAU * t), 7)})
	anims["run"] = [RUN_FPS, true, run]

	# Jump: a tucked forward flip, the cloak wrapped round him in a spiral.
	var flip := []
	for i in 8:
		flip.append({"flip": i * 45.0})
	anims["jump"] = [20.0, true, flip]

	# Fall: one elbow bent up beside the head, the other arm reaching up, legs dangling.
	var fall := []
	for i in 8:
		var p := TAU * i / 8.0
		var s := sin(p)
		fall.append({"lean": -6.0 + s, "hip": Vector2(0, -1),
			"front_hand": Vector2(9.0 + s * 0.5, -8.0 - s * 0.5), "front_elbow": "up",
			"back_hand": Vector2(-7.0 - s * 0.5, -11.0 + absf(s)), "back_elbow": "up",
			"front_foot": Vector2(2.0 + s, -3.0 - cos(p)), "back_foot": Vector2(-3.0 - s, -1.0 + cos(p) * 0.5)})
	anims["fall"] = [10.0, true, fall]

	# Land: straight legs, a deep knee bend to absorb the shock, then back up.
	var land := []
	for d in [0.0, 4.0, 7.0, 8.0, 7.0, 5.0, 2.0, 0.0]:
		land.append({"hip": Vector2(0, d), "lean": d * 2.5, "back_foot": Vector2(-2, 0), "front_foot": Vector2(3, 0),
			"front_hand": Vector2(4.0 + d * 0.4, 9.0 - d * 0.6), "back_hand": Vector2(-4.0 - d * 0.2, 8.0 - d * 0.5)})
	anims["land"] = [16.0, false, land]

	var charge := []
	for alpha in [0.9, 0.45, 0.7]:
		charge.append({"hip": Vector2(0, 3), "lean": 10.0, "on_hilt": true, "back_hand": Vector2(-3, 7),
			"back_foot": Vector2(-3, 0), "front_foot": Vector2(4, 0), "aura": alpha})
	anims["charge"] = [8.0, true, charge]
	anims["meditate"] = [30.0, false, _meditate()]
	anims["iai_enter"] = [20.0, false, _iai_enter()]
	# Reeling from a hit: snapped back, arms flung, then catching himself.
	anims["reel"] = [12.0, false, _keyframes([
		{"hip": Vector2(-1, 3), "lean": -26.0, "front_hand": Vector2(5, -9), "front_elbow": "up",
			"back_hand": Vector2(-8, -5), "front_foot": Vector2(4, 0), "back_foot": Vector2(-5, 0)},
		{"hip": Vector2(-1, 4), "lean": -18.0, "front_hand": Vector2(7, -4), "back_hand": Vector2(-8, 1),
			"front_foot": Vector2(4, 0), "back_foot": Vector2(-6, 0)},
		{"hip": Vector2(0, 2), "lean": -4.0, "front_hand": Vector2(3, 8), "back_hand": Vector2(-4, 8),
			"front_foot": Vector2(3, 0), "back_foot": Vector2(-4, 0)},
	], 5)]
	var hold := []
	for i in 4:
		var b := (1.0 - cos(TAU * i / 4.0)) * 0.5
		hold.append(_with(IAI, {"hip": IAI.hip + Vector2(0, b * 0.6), "torso": (1.0 - b) * 0.5}))
	anims["iai_hold"] = [4.0, true, hold]
	# The Iai draws, each from the stance: Scale the Summit, one long cut up and behind;
	# Imbibe the Sky, straight up overhead; Sever the Roots, a sweeping cut behind.
	var drawn := {"hip": Vector2(0, 8), "front_foot": IAI.front_foot, "back_foot": IAI.back_foot, "back_on_sheath": true}
	anims["imbibe"] = [30.0, false, _keyframes([
		IAI,
		_with(drawn, {"lean": 30.0, "front_hand": Vector2(9, 5), "blade": 15.0}),
		_with(drawn, {"lean": 15.0, "hip": Vector2(0, 6), "front_hand": Vector2(6, -6), "blade": -60.0}),
		_with(drawn, {"lean": 0.0, "hip": Vector2(0, 4), "front_hand": Vector2(2, -13), "blade": -88.0, "arm_in_front": true}),
		_with(drawn, {"lean": -2.0, "hip": Vector2(0, 4), "front_hand": Vector2(1, -14), "blade": -90.0, "arm_in_front": true}),
	], 12)]
	# Usurp the Heavens: draws and lifts the sword straight up, high over his head,
	# and holds it there for the lightning.
	anims["usurp"] = [30.0, false, _keyframes([
		IAI,
		_with(drawn, {"lean": 22.0, "front_hand": Vector2(8, 3), "blade": -20.0}),
		_with(drawn, {"lean": 6.0, "hip": Vector2(0, 5), "front_hand": Vector2(3, -10), "blade": -80.0, "arm_in_front": true}),
		_with(drawn, {"lean": -4.0, "hip": Vector2(0, 3), "front_hand": Vector2(1, -16), "blade": -90.0, "arm_in_front": true}),
		_with(drawn, {"lean": -4.0, "hip": Vector2(0, 3), "front_hand": Vector2(1, -16), "blade": -90.0, "arm_in_front": true}),
	], 12)]
	anims["sever"] = [30.0, false, _keyframes([
		IAI,
		_with(drawn, {"lean": 30.0, "front_hand": Vector2(10, 3), "blade": 0.0}),
		_with(drawn, {"lean": 12.0, "hip": Vector2(0, 7), "front_hand": Vector2(2, 6), "blade": 95.0}),
		_with(drawn, {"lean": -8.0, "hip": Vector2(0, 7), "front_hand": Vector2(-9, 2), "blade": 180.0}),
		_with(drawn, {"lean": -10.0, "hip": Vector2(0, 7), "front_hand": Vector2(-10, 2), "blade": 180.0}),
	], 10)]
	anims["scale_the_summit"] = [30.0, false, _keyframes([
		IAI,
		_with(drawn, {"lean": 32.0, "front_hand": Vector2(9, 6), "blade": 10.0}),
		_with(drawn, {"lean": 22.0, "front_hand": Vector2(7, -3), "blade": -55.0}),
		_with(drawn, {"lean": 12.0, "hip": Vector2(0, 7), "front_hand": Vector2(1, -10), "blade": -105.0}),
		_with(drawn, {"lean": 6.0, "hip": Vector2(0, 6), "front_hand": Vector2(-5, -12), "blade": SUMMIT_ANGLE}),
		_with(drawn, {"lean": 6.0, "hip": Vector2(0, 6), "front_hand": Vector2(-5, -12), "blade": SUMMIT_ANGLE}),
	], 12)]

	# --- Attacks ---
	var lunge := {"front_foot": Vector2(8, 0), "back_foot": Vector2(-7, 0)}

	anims["slash"] = [40.0, false, _keyframes([
		{"hip": Vector2(0, 2), "lean": 4.0, "front_hand": Vector2(-6, -3), "blade": -150.0, "back_hand": Vector2(-3, 6), "front_foot": Vector2(1, 0), "back_foot": Vector2(-2, 0)},
		_with(lunge, {"hip": Vector2(1, 5), "lean": 22.0, "front_hand": Vector2(10, 1), "blade": 0.0, "back_hand": Vector2(-7, 3)}),
		_with(lunge, {"hip": Vector2(1, 6), "lean": 26.0, "front_hand": Vector2(9, 5), "blade": 30.0, "back_hand": Vector2(-8, 4), "front_foot": Vector2(9, 0), "back_foot": Vector2(-8, 0)}),
	], 6)]

	anims["uppercut"] = [25.0, false, _keyframes([
		{"hip": Vector2(1, 8), "lean": 18.0, "two_hands": true, "front_hand": Vector2(5, 9), "blade": 115.0, "front_foot": Vector2(4, 0), "back_foot": Vector2(-4, 0)},
		{"hip": Vector2(1, 8), "lean": 18.0, "two_hands": true, "front_hand": Vector2(5, 9), "blade": 115.0, "front_foot": Vector2(4, 0), "back_foot": Vector2(-4, 0)},
		{"hip": Vector2(1, 3), "lean": 8.0, "two_hands": true, "front_hand": Vector2(7, 2), "blade": 20.0, "front_foot": Vector2(3, 0), "back_foot": Vector2(-3, 0)},
		{"hip": Vector2(0, -2), "lean": -10.0, "two_hands": true, "arm_in_front": true, "front_hand": Vector2(3, -14), "blade": -100.0, "front_foot": Vector2(2, -1), "back_foot": Vector2(-3, -2)},
		{"hip": Vector2(0, -2), "lean": -12.0, "two_hands": true, "arm_in_front": true, "front_hand": Vector2(2, -15), "blade": -110.0, "front_foot": Vector2(2, -1), "back_foot": Vector2(-3, -2)},
	], 7)]

	anims["chop"] = [14.0, false, _keyframes([
		{"lean": -4.0, "two_hands": true, "arm_in_front": true, "front_hand": Vector2(2, -14), "blade": -110.0},
		_with(lunge, {"hip": Vector2(1, 3), "lean": 15.0, "two_hands": true, "front_hand": Vector2(8, -2), "blade": 10.0}),
		_with(lunge, {"hip": Vector2(1, 7), "lean": 24.0, "two_hands": true, "front_hand": Vector2(7, 6), "blade": 85.0}),
	], 5)]

	anims["heavy"] = [5.0, false, _keyframes([
		{"lean": -6.0, "front_hand": Vector2(-8, -1), "blade": 180.0, "back_hand": Vector2(3, 7), "front_foot": Vector2(3, 0), "back_foot": Vector2(-3, 0)},
		_with(lunge, {"hip": Vector2(2, 4), "lean": 26.0, "front_hand": Vector2(11, 0), "blade": 0.0, "back_hand": Vector2(-8, 2), "front_foot": Vector2(9, 0), "back_foot": Vector2(-8, 0)}),
		_with(lunge, {"hip": Vector2(2, 5), "lean": 28.0, "front_hand": Vector2(9, 5), "blade": 45.0, "back_hand": Vector2(-8, 3), "front_foot": Vector2(9, 0), "back_foot": Vector2(-8, 0)}),
	], 5)]

	var tri_a := {"hip": Vector2(0, 3), "lean": 12.0, "front_hand": Vector2(7, 6), "blade": 60.0, "back_hand": Vector2(-5, 6), "front_foot": Vector2(4, 0), "back_foot": Vector2(-4, 0)}
	var tri_b := {"hip": Vector2(0, 2), "lean": 16.0, "front_hand": Vector2(8, -1), "blade": -30.0, "back_hand": Vector2(-6, 4), "front_foot": Vector2(5, 0), "back_foot": Vector2(-5, 0)}
	var tri_c := _with(lunge, {"hip": Vector2(1, 2), "lean": 22.0, "front_hand": Vector2(8, -7), "blade": -45.0, "back_hand": Vector2(-8, 3)})
	anims["tri"] = [20.0, false, [tri_a, _lerp_pose(tri_a, tri_b, 0.5), tri_b, _lerp_pose(tri_b, tri_c, 0.5), tri_c, tri_c]]

	var stride_a := {"front_foot": Vector2(6, 0), "back_foot": Vector2(-6, -3)}
	var stride_b := {"front_foot": Vector2(-5, -3), "back_foot": Vector2(5, 0)}
	anims["running_slash"] = [12.5, false, [
		_with(stride_a, {"lean": 20.0, "hip": Vector2(0, 2), "front_hand": Vector2(6, 9), "blade": 100.0}),
		_with(stride_b, {"lean": 18.0, "hip": Vector2(0, 1), "front_hand": Vector2(8, 2), "blade": 10.0}),
		_with(stride_a, {"lean": 14.0, "hip": Vector2(0, 2), "front_hand": Vector2(5, -8), "blade": -80.0}),
		_with(stride_b, {"lean": 10.0, "hip": Vector2(0, 1), "front_hand": Vector2(-1, -12), "blade": -130.0}),
		_with(stride_a, {"lean": 8.0, "hip": Vector2(0, 2), "front_hand": Vector2(-3, -12), "blade": -150.0}),
	]]

	var thrust_back := {"hip": Vector2(0, 3), "lean": -6.0, "front_hand": Vector2(-7, 1), "blade": 175.0, "back_hand": Vector2(3, 6)}
	var thrust_out := _with(lunge, {"hip": Vector2(2, 5), "lean": 28.0, "front_hand": Vector2(12, -3), "blade": -15.0, "back_hand": Vector2(-9, 0), "front_foot": Vector2(9, 0), "back_foot": Vector2(-8, 0)})
	anims["thrust"] = [12.0, false, [thrust_back, thrust_back, _lerp_pose(thrust_back, thrust_out, 0.6), thrust_out]]

	anims["throw"] = [12.0, false, _keyframes([
		{"lean": -4.0, "front_hand": Vector2(-7, -6), "open_hand": true, "back_hand": Vector2(4, 6)},
		{"hip": Vector2(1, 2), "lean": 18.0, "front_hand": Vector2(11, -3), "open_hand": true, "back_hand": Vector2(-6, 5), "front_foot": Vector2(5, 0), "back_foot": Vector2(-5, 0)},
	], 3)]

	anims["dash"] = [10.0, false, [
		{"lean": 32.0, "hip": Vector2(2, 4), "front_foot": Vector2(10, 0), "back_foot": Vector2(-10, 0), "front_hand": Vector2(-8, 4), "back_hand": Vector2(-6, 6)},
		{"lean": 34.0, "hip": Vector2(2, 5), "front_foot": Vector2(10, 0), "back_foot": Vector2(-11, -1), "front_hand": Vector2(-9, 4), "back_hand": Vector2(-7, 6)},
	]]

	anims["dive"] = [8.0, false, [
		{"lean": 45.0, "front_foot": Vector2(-8, -8), "back_foot": Vector2(-12, -4), "front_hand": Vector2(6, 6), "back_hand": Vector2(4, 8)},
		{"lean": 48.0, "front_foot": Vector2(-9, -9), "back_foot": Vector2(-13, -5), "front_hand": Vector2(7, 6), "back_hand": Vector2(5, 8)},
	]]
	return anims


## A running foot's ankle offset (from standing) at point `t` (0..1) of the cycle:
## planted from t = 0 to CONTACT, sliding back at running speed, then the swing.
static func _run_foot(t: float) -> Vector2:
	var slide := RUN_SPEED / RUN_FPS * RUN_FRAMES * CONTACT # px covered while planted
	var land_x := 7.0
	if t < CONTACT:
		return Vector2(land_x - slide * t / CONTACT, 0)
	# Swing: (t, x, lift) keys from lift-off, kicking up behind, forward to landing.
	var keys := [[CONTACT, land_x - slide, 0.0], [0.35, -12.0, 4.0], [0.5, -10.0, 7.0],
		[0.7, -2.0, 6.0], [0.85, 5.0, 3.0], [1.0, land_x, 0.0]]
	for k in keys.size() - 1:
		var a: Array = keys[k]
		var b: Array = keys[k + 1]
		if t <= b[0]:
			var s := smoothstep(0.0, 1.0, (t - a[0]) / (b[0] - a[0]))
			return Vector2(lerpf(a[1], b[1], s), -lerpf(a[2], b[2], s))
	return Vector2(land_x, 0)


## `count` frames eased smoothly through the key poses.
static func _keyframes(keys: Array, count: int) -> Array:
	var poses := []
	for i in count:
		var u := float(i) / (count - 1) * (keys.size() - 1)
		var k := mini(int(u), keys.size() - 2)
		poses.append(_lerp_pose(keys[k], keys[k + 1], smoothstep(0.0, 1.0, u - k)))
	return poses


static func _lerp_pose(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var pose := {}
	for key in a.keys() + b.keys():
		if pose.has(key):
			continue
		var va = a.get(key, DEFAULTS.get(key))
		var vb = b.get(key, DEFAULTS.get(key))
		if (va is float or va is Vector2) and typeof(va) == typeof(vb):
			pose[key] = lerp(va, vb, t)
		else:
			var chosen = vb if t >= 0.5 else va
			if chosen != null: # A setting only one side has applies from halfway.
				pose[key] = chosen
	return pose


static func _with(base: Dictionary, extra: Dictionary) -> Dictionary:
	var pose := base.duplicate()
	pose.merge(extra, true)
	return pose


# --- The skeleton ------------------------------------------------------------

## Draws one pose.
static func draw(pose: Dictionary) -> Image:
	if pose.has("flip"):
		return _draw_flip(pose.flip)
	if pose.has("front"):
		return _draw_front(pose)
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var b := _bones(pose)
	if pose.has("cape"):
		_profile_cape(img, b, pose.cape)

	var in_front: bool = pose.get("arm_in_front", false)
	var raised: bool = b.front_hand.y < b.neck.y and not in_front
	if not in_front:
		_arm(img, b.back_shoulder, b.back_hand, pose.get("back_elbow", ""), true, false)
	_leg(img, b.hip, b.back_ankle, true)
	_torso(img, b)
	_leg(img, b.hip, b.front_ankle, false)
	_sheath(img, b, pose.has("blade") or pose.get("open_hand", false))
	if raised:
		_arm(img, b.front_shoulder, b.front_hand, pose.get("front_elbow", ""), false, pose.get("open_hand", false))
	if pose.has("head_front"):
		_head_front(img, b.head + Vector2(-1, 0), pose.head_front)
	else:
		_head(img, b.head)
	if in_front:
		_arm(img, b.back_shoulder, b.back_hand, pose.get("back_elbow", ""), true, false)
	if not raised:
		_arm(img, b.front_shoulder, b.front_hand, pose.get("front_elbow", ""), false, pose.get("open_hand", false))
	if pose.has("blade"):
		_katana(img, b.front_hand, pose.blade)
	_outline(img, OUTLINE)
	if pose.has("aura"):
		_outline(img, Color(AURA, pose.aura))
	if pose.get("mirror", false):
		img.flip_x()
	return img


## Joint positions for a pose.
static func _bones(pose: Dictionary) -> Dictionary:
	var lean := deg_to_rad(pose.get("lean", 0.0))
	var up := Vector2(sin(lean), -cos(lean)) # Along the spine.
	var side := Vector2(cos(lean), sin(lean)) # Forward, across the spine.
	var hip: Vector2 = HIP + pose.get("hip", Vector2.ZERO)
	var neck: Vector2 = hip + up * (TORSO + pose.get("torso", 0.0))
	var b := {
		"up": up, "side": side, "hip": hip, "neck": neck,
		"head": neck + up * 6.0 + side,
		"front_shoulder": neck + side * 1.5 - up * 1.5,
		"back_shoulder": neck - side * 1.5 - up * 1.5,
		"front_ankle": FRONT_ANKLE + pose.get("front_foot", Vector2.ZERO),
		"back_ankle": BACK_ANKLE + pose.get("back_foot", Vector2.ZERO),
		"sheath_mouth": hip + side * 3.0 + up * 1.0,
	}
	b.front_hand = b.front_shoulder + pose.get("front_hand", DEFAULTS.front_hand)
	b.back_hand = b.back_shoulder + pose.get("back_hand", DEFAULTS.back_hand)
	var hilt: Vector2 = b.sheath_mouth + side * 3.0 + up * 1.5
	if pose.get("on_hilt", false):
		b.front_hand = hilt
	elif pose.has("hand_to_hilt"):
		b.front_hand = b.front_hand.lerp(hilt, pose.hand_to_hilt)
	if pose.get("back_on_sheath", false):
		b.back_hand = b.sheath_mouth - side * 1.5 + Vector2(0, 1)
	if pose.get("two_hands", false) and pose.has("blade"):
		b.back_hand = b.front_hand - Vector2.from_angle(deg_to_rad(pose.blade)) * 3.0
	return b


## The back of the neck, where the cloak hangs from, relative to the sprite origin.
static func _cloak_anchor(pose: Dictionary) -> Vector2:
	if pose.has("flip"):
		return Vector2.ZERO
	var b := _bones(pose)
	return b.neck - b.side * 3.0 + b.up * 0.5 - Vector2(SIZE, SIZE) / 2.0


static func _leg(img: Image, hip: Vector2, ankle: Vector2, back: bool) -> void:
	var knee := _joint(hip, ankle, THIGH, SHIN, "forward")
	var foot := knee + (ankle - knee).limit_length(SHIN)
	var color := PANTS_SHADE if back else PANTS
	_thick_line(img, hip, knee, 1.6, color)
	_thick_line(img, knee, foot, 1.3, color)
	var f := Vector2i(foot.round())
	for x in range(f.x - 1, f.x + 4):
		_put(img, x, f.y + 1, SHOES)
	for x in range(f.x - 1, f.x + 3):
		_put(img, x, f.y + 2, SHOES)


static func _torso(img: Image, b: Dictionary) -> void:
	var hip: Vector2 = b.hip
	var neck: Vector2 = b.neck
	var side: Vector2 = b.side
	var up: Vector2 = b.up
	# The robe's body, and its front flaps hanging over the thighs.
	_fill_polygon(img, [hip + side * 3.5, neck + side * 4.0, neck - side * 4.0, hip - side * 3.5], ROBE)
	var flap := [hip + side * 3.5, hip - side * 3.5, hip - side * 3.5 + Vector2(-1, 6), hip + side * 3.5 + Vector2(1, 6)]
	_fill_polygon(img, flap, ROBE)
	_trim_line(img, flap[2], flap[3])
	# Brown shirt in the open front, the trimmed front edge, and a dark sash.
	_fill_polygon(img, [hip + side * 1.0 + up * 2.0, hip + side * 3.0 + up * 2.0, neck + side * 3.2, neck + side * 1.0], SHIRT)
	_trim_line(img, hip + side * 3.5 + Vector2(1, 6), neck + side * 3.6)
	_thick_line(img, hip + up * 1.5 - side * 3.5, hip + up * 1.5 + side * 3.5, 0.8, ROBE_SHADE)
	# A fold of lighter cloth down the back.
	_thick_line(img, hip - side * 2.0 + up * 2.0, neck - side * 2.5, 0.5, ROBE_LIGHT)


static func _sheath(img: Image, b: Dictionary, drawn: bool) -> void:
	var mouth: Vector2 = b.sheath_mouth
	var tip: Vector2 = b.hip - b.side * 13.0 + Vector2(0, 5)
	_thick_line(img, mouth, tip, 0.6, SHEATH)
	_put(img, int(round(tip.x)), int(round(tip.y)), GOLD)
	if not drawn:
		_thick_line(img, mouth + b.side, mouth + b.side * 5.0 + b.up * 2.5, 0.6, HILT)
		_put(img, int(round(mouth.x + b.side.x)), int(round(mouth.y + b.side.y)), GOLD)


## A wide black sleeve (with a lighter rim), a trimmed cuff, and the hand.
static func _arm(img: Image, shoulder: Vector2, target: Vector2, elbow_mode: String, back: bool, open_hand: bool) -> void:
	var elbow := _joint(shoulder, target, UPPER_ARM, FOREARM, "up" if elbow_mode == "up" else "down")
	var hand := elbow + (target - elbow).limit_length(FOREARM)
	var rim := ROBE if back else ROBE_LIGHT
	for segment in [[shoulder, elbow, 1.7], [elbow, hand, 1.4]]:
		_thick_line(img, segment[0], segment[1], segment[2], rim)
		_thick_line(img, segment[0], segment[1], segment[2] - 0.8, ROBE_SHADE if back else ROBE)
	var cuff := hand + (elbow - hand).limit_length(1.5)
	_put(img, int(round(cuff.x)), int(round(cuff.y)), _herringbone(int(round(cuff.x)), int(round(cuff.y))))
	_disc(img, hand, 1.1, SKIN_SHADE if back else SKIN)
	if open_hand:
		var finger := hand + (hand - elbow).limit_length(2.0)
		_put(img, int(round(finger.x)), int(round(finger.y)), SKIN_SHADE)


static func _katana(img: Image, hand: Vector2, angle_degrees: float) -> void:
	var dir := Vector2.from_angle(deg_to_rad(angle_degrees))
	_thick_line(img, hand - dir * 4.0, hand, 0.6, HILT)
	_disc(img, hand, 1.0, SKIN)
	var guard := hand + dir * 1.5
	_put(img, int(round(guard.x)), int(round(guard.y)), GOLD)
	var cells := _line_cells(hand + dir * 2.5, hand + dir * (2.5 + BLADE_LENGTH))
	for i in cells.size():
		_put(img, cells[i].x, cells[i].y, BLADE_EDGE if i >= cells.size() - 2 else BLADE)


## The head in profile: hood, greying hair, a bushy brow, an open green eye, a
## nose, lines of age, and a short grey beard.
static func _head(img: Image, center: Vector2) -> void:
	var hx := int(round(center.x))
	var hy := int(round(center.y))
	# Hood over the top and back of the head.
	for y in range(hy - 8, hy + 7):
		for x in range(hx - 7, hx + 5):
			var dx := (x - (hx - 1)) / 5.6
			var dy := (y - (hy - 1)) / 6.8
			if dx * dx + dy * dy <= 1.0:
				_put(img, x, y, ROBE_SHADE if x <= hx - 5 else ROBE)
	# Face.
	for y in range(hy - 3, hy + 6):
		for x in range(hx - 1, hx + 5):
			_put(img, x, y, SKIN_SHADE if x == hx - 1 else SKIN)
	_put(img, hx + 4, hy + 5, Color(0, 0, 0, 0))
	# Hood trim around the face.
	for y in range(hy - 4, hy + 6):
		_put(img, hx - 2, y, _herringbone(hx - 2, y))
	for x in range(hx - 1, hx + 5):
		_put(img, x, hy - 4, _herringbone(x, hy - 4))
	# Greying, messy hair under the hood, with stray tufts.
	for x in range(hx - 1, hx + 5):
		_put(img, x, hy - 3, HAIR_LIGHT if (x + hy) % 2 == 0 else HAIR_GREY)
	for p in [[0, -2, HAIR_GREY], [1, -2, HAIR_DARK], [3, -2, HAIR_LIGHT], [5, -3, HAIR_GREY], [5, -4, HAIR_LIGHT], [4, -5, HAIR_GREY]]:
		_put(img, hx + p[0], hy + p[1], p[2])
	# Bushy grey eyebrow, and an open green eye (white, iris, pupil).
	for x in range(hx + 1, hx + 4):
		_put(img, x, hy - 1, HAIR_LIGHT)
	_put(img, hx + 1, hy, EYE_WHITE)
	_put(img, hx + 2, hy, EYE_GREEN)
	_put(img, hx + 3, hy, PUPIL)
	_put(img, hx + 1, hy + 1, SKIN_SHADE)
	_put(img, hx + 2, hy + 1, EYE_GREEN_DARK)
	_put(img, hx + 3, hy + 1, EYE_GREEN)
	# Crow's feet and a cheek line.
	_put(img, hx, hy, SKIN_SHADE)
	_put(img, hx, hy + 1, SKIN_SHADE)
	_put(img, hx + 2, hy + 2, SKIN_SHADE)
	# Nose.
	_put(img, hx + 5, hy + 1, SKIN)
	_put(img, hx + 5, hy + 2, SKIN)
	_put(img, hx + 4, hy + 3, SKIN_SHADE)
	# Short grey beard and moustache.
	for y in range(hy + 3, hy + 6):
		for x in range(hx, hx + 4):
			if y > hy + 3 or x >= hx + 2:
				_put(img, x, y, BEARD if (x + y) % 3 != 0 else HAIR_LIGHT)
	_put(img, hx + 4, hy + 4, SKIN_SHADE) # Mouth.


## The Stagger Break intro (30 frames): he reaches back and grabs his cape, turns away
## from the enemy sweeping it out on an extended arm, then turns half toward the
## screen (still half facing away from the enemy), lowers the cape, sits
## cross-legged, crosses his arms and closes his eyes.
static func _meditate() -> Array:
	var frames := []
	var stance := {"front_foot": Vector2(5, 0), "back_foot": Vector2(-5, 0)}
	# Reaching back over the shoulder for the cape (anticipation).
	for k in [[-4.0, 2.0, Vector2(-7, -3)], [-8.0, 3.0, Vector2(-10, -4)], [-10.0, 3.0, Vector2(-11, -5)]]:
		frames.append(_with(stance, {"lean": k[0], "hip": Vector2(0, k[1]), "front_hand": k[2],
			"front_elbow": "up", "cape": "hang"}))
	# Turned away, sweeping the cape out on an extended arm and holding the flourish.
	var sweep := [[12.0, Vector2(-9, 2)], [4.0, Vector2(-12, -1)], [-6.0, Vector2(-13, -4)],
		[-8.0, Vector2(-13, -5)], [-8.0, Vector2(-12, -5)], [-7.0, Vector2(-12, -4)], [-6.0, Vector2(-11, -3)]]
	for k in sweep:
		frames.append(_with(stance, {"lean": k[0], "hip": Vector2(0, 1), "front_hand": k[1],
			"front_elbow": "up", "arm_in_front": true, "cape": "held", "mirror": true}))
	# Facing the screen at 45 degrees: the arm (and cape) comes down...
	for out in [1.0, 0.75, 0.4, 0.0]:
		frames.append({"front": true, "mirror": true, "arm_out": out})
	# ...he sits down cross-legged, crossing his arms on the way...
	for i in 8:
		var t := smoothstep(0.0, 1.0, (i + 1) / 8.0)
		frames.append({"front": true, "mirror": true, "sit": t, "cross": clampf((t - 0.3) / 0.7, 0.0, 1.0)})
	# ...and settles, closing his eyes to concentrate.
	for eyes in [0, 0, 1, 1, 2, 2, 2, 2]:
		frames.append({"front": true, "mirror": true, "sit": 1.0, "cross": 1.0, "eyes": eyes})
	return frames


## Entering the Iai stance (16 frames): a quick rise and twist, a drop that overshoots
## into the wide stance, then the hand slowly rising to the hilt as his face turns to
## the camera and his eyes close.
static func _iai_enter() -> Array:
	var rise := {"hip": Vector2(0, -1), "lean": -10.0, "front_hand": Vector2(-6, 6), "back_hand": Vector2(-8, 5),
		"front_foot": Vector2(2, 0), "back_foot": Vector2(-2, -1)}
	var drop := {"hip": Vector2(0, 6), "lean": 25.0, "front_hand": Vector2(8, 8), "back_hand": Vector2(-4, 7),
		"front_foot": Vector2(7, 0), "back_foot": Vector2(-10, 0)}
	var overshoot := {"hip": Vector2(0, 10), "lean": 38.0, "front_hand": Vector2(6, 10), "back_on_sheath": true,
		"front_foot": Vector2(11, 0), "back_foot": Vector2(-16, 0), "head_front": 0}
	var settled := _with(IAI, {"hand_to_hilt": 0.0, "head_front": 0})
	var frames := [rise, rise, _lerp_pose(rise, drop, 0.4), _lerp_pose(rise, drop, 0.8), drop,
		_lerp_pose(drop, overshoot, 0.6), overshoot, settled]
	# The hand rises slowly to the hilt; the eyes close.
	for i in 8:
		var t := smoothstep(0.0, 1.0, (i + 1) / 8.0)
		frames.append(_with(IAI, {"hand_to_hilt": t, "head_front": 0 if i < 3 else (1 if i < 5 else 2)}))
	return frames


## A cape drawn into a profile frame, behind the body: hanging down his back from
## the neck, or ("held") swept out from the neck to the front hand and falling from it.
static func _profile_cape(img: Image, b: Dictionary, style: String) -> void:
	var anchor: Vector2 = b.neck - b.side * 3.0 + b.up * 0.5
	var points: Array
	var widths: Array
	if style == "held":
		var hand: Vector2 = b.front_hand
		points = [anchor, (anchor + hand) / 2.0 + Vector2(0, -3), hand, hand + Vector2(-3, 6), hand + Vector2(-4, 13)]
		widths = [2.0, 5.0, 3.0, 5.0, 6.5]
	else:
		points = [anchor, anchor + Vector2(-2, 7), anchor + Vector2(-3, 14), anchor + Vector2(-3, 20)]
		widths = [2.0, 3.5, 4.5, 5.5]
	_ribbon(img, points, widths)


## A cloth ribbon along `points` with half-widths `widths`: black, a herringbone trim
## down both edges and across the end.
static func _ribbon(img: Image, points: Array, widths: Array) -> void:
	var left: Array[Vector2] = []
	var right: Array[Vector2] = []
	for i in points.size():
		var before: Vector2 = points[maxi(i - 1, 0)]
		var after: Vector2 = points[mini(i + 1, points.size() - 1)]
		var normal := (after - before).normalized().orthogonal()
		left.append(points[i] + normal * widths[i])
		right.append(points[i] - normal * widths[i])
	var polygon: Array = left.duplicate()
	for i in range(points.size() - 1, -1, -1):
		polygon.append(right[i])
	_fill_polygon(img, polygon, ROBE)
	for edge in [left, right]:
		for i in range(1, edge.size() - 1):
			_trim_line(img, edge[i], edge[i + 1])
	_trim_line(img, left[-1], right[-1])


## Him seen at 45 degrees, half toward the screen and half toward his facing
## direction (right, or left with `mirror`): a narrow torso pushed to the near side,
## the face turned with the nose past the cheek, and the far eye barely showing.
## Keys (all 0..1 unless noted):
##   sit: standing (0) to sitting cross-legged on the floor (1)
##   cross: arms at his sides (0) to folded across his chest (1)
##   arm_out: the far arm held out to the side, holding the edge of the cape
##   eyes: 0 open, 1 half closed, 2 closed
##   mirror: face left instead
static func _draw_front(pose: Dictionary) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var sit: float = pose.get("sit", 0.0)
	var cross: float = pose.get("cross", 0.0)
	var out: float = pose.get("arm_out", 0.0)
	var hip_y := 41.0 + 10.0 * sit
	var neck := Vector2(33, hip_y - TORSO)
	var hip := Vector2(32, hip_y)

	# Arms: shoulders (the far one tucked in by the turn), then elbows/hands blended
	# between hanging, folded, and (far arm) held out holding the cape.
	var far_shoulder := neck + Vector2(-4, 1.5)
	var near_shoulder := neck + Vector2(5, 1.5)
	var far_elbow: Vector2 = (neck + Vector2(-5, 7)).lerp(neck + Vector2(-4.5, 7), cross)
	var far_hand: Vector2 = (neck + Vector2(-5, 12)).lerp(neck + Vector2(4, 6), cross)
	var near_elbow: Vector2 = (neck + Vector2(6, 7)).lerp(neck + Vector2(5.5, 7), cross)
	var near_hand: Vector2 = (neck + Vector2(6, 12)).lerp(neck + Vector2(-2, 6.5), cross)
	far_elbow = far_elbow.lerp(neck + Vector2(-10, 1), out)
	far_hand = far_hand.lerp(neck + Vector2(-16, -1), out)

	# Cape behind him: from the shoulders down to a hem that pools on the floor as he
	# sits; its far side follows the hand while he holds it out.
	var hem_y := lerpf(neck.y + 20.0, 58.0, sit)
	var cape_near := Vector2(lerpf(42.0, 46.0, sit), hem_y)
	var cape_far := Vector2(lerpf(21.0, 16.0, sit), hem_y).lerp(far_hand + Vector2(-1, 12), out)
	var cape_far_top: Vector2 = far_hand.lerp(neck + Vector2(-5, -1), 1.0 - out)
	var cape := [neck + Vector2(-5, -1), neck + Vector2(5, -1), cape_near, cape_far, cape_far_top]
	_fill_polygon(img, cape, ROBE)
	_trim_line(img, cape_far, cape_near)
	_trim_line(img, neck + Vector2(5, -1), cape_near)
	_trim_line(img, cape_far_top, cape_far)

	# The far arm is behind the body.
	_front_arm(img, far_shoulder, far_elbow, far_hand, true)

	# Legs: standing, then squatting with knees out, then crossed on the floor. Once
	# seated they are drawn after the robe lap, so the crossed shins show in front.
	var legs := [
		[Vector2(30, 41), Vector2(29.5, 49), Vector2(29, 57), Vector2(30, 46), Vector2(26, 48), Vector2(29, 57), Vector2(30, 51), Vector2(25, 55), Vector2(37, 57)],
		[Vector2(34, 41), Vector2(34.5, 49), Vector2(35, 57), Vector2(34, 46), Vector2(39, 48), Vector2(35, 57), Vector2(34, 51), Vector2(42, 55), Vector2(29, 57)],
	]
	var draw_legs := func() -> void:
		for leg_index in 2:
			var l: Array = legs[leg_index]
			var joints := []
			for j in 3:
				var stand_to_squat: Vector2 = l[j].lerp(l[j + 3], clampf(sit * 2.0, 0.0, 1.0))
				joints.append(stand_to_squat.lerp(l[j + 6], clampf(sit * 2.0 - 1.0, 0.0, 1.0)))
			var color := PANTS_SHADE if leg_index == 0 else PANTS
			_thick_line(img, joints[0], joints[1], 1.7, color)
			_thick_line(img, joints[1], joints[2], 1.5, color)
			_disc(img, joints[2] + Vector2(0, 1), 1.4, SHOES)
	if sit <= 0.5:
		draw_legs.call()

	# Torso, turned: narrow, with the open front (shirt, both lapels) toward the near side.
	_fill_polygon(img, [hip + Vector2(-4, 0), hip + Vector2(4, 0), neck + Vector2(5, 0), neck + Vector2(-4, 0)], ROBE)
	_fill_polygon(img, [neck + Vector2(1, 0), neck + Vector2(3.5, 0), hip + Vector2(3, -3), hip + Vector2(2, -3)], SHIRT)
	_trim_line(img, neck, hip + Vector2(1, -2))
	_trim_line(img, neck + Vector2(4, 0), hip + Vector2(3, -2))
	_thick_line(img, hip + Vector2(-4, -2), hip + Vector2(4, -2), 0.7, ROBE_SHADE)
	# Seated, the skirt of the robe lies over his lap.
	if sit > 0.5:
		var lap := [hip + Vector2(-5, -1), hip + Vector2(6, -1), hip + Vector2(9, 4), hip + Vector2(-7, 4)]
		_fill_polygon(img, lap, ROBE)
		_trim_line(img, lap[2], lap[3])
		draw_legs.call()

	# The near arm, folded over the far one.
	_front_arm(img, near_shoulder, near_elbow, near_hand, false)

	_head_front(img, neck + Vector2(0, -6), pose.get("eyes", 0))
	_outline(img, OUTLINE)
	if pose.get("mirror", false):
		img.flip_x()
	return img


static func _front_arm(img: Image, shoulder: Vector2, elbow: Vector2, hand: Vector2, far: bool) -> void:
	var rim := ROBE if far else ROBE_LIGHT
	for segment in [[shoulder, elbow, 1.7], [elbow, hand, 1.4]]:
		_thick_line(img, segment[0], segment[1], segment[2], rim)
		_thick_line(img, segment[0], segment[1], segment[2] - 0.8, ROBE_SHADE if far else ROBE)
	_disc(img, hand, 1.1, SKIN_SHADE if far else SKIN)


## The head turned 45 degrees: the back of the hood bulging behind, the face shifted
## toward the near side with the nose past the cheek, a one-pixel far eye, and a
## grey beard.
static func _head_front(img: Image, center: Vector2, eyes: int) -> void:
	var hx := int(round(center.x))
	var hy := int(round(center.y))
	for y in range(hy - 9, hy + 7):
		for x in range(hx - 9, hx + 7):
			var dx := (x - (hx - 1.5)) / 6.4
			var dy := (y - (hy - 1)) / 7.2
			if dx * dx + dy * dy <= 1.0:
				_put(img, x, y, ROBE_SHADE if x <= hx - 6 else ROBE)
	for y in range(hy - 3, hy + 6):
		for x in range(hx - 1, hx + 6):
			if (y == hy + 5 and (x == hx - 1 or x == hx + 5)) or (y == hy - 3 and x == hx + 5):
				continue
			_put(img, x, y, SKIN_SHADE if x <= hx else SKIN)
	for y in range(hy - 4, hy + 5):
		_put(img, hx - 2, y, _herringbone(hx - 2, y))
	for y in range(hy - 3, hy + 1):
		_put(img, hx + 6, y, _herringbone(hx + 6, y))
	for x in range(hx - 1, hx + 6):
		_put(img, x, hy - 4, _herringbone(x, hy - 4))
	# Greying, messy hair.
	for x in range(hx - 1, hx + 6):
		_put(img, x, hy - 3, HAIR_LIGHT if (x + hy) % 2 == 0 else HAIR_GREY)
	for p in [[0, -2, HAIR_GREY], [2, -2, HAIR_DARK], [4, -2, HAIR_LIGHT], [6, -4, HAIR_GREY], [-3, -5, HAIR_LIGHT]]:
		_put(img, hx + p[0], hy + p[1], p[2])
	# Brows: a short far one, a bushy near one.
	_put(img, hx, hy - 1, HAIR_LIGHT)
	for x in range(hx + 2, hx + 5):
		_put(img, x, hy - 1, HAIR_LIGHT)
	match eyes:
		0:
			_put(img, hx, hy, EYE_GREEN)
			_put(img, hx + 2, hy, EYE_WHITE)
			_put(img, hx + 3, hy, EYE_GREEN)
			_put(img, hx + 4, hy, PUPIL)
			_put(img, hx + 3, hy + 1, EYE_GREEN_DARK)
			_put(img, hx + 4, hy + 1, EYE_GREEN)
		1:
			for x in [hx, hx + 2, hx + 3, hx + 4]:
				_put(img, x, hy, LASH)
			_put(img, hx + 3, hy + 1, EYE_GREEN_DARK)
		_:
			for x in [hx, hx + 2, hx + 3, hx + 4]:
				_put(img, x, hy + 1, LASH)
			_put(img, hx + 1, hy, SKIN_SHADE) # The crease between the brows: concentrating.
	# Nose past the cheek, beard and moustache, mouth.
	_put(img, hx + 6, hy + 1, SKIN)
	_put(img, hx + 6, hy + 2, SKIN)
	_put(img, hx + 5, hy + 3, SKIN_SHADE)
	for y in range(hy + 3, hy + 6):
		for x in range(hx - 1, hx + 5):
			if y > hy + 3 or x >= hx + 2:
				_put(img, x, y, BEARD if (x + y) % 3 != 0 else HAIR_LIGHT)
	_put(img, hx + 3, hy + 4, SKIN_SHADE)
	_put(img, hx + 4, hy + 4, SKIN_SHADE)


## The jump: tucked into a ball wrapped in the cloak, rotated by `angle_degrees`
## (clockwise = forward for a right-facing player), with the cloak's tail trailing in
## a spiral that shows which way he's spinning.
static func _draw_flip(angle_degrees: float) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(32, 40)
	var rot := deg_to_rad(angle_degrees)
	var at := func(local: Vector2) -> Vector2: return center + local.rotated(rot)
	# Spiral tail: starts at the back of the neck and lags behind the spin.
	var start: Vector2 = at.call(Vector2(-3, -5)) - center
	var start_angle := start.angle()
	var steps := 24
	for i in steps + 1:
		var t := float(i) / steps
		var point := center + Vector2.from_angle(start_angle - t * 2.7) * (7.0 + t * 11.0)
		var radius := 3.0 - t * 2.2
		_disc(img, point, radius + 1.0, _herringbone(int(point.x), int(point.y)))
	for i in steps + 1:
		var t := float(i) / steps
		var point := center + Vector2.from_angle(start_angle - t * 2.7) * (7.0 + t * 11.0)
		_disc(img, point, 3.0 - t * 2.2, ROBE)
	# The cloak-wrapped body.
	_disc(img, center, 8.5, ROBE)
	_disc(img, at.call(Vector2(-2, 1)), 4.0, ROBE_LIGHT)
	_disc(img, at.call(Vector2(-2, 1)), 3.0, ROBE)
	# Knees, shoes and hands poking out of the cloak.
	_disc(img, at.call(Vector2(5, 3)), 2.0, PANTS)
	_disc(img, at.call(Vector2(2, 8)), 2.0, SHOES)
	_disc(img, at.call(Vector2(6, 0)), 1.2, SKIN)
	# Head: hood, a bit of face with the green eye, and grey hair.
	var head: Vector2 = at.call(Vector2(2, -7))
	_disc(img, head, 3.8, ROBE)
	var face: Vector2 = at.call(Vector2(4, -7))
	_disc(img, face, 1.6, SKIN)
	var eye: Vector2 = at.call(Vector2(4.5, -7.5))
	_put(img, int(round(eye.x)), int(round(eye.y)), EYE_GREEN)
	var hair: Vector2 = at.call(Vector2(3.5, -9.5))
	_put(img, int(round(hair.x)), int(round(hair.y)), HAIR_LIGHT)
	_outline(img, OUTLINE)
	return img


# --- Drawing helpers ---------------------------------------------------------

## Two-bone IK: where the middle joint goes so a limb from `root` reaches `target`.
## `mode` picks which of the two solutions: "forward" (max x), "up" (min y) or down.
static func _joint(root: Vector2, target: Vector2, a: float, b: float, mode: String) -> Vector2:
	var to := target - root
	var d := clampf(to.length(), 0.01, a + b - 0.01)
	var base := to.angle()
	var bend := acos(clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0))
	var j1 := root + Vector2.from_angle(base + bend) * a
	var j2 := root + Vector2.from_angle(base - bend) * a
	match mode:
		"forward":
			return j1 if j1.x >= j2.x else j2
		"up":
			return j1 if j1.y <= j2.y else j2
		_:
			return j1 if j1.y >= j2.y else j2


static func _herringbone(x: int, y: int) -> Color:
	var phase := (y + x) % 4 if x % 2 == 0 else (y - x + 64) % 4
	return TRIM[[0, 1, 2, 1][posmod(phase, 4)]]


static func _put(img: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < SIZE and y >= 0 and y < SIZE:
		img.set_pixel(x, y, color)


static func _disc(img: Image, center: Vector2, radius: float, color: Color) -> void:
	for y in range(int(floor(center.y - radius)), int(ceil(center.y + radius)) + 1):
		for x in range(int(floor(center.x - radius)), int(ceil(center.x + radius)) + 1):
			if Vector2(x + 0.5, y + 0.5).distance_to(center + Vector2(0.5, 0.5)) <= radius + 0.2:
				_put(img, x, y, color)


static func _thick_line(img: Image, a: Vector2, b: Vector2, radius: float, color: Color) -> void:
	for cell in _line_cells(a, b):
		_disc(img, Vector2(cell), radius, color)


static func _trim_line(img: Image, a: Vector2, b: Vector2) -> void:
	for cell in _line_cells(a, b):
		_put(img, cell.x, cell.y, _herringbone(cell.x, cell.y))


static func _line_cells(a: Vector2, b: Vector2) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var steps := maxi(1, int(ceil(maxf(absf(b.x - a.x), absf(b.y - a.y)))))
	for i in steps + 1:
		var cell := Vector2i(a.lerp(b, float(i) / steps).round())
		if cells.is_empty() or cells[-1] != cell:
			cells.append(cell)
	return cells


static func _fill_polygon(img: Image, points: Array, color: Color) -> void:
	var polygon := PackedVector2Array(points)
	var box := Rect2(polygon[0], Vector2.ZERO)
	for p in polygon:
		box = box.expand(p)
	for y in range(int(floor(box.position.y)), int(ceil(box.end.y)) + 1):
		for x in range(int(floor(box.position.x)), int(ceil(box.end.x)) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), polygon):
				_put(img, x, y, color)


## A 1px border just outside the silhouette.
static func _outline(img: Image, color: Color) -> void:
	var source := img.duplicate()
	for y in SIZE:
		for x in SIZE:
			if source.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.x < SIZE and n.y >= 0 and n.y < SIZE and source.get_pixel(n.x, n.y).a > 0.0:
					img.set_pixel(x, y, color)
					break
