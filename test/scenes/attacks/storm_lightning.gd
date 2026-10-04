extends Node2D

## Light-blue lightning crackling along a sword slash while the player has the Storm
## buff. Attached to a sword scene's slash sprite (see attach()), it follows the
## visible stretch of the slash's arc (or streak) frame by frame, using the same
## spec and timing as slash_sprite.gd, and re-jags itself every couple of frames.

const SlashSprite = preload("res://scenes/attacks/slash_sprite.gd")

const GLOW := Color(0.45, 0.8, 1.0, 0.4)
const CORE := Color(0.82, 0.95, 1.0)
const JITTER := 3.5 # px either side of the arc
const SEGMENTS := 9

var _spec: Dictionary
var _sprite: AnimatedSprite2D


## Adds storm lightning to a freshly spawned sword scene (one with a generated arc).
## `ghost_material` draws it the way the ghost previews draw everything else.
static func attach(sword: Node, ghost_material: Material = null) -> void:
	var entry = SlashSprite.SCENE_ARCS.get(sword.scene_file_path)
	if entry == null:
		return
	var sprite: AnimatedSprite2D = sword.get_node("AnimatedSprite2D")
	var lines = load("res://scenes/attacks/storm_lightning.gd").new()
	lines._spec = SlashSprite.ARCS[entry[0]]
	lines._sprite = sprite
	if ghost_material:
		lines.material = ghost_material
	sprite.add_child(lines)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(_sprite) or not _sprite.visible:
		return
	var per: int = _spec.get("frames", SlashSprite.FRAMES)
	var swings: Array = _spec.get("swings", [_spec])
	var k := _sprite.frame
	var swing: Dictionary = swings[mini(k / per, swings.size() - 1)]
	var p := float(k % per + 1) / per
	# The same visible stretch as the slash art (see slash_sprite.gd).
	var head := 1.0 - pow(1.0 - minf(1.0, p / 0.6), 2.0)
	var tail := clampf((p - 0.45) / 0.55, 0.0, 1.0)
	if head - tail < 0.02:
		return
	# Art faces left; flip_h turns it to face right. The pivot is pivot_ahead behind
	# the sprite's center.
	var s := 1.0 if _sprite.flip_h else -1.0
	var pivot := Vector2(-s * _spec.pivot_ahead, 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = Engine.get_physics_frames() / 2 + get_instance_id()
	var points := PackedVector2Array()
	for i in SEGMENTS + 1:
		var t := lerpf(tail, head, float(i) / SEGMENTS)
		var jitter := rng.randf_range(-JITTER, JITTER) if i > 0 and i < SEGMENTS else 0.0
		if _spec.get("streak", false):
			var angle := deg_to_rad(_spec.angle)
			var dir := Vector2(s * cos(angle), sin(angle))
			var along: float = lerpf(_spec.from, _spec.to, t)
			points.append(pivot + dir * along + dir.orthogonal() * jitter)
		else:
			var angle := deg_to_rad(lerpf(swing.from, swing.to, t))
			var radius: float = swing.radius - swing.thickness * 0.3 + jitter
			points.append(pivot + Vector2(s * cos(angle), sin(angle)) * radius)
	_bolt(points)
	# A small fork off the middle.
	var fork_start := points[SEGMENTS / 2]
	var away := (fork_start - pivot).normalized()
	var fork := PackedVector2Array([fork_start])
	for i in 3:
		fork.append(fork[-1] + away.rotated(rng.randf_range(-0.9, 0.9)) * rng.randf_range(3.0, 6.0))
	_bolt(fork, 0.6)


func _bolt(points: PackedVector2Array, scale_width := 1.0) -> void:
	draw_polyline(points, GLOW, 3.5 * scale_width)
	draw_polyline(points, CORE, 1.2 * scale_width)
