extends Node

## The opening level's weather: a dark stormy sky with distant mountains, slanting
## rain (which hangs frozen in the air while time is stopped) with a rain ambience,
## and every few seconds a lightning bolt across the sky, a flash, and thunder.

const Sfx = preload("res://scenes/audio/sfx.gd")

const SCREEN := Vector2(1152, 648)
const LIGHTNING_INTERVAL := Vector2(4.0, 9.0) # Random seconds between strikes.

var combat
var _rain: CPUParticles2D
var _bolt: Line2D
var _flash: ColorRect
var _timer := 2.5


func _ready() -> void:
	combat = get_tree().get_first_node_in_group("combat_manager")
	_build_sky()
	_build_rain()
	Sfx.play_loop(self, "rain")


func _process(delta: float) -> void:
	var stopped: bool = combat != null and combat.time_stopped
	_rain.speed_scale = 0.0 if stopped else 1.0
	if stopped:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(LIGHTNING_INTERVAL.x, LIGHTNING_INTERVAL.y)
		_strike()


func _build_sky() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10 # Behind the world.
	add_child(layer)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.06, 0.07, 0.12))
	gradient.set_color(1, Color(0.21, 0.23, 0.31))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	var sky := TextureRect.new()
	sky.texture = texture
	sky.size = SCREEN
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	layer.add_child(sky)
	# Two ranges of distant mountains.
	for range_spec in [[Color(0.12, 0.13, 0.19), 0.55, 11], [Color(0.16, 0.17, 0.24), 0.68, 7]]:
		var ridge := Polygon2D.new()
		ridge.color = range_spec[0]
		var points := PackedVector2Array([Vector2(0, SCREEN.y)])
		var rng := RandomNumberGenerator.new()
		rng.seed = range_spec[2]
		var peaks: int = range_spec[2]
		for i in peaks + 1:
			var x := SCREEN.x * i / peaks
			var y: float = SCREEN.y * range_spec[1] - rng.randf_range(0.0, 120.0) * (1 if i % 2 == 0 else 0.4)
			points.append(Vector2(x, y))
		points.append(SCREEN)
		ridge.polygon = points
		layer.add_child(ridge)
	_bolt = Line2D.new()
	_bolt.width = 2.5
	_bolt.default_color = Color(0.88, 0.92, 1.0)
	_bolt.visible = false
	layer.add_child(_bolt)
	# The flash lights up everything but the HUD.
	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 1
	add_child(flash_layer)
	_flash = ColorRect.new()
	_flash.size = SCREEN
	_flash.color = Color(0.85, 0.9, 1.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_layer.add_child(_flash)


func _build_rain() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0))
	gradient.set_color(1, Color(1, 1, 1, 1))
	var streak := GradientTexture2D.new() # A thin streak, faded at the top.
	streak.gradient = gradient
	streak.fill_from = Vector2(0, 0)
	streak.fill_to = Vector2(0, 1)
	streak.width = 2
	streak.height = 14
	_rain = CPUParticles2D.new()
	_rain.texture = streak
	_rain.amount = 280
	_rain.lifetime = 0.9
	_rain.preprocess = 1.0
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(SCREEN.x / 2.0 + 200.0, 4)
	_rain.position = Vector2(SCREEN.x / 2.0 + 150.0, -20)
	_rain.direction = Vector2(-0.28, 1.0)
	_rain.spread = 2.0
	_rain.gravity = Vector2.ZERO
	_rain.initial_velocity_min = 650.0
	_rain.initial_velocity_max = 850.0
	_rain.particle_flag_align_y = true
	_rain.color = Color(0.72, 0.8, 1.0, 0.32)
	layer.add_child(_rain)


## A jagged bolt somewhere across the sky, a double flash, then thunder.
func _strike() -> void:
	var x := randf_range(0.15, 0.85) * SCREEN.x
	var points := PackedVector2Array([Vector2(x, 0)])
	var y := 0.0
	while y < SCREEN.y * 0.5:
		y += randf_range(18.0, 34.0)
		x += randf_range(-22.0, 22.0)
		points.append(Vector2(x, y))
	_bolt.points = points
	_bolt.visible = true
	_bolt.modulate.a = 1.0
	var bolt_fade := _bolt.create_tween()
	bolt_fade.tween_property(_bolt, "modulate:a", 0.0, 0.35)
	bolt_fade.tween_callback(func() -> void: _bolt.visible = false)
	var flash := _flash.create_tween()
	flash.tween_property(_flash, "color:a", 0.35, 0.04)
	flash.tween_property(_flash, "color:a", 0.0, 0.12)
	flash.tween_property(_flash, "color:a", 0.22, 0.05)
	flash.tween_property(_flash, "color:a", 0.0, 0.2)
	get_tree().create_timer(0.35).timeout.connect(func() -> void: Sfx.play(self, "thunder"))
