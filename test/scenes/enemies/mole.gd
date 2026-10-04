extends "res://scenes/enemies/enemy_base.gd"

## A big mole: patrols near home, walks toward the player when he's close, and
## swipes its claws (windup, a short active window, recovery). With `boss` set it's
## the Burrow King: bigger and tougher, unflinching, and between swipes it hurls
## volleys of homing fireballs. A boss waits (`active` false) until the cutscene.
## When the player keeps their distance it sometimes slams the ground: three earth
## spikes erupt one after another, half a second apart, stepping toward where the
## player stood when it slammed (the third comes up right there).

const EnemySprites = preload("res://scenes/enemies/enemy_sprites.gd")
const Fireball = preload("res://scenes/enemies/fireball.gd")
const EarthSpike = preload("res://scenes/enemies/earth_spike.gd")

const WALK_SPEED := 45.0
const PATROL_RANGE := 80.0
const CHASE_RANGE := 170.0
const WINDUP := 0.25
const ACTIVE := 0.12
const RECOVER := 0.4
const COOLDOWN := 0.7
const FLINCH := 0.25
const VOLLEY_INTERVAL := 3.5
const QUAKE_RANGE := Vector2(90.0, 240.0) # Horizontal distance to the player it quakes at.
const QUAKE_WINDUP := 0.45
const QUAKE_RECOVER := 0.6
const QUAKE_INTERVAL := Vector2(3.0, 5.5) # Random seconds (in range) between quakes.
const SPIKE_DELAY := 0.5

var boss := false
var active := true
var facing := 1.0

var _size := 1.0
var _home_x := 0.0
var _patrol_dir := 1.0
var _state := "walk"
var _timer := 0.0
var _cooldown := 0.0
var _hit_landed := false
var _volley_timer := VOLLEY_INTERVAL
var _attack_area: Area2D
var _quake_timer := randf_range(1.0, 3.0)
var _quake_target_x := 0.0


func _ready() -> void:
	_size = 1.8 if boss else 1.0
	max_hp = 30 if boss else 4
	max_stagger = 60.0 if boss else 30.0
	_setup_body(EnemySprites.mole_frames(), Vector2(1, -27), Vector2(34, 24), Vector2(0, -12), -32.0, _size)
	_home_x = global_position.x
	# The claw swipe's hitbox, in front of the mole.
	_attack_area = Area2D.new()
	_attack_area.collision_layer = 0
	_attack_area.collision_mask = 2 # The player.
	var shape := RectangleShape2D.new()
	shape.size = Vector2(26, 22) * _size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	_attack_area.add_child(collider)
	add_child(_attack_area)
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	if dead or frozen():
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	var target = player()
	_cooldown = maxf(_cooldown - delta, 0.0)
	match _state:
		"walk":
			if not _try_quake(target, delta):
				_walk(target)
		"windup", "active", "recover", "hurt", "quake":
			velocity.x = 0.0
			_timer -= delta
			if _state == "active" and not _hit_landed and target in _attack_area.get_overlapping_bodies():
				_hit_landed = true
				target.take_hit(global_position)
			if _timer <= 0.0:
				_advance_attack()
	if boss and active and _state == "walk" and target:
		_volley_timer -= delta
		if _volley_timer <= 0.0:
			_volley_timer = VOLLEY_INTERVAL
			_volley(target)
	move_and_slide()
	sprite.flip_h = facing < 0.0
	_attack_area.position = Vector2(facing * 26.0, -12.0) * _size


func _walk(target) -> void:
	if not active or target == null:
		velocity.x = 0.0
		sprite.play("idle")
		return
	var to_player: Vector2 = target.global_position - global_position
	var reach := 30.0 * _size
	if absf(to_player.x) < CHASE_RANGE * _size and absf(to_player.y) < 60.0 * _size:
		facing = signf(to_player.x) if to_player.x != 0.0 else facing
		if absf(to_player.x) < reach and _cooldown <= 0.0:
			_state = "windup"
			_timer = WINDUP
			_hit_landed = false
			sprite.play("attack")
			return
		velocity.x = facing * WALK_SPEED if absf(to_player.x) > reach * 0.7 else 0.0
	else:
		# Patrol back and forth around home.
		if absf(global_position.x - _home_x) > PATROL_RANGE or is_on_wall():
			_patrol_dir = -signf(global_position.x - _home_x) if absf(global_position.x - _home_x) > PATROL_RANGE else -_patrol_dir
		facing = _patrol_dir
		velocity.x = _patrol_dir * WALK_SPEED * 0.6
	sprite.play("walk" if velocity.x != 0.0 else "idle")


func _advance_attack() -> void:
	match _state:
		"quake":
			_slam()
			_state = "recover"
			_timer = QUAKE_RECOVER
		"windup":
			_state = "active"
			_timer = ACTIVE
			Sfx.play(self, "swing")
		"active":
			_state = "recover"
			_timer = RECOVER
		_:
			_state = "walk"
			_cooldown = COOLDOWN


## Counts down to an earthquake while the player is at a distance, and starts one
## (remembering where the player is standing) when it's time.
func _try_quake(target, delta: float) -> bool:
	if not active or target == null:
		return false
	var to_player: Vector2 = target.global_position - global_position
	var distance := absf(to_player.x)
	if distance < QUAKE_RANGE.x * _size or distance > QUAKE_RANGE.y * _size or absf(to_player.y) > 120.0 * _size:
		return false
	_quake_timer -= delta
	if _quake_timer > 0.0:
		return false
	_quake_timer = randf_range(QUAKE_INTERVAL.x, QUAKE_INTERVAL.y)
	_quake_target_x = target.global_position.x
	facing = signf(to_player.x) if to_player.x != 0.0 else facing
	velocity.x = 0.0
	_state = "quake"
	_timer = QUAKE_WINDUP
	sprite.play("attack")
	return true


## Slams the ground: three spikes, evenly spaced from just in front of it to the
## remembered spot, each coming up SPIKE_DELAY after the last.
func _slam() -> void:
	Sfx.play(self, "slam")
	var start_x := global_position.x + facing * 34.0 * _size
	for i in 3:
		var x := lerpf(start_x, _quake_target_x, (i + 1) / 3.0)
		var spike := EarthSpike.new()
		spike.size = 1.4 if boss else 1.0
		spike.age = -i * SPIKE_DELAY
		get_tree().current_scene.add_child(spike)
		spike.global_position = Vector2(x, _ground_y(x))


## The floor's height at `x` near the mole (its own height if there's no floor).
func _ground_y(x: float) -> float:
	var query := PhysicsRayQueryParameters2D.create(Vector2(x, global_position.y - 80.0),
		Vector2(x, global_position.y + 240.0), 1, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.position.y if not hit.is_empty() else global_position.y


## Three fireballs fanned toward the player (boss only).
func _volley(target) -> void:
	var mouth := enemy_collision.global_position + Vector2(facing * 22.0 * _size, -6.0 * _size)
	var aim: Vector2 = (target.get_node("player_collision").global_position - mouth).normalized()
	for spread in [-0.35, 0.0, 0.35]:
		var fireball := Fireball.new()
		fireball.velocity = aim.rotated(spread) * Fireball.SPEED
		get_tree().current_scene.add_child(fireball)
		fireball.global_position = mouth
	Sfx.play(self, "fireball")


func _flinch() -> void:
	if boss or dead:
		return
	_state = "hurt"
	_timer = FLINCH
	sprite.play("hurt")
