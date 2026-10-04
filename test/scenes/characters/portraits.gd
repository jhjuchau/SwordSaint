extends RefCounted

## Character select portraits: pixel-art busts (100x110), drawn in code like the rest of
## the art and cached. The Sword Saint, hooded, grey-bearded and green-eyed with his
## katana over his shoulder, against the storm; Dogood, bald with long grey-brown hair
## and round spectacles, broad bare shoulders under a red cape, with a kite and a
## lightning bolt behind him.

const W := 100
const H := 110
const OUTLINE := Color(0.05, 0.04, 0.07)

static var _cache := {}


static func portrait(character: String) -> Texture2D:
	if not _cache.has(character):
		var figure := Image.create(W, H, false, Image.FORMAT_RGBA8)
		var back := Image.create(W, H, false, Image.FORMAT_RGBA8)
		if character == "dogood":
			_dogood_background(back)
			_dogood(figure)
		elif character == "elf":
			_elf_background(back)
			_elf(figure)
		else:
			_saint_background(back)
			_saint(figure)
		_outline(figure)
		back.blend_rect(figure, Rect2i(0, 0, W, H), Vector2i.ZERO)
		_cache[character] = ImageTexture.create_from_image(back)
	return _cache[character]


# --- The Sword Saint --------------------------------------------------------------

const ROBE := Color(0.11, 0.11, 0.14)
const ROBE_LIGHT := Color(0.24, 0.25, 0.32)
const TRIM := [Color(0.42, 0.66, 1.0), Color(0.24, 0.43, 0.88), Color(0.12, 0.22, 0.58)]
const SAINT_SKIN := Color(0.96, 0.8, 0.68)
const SAINT_SHADE := Color(0.8, 0.62, 0.52)
const SAINT_DEEP := Color(0.62, 0.45, 0.38)
const GREY := Color(0.62, 0.62, 0.62)
const GREY_LIGHT := Color(0.86, 0.86, 0.84)
const GREY_DARK := Color(0.42, 0.4, 0.4)
const GREEN := Color(0.3, 0.82, 0.38)
const GREEN_DARK := Color(0.12, 0.5, 0.22)


static func _saint_background(img: Image) -> void:
	_gradient(img, Color(0.16, 0.19, 0.3), Color(0.05, 0.06, 0.1))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 26:
		var p := Vector2(rng.randf_range(0, W), rng.randf_range(0, H))
		_line(img, p, p + Vector2(-2, 7), 0.3, Color(0.6, 0.7, 0.9, 0.35))
	# Distant ridges.
	_polygon(img, [Vector2(0, 80), Vector2(22, 66), Vector2(40, 74), Vector2(66, 60), Vector2(100, 72), Vector2(100, 110), Vector2(0, 110)], Color(0.1, 0.11, 0.17))


static func _saint(img: Image) -> void:
	# The katana over his shoulder: hilt wrapped in red diamonds, gold guard.
	_line(img, Vector2(84, 6), Vector2(64, 40), 2.6, Color(0.2, 0.2, 0.26))
	for i in 5:
		var p := Vector2(84, 6).lerp(Vector2(66, 37), (i + 0.5) / 5.0)
		_disc(img, p, 1.2, Color(0.66, 0.14, 0.14))
	_disc(img, Vector2(64, 41), 4.0, Color(0.62, 0.48, 0.18))
	_disc(img, Vector2(64, 41), 2.6, Color(0.86, 0.7, 0.3))
	# Robe over the shoulders, open at the front over a brown shirt.
	_polygon(img, [Vector2(4, 110), Vector2(10, 84), Vector2(28, 72), Vector2(72, 72), Vector2(90, 84), Vector2(96, 110)], ROBE)
	_polygon(img, [Vector2(16, 110), Vector2(20, 88), Vector2(30, 80), Vector2(26, 110)], ROBE_LIGHT)
	_polygon(img, [Vector2(44, 74), Vector2(58, 74), Vector2(62, 110), Vector2(40, 110)], Color(0.56, 0.36, 0.2))
	_trim(img, Vector2(44, 74), Vector2(40, 110))
	_trim(img, Vector2(58, 74), Vector2(62, 110))
	# Neck, then the hood around the head.
	_polygon(img, [Vector2(43, 60), Vector2(58, 60), Vector2(57, 76), Vector2(44, 76)], SAINT_SHADE)
	_ellipse(img, Vector2(50, 44), Vector2(27, 31), ROBE)
	_ellipse(img, Vector2(47, 40), Vector2(22, 25), ROBE_LIGHT)
	_ellipse(img, Vector2(51, 46), Vector2(20, 24), ROBE)
	# Herringbone trim round the face opening.
	for i in 64:
		var a := TAU * i / 64.0
		var p := Vector2(52, 48) + Vector2(cos(a) * 17.5, sin(a) * 21.5)
		if p.y < 70:
			_put(img, int(p.x), int(p.y), TRIM[i % 3])
	# The face, shaded on the hood side.
	_ellipse(img, Vector2(52, 50), Vector2(15, 19), SAINT_SKIN)
	_polygon(img, [Vector2(37, 40), Vector2(42, 34), Vector2(43, 66), Vector2(38, 60)], SAINT_SHADE)
	# Grey hair escaping the hood.
	for i in 9:
		var x := 41 + i * 3
		_line(img, Vector2(x, 31), Vector2(x - 1 + (i % 3), 37 + (i % 2) * 2), 0.6, GREY_LIGHT if i % 2 == 0 else GREY)
	# Bushy grey brows, green eyes, lines of age.
	_line(img, Vector2(42, 45), Vector2(49, 44), 0.8, GREY_LIGHT)
	_line(img, Vector2(55, 44), Vector2(62, 45), 0.8, GREY_LIGHT)
	for eye in [Vector2(46, 48), Vector2(58, 48)]:
		_rect(img, Rect2(eye.x - 2, eye.y, 5, 2), Color(0.96, 0.96, 0.92))
		_rect(img, Rect2(eye.x, eye.y, 2, 2), GREEN)
		_put(img, int(eye.x) + 1, int(eye.y), Color(0.04, 0.12, 0.06))
		_put(img, int(eye.x), int(eye.y) + 1, GREEN_DARK)
		_put(img, int(eye.x) + 3, int(eye.y) + 2, SAINT_DEEP)
	_line(img, Vector2(43, 51), Vector2(41, 53), 0.3, SAINT_DEEP)
	_line(img, Vector2(63, 51), Vector2(64, 53), 0.3, SAINT_DEEP)
	# Nose.
	_line(img, Vector2(53, 49), Vector2(55, 56), 0.5, SAINT_SHADE)
	_rect(img, Rect2(52, 57, 4, 1), SAINT_DEEP)
	# Short grey beard and moustache, the mouth set and stern.
	_polygon(img, [Vector2(39, 58), Vector2(45, 59), Vector2(52, 61), Vector2(60, 59), Vector2(66, 57), Vector2(64, 66), Vector2(57, 72), Vector2(47, 72), Vector2(40, 66)], GREY)
	for i in 10:
		_line(img, Vector2(41 + i * 2.4, 60), Vector2(42 + i * 2.2, 70), 0.3, GREY_LIGHT if i % 2 == 0 else GREY_DARK)
	_line(img, Vector2(47, 62), Vector2(58, 62), 0.5, Color(0.3, 0.2, 0.18))


static func _trim(img: Image, a: Vector2, b: Vector2) -> void:
	var steps := int(a.distance_to(b))
	for i in steps:
		var p := a.lerp(b, float(i) / steps)
		for dx in [-1, 0, 1]:
			_put(img, int(p.x) + dx, int(p.y), TRIM[posmod(i + dx * 2, 3)])


# --- Dogood -----------------------------------------------------------------------

const SKIN := Color(0.93, 0.74, 0.6)
const SKIN_LIGHT := Color(1.0, 0.87, 0.75)
const SKIN_SHADE := Color(0.78, 0.56, 0.44)
const SKIN_DEEP := Color(0.6, 0.4, 0.32)
const HAIR := Color(0.6, 0.52, 0.44)
const HAIR_LIGHT := Color(0.78, 0.72, 0.64)
const HAIR_DARK := Color(0.42, 0.36, 0.3)
const CAPE := Color(0.74, 0.1, 0.1)
const CAPE_DARK := Color(0.5, 0.06, 0.07)
const GOLD := Color(0.95, 0.78, 0.3)
const GOLD_DARK := Color(0.7, 0.52, 0.16)


static func _dogood_background(img: Image) -> void:
	_gradient(img, Color(0.38, 0.14, 0.1), Color(0.1, 0.04, 0.06))
	# A kite flying in the storm, on a long string...
	_polygon(img, [Vector2(16, 8), Vector2(24, 16), Vector2(16, 28), Vector2(8, 16)], Color(0.92, 0.88, 0.76))
	_polygon(img, [Vector2(16, 8), Vector2(24, 16), Vector2(16, 16)], Color(0.8, 0.18, 0.16))
	_polygon(img, [Vector2(16, 16), Vector2(8, 16), Vector2(16, 28)], Color(0.8, 0.18, 0.16))
	_line(img, Vector2(16, 28), Vector2(30, 70), 0.3, Color(0.9, 0.86, 0.8, 0.7))
	# ...and the lightning it called down.
	var bolt := [Vector2(88, 0), Vector2(80, 14), Vector2(86, 16), Vector2(74, 34), Vector2(80, 35), Vector2(70, 52)]
	for i in bolt.size() - 1:
		_line(img, bolt[i], bolt[i + 1], 2.2, Color(1.0, 0.95, 0.6, 0.35))
		_line(img, bolt[i], bolt[i + 1], 0.8, Color(1.0, 1.0, 0.9))


static func _dogood(img: Image) -> void:
	# The cape around his shoulders, gold-trimmed, clasped with a gold chain.
	_polygon(img, [Vector2(0, 110), Vector2(6, 78), Vector2(26, 66), Vector2(74, 66), Vector2(94, 78), Vector2(100, 110)], CAPE)
	_polygon(img, [Vector2(0, 110), Vector2(6, 78), Vector2(16, 72), Vector2(12, 110)], CAPE_DARK)
	_polygon(img, [Vector2(100, 110), Vector2(94, 78), Vector2(84, 72), Vector2(88, 110)], CAPE_DARK)
	_line(img, Vector2(6, 78), Vector2(26, 66), 0.9, GOLD)
	_line(img, Vector2(74, 66), Vector2(94, 78), 0.9, GOLD)
	# Broad bare shoulders and chest.
	_polygon(img, [Vector2(14, 110), Vector2(18, 86), Vector2(32, 72), Vector2(68, 72), Vector2(82, 86), Vector2(86, 110)], SKIN)
	_polygon(img, [Vector2(14, 110), Vector2(18, 86), Vector2(30, 76), Vector2(26, 110)], SKIN_SHADE)
	_line(img, Vector2(30, 98), Vector2(48, 102), 0.8, SKIN_SHADE) # Pecs.
	_line(img, Vector2(52, 102), Vector2(72, 98), 0.8, SKIN_SHADE)
	_line(img, Vector2(50, 84), Vector2(50, 108), 0.5, SKIN_SHADE)
	_line(img, Vector2(66, 84), Vector2(74, 92), 0.6, SKIN_LIGHT)
	for p in [Vector2(44, 92), Vector2(47, 95), Vector2(54, 93), Vector2(57, 96), Vector2(50, 90)]:
		_put(img, int(p.x), int(p.y), HAIR_LIGHT)
	_disc(img, Vector2(30, 76), 3.0, GOLD_DARK)
	_disc(img, Vector2(30, 76), 2.0, GOLD)
	_disc(img, Vector2(70, 76), 3.0, GOLD_DARK)
	_disc(img, Vector2(70, 76), 2.0, GOLD)
	for i in 9:
		var p := Vector2(30, 76).lerp(Vector2(70, 76), (i + 0.5) / 9.0) + Vector2(0, sin(PI * (i + 0.5) / 9.0) * 6.0)
		_disc(img, p, 1.0, GOLD if i % 2 == 0 else GOLD_DARK)
	# A thick neck, then long hair falling to his shoulders on both sides.
	_polygon(img, [Vector2(38, 58), Vector2(62, 58), Vector2(66, 76), Vector2(34, 76)], SKIN_SHADE)
	_polygon(img, [Vector2(28, 36), Vector2(36, 34), Vector2(40, 64), Vector2(36, 78), Vector2(26, 76), Vector2(24, 56)], HAIR)
	_polygon(img, [Vector2(72, 36), Vector2(64, 34), Vector2(62, 64), Vector2(66, 78), Vector2(76, 76), Vector2(76, 56)], HAIR)
	for i in 5:
		_line(img, Vector2(27 + i * 2, 40), Vector2(26 + i * 2.2, 74), 0.4, HAIR_LIGHT if i % 2 == 0 else HAIR_DARK)
		_line(img, Vector2(66 + i * 2, 40), Vector2(66 + i * 2.2, 74), 0.4, HAIR_LIGHT if i % 2 == 1 else HAIR_DARK)
	# The head: a big bald dome with a shine, a strong jaw and a hint of jowl.
	_ellipse(img, Vector2(50, 44), Vector2(17, 21), SKIN)
	_polygon(img, [Vector2(35, 52), Vector2(65, 52), Vector2(62, 64), Vector2(54, 68), Vector2(46, 68), Vector2(38, 64)], SKIN)
	_ellipse(img, Vector2(44, 30), Vector2(7, 4), SKIN_LIGHT)
	_line(img, Vector2(39, 64), Vector2(46, 69), 0.5, SKIN_SHADE)
	_line(img, Vector2(61, 64), Vector2(54, 69), 0.5, SKIN_SHADE)
	_polygon(img, [Vector2(33, 40), Vector2(37, 36), Vector2(37, 62), Vector2(34, 56)], SKIN_SHADE)
	# Bushy brows, then the little round spectacles (one catching the light).
	_line(img, Vector2(39, 40), Vector2(47, 39), 1.0, HAIR_DARK)
	_line(img, Vector2(53, 39), Vector2(61, 40), 1.0, HAIR_DARK)
	for eye in [Vector2(43, 46), Vector2(57, 46)]:
		_disc(img, eye, 4.4, GOLD)
		_disc(img, eye, 3.4, Color(0.8, 0.92, 1.0))
		_rect(img, Rect2(eye.x - 1, eye.y - 1, 3, 2), Color(0.96, 0.96, 0.94))
		_rect(img, Rect2(eye.x, eye.y - 1, 1, 2), Color(0.2, 0.28, 0.38))
	_line(img, Vector2(47.5, 45), Vector2(52.5, 45), 0.4, GOLD)
	_line(img, Vector2(38.6, 45), Vector2(34, 44), 0.4, GOLD)
	_line(img, Vector2(61.4, 45), Vector2(66, 44), 0.4, GOLD)
	_line(img, Vector2(55, 43), Vector2(58, 46), 0.3, Color(1, 1, 1))
	# A big, rounded nose and a confident half-grin.
	_line(img, Vector2(50, 47), Vector2(52, 55), 0.6, SKIN_SHADE)
	_disc(img, Vector2(51, 56), 2.4, SKIN)
	_put(img, 49, 57, SKIN_DEEP)
	_put(img, 53, 57, SKIN_DEEP)
	_line(img, Vector2(45, 61), Vector2(55, 61), 0.5, Color(0.42, 0.16, 0.14))
	_line(img, Vector2(55, 61), Vector2(58, 59), 0.5, Color(0.42, 0.16, 0.14))
	_rect(img, Rect2(48, 61, 6, 1), Color(0.98, 0.96, 0.9))
	_line(img, Vector2(44, 58), Vector2(43, 62), 0.3, SKIN_SHADE)


# --- Ilyra -------------------------------------------------------------------------

const ELF_SKIN := Color(0.98, 0.86, 0.78)
const ELF_SHADE := Color(0.86, 0.68, 0.62)
const ELF_DEEP := Color(0.7, 0.5, 0.48)
const ELF_HAIR := Color(0.14, 0.62, 0.42)
const ELF_HAIR_LIGHT := Color(0.4, 0.86, 0.6)
const ELF_HAIR_DARK := Color(0.07, 0.38, 0.26)
const VIOLET := Color(0.46, 0.2, 0.66)
const VIOLET_LIGHT := Color(0.66, 0.38, 0.86)
const VIOLET_DARK := Color(0.28, 0.1, 0.42)
const EMERALD := Color(0.3, 0.84, 0.46)
const EMERALD_DARK := Color(0.12, 0.5, 0.28)
const ORB_GLOW := Color(0.55, 1.0, 0.7)
const ELF_GOLD := Color(0.98, 0.82, 0.32)
const LASHES := Color(0.1, 0.06, 0.14)
const ELF_LIPS := Color(0.74, 0.3, 0.5)


static func _elf_background(img: Image) -> void:
	_gradient(img, Color(0.22, 0.1, 0.32), Color(0.06, 0.03, 0.1))
	_disc(img, Vector2(16, 18), 9.0, Color(0.9, 0.95, 0.85, 0.85)) # The moon,
	_disc(img, Vector2(20, 15), 8.0, Color(0.2, 0.09, 0.3)) # a crescent.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 22: # Drifting motes of magic.
		var p := Vector2(rng.randf_range(0, W), rng.randf_range(0, H))
		var mote := Color(0.5, 1.0, 0.65, rng.randf_range(0.4, 0.9)) if i % 3 != 0 else Color(0.85, 0.6, 1.0, 0.8)
		_put(img, int(p.x), int(p.y), mote)


static func _elf(img: Image) -> void:
	# The staff behind her shoulder, its orb blazing.
	_line(img, Vector2(92, 110), Vector2(82, 30), 1.6, Color(0.46, 0.3, 0.18))
	_line(img, Vector2(82, 30), Vector2(78, 24), 0.8, EMERALD_DARK)
	_line(img, Vector2(82, 30), Vector2(87, 24), 0.8, EMERALD_DARK)
	_disc(img, Vector2(82, 18), 9.0, Color(ORB_GLOW, 0.25))
	_disc(img, Vector2(82, 18), 6.0, Color(ORB_GLOW, 0.35))
	_disc(img, Vector2(82, 18), 4.0, Color(0.6, 1.0, 0.7))
	_disc(img, Vector2(83, 19), 1.8, Color(0.85, 0.6, 1.0))
	_put(img, 80, 16, Color(1, 1, 1))
	# Long hair falling behind her shoulders.
	_polygon(img, [Vector2(30, 46), Vector2(40, 46), Vector2(40, 96), Vector2(26, 104), Vector2(22, 80)], ELF_HAIR)
	_polygon(img, [Vector2(60, 46), Vector2(70, 46), Vector2(78, 80), Vector2(74, 104), Vector2(60, 96)], ELF_HAIR)
	for i in 4:
		_line(img, Vector2(28 + i * 3, 50), Vector2(25 + i * 3.5, 100), 0.4, ELF_HAIR_LIGHT if i % 2 == 0 else ELF_HAIR_DARK)
		_line(img, Vector2(63 + i * 3, 50), Vector2(64 + i * 3.4, 100), 0.4, ELF_HAIR_LIGHT if i % 2 == 1 else ELF_HAIR_DARK)
	# Bare shoulders, then the bodice with its green-trimmed neckline and a gold gem.
	_polygon(img, [Vector2(14, 110), Vector2(18, 92), Vector2(34, 82), Vector2(66, 82), Vector2(82, 92), Vector2(86, 110)], ELF_SKIN)
	_line(img, Vector2(38, 88), Vector2(48, 90), 0.4, ELF_SHADE) # Collarbones.
	_line(img, Vector2(52, 90), Vector2(62, 88), 0.4, ELF_SHADE)
	var neckline := [Vector2(18, 98), Vector2(30, 96), Vector2(42, 100), Vector2(50, 104), Vector2(58, 100), Vector2(70, 96), Vector2(82, 98)]
	_polygon(img, [Vector2(14, 110)] + neckline + [Vector2(86, 110)], VIOLET)
	_polygon(img, [Vector2(14, 110), Vector2(18, 98), Vector2(26, 97), Vector2(24, 110)], VIOLET_DARK)
	for i in neckline.size() - 1:
		_line(img, neckline[i], neckline[i + 1], 0.8, EMERALD)
	_disc(img, Vector2(50, 105), 1.6, ELF_GOLD)
	_line(img, Vector2(34, 104), Vector2(40, 107), 0.6, VIOLET_LIGHT)
	_line(img, Vector2(60, 107), Vector2(66, 104), 0.6, VIOLET_LIGHT)
	# Neck, long pointed ears, and the face.
	_polygon(img, [Vector2(44, 66), Vector2(56, 66), Vector2(57, 84), Vector2(43, 84)], ELF_SHADE)
	_polygon(img, [Vector2(37, 52), Vector2(18, 38), Vector2(37, 60)], ELF_SKIN)
	_polygon(img, [Vector2(63, 52), Vector2(82, 38), Vector2(63, 60)], ELF_SKIN)
	_line(img, Vector2(35, 54), Vector2(23, 42), 0.4, ELF_DEEP)
	_line(img, Vector2(65, 54), Vector2(77, 42), 0.4, ELF_DEEP)
	_ellipse(img, Vector2(50, 55), Vector2(14, 17), ELF_SKIN)
	_polygon(img, [Vector2(38, 62), Vector2(62, 62), Vector2(54, 72), Vector2(46, 72)], ELF_SKIN)
	_polygon(img, [Vector2(36, 50), Vector2(39, 46), Vector2(40, 66), Vector2(37, 60)], ELF_SHADE)
	# Big green eyes with lashes and a sparkle, a blush, and a knowing smile.
	for eye in [Vector2(44, 55), Vector2(57, 55)]:
		_ellipse(img, eye, Vector2(3.5, 2.6), Color(0.98, 0.98, 0.96))
		_ellipse(img, eye + Vector2(0.5, 0.2), Vector2(2.2, 2.4), Color(0.3, 0.86, 0.5))
		_disc(img, eye + Vector2(0.6, 0.4), 1.1, Color(0.05, 0.2, 0.12))
		_put(img, int(eye.x), int(eye.y) - 1, Color(1, 1, 1))
		_line(img, eye + Vector2(-4, -2.5), eye + Vector2(4, -3), 0.6, LASHES)
		_line(img, eye + Vector2(4, -3), eye + Vector2(5.5, -4.5), 0.4, LASHES)
	_line(img, Vector2(40, 50), Vector2(47, 49), 0.4, ELF_HAIR_DARK)
	_line(img, Vector2(54, 49), Vector2(61, 50), 0.4, ELF_HAIR_DARK)
	_disc(img, Vector2(41, 61), 1.8, Color(0.98, 0.62, 0.66, 0.6))
	_disc(img, Vector2(60, 61), 1.8, Color(0.98, 0.62, 0.66, 0.6))
	_line(img, Vector2(50, 58), Vector2(51, 62), 0.4, ELF_SHADE)
	_line(img, Vector2(46, 66), Vector2(54, 66), 0.5, ELF_LIPS)
	_line(img, Vector2(54, 66), Vector2(56, 64), 0.5, ELF_LIPS)
	_put(img, 50, 67, Color(0.85, 0.45, 0.6))
	# Emerald bangs under the hat.
	_polygon(img, [Vector2(35, 40), Vector2(65, 40), Vector2(66, 50), Vector2(60, 46), Vector2(56, 51), Vector2(51, 45), Vector2(46, 50),
		Vector2(42, 45), Vector2(37, 52), Vector2(34, 46)], ELF_HAIR)
	_line(img, Vector2(44, 42), Vector2(42, 47), 0.4, ELF_HAIR_LIGHT)
	_line(img, Vector2(56, 42), Vector2(58, 48), 0.4, ELF_HAIR_LIGHT)
	# The hat: a tall cone kinking over to the side, a green band and buckle, and a
	# wide drooping brim.
	_polygon(img, [Vector2(34, 40), Vector2(40, 20), Vector2(50, 8), Vector2(66, 4), Vector2(74, 10), Vector2(60, 12), Vector2(58, 24), Vector2(66, 40)], VIOLET)
	_polygon(img, [Vector2(34, 40), Vector2(40, 20), Vector2(50, 8), Vector2(46, 22), Vector2(44, 40)], VIOLET_DARK)
	_line(img, Vector2(56, 16), Vector2(60, 34), 0.5, VIOLET_LIGHT)
	_disc(img, Vector2(74, 10), 1.5, ELF_GOLD)
	_polygon(img, [Vector2(35, 34), Vector2(65, 34), Vector2(66, 39), Vector2(34, 39)], EMERALD)
	_rect(img, Rect2(55, 34, 5, 5), ELF_GOLD)
	_rect(img, Rect2(56, 35, 3, 3), EMERALD)
	_polygon(img, [Vector2(6, 46), Vector2(20, 38), Vector2(50, 36), Vector2(80, 38), Vector2(94, 46), Vector2(80, 44), Vector2(50, 42), Vector2(20, 44)], VIOLET)
	_line(img, Vector2(6, 46), Vector2(20, 44), 0.5, VIOLET_DARK)
	_line(img, Vector2(20, 44), Vector2(80, 44), 0.5, VIOLET_DARK)
	_line(img, Vector2(80, 44), Vector2(94, 46), 0.5, VIOLET_DARK)


# --- Helpers -----------------------------------------------------------------------

static func _put(img: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < W and y >= 0 and y < H:
		if color.a < 1.0:
			img.set_pixel(x, y, img.get_pixel(x, y).blend(color))
		else:
			img.set_pixel(x, y, color)


static func _rect(img: Image, rect: Rect2, color: Color) -> void:
	for y in range(int(rect.position.y), int(rect.end.y)):
		for x in range(int(rect.position.x), int(rect.end.x)):
			_put(img, x, y, color)


static func _disc(img: Image, center: Vector2, radius: float, color: Color) -> void:
	for y in range(int(floor(center.y - radius)), int(ceil(center.y + radius)) + 1):
		for x in range(int(floor(center.x - radius)), int(ceil(center.x + radius)) + 1):
			if Vector2(x + 0.5, y + 0.5).distance_to(center) <= radius:
				_put(img, x, y, color)


static func _ellipse(img: Image, center: Vector2, radii: Vector2, color: Color) -> void:
	for y in range(int(center.y - radii.y), int(center.y + radii.y) + 1):
		for x in range(int(center.x - radii.x), int(center.x + radii.x) + 1):
			var d := (Vector2(x + 0.5, y + 0.5) - center) / radii
			if d.length_squared() <= 1.0:
				_put(img, x, y, color)


static func _line(img: Image, a: Vector2, b: Vector2, radius: float, color: Color) -> void:
	var steps := maxi(1, int(a.distance_to(b) * 2.0))
	var done := {}
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		for y in range(int(floor(p.y - radius)), int(ceil(p.y + radius)) + 1):
			for x in range(int(floor(p.x - radius)), int(ceil(p.x + radius)) + 1):
				var key := Vector2i(x, y)
				if not done.has(key) and Vector2(x + 0.5, y + 0.5).distance_to(p) <= radius + 0.5:
					done[key] = true
					_put(img, x, y, color)


static func _polygon(img: Image, points: Array, color: Color) -> void:
	var polygon := PackedVector2Array(points)
	var box := Rect2(polygon[0], Vector2.ZERO)
	for p in polygon:
		box = box.expand(p)
	for y in range(int(box.position.y), int(box.end.y) + 1):
		for x in range(int(box.position.x), int(box.end.x) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), polygon):
				_put(img, x, y, color)


static func _gradient(img: Image, top: Color, bottom: Color) -> void:
	for y in H:
		var color := top.lerp(bottom, float(y) / H)
		for x in W:
			img.set_pixel(x, y, color)


static func _outline(img: Image) -> void:
	var source := img.duplicate()
	for y in H:
		for x in W:
			if source.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.x < W and n.y >= 0 and n.y < H and source.get_pixel(n.x, n.y).a > 0.0:
					img.set_pixel(x, y, OUTLINE)
					break
