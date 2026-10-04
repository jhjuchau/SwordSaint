extends Node2D

## The village behind the street: a row of timber houses with peaked roofs and
## warm-lit (or dark) windows, a few with storm-wrecked roofs. Drawn behind the
## terrain, standing on `ground_y`, from x = 100 to `village_end`.

const WALL := Color(0.26, 0.22, 0.21)
const TIMBER := Color(0.16, 0.12, 0.11)
const ROOFS := [Color(0.34, 0.14, 0.13), Color(0.22, 0.24, 0.32), Color(0.3, 0.2, 0.14)]
const WINDOW_LIT := Color(1.0, 0.78, 0.4)
const WINDOW_DARK := Color(0.08, 0.08, 0.11)
const DOOR := Color(0.15, 0.1, 0.08)

var ground_y := 540.0
var village_end := 2340.0


func _ready() -> void:
	z_index = -5


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var x := 100.0
	while x < village_end - 160.0:
		var width := rng.randf_range(70.0, 110.0)
		var height := rng.randf_range(48.0, 70.0)
		var roof := rng.randf_range(28.0, 44.0)
		_house(x, width, height, roof, ROOFS[rng.randi() % ROOFS.size()], rng, rng.randf() < 0.25)
		x += width + rng.randf_range(30.0, 90.0)


func _house(x: float, width: float, height: float, roof_height: float, roof_color: Color,
		rng: RandomNumberGenerator, wrecked: bool) -> void:
	var base := ground_y
	draw_rect(Rect2(x, base - height, width, height), WALL)
	# Timber frame.
	draw_rect(Rect2(x, base - height, width, height), TIMBER, false, 2.0)
	draw_line(Vector2(x, base - height * 0.55), Vector2(x + width, base - height * 0.55), TIMBER, 2.0)
	# Roof: a peak, or a broken one with a jagged hole.
	var peak := Vector2(x + width / 2.0, base - height - roof_height)
	var roof := PackedVector2Array([Vector2(x - 6, base - height), peak, Vector2(x + width + 6, base - height)])
	if wrecked:
		roof = PackedVector2Array([Vector2(x - 6, base - height), peak + Vector2(-6, 10),
			peak + Vector2(2, 20), peak + Vector2(8, 6), Vector2(x + width * 0.75, base - height - roof_height * 0.4),
			Vector2(x + width + 6, base - height)])
	draw_colored_polygon(roof, roof_color)
	draw_polyline(roof, TIMBER, 2.0)
	# Chimney.
	draw_rect(Rect2(x + width * 0.7, peak.y + roof_height * 0.35, 8, roof_height * 0.4), TIMBER)
	# Door and windows.
	draw_rect(Rect2(x + width * 0.42, base - 26, 14, 26), DOOR)
	for wx in [x + width * 0.14, x + width * 0.68]:
		for wy in [base - height * 0.85, base - height * 0.42]:
			var lit := rng.randf() < 0.55 and not wrecked
			draw_rect(Rect2(wx, wy, 12, 10), WINDOW_LIT if lit else WINDOW_DARK)
			draw_rect(Rect2(wx, wy, 12, 10), TIMBER, false, 1.5)
