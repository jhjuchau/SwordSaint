extends Node

## Stagger Break presentation: the orange burst and shatter sound when an enemy
## breaks, the sliding "BREAK!" banner, and the blue time-stop filter with drifting
## clouds. Created by the CombatManager.

const Sfx = preload("res://scenes/audio/sfx.gd")
const Sparkle = preload("res://scenes/combat/sparkle.gd")
const LightningBolt = preload("res://scenes/combat/lightning_bolt.gd")
const FONT := preload("res://assets/2D/brackeys_platformer_assets/fonts/PixelOperator8.ttf")

const FILTER_LAYER := 1 # Above the world, below the HUD and menu.
const BANNER_LAYER := 3 # Above everything.

const FILTER_COLOR := Color(0.15, 0.4, 1.0, 0.22)
const FILTER_FADE := 0.25

const BANNER_SLIDE := 0.18
const BANNER_HOLD := 1.5
const BANNER_SKEW := 0.3 # Radians; slants the banner so the text reads as italic.
const BANNER_TEXT_COLOR := Color(1.0, 0.75, 0.2)
const BANNER_ACCENT_COLOR := Color(1.0, 0.5, 0.1)

## One line from this file is shown under the banner. Edit it freely; it's re-read on every break.
const BREAK_LINES_PATH := "res://data/break_lines.txt"

var _filter: Control
var _clouds: CPUParticles2D
var _speed_lines: CPUParticles2D
var _banner_layer: CanvasLayer


func _ready() -> void:
	_build_filter()
	_build_speed_lines()
	_banner_layer = CanvasLayer.new()
	_banner_layer.layer = BANNER_LAYER
	add_child(_banner_layer)


## Everything that happens the moment an enemy's stagger meter breaks.
func play_break(enemy_position: Vector2) -> void:
	_spawn_burst(enemy_position)
	Sfx.play(self, "shatter")
	_show_banner()
	set_filter_active(true)


func set_filter_active(active: bool) -> void:
	var tween := _filter.create_tween()
	if active:
		var screen := _screen_size()
		_clouds.position = Vector2(screen.x + 150.0, screen.y / 2.0)
		_clouds.emission_rect_extents = Vector2(10.0, screen.y / 2.0)
		_clouds.restart() # Preprocess fills the screen with clouds right away.
		_filter.show()
		tween.tween_property(_filter, "modulate:a", 1.0, FILTER_FADE)
	else:
		_clouds.emitting = false
		tween.tween_property(_filter, "modulate:a", 0.0, FILTER_FADE)
		tween.tween_callback(_filter.hide)


## Streaks flying across the screen while the planned combo is performed.
func set_speed_lines_active(active: bool) -> void:
	if active:
		var screen := _screen_size()
		_speed_lines.position = Vector2(screen.x + 200.0, screen.y / 2.0)
		_speed_lines.emission_rect_extents = Vector2(10.0, screen.y / 2.0)
		_speed_lines.restart() # Preprocess puts lines on screen immediately.
	else:
		_speed_lines.emitting = false # Lines already in flight finish crossing.


func _build_speed_lines() -> void:
	var layer := CanvasLayer.new()
	layer.layer = FILTER_LAYER
	add_child(layer)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0))
	gradient.set_color(1, Color(1, 1, 1, 1))
	var texture := GradientTexture2D.new() # A thin streak, faded at its trailing end.
	texture.gradient = gradient
	texture.width = 128
	texture.height = 2
	_speed_lines = CPUParticles2D.new()
	_speed_lines.emitting = false
	_speed_lines.texture = texture
	_speed_lines.amount = 45
	_speed_lines.lifetime = 0.7
	_speed_lines.preprocess = 0.7
	_speed_lines.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_speed_lines.direction = Vector2.LEFT
	_speed_lines.spread = 0.0
	_speed_lines.gravity = Vector2.ZERO
	_speed_lines.initial_velocity_min = 1800.0
	_speed_lines.initial_velocity_max = 2600.0
	_speed_lines.scale_amount_min = 0.8
	_speed_lines.scale_amount_max = 2.5
	_speed_lines.color = Color(1, 1, 1, 0.45)
	layer.add_child(_speed_lines)


func _spawn_burst(at: Vector2) -> void:
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 160
	burst.lifetime = 0.8
	burst.direction = Vector2.RIGHT
	burst.spread = 180.0
	# World-space values; the camera's 2.5x zoom makes these read much larger on screen.
	burst.initial_velocity_min = 40.0
	burst.initial_velocity_max = 150.0
	burst.damping_min = 100.0
	burst.damping_max = 200.0
	burst.gravity = Vector2(0, 80)
	burst.scale_amount_min = 1.0
	burst.scale_amount_max = 3.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.3))
	ramp.set_color(1, Color(1.0, 0.3, 0.0, 0.0))
	ramp.add_point(0.4, Color(1.0, 0.55, 0.1))
	burst.color_ramp = ramp
	get_tree().current_scene.add_child(burst)
	burst.global_position = at
	burst.emitting = true
	get_tree().create_timer(burst.lifetime + 0.5).timeout.connect(burst.queue_free)


## Motes of `color` drifting down from all along a blade's cut, from `from` to `to`
## (world positions), for the length of the swing.
func spawn_blade_particles(color: Color, from: Vector2, to: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.amount = 70
	particles.lifetime = 0.9
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	var points := PackedVector2Array()
	for i in 24:
		points.append((to - from) * (i / 23.0))
	particles.emission_points = points
	particles.direction = Vector2.DOWN
	particles.spread = 25.0
	particles.initial_velocity_min = 5.0
	particles.initial_velocity_max = 25.0
	particles.gravity = Vector2(0, 90)
	particles.damping_min = 5.0
	particles.damping_max = 15.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color.lightened(0.3), 1.0))
	ramp.set_color(1, Color(color, 0.0))
	particles.color_ramp = ramp
	particles.z_index = 6
	get_tree().current_scene.add_child(particles)
	particles.global_position = from
	particles.emitting = true
	# Emit through the swing, then let the last motes fall and fade.
	get_tree().create_timer(0.45).timeout.connect(func() -> void:
		if is_instance_valid(particles): # (Gone if the scene was reloaded meanwhile.)
			particles.emitting = false)
	get_tree().create_timer(0.45 + particles.lifetime + 0.2).timeout.connect(particles.queue_free)


## A single silver star at a world position.
func spawn_sparkle(at: Vector2, size := 6.0, duration := 0.35) -> void:
	var sparkle := Sparkle.new()
	sparkle.size = size
	sparkle.duration = duration
	sparkle.global_position = at
	get_tree().current_scene.add_child(sparkle)


## A lightning strike through `points` (sky, enemy, sword), with a quick white flash
## over the screen.
func spawn_lightning(points: PackedVector2Array) -> void:
	var bolt := LightningBolt.new()
	bolt.points = points
	get_tree().current_scene.add_child(bolt)
	var layer := CanvasLayer.new()
	layer.layer = FILTER_LAYER
	add_child(layer)
	var flash := ColorRect.new()
	flash.size = _screen_size()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(0.85, 0.93, 1.0, 0.45)
	layer.add_child(flash)
	var fade := flash.create_tween()
	fade.tween_property(flash, "color:a", 0.0, 0.25)
	fade.tween_callback(layer.queue_free)


## A shouted line in big outlined letters that pops up over `at` and floats away.
func spawn_shout(text: String, at: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3))
	label.add_theme_color_override("font_outline_color", Color(0.35, 0.05, 0.05))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(200, 14)
	label.pivot_offset = label.size / 2.0
	label.z_index = 20
	get_tree().current_scene.add_child(label)
	label.global_position = at - label.size / 2.0
	label.scale = Vector2(0.4, 0.4)
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.08)
	tween.tween_interval(0.6)
	tween.tween_property(label, "global_position:y", label.global_position.y - 14.0, 0.4)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(label.queue_free)


## A spell going off: emerald fire, a burst of thorny vines, a violet implosion or a
## green lightning strike (with a flash), each with its sound.
func spawn_spell_burst(kind: String, at: Vector2, to := Vector2.ZERO) -> void:
	var colors := {"fireball": [Color(0.5, 1.0, 0.6), Color(0.75, 0.4, 1.0)], "snare": [Color(0.35, 0.85, 0.4), Color(0.45, 0.2, 0.55)],
		"well": [Color(0.75, 0.45, 1.0), Color(0.3, 1.0, 0.55)], "fizzle": [Color(0.5, 1.0, 0.6), Color(0.4, 0.4, 0.5)]}
	if kind == "cloud":
		var bolt := LightningBolt.new()
		bolt.points = PackedVector2Array([at, to])
		bolt.glow = Color(0.4, 1.0, 0.55, 0.45)
		bolt.core = Color(0.92, 1.0, 0.92)
		get_tree().current_scene.add_child(bolt)
		Sfx.play(self, "lightning")
		spawn_dust(to)
		return
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 50 if kind != "fizzle" else 14
	burst.lifetime = 0.6
	burst.spread = 180.0
	burst.direction = Vector2.UP
	burst.initial_velocity_min = 40.0
	burst.initial_velocity_max = 150.0 if kind != "well" else 60.0
	burst.gravity = Vector2(0, 120) if kind == "snare" else Vector2.ZERO
	burst.damping_min = 60.0
	burst.damping_max = 140.0
	burst.scale_amount_min = 1.5
	burst.scale_amount_max = 4.0
	var pair: Array = colors.get(kind, colors.fireball)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1))
	ramp.add_point(0.25, pair[0])
	ramp.set_color(1, Color(pair[1], 0.0))
	burst.color_ramp = ramp
	burst.z_index = 7
	get_tree().current_scene.add_child(burst)
	burst.global_position = at
	burst.emitting = true
	get_tree().create_timer(1.2).timeout.connect(burst.queue_free)
	match kind:
		"fireball": Sfx.play(self, "heavy_slash")
		"snare": Sfx.play(self, "spike")
		"well": Sfx.play(self, "slam")
		"fizzle": Sfx.play(self, "fizzle")
	if kind == "snare": # Thorny vines lashing up round the target.
		for i in 5:
			var vine := Line2D.new()
			vine.width = 2.0
			vine.default_color = Color(0.25, 0.65, 0.35)
			vine.z_index = 7
			var x := -14.0 + i * 7.0
			vine.points = PackedVector2Array([Vector2(x, 0), Vector2(x + 3, -10), Vector2(x - 2, -20), Vector2(x + 2, -28)])
			get_tree().current_scene.add_child(vine)
			vine.global_position = at + Vector2(0, 10)
			vine.scale = Vector2(1, 0.1)
			var grow := vine.create_tween()
			grow.tween_property(vine, "scale", Vector2.ONE, 0.12)
			grow.tween_interval(0.5)
			grow.tween_property(vine, "modulate:a", 0.0, 0.3)
			grow.tween_callback(vine.queue_free)


## A burst of dust and grit where something slams into the ground.
func spawn_dust(at: Vector2) -> void:
	var dust := CPUParticles2D.new()
	dust.one_shot = true
	dust.explosiveness = 0.95
	dust.amount = 28
	dust.lifetime = 0.55
	dust.direction = Vector2.UP
	dust.spread = 80.0
	dust.initial_velocity_min = 30.0
	dust.initial_velocity_max = 90.0
	dust.gravity = Vector2(0, 220)
	dust.scale_amount_min = 1.5
	dust.scale_amount_max = 3.5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.78, 0.66, 0.95))
	ramp.set_color(1, Color(0.6, 0.52, 0.42, 0.0))
	dust.color_ramp = ramp
	dust.z_index = 6
	get_tree().current_scene.add_child(dust)
	dust.global_position = at
	dust.emitting = true
	get_tree().create_timer(1.2).timeout.connect(dust.queue_free)


## Purely visual explosion of silver glints and a few larger stars.
func spawn_sparkle_burst(at: Vector2) -> void:
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 90
	burst.lifetime = 0.6
	burst.direction = Vector2.RIGHT
	burst.spread = 180.0
	burst.initial_velocity_min = 50.0
	burst.initial_velocity_max = 170.0
	burst.damping_min = 120.0
	burst.damping_max = 240.0
	burst.scale_amount_min = 0.8
	burst.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color.WHITE)
	ramp.set_color(1, Color(0.75, 0.82, 1.0, 0.0))
	burst.color_ramp = ramp
	burst.z_index = 6
	get_tree().current_scene.add_child(burst)
	burst.global_position = at
	burst.emitting = true
	get_tree().create_timer(burst.lifetime + 0.5).timeout.connect(burst.queue_free)
	for i in 6:
		var offset := Vector2.from_angle(randf() * TAU) * randf_range(6.0, 22.0)
		spawn_sparkle(at + offset, randf_range(3.0, 6.0), randf_range(0.3, 0.5))


## Slides "BREAK!" (plus a random line from BREAK_LINES_PATH under it) in from the
## right, holds it in the center, then slides it out to the left and frees it once
## it's off screen.
func _show_banner() -> void:
	var screen := _screen_size()
	# Children of a skewed Node2D are drawn skewed, which gives the italic slant.
	var banner := Node2D.new()
	banner.skew = BANNER_SKEW
	_banner_layer.add_child(banner)

	var label := Label.new()
	label.text = "BREAK!"
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 96)
	label.add_theme_color_override("font_color", BANNER_TEXT_COLOR)
	label.add_theme_color_override("font_outline_color", Color(0.25, 0.08, 0.0))
	label.add_theme_constant_override("outline_size", 16)
	banner.add_child(label)
	var text_size := label.get_combined_minimum_size()
	var box_size := text_size + Vector2(96, 24)

	var box := ColorRect.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.color = Color(0, 0, 0, 0.65)
	box.size = box_size
	box.position = -box_size / 2.0
	banner.add_child(box)
	for y in [-box_size.y / 2.0, box_size.y / 2.0 - 4.0]:
		var stripe := ColorRect.new()
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stripe.color = BANNER_ACCENT_COLOR
		stripe.size = Vector2(box_size.x, 4)
		stripe.position = Vector2(-box_size.x / 2.0, y)
		banner.add_child(stripe)
	banner.move_child(label, -1) # Draw the text over the box.
	label.position = -text_size / 2.0

	var line := _random_break_line()
	if line != "":
		var subtitle := Label.new()
		subtitle.text = line
		subtitle.add_theme_font_override("font", FONT)
		subtitle.add_theme_font_size_override("font_size", 24)
		subtitle.add_theme_color_override("font_color", Color.WHITE)
		subtitle.add_theme_color_override("font_outline_color", Color(0.25, 0.08, 0.0))
		subtitle.add_theme_constant_override("outline_size", 8)
		banner.add_child(subtitle)
		var subtitle_size := subtitle.get_combined_minimum_size()
		var strip := ColorRect.new()
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.color = Color(0, 0, 0, 0.65)
		strip.size = subtitle_size + Vector2(32, 8)
		strip.position = Vector2(-strip.size.x / 2.0, box_size.y / 2.0 + 6.0)
		banner.add_child(strip)
		banner.move_child(subtitle, -1)
		subtitle.position = strip.position + Vector2(16, 4)

	# Extra margin covers the horizontal lean the skew adds.
	var off_screen := box_size.x / 2.0 + box_size.y
	banner.position = Vector2(screen.x + off_screen, screen.y / 2.0)
	var tween := banner.create_tween()
	tween.tween_property(banner, "position:x", screen.x / 2.0, BANNER_SLIDE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(BANNER_HOLD)
	tween.tween_property(banner, "position:x", -off_screen, BANNER_SLIDE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(banner.queue_free)


## Picks a random non-empty, non-comment line from BREAK_LINES_PATH. Works for any
## number of lines, so new ones can simply be appended to the file.
func _random_break_line() -> String:
	var lines: Array[String] = []
	for raw_line in FileAccess.get_file_as_string(BREAK_LINES_PATH).split("
"):
		var line := raw_line.strip_edges()
		if line != "" and not line.begins_with("#"):
			lines.append(line)
	if lines.is_empty():
		return ""
	return lines[randi_range(0, lines.size() - 1)]


func _build_filter() -> void:
	var layer := CanvasLayer.new()
	layer.layer = FILTER_LAYER
	add_child(layer)
	_filter = Control.new()
	_filter.set_anchors_preset(Control.PRESET_FULL_RECT)
	_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_filter.modulate.a = 0.0
	_filter.hide()
	layer.add_child(_filter)

	var tint := ColorRect.new()
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.color = FILTER_COLOR
	_filter.add_child(tint)

	# Soft white puffs drifting right to left across the screen.
	_clouds = CPUParticles2D.new()
	_clouds.emitting = false
	_clouds.texture = _make_cloud_texture()
	_clouds.amount = 24
	_clouds.lifetime = 9.0
	_clouds.preprocess = 9.0
	_clouds.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_clouds.direction = Vector2.LEFT
	_clouds.spread = 4.0
	_clouds.gravity = Vector2.ZERO
	_clouds.initial_velocity_min = 180.0
	_clouds.initial_velocity_max = 260.0
	_clouds.scale_amount_min = 1.5
	_clouds.scale_amount_max = 3.5
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.15, Color(1, 1, 1, 0.14))
	fade.add_point(0.85, Color(1, 1, 1, 0.14))
	_clouds.color_ramp = fade
	_filter.add_child(_clouds)


func _make_cloud_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 56
	return texture


func _screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size
