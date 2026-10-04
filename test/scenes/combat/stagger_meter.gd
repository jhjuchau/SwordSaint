extends Node2D

## An enemy's stagger meter, drawn as a yellow bar above its head.
## Real-time hits drain it; when it empties the enemy is open to a Stagger Break.
## Enemies that can't be comboed use it as a red HP bar instead (see enemy_base.gd).

const WIDTH := 18.0
const HEIGHT := 3.0
const FILL_COLOR := Color(1.0, 0.85, 0.1)
const BACK_COLOR := Color(0.0, 0.0, 0.0, 0.7)

var max_stagger := 30.0
var fill_color := FILL_COLOR
var stagger := max_stagger

## Drains the meter and returns true if it is now empty.
func take(amount: float) -> bool:
	stagger = maxf(stagger - amount, 0.0)
	queue_redraw()
	return stagger <= 0.0

func reset() -> void:
	stagger = max_stagger
	queue_redraw()

func _draw() -> void:
	var top_left := Vector2(-WIDTH / 2.0, 0.0)
	draw_rect(Rect2(top_left - Vector2.ONE, Vector2(WIDTH + 2.0, HEIGHT + 2.0)), BACK_COLOR)
	draw_rect(Rect2(top_left, Vector2(WIDTH * stagger / max_stagger, HEIGHT)), fill_color)
