extends Sprite2D

## The long tail of the player's robe, drawn behind the body and driven by a
## stylised `momentum` (px/s) rather than a physics simulation: it trails opposite
## to that momentum (billowing up when falling, streaming behind when dashing),
## hangs down behind him when it's small, and ripples on a loop.
##
## Real time: `momentum` follows the player's velocity, and settles when he stands
## still. During a Stagger Break the CombatManager plans it alongside each move (see
## its _step()), so it's predictable and the ghost previews match; it holds through
## moves that don't move the player.
##
## Textures are generated on demand and cached, keyed by style, trailing direction
## (16 steps), strength (3 levels) and ripple phase (4 frames).
##
## Each character has a style (STYLES): the Sword Saint's black robe with blue
## herringbone trim, or Dogood's red cape with gold trim, or Ilyra's purple cape with green trim. The cape hangs from wherever
## the character's sprite set (player.sprites) says the back of the neck is.

const PlayerSprites = preload("res://scenes/player_sprites.gd")

const SIZE := 64
const ANGLE_STEPS := 16
const FULL_STRENGTH := 260.0 # Momentum (px/s) at which the cloak streams fully.
const WIND_PUSH := 140.0 # Momentum (px/s) that blows it a full unit off its resting hang.
const MAX_MOMENTUM := 450.0
const RIPPLE_FPS := 10.0
const FOLLOW_RATE := 10.0 # Real time: how quickly the cloak takes on the player's motion.
const SETTLE_RATE := 5.0 # How quickly it settles once he stands still.
const LENGTH := 22.0

const ROBE := PlayerSprites.ROBE
const ROBE_LIGHT := PlayerSprites.ROBE_LIGHT
const STYLES := {
	"saint": {"cloth": PlayerSprites.ROBE, "fold": PlayerSprites.ROBE_LIGHT, "trim": []}, # Herringbone.
	"dogood": {"cloth": Color(0.72, 0.1, 0.1), "fold": Color(0.9, 0.24, 0.2),
		"trim": [Color(0.98, 0.82, 0.3), Color(0.78, 0.58, 0.16)]},
	"elf": {"cloth": Color(0.36, 0.14, 0.52), "fold": Color(0.54, 0.28, 0.72),
		"trim": [Color(0.3, 0.84, 0.46), Color(0.12, 0.5, 0.28)]},
}

var momentum := Vector2.ZERO
var player # player.gd
var style := "saint"

var _ripple_time := 0.0
static var _cache := {}


func _physics_process(delta: float) -> void:
	if player == null or player.combat.time_stopped:
		return # The CombatManager drives the cloak during a Stagger Break.
	var velocity: Vector2 = player.velocity
	if player.is_on_floor() and velocity.length() < 5.0:
		momentum *= exp(-SETTLE_RATE * delta)
	else:
		momentum = momentum.lerp(velocity, 1.0 - exp(-FOLLOW_RATE * delta))
	momentum = momentum.limit_length(MAX_MOMENTUM)


func _process(delta: float) -> void:
	if player == null:
		return
	var combat = player.combat
	# Ripple, except while time is stopped for planning (the real player is frozen).
	if not (combat.time_stopped and not combat._busy):
		_ripple_time += delta
	var sprite: AnimatedSprite2D = player.charging_player_sprite if player.charging_player_sprite.visible else player.player_sprite
	visible = sprite.visible and player.sprites.cape_visible(sprite.animation, sprite.frame)
	var anchor: Vector2 = player.sprites.anchor(sprite.animation, sprite.frame)
	if not player.facing_right:
		anchor.x = -anchor.x
	position = sprite.position + anchor
	texture = texture_for(momentum, player.facing_right, int(_ripple_time * RIPPLE_FPS), style)


## The cloak texture for `cloak_momentum`, with the anchor at the texture's center.
static func texture_for(cloak_momentum: Vector2, facing_right: bool, ripple: int, cloak_style := "saint") -> Texture2D:
	# At rest it hangs down and a little behind; momentum blows it the other way.
	var rest := Vector2(-0.15 if facing_right else 0.15, 1.0).normalized()
	var flow := rest - cloak_momentum / WIND_PUSH
	var strength := clampf(cloak_momentum.length() / FULL_STRENGTH, 0.0, 1.0)
	var level := 0 if strength < 0.2 else (1 if strength < 0.65 else 2)
	var bucket := posmod(roundi(flow.angle() / TAU * ANGLE_STEPS), ANGLE_STEPS)
	var key := [cloak_style, bucket, level, posmod(ripple, 4)]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(_draw_cloak(bucket * TAU / ANGLE_STEPS, level, key[3], cloak_style))
	return _cache[key]


## A tapering-out ribbon from the anchor along `angle`, with a travelling ripple,
## a lighter fold, herringbone trim down both edges and across the hem, and an outline.
static func _draw_cloak(angle: float, level: int, phase: int, cloak_style := "saint") -> Image:
	var colors: Dictionary = STYLES[cloak_style]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var anchor := Vector2(SIZE, SIZE) / 2.0
	var dir := Vector2.from_angle(angle)
	var normal := dir.orthogonal()
	var amplitude := 0.6 + level * 1.3
	var length := LENGTH + level * 4.0
	# In a strong wind the far end lifts out level, away from his back.
	var level_dir := Vector2(signf(dir.x) if absf(dir.x) > 0.2 else 0.0, 0.0)
	var curl := 0.25 * level
	var segments := 16
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var middle := PackedVector2Array()
	for i in segments + 1:
		var t := float(i) / segments
		var wave := sin(TAU * t * 1.2 - phase * PI / 2.0) * amplitude * t
		var heading := dir.lerp(level_dir, curl * t).normalized() if level_dir != Vector2.ZERO else dir
		var center := anchor + heading * length * t + normal * wave
		# At rest it lies flat against his back; streaming, it spreads out.
		var half_width := (1.8 + 2.4 * t) if level == 0 else (2.5 + 4.5 * t)
		left.append(center + normal * half_width)
		right.append(center - normal * half_width)
		middle.append(center + normal * wave * 0.5)
	# A ragged hem: the trailing corners stretch a little further out.
	left[segments] += dir * 2.0
	var polygon := left.duplicate()
	for i in range(segments, -1, -1):
		polygon.append(right[i])
	PlayerSprites._fill_polygon(img, polygon, colors.cloth)
	for i in range(3, segments):
		PlayerSprites._put(img, int(round(middle[i].x)), int(round(middle[i].y)), colors.fold)
	for edge in [left, right]:
		for i in range(1, segments):
			_edge(img, edge[i], edge[i + 1], colors.trim)
	_edge(img, left[segments], right[segments], colors.trim)
	PlayerSprites._outline(img, PlayerSprites.OUTLINE)
	return img


## A trimmed edge: the Saint's herringbone (no colours given), or dashes alternating
## between the given colours.
static func _edge(img: Image, a: Vector2, b: Vector2, trim: Array) -> void:
	if trim.is_empty():
		PlayerSprites._trim_line(img, a, b)
		return
	for cell in PlayerSprites._line_cells(a, b):
		PlayerSprites._put(img, cell.x, cell.y, trim[((cell.x + cell.y) / 2) % trim.size()])
