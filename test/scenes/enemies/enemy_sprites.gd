extends RefCounted

## Sprites for the opening level's enemies, drawn in code like the player's
## (see player_sprites.gd): a big mole, a bat, and the bat's fireball. Frames are
## 64x64 facing right (flip_h for left), built once and cached. The mole's feet are
## on row 58 and the bat's body is centered.

const PlayerSprites = preload("res://scenes/player_sprites.gd")

const FUR := Color(0.42, 0.3, 0.22)
const FUR_DARK := Color(0.29, 0.2, 0.15)
const FUR_LIGHT := Color(0.56, 0.42, 0.31)
const BELLY := Color(0.62, 0.5, 0.39)
const NOSE := Color(0.96, 0.55, 0.62)
const CLAW := Color(0.94, 0.9, 0.78)
const EYE := Color(0.04, 0.04, 0.05)
const GLINT := Color(1, 1, 1)
const BAT_BODY := Color(0.27, 0.16, 0.33)
const BAT_WING := Color(0.38, 0.22, 0.45)
const BAT_WING_DARK := Color(0.24, 0.13, 0.29)
const BAT_EYE := Color(1.0, 0.25, 0.2)
const FIRE_CORE := Color(1.0, 0.96, 0.72)
const FIRE_MID := Color(1.0, 0.6, 0.15)
const FIRE_EDGE := Color(0.86, 0.2, 0.1)

static var _mole: SpriteFrames
static var _bat: SpriteFrames
static var _fireball: SpriteFrames
static var _spike: Texture2D


# --- Mole ------------------------------------------------------------------

## idle, walk (6), attack (windup, swipe, recover: 6), hurt.
static func mole_frames() -> SpriteFrames:
	if _mole == null:
		_mole = _frames({
			"idle": [3.0, true, [{}, {"bob": 1}]],
			"walk": [9.0, true, _mole_walk()],
			"attack": [12.0, false, [
				{"lean": -2.0, "hand": Vector2(46, 40)},
				{"lean": -4.0, "hand": Vector2(44, 33), "bob": -1},
				{"lean": -5.0, "hand": Vector2(42, 30), "bob": -1},
				{"lean": 5.0, "hand": Vector2(59, 47), "swipe": true},
				{"lean": 4.0, "hand": Vector2(57, 50)},
				{"lean": 1.0, "hand": Vector2(50, 50)},
			]],
			"hurt": [1.0, false, [{"lean": -4.0, "hurt": true, "hand": Vector2(44, 44)}]],
		}, _draw_mole)
	return _mole


static func _mole_walk() -> Array:
	var poses := []
	for i in 6:
		var p := TAU * i / 6.0
		poses.append({"bob": 1 if i % 3 == 1 else 0, "feet": sin(p) * 3.0,
			"hand": Vector2(48.0 + cos(p) * 2.0, 50.0 - maxf(0.0, sin(p)) * 2.0)})
	return poses


static func _draw_mole(pose: Dictionary) -> Image:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var lean: float = pose.get("lean", 0.0)
	var bob: float = pose.get("bob", 0)
	var feet: float = pose.get("feet", 0.0)
	var center := Vector2(31 + lean, 44 + bob)
	# Back feet.
	PlayerSprites._disc(img, Vector2(22 - feet, 56), 2.6, FUR_DARK)
	PlayerSprites._disc(img, Vector2(30 + feet, 56), 2.6, FUR_DARK)
	# Body: a big furry oval, shaded underneath, lighter across the back.
	for y in range(int(center.y) - 14, int(center.y) + 14):
		for x in range(int(center.x) - 20, int(center.x) + 20):
			var d := Vector2((x - center.x) / 18.5, (y - center.y) / 12.5)
			if d.length_squared() <= 1.0:
				var color := FUR
				if d.y > 0.45:
					color = FUR_DARK
				elif d.y < -0.55 and d.x > -0.6:
					color = FUR_LIGHT
				elif (x + y) % 5 == 0:
					color = FUR_DARK # Rough fur texture.
				PlayerSprites._put(img, x, y, color)
	PlayerSprites._fill_polygon(img, [center + Vector2(4, 4), center + Vector2(14, 2), center + Vector2(12, 10), center + Vector2(2, 11)], BELLY)
	# Snout, nose, whiskers, eye.
	var snout := center + Vector2(17, -1)
	for y in range(int(snout.y) - 4, int(snout.y) + 5):
		for x in range(int(snout.x) - 6, int(snout.x) + 7):
			var d := Vector2((x - snout.x) / 6.5, (y - snout.y) / 4.2)
			if d.length_squared() <= 1.0:
				PlayerSprites._put(img, x, y, FUR_LIGHT)
	PlayerSprites._disc(img, snout + Vector2(6, -1), 2.2, NOSE)
	for w in [Vector2(9, -3), Vector2(10, 1), Vector2(9, 3)]:
		PlayerSprites._thick_line(img, snout + Vector2(2, 0), snout + w, 0.1, FUR_DARK)
	var eye := center + Vector2(12, -6)
	if pose.get("hurt", false):
		for o in [Vector2(-1, -1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2.ZERO]:
			PlayerSprites._put(img, int(eye.x + o.x), int(eye.y + o.y), EYE)
	else:
		PlayerSprites._put(img, int(eye.x), int(eye.y), EYE)
		PlayerSprites._put(img, int(eye.x) + 1, int(eye.y), EYE)
		PlayerSprites._put(img, int(eye.x), int(eye.y) - 1, GLINT)
	# Front arm and its big digging claws.
	var shoulder := center + Vector2(10, 4)
	var hand: Vector2 = pose.get("hand", Vector2(48, 50))
	PlayerSprites._thick_line(img, shoulder, hand, 2.6, FUR_DARK)
	PlayerSprites._thick_line(img, shoulder, hand, 1.6, FUR)
	var reach := (hand - shoulder).normalized()
	for spread in [-0.5, 0.0, 0.5]:
		var tip := hand + reach.rotated(spread) * 5.5
		PlayerSprites._thick_line(img, hand, tip, 0.6, CLAW)
	if pose.get("swipe", false):
		# Motion streaks behind the swipe.
		for k in 3:
			PlayerSprites._thick_line(img, hand + Vector2(-10 + k * 2, -12 + k * 4), hand + Vector2(-2, -4 + k * 4), 0.3, Color(1, 1, 1, 0.7))
	PlayerSprites._outline(img, PlayerSprites.OUTLINE)
	return img


# --- Bat -------------------------------------------------------------------

## fly (4 flaps), spit (2).
static func bat_frames() -> SpriteFrames:
	if _bat == null:
		_bat = _frames({
			"fly": [10.0, true, [{"wing": -1.0}, {"wing": 0.0}, {"wing": 1.0}, {"wing": 0.0}]],
			"spit": [10.0, false, [{"wing": -0.5, "spit": true}, {"wing": 0.3, "spit": true}]],
		}, _draw_bat)
	return _bat


static func _draw_bat(pose: Dictionary) -> Image:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var wing: float = pose.get("wing", 0.0) # -1 up, 0 level, 1 down
	var body := Vector2(32, 32)
	for side in [-1.0, 1.0]:
		var shoulder := body + Vector2(4.0 * side, -2)
		var tip := body + Vector2(21.0 * side, -2 + wing * 11.0)
		var elbow := body + Vector2(12.0 * side, -6 + wing * 5.0)
		var trail := body + Vector2(14.0 * side, 5 + wing * 6.0)
		PlayerSprites._fill_polygon(img, [shoulder, elbow, tip, trail, body + Vector2(5.0 * side, 4)], BAT_WING)
		PlayerSprites._thick_line(img, shoulder, elbow, 0.5, BAT_WING_DARK)
		PlayerSprites._thick_line(img, elbow, tip, 0.4, BAT_WING_DARK)
		PlayerSprites._thick_line(img, elbow, trail, 0.3, BAT_WING_DARK)
	for y in range(26, 39):
		for x in range(26, 39):
			var d := Vector2((x - body.x) / 5.2, (y - body.y) / 6.3)
			if d.length_squared() <= 1.0:
				PlayerSprites._put(img, x, y, BAT_BODY)
	# Ears, eyes, fangs.
	PlayerSprites._fill_polygon(img, [Vector2(28, 28), Vector2(29, 22), Vector2(31, 27)], BAT_BODY)
	PlayerSprites._fill_polygon(img, [Vector2(33, 27), Vector2(35, 22), Vector2(36, 28)], BAT_BODY)
	PlayerSprites._put(img, 33, 30, BAT_EYE)
	PlayerSprites._put(img, 35, 30, BAT_EYE)
	if pose.get("spit", false):
		PlayerSprites._disc(img, Vector2(35, 34), 1.4, FIRE_MID)
		PlayerSprites._put(img, 35, 34, FIRE_CORE)
	else:
		PlayerSprites._put(img, 34, 34, CLAW)
		PlayerSprites._put(img, 36, 34, CLAW)
	PlayerSprites._outline(img, PlayerSprites.OUTLINE)
	return img


# --- Fireball --------------------------------------------------------------

## A flickering fireball with a short tail pointing left (rotate it to its heading).
static func fireball_frames() -> SpriteFrames:
	if _fireball == null:
		_fireball = SpriteFrames.new()
		_fireball.set_animation_speed(&"default", 14.0)
		for flicker in [0.0, 0.6, 1.2]:
			var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
			var c := Vector2(9, 8)
			for i in 4:
				var t := c + Vector2(-3.5 - i * 1.6, sin(flicker + i) * 0.8)
				_soft_disc(img, t, 2.4 - i * 0.5, Color(FIRE_EDGE, 0.8 - i * 0.18))
			_soft_disc(img, c, 5.0 + sin(flicker) * 0.4, FIRE_EDGE)
			_soft_disc(img, c, 3.8, FIRE_MID)
			_soft_disc(img, c + Vector2(0.5, -0.3), 2.0, FIRE_CORE)
			_fireball.add_frame(&"default", ImageTexture.create_from_image(img))
	return _fireball


# --- Earth spike -------------------------------------------------------------

const ROCK := Color(0.47, 0.38, 0.3)
const ROCK_LIGHT := Color(0.62, 0.52, 0.41)
const ROCK_DARK := Color(0.3, 0.24, 0.19)

## A jagged rock spike, point up, its base on the bottom row (16x34).
static func earth_spike_texture() -> Texture2D:
	if _spike == null:
		var img := Image.create(16, 34, false, Image.FORMAT_RGBA8)
		for y in range(1, 34):
			var half := 0.6 + (y - 1) / 32.0 * 6.6
			# A couple of notches along the edges.
			if y in [12, 13, 22]:
				half -= 1.0
			for x in 16:
				var dx := x + 0.5 - 8.0
				if absf(dx) > half:
					continue
				var color := ROCK
				if dx < -half * 0.35:
					color = ROCK_LIGHT
				elif dx > half * 0.4:
					color = ROCK_DARK
				img.set_pixel(x, y, color)
		# Cracks.
		for crack in [[Vector2i(7, 15), Vector2i(1, 1)], [Vector2i(9, 25), Vector2i(-1, 1)]]:
			var p: Vector2i = crack[0]
			for i in 4:
				img.set_pixel(p.x, p.y, ROCK_DARK)
				p += crack[1] if i % 2 == 0 else Vector2i(0, 1)
		_outline_any(img, PlayerSprites.OUTLINE)
		_spike = ImageTexture.create_from_image(img)
	return _spike


## A 1px border just outside the silhouette, for an image of any size.
static func _outline_any(img: Image, color: Color) -> void:
	var source := img.duplicate()
	var size := img.get_size()
	for y in size.y:
		for x in size.x:
			if source.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.x < size.x and n.y >= 0 and n.y < size.y and source.get_pixel(n.x, n.y).a > 0.0:
					img.set_pixel(x, y, color)
					break


static func _soft_disc(img: Image, center: Vector2, radius: float, color: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			if Vector2(x + 0.5, y + 0.5).distance_to(center) <= radius:
				img.set_pixel(x, y, color)


static func _frames(animations: Dictionary, drawer: Callable) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim in animations:
		var spec: Array = animations[anim]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, spec[0])
		frames.set_animation_loop(anim, spec[1])
		for pose in spec[2]:
			frames.add_frame(anim, ImageTexture.create_from_image(drawer.call(pose)))
	return frames
