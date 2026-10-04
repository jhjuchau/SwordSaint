extends Node2D

## A grappling hook's rope: a brown line from `from` to `to` with a silver hook at
## the `to` end. `sag` bows the middle of the line sideways (downhill) to make it
## look slack; 0 is taut. The CombatManager animates these values.
## Positions are global; the node itself stays at the origin.

const ROPE_COLOR := Color(0.45, 0.28, 0.12)
const HOOK_COLOR := Color(0.82, 0.85, 0.9)
const GHOST_ROPE_COLOR := Color(0.7, 0.7, 0.7, 0.5)
const GHOST_HOOK_COLOR := Color(0.85, 0.85, 0.85, 0.6)
const ROPE_WIDTH := 1.5
const SEGMENTS := 16

var from := Vector2.ZERO
var to := Vector2.ZERO
var sag := 0.0
## Draws in translucent grey, for move previews.
var ghost := false
## Optional: when valid, called every frame to keep an end attached to a moving body.
var from_source := Callable()
var to_source := Callable()


func _ready() -> void:
	top_level = true
	z_index = 5 # In front of the characters.


func _process(_delta: float) -> void:
	if from_source.is_valid():
		from = from_source.call()
	if to_source.is_valid():
		to = to_source.call()
	queue_redraw()


func _draw() -> void:
	var span := to - from
	if span.length() < 1.0:
		return
	# Sag perpendicular to the rope, toward the ground.
	var side := span.orthogonal().normalized()
	if side.y < 0.0:
		side = -side
	var control := (from + to) / 2.0 + side * sag
	var points := PackedVector2Array()
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		points.append(from.lerp(control, t).lerp(control.lerp(to, t), t))
	var rope_color := GHOST_ROPE_COLOR if ghost else ROPE_COLOR
	var hook_color := GHOST_HOOK_COLOR if ghost else HOOK_COLOR
	draw_polyline(points, rope_color, ROPE_WIDTH)

	# Hook: a short shank along the rope's last segment with two barbs swept back.
	var dir := (points[-1] - points[-2]).normalized()
	var normal := dir.orthogonal()
	draw_line(to - dir * 2.5, to + dir * 1.5, hook_color, 1.5)
	draw_line(to + dir * 1.5, to - dir * 2.0 + normal * 2.5, hook_color, 1.0)
	draw_line(to + dir * 1.5, to - dir * 2.0 - normal * 2.5, hook_color, 1.0)
