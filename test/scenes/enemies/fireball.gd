extends Area2D

## A bat's fireball: flies at a steady speed, turning slightly toward the player
## (homing), and fizzles out on terrain, on the player (hurting him), when a sword
## cuts it, or when it burns out.
##
## While time is stopped it doesn't move by itself: the CombatManager simulates it
## as part of each planned combo step (see its _step_projectiles()) through the
## enemy-projectile interface below, and places it wherever the planned timeline has it.
##
## Enemy-projectile interface (shared with earth_spike.gd; everything in the
## "enemy_projectiles" group has it): state() / apply_state() snapshot a dictionary
## with at least {pos, alive}; plan_advance(), plan_hits_player() and the `cuttable` /
## `ends_on_terrain` flags drive the planner; end_effect() plays when it goes out;
## ghost_texture() / ghost_transform() draw it in the ghost previews.

const EnemySprites = preload("res://scenes/enemies/enemy_sprites.gd")
const Sfx = preload("res://scenes/audio/sfx.gd")

const SPEED := 100.0
const TURN_RATE := 1.4 # rad/s: gentle homing.
const LIFETIME := 3.5
const HIT_RADIUS := 9.0 # From the player's center, for planned combos.

var velocity := Vector2.ZERO
var age := 0.0
var combat
var cuttable := true # Sword attacks put it out.
var ends_on_terrain := true


## One step of flight for a fireball's state {pos, vel, age, alive}: turn a little
## toward `target`, then move. Shared by real time and combo planning.
static func advance(state: Dictionary, target: Vector2, delta: float) -> void:
	var vel: Vector2 = state.vel
	var turn := clampf(angle_difference(vel.angle(), (target - state.pos).angle()), -TURN_RATE * delta, TURN_RATE * delta)
	vel = vel.rotated(turn).normalized() * SPEED
	state.vel = vel
	state.pos += vel * delta
	state.age += delta


## Red, fizzling sparks where a fireball went out.
static func spawn_fizzle(tree: SceneTree, at: Vector2) -> void:
	var sparks := CPUParticles2D.new()
	sparks.one_shot = true
	sparks.explosiveness = 0.8
	sparks.amount = 26
	sparks.lifetime = 0.5
	sparks.spread = 180.0
	sparks.initial_velocity_min = 25.0
	sparks.initial_velocity_max = 85.0
	sparks.gravity = Vector2(0, 70)
	sparks.damping_min = 40.0
	sparks.damping_max = 90.0
	sparks.scale_amount_min = 1.0
	sparks.scale_amount_max = 2.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.5, 0.3))
	ramp.set_color(1, Color(0.5, 0.05, 0.05, 0.0))
	ramp.add_point(0.4, Color(0.95, 0.15, 0.1))
	sparks.color_ramp = ramp
	sparks.z_index = 6
	tree.current_scene.add_child(sparks)
	sparks.global_position = at
	sparks.emitting = true
	tree.create_timer(1.0).timeout.connect(sparks.queue_free)
	Sfx.play(tree.current_scene, "fizzle")


func _ready() -> void:
	add_to_group("enemy_projectiles")
	combat = get_tree().get_first_node_in_group("combat_manager")
	collision_layer = 0
	collision_mask = 1 | 2 # Terrain, enemies and sword areas; the player.
	var shape := CircleShape2D.new()
	shape.radius = 4.0
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = EnemySprites.fireball_frames()
	sprite.play()
	add_child(sprite)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	rotation = velocity.angle()


# --- Enemy-projectile interface (see the top of this file) ---

## One planned physics step. Returns "" while it's still going, or "fizzle" when it burns out.
func plan_advance(s: Dictionary, player_rect: Rect2, delta: float) -> String:
	advance(s, player_rect.get_center(), delta)
	return "fizzle" if s.age > LIFETIME else ""


func plan_hits_player(s: Dictionary, player_rect: Rect2) -> bool:
	return s.pos.distance_to(player_rect.get_center()) < HIT_RADIUS


func end_effect(tree: SceneTree, s: Dictionary) -> void:
	spawn_fizzle(tree, s.pos)


func ghost_texture(_s: Dictionary) -> Texture2D:
	return EnemySprites.fireball_frames().get_frame_texture(&"default", 0)


func ghost_transform(s: Dictionary) -> Transform2D:
	return Transform2D(s.vel.angle(), s.pos)


func state() -> Dictionary:
	return {"pos": global_position, "vel": velocity, "age": age, "alive": true}


func apply_state(s: Dictionary, _playback := false) -> void:
	global_position = s.pos
	velocity = s.vel
	age = s.age
	rotation = velocity.angle()
	visible = s.alive


func _physics_process(delta: float) -> void:
	if combat and combat.time_stopped:
		return
	var s := state()
	var target: Vector2 = combat.player.get_node("player_collision").global_position if combat else global_position
	advance(s, target, delta)
	apply_state(s)
	if age > LIFETIME:
		fizzle()


func fizzle() -> void:
	spawn_fizzle(get_tree(), global_position)
	queue_free()


func _on_body_entered(body: Node) -> void:
	if (combat and combat.time_stopped) or body.is_in_group("enemies"):
		return
	if combat and body == combat.player:
		body.take_hit(global_position)
	fizzle()


## A sword cuts it.
func _on_area_entered(area: Area2D) -> void:
	if (combat and combat.time_stopped) or area.name != "sword_area":
		return
	fizzle()
