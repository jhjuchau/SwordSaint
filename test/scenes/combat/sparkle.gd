extends Node2D

## A four-pointed silver star that flares up, spins a little, fades out, and frees
## itself. Set `global_position` (and optionally `size`/`duration`) before adding it.

const COLOR := Color(0.88, 0.92, 1.0)

var size := 6.0
var duration := 0.35


func _ready() -> void:
	top_level = true
	z_index = 6 # In front of the characters.
	scale = Vector2.ZERO
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2.ONE, duration * 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", PI / 4.0, duration)
	tween.tween_property(self, "modulate:a", 0.0, duration * 0.6).set_delay(duration * 0.4)
	tween.chain().tween_callback(queue_free)


func _draw() -> void:
	var thin := size * 0.18
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -size), Vector2(thin, 0), Vector2(0, size), Vector2(-thin, 0)]), COLOR)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-size, 0), Vector2(0, -thin), Vector2(size, 0), Vector2(0, thin)]), COLOR)
	draw_circle(Vector2.ZERO, size * 0.22, Color.WHITE)
