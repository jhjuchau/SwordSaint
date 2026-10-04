extends Node2D

## One spike of a mole's earthquake. After `age` climbs past 0 (it starts negative,
## so a quake's spikes come up one after another) it pokes just its point out of the
## ground, a harmless warning, then bursts up and hurts the player while it's out,
## holds, and sinks back. Its base sits at its position, on the ground.
##
## Like fireballs it's an enemy projectile (see the interface at the top of
## fireball.gd): frozen while time is stopped, simulated by the combo planner.

const EnemySprites = preload("res://scenes/enemies/enemy_sprites.gd")
const Sfx = preload("res://scenes/audio/sfx.gd")

const TIP := 0.3 # Seconds showing just the point.
const RISE := 0.08
const HOLD := 0.45
const SINK := 0.2
const TIP_HEIGHT := 5.0
const HEIGHT := 33.0 # Fully out (the texture's height, less its top row).
const HALF_WIDTH := 6.0 # Of the part that hurts.

var size := 1.0
var age := 0.0
var combat
var cuttable := false
var ends_on_terrain := false
var _sprite: Sprite2D
static var _ghost_textures := {}


static func height_at(t: float) -> float:
	if t < 0.0:
		return 0.0
	if t < TIP:
		return TIP_HEIGHT * minf(t / 0.06, 1.0)
	t -= TIP
	if t < RISE:
		return lerpf(TIP_HEIGHT, HEIGHT, t / RISE)
	t -= RISE
	if t < HOLD:
		return HEIGHT
	t -= HOLD
	return HEIGHT * maxf(1.0 - t / SINK, 0.0)


## Hurts only once it's properly out (not the warning tip, not while sinking).
static func dangerous(t: float) -> bool:
	return t >= TIP + RISE * 0.5 and t < TIP + RISE + HOLD


static func lifetime() -> float:
	return TIP + RISE + HOLD + SINK


func _ready() -> void:
	add_to_group("enemy_projectiles")
	combat = get_tree().get_first_node_in_group("combat_manager")
	scale = Vector2.ONE * size
	_sprite = Sprite2D.new()
	_sprite.texture = EnemySprites.earth_spike_texture()
	_sprite.centered = false
	_sprite.region_enabled = true
	add_child(_sprite)
	_update()


func _physics_process(delta: float) -> void:
	if combat and combat.time_stopped:
		return
	var before := age
	age += delta
	_effects(before, age)
	_update()
	if combat and dangerous(age):
		var player = combat.player
		if _hurt_rect(state()).intersects(_player_rect(player)):
			player.take_hit(global_position)
	if age > lifetime():
		queue_free()


func _update() -> void:
	var h := height_at(age)
	_sprite.visible = h > 0.5
	_sprite.region_rect = Rect2(0, 1, 16, h)
	_sprite.position = Vector2(-8, -h)


## Dust and sound as the point breaks the ground and as the spike bursts out.
func _effects(before: float, now: float) -> void:
	if before < 0.0 and now >= 0.0:
		_dust(6, 25.0)
		Sfx.play(self, "spike_tip")
	if before < TIP and now >= TIP:
		_dust(16, 60.0)
		Sfx.play(self, "spike")


func _dust(amount: int, speed: float) -> void:
	var dust := CPUParticles2D.new()
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.amount = amount
	dust.lifetime = 0.5
	dust.direction = Vector2.UP
	dust.spread = 70.0
	dust.initial_velocity_min = speed * 0.4
	dust.initial_velocity_max = speed
	dust.gravity = Vector2(0, 160)
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.5
	dust.color = Color(0.55, 0.45, 0.35, 0.85)
	get_tree().current_scene.add_child(dust)
	dust.global_position = global_position
	dust.emitting = true
	get_tree().create_timer(1.0).timeout.connect(dust.queue_free)


func _hurt_rect(s: Dictionary) -> Rect2:
	var h := height_at(s.age) * size
	return Rect2(s.pos.x - HALF_WIDTH * size, s.pos.y - h, HALF_WIDTH * 2.0 * size, h)


static func _player_rect(player) -> Rect2:
	var collision: CollisionShape2D = player.get_node("player_collision")
	var extents: Vector2 = collision.shape.get_rect().size * collision.global_scale.abs()
	return Rect2(collision.global_position - extents / 2.0, extents)


# --- Enemy-projectile interface (see fireball.gd) ---

func state() -> Dictionary:
	return {"pos": global_position, "age": age, "alive": true}


## `playback`: being moved by a combo playing out, so it makes its dust and sounds.
func apply_state(s: Dictionary, playback := false) -> void:
	if playback:
		_effects(age, s.age)
	global_position = s.pos
	age = s.age
	visible = s.alive
	_update()


func plan_advance(s: Dictionary, _player_rect_now: Rect2, delta: float) -> String:
	s.age += delta
	return "end" if s.age > lifetime() else ""


func plan_hits_player(s: Dictionary, player_rect: Rect2) -> bool:
	return dangerous(s.age) and _hurt_rect(s).intersects(player_rect)


func end_effect(_tree: SceneTree, _s: Dictionary) -> void:
	pass


## The part that's out of the ground, as a texture (cached per height).
func ghost_texture(s: Dictionary) -> Texture2D:
	var h := roundi(height_at(s.age))
	if h <= 0:
		return null
	if not _ghost_textures.has(h):
		var atlas := AtlasTexture.new()
		atlas.atlas = EnemySprites.earth_spike_texture()
		atlas.region = Rect2(0, 1, 16, h)
		_ghost_textures[h] = atlas
	return _ghost_textures[h]


func ghost_transform(s: Dictionary) -> Transform2D:
	var h := roundf(height_at(s.age))
	return Transform2D(0.0, Vector2.ONE * size, 0.0, s.pos + Vector2(0, -h * size / 2.0))
