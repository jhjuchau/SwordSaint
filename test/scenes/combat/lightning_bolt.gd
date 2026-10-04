extends Node2D

## A lightning strike along `points` (world positions, e.g. high in the sky, through
## the enemy, down to the player's raised sword): a jagged, glowing bolt with a few
## forks that flickers and fades. Usurp the Heavens uses it; ghost previews spawn it
## with `ghost` set (grey, no screen flash).

const GLOW := Color(0.45, 0.8, 1.0, 0.45)
const CORE := Color(0.92, 0.98, 1.0)
const LIFETIME := 0.45
const STEP := 14.0 # px between kinks
const JAG := 7.0

var points := PackedVector2Array()
var ghost := false
var glow := GLOW
var core := CORE
var _path := PackedVector2Array()
var _forks: Array[PackedVector2Array] = []
var _age := 0.0


func _ready() -> void:
	top_level = true
	z_index = 7
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Kinks between each pair of key points, which the bolt passes through exactly.
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var count := maxi(int(a.distance_to(b) / STEP), 1)
		var side := (b - a).normalized().orthogonal()
		for j in count:
			var t := float(j) / count
			_path.append(a.lerp(b, t) + side * (rng.randf_range(-JAG, JAG) if j > 0 else 0.0))
	_path.append(points[-1])
	for f in 4:
		var start := _path[rng.randi_range(1, _path.size() - 2)]
		var fork := PackedVector2Array([start])
		var dir := Vector2.DOWN.rotated(rng.randf_range(-1.2, 1.2))
		for j in 4:
			fork.append(fork[-1] + dir.rotated(rng.randf_range(-0.6, 0.6)) * rng.randf_range(8.0, 16.0))
		_forks.append(fork)
	if ghost:
		modulate = Color(0.85, 0.85, 0.85, 0.55)


func _process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return
	# Flicker: bright, dim, bright, then fade.
	var flicker := 1.0 if fmod(_age, 0.09) < 0.06 else 0.45
	self_modulate.a = flicker * (1.0 - smoothstep(LIFETIME * 0.5, LIFETIME, _age))
	queue_redraw()


func _draw() -> void:
	draw_polyline(_path, glow, 9.0)
	draw_polyline(_path, core, 2.5)
	for fork in _forks:
		draw_polyline(fork, glow, 4.0)
		draw_polyline(fork, core, 1.2)
