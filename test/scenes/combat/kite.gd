extends Node2D

## Dogood's kite: a diamond kite with a cross-spar, a tail of bows, a brass key
## hanging on its string, and the string running down to his raised hand. During a
## Stagger Break the CombatManager places it (planned kite state {pos, alive, ready});
## an enemy thrown into it is struck by lightning (see CombatManager._step()).

const KITE_SIZE := Vector2(20, 26)
const BODY := Color(0.92, 0.88, 0.76)
const PANEL := Color(0.8, 0.18, 0.16)
const SPAR := Color(0.36, 0.24, 0.14)
const STRING := Color(0.92, 0.9, 0.84, 0.85)
const BOW := Color(0.95, 0.8, 0.28)
const KEY := Color(0.86, 0.7, 0.3)

var hand := Vector2.ZERO # Where the string ends (world).
var _time := 0.0
static var _texture: Texture2D


func _ready() -> void:
	top_level = true
	z_index = 3


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	# String (sagging a little) with the key a third of the way down, then the tail.
	var to := hand - global_position
	var sag := Vector2(0, 10)
	var points := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		points.append(Vector2(0, 10).lerp(to, t) + sag * sin(PI * t))
	draw_polyline(points, STRING, 1.0)
	var key_at := points[4]
	draw_rect(Rect2(key_at + Vector2(-1.5, 0), Vector2(3, 5)), KEY)
	draw_circle(key_at + Vector2(0, 6), 1.8, KEY)
	var flutter := sin(_time * 7.0)
	var tail := PackedVector2Array()
	for i in 8:
		tail.append(Vector2(sin(_time * 5.0 + i * 0.9) * (1.5 + i * 0.6) + flutter, 12 + i * 4.0))
	draw_polyline(tail, SPAR, 1.0)
	for i in [2, 4, 6]:
		var p := tail[i]
		draw_colored_polygon(PackedVector2Array([p + Vector2(-3, -2), p, p + Vector2(-3, 2)]), BOW)
		draw_colored_polygon(PackedVector2Array([p + Vector2(3, -2), p, p + Vector2(3, 2)]), BOW)
	draw_set_transform(Vector2.ZERO, flutter * 0.08)
	draw_texture(kite_texture(), -KITE_SIZE / 2.0)
	draw_set_transform(Vector2.ZERO)


## The kite itself (the diamond, its panels and spars), centered.
static func kite_texture() -> Texture2D:
	if _texture == null:
		var w := int(KITE_SIZE.x)
		var h := int(KITE_SIZE.y)
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var diamond := PackedVector2Array([Vector2(w / 2.0, 0), Vector2(w, h * 0.38), Vector2(w / 2.0, h), Vector2(0, h * 0.38)])
		for y in h:
			for x in w:
				var p := Vector2(x + 0.5, y + 0.5)
				if not Geometry2D.is_point_in_polygon(p, diamond):
					continue
				var upper := y < h * 0.38
				var left := x < w / 2.0
				img.set_pixel(x, y, PANEL if upper == left else BODY)
		for y in h:
			img.set_pixel(w / 2, y, SPAR)
		for x in w:
			img.set_pixel(x, int(h * 0.38), SPAR)
		_texture = ImageTexture.create_from_image(img)
	return _texture
