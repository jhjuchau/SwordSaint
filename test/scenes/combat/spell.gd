extends Node2D

## One of Ilyra's spells on the field during a Stagger Break, drawn from its planned
## state (CombatManager._step_spells() simulates them; this only shows them). Kinds:
##   fireball: a homing ball of emerald witch-fire trailing violet sparks
##   cloud:    a brooding storm cloud, crackling as it charges toward its strike
##   snare:    a glowing rune circle on the ground, ready to burst into thorns
##   well:     a violet vortex, a spark while dormant, a churning whirlpool while it pulls
## The ghost previews use these too, with `ghost` set (grey, translucent).

const FIRE_OUTER := Color(0.25, 0.9, 0.45, 0.35)
const FIRE_MID := Color(0.45, 1.0, 0.55)
const FIRE_CORE := Color(0.92, 1.0, 0.9)
const SPARK := Color(0.8, 0.5, 1.0)
const CLOUD_DARK := Color(0.22, 0.18, 0.3)
const CLOUD_MID := Color(0.34, 0.28, 0.44)
const CLOUD_TOP := Color(0.48, 0.42, 0.58)
const RAIN := Color(0.6, 0.7, 0.9, 0.5)
const CRACKLE := Color(0.6, 1.0, 0.7)
const RUNE := Color(0.35, 1.0, 0.55)
const VOID := Color(0.2, 0.05, 0.3)
const VIOLET := Color(0.7, 0.4, 1.0)

var kind := ""
var state := {}
var ghost := false
var tint := Color.WHITE
var _time := 0.0


func _ready() -> void:
	top_level = true
	z_index = 5
	if ghost:
		modulate = Color(0.82 * tint.r, 0.82 * tint.g, 0.82 * tint.b, 0.55)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func show_state(s: Dictionary) -> void:
	state = s
	kind = s.kind
	visible = s.alive
	if s.alive:
		global_position = s.pos


func _draw() -> void:
	if state.is_empty():
		return
	match kind:
		"fireball": _draw_fireball()
		"cloud": _draw_cloud()
		"snare": _draw_snare()
		"well": _draw_well()


func _draw_fireball() -> void:
	var vel: Vector2 = state.get("vel", Vector2.RIGHT)
	var back := -vel.normalized()
	for i in 6: # A trail of violet sparks and fading flame.
		var p := back * (4.0 + i * 3.5) + back.orthogonal() * sin(_time * 18.0 + i) * 1.5
		draw_circle(p, 3.5 - i * 0.5, Color(FIRE_OUTER, 0.3 - i * 0.04))
		if i % 2 == 0:
			draw_circle(p + back.orthogonal() * 2.0, 0.9, SPARK)
	var flicker := 1.0 + 0.12 * sin(_time * 25.0)
	draw_circle(Vector2.ZERO, 8.0 * flicker, FIRE_OUTER)
	draw_circle(Vector2.ZERO, 5.5 * flicker, FIRE_MID)
	draw_circle(back * 0.8, 2.8, FIRE_CORE)


func _draw_cloud() -> void:
	var charge := clampf(state.get("age", 0.0) / state.get("delay", 1.0), 0.0, 1.0)
	# Rain beneath.
	for i in 7:
		var x := -20.0 + i * 6.5
		var y := fmod(_time * 120.0 + i * 13.0, 26.0)
		draw_line(Vector2(x, 6 + y), Vector2(x - 2, 12 + y), RAIN, 1.0)
	# Glow under it, building as it charges.
	draw_circle(Vector2(0, 6), 14.0, Color(CRACKLE, 0.12 * charge))
	for puff in [[Vector2(-14, 2), 8.0], [Vector2(14, 2), 8.0], [Vector2(-5, -3), 10.0], [Vector2(7, -4), 9.0], [Vector2(0, 4), 9.0]]:
		draw_circle(puff[0], puff[1], CLOUD_DARK)
	for puff in [[Vector2(-5, -6), 7.0], [Vector2(7, -7), 6.0], [Vector2(-13, -1), 5.0]]:
		draw_circle(puff[0], puff[1], CLOUD_MID)
	draw_circle(Vector2(-4, -9), 3.5, CLOUD_TOP)
	draw_circle(Vector2(8, -9), 2.5, CLOUD_TOP)
	# Crackles inside as the strike nears.
	if charge > 0.4:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(_time * 12.0)
		for i in int(1 + charge * 3.0):
			var p := Vector2(rng.randf_range(-14, 14), rng.randf_range(-4, 4))
			var q := p + Vector2(rng.randf_range(-6, 6), rng.randf_range(2, 6))
			draw_line(p, q, Color(CRACKLE, 0.5 + charge * 0.5), 1.0)
	# A ring ticking down the time to the strike.
	draw_arc(Vector2(0, -1), 18.0, -PI / 2.0, -PI / 2.0 + TAU * charge, 24, Color(CRACKLE, 0.45), 1.0)


func _draw_snare() -> void:
	var armed: bool = state.get("armed", false)
	var pulse := 0.6 + 0.4 * sin(_time * 6.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 20.0, Color(RUNE, 0.12 * pulse))
	draw_arc(Vector2.ZERO, 20.0, 0, TAU, 36, Color(RUNE, 0.9 if armed else 0.5), 1.5)
	draw_arc(Vector2.ZERO, 13.0, 0, TAU, 28, Color(VIOLET, 0.7), 1.0)
	for i in 6: # Runes going round.
		var a := _time * 1.5 + i * TAU / 6.0
		var p := Vector2.from_angle(a) * 16.5
		draw_line(p - Vector2.from_angle(a + 1.2) * 2.0, p + Vector2.from_angle(a + 1.2) * 2.0, Color(RUNE, pulse), 1.5)
	draw_set_transform(Vector2.ZERO)
	if armed: # Little thorn tips poking up.
		for x in [-12.0, -4.0, 5.0, 12.0]:
			draw_colored_polygon(PackedVector2Array([Vector2(x - 1.5, 0), Vector2(x, -3.0 - pulse), Vector2(x + 1.5, 0)]), Color(0.3, 0.7, 0.4))


func _draw_well() -> void:
	var age: float = state.get("age", 0.0)
	var active: bool = age >= state.get("wake", 0.0)
	var spin := _time * (8.0 if active else 2.0)
	var size := 18.0 if active else 7.0
	draw_circle(Vector2.ZERO, size * 0.55, VOID)
	for ring in 3:
		var r := size * (0.5 + ring * 0.25)
		var start := spin * (1.0 + ring * 0.3) + ring
		draw_arc(Vector2.ZERO, r, start, start + PI * 1.2, 16, Color(VIOLET, 0.8 - ring * 0.2), 1.5)
		draw_arc(Vector2.ZERO, r, start + PI, start + PI * 1.8, 10, Color(RUNE, 0.5 - ring * 0.12), 1.0)
	if active: # Streaks being sucked in.
		for i in 8:
			var a := i * TAU / 8.0 - spin * 0.5
			var t := fmod(_time * 2.0 + i * 0.37, 1.0)
			var p := Vector2.from_angle(a) * (40.0 * (1.0 - t) + 10.0)
			draw_line(p, p * 0.8, Color(VIOLET, 0.6 * (1.0 - t)), 1.0)
	draw_circle(Vector2.ZERO, 2.0, Color(1, 1, 1, 0.9))
