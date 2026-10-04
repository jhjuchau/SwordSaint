extends "res://scenes/enemies/enemy_base.gd"

## A bat: hovers near home with a gentle bob, drifting a little toward the player,
## and spits slightly homing fireballs at him in quick succession while he's in range.

const EnemySprites = preload("res://scenes/enemies/enemy_sprites.gd")
const Fireball = preload("res://scenes/enemies/fireball.gd")

const HOVER_SPEED := 70.0
const LEASH := 110.0 # How far it strays from home toward the player.
const SHOOT_RANGE := 260.0
const SHOOT_INTERVAL := 1.1

var _home := Vector2.ZERO
var _bob := 0.0
var _shoot_timer := SHOOT_INTERVAL


func _ready() -> void:
	max_hp = 2
	comboable = false # Too small to be worth a combo: no Stagger Break, a red HP bar.
	_setup_body(EnemySprites.bat_frames(), Vector2.ZERO, Vector2(14, 12), Vector2.ZERO, -16.0)
	_home = global_position
	_bob = randf() * TAU
	sprite.play("fly")
	sprite.animation_finished.connect(func() -> void: sprite.play("fly"))


func _physics_process(delta: float) -> void:
	if dead or frozen():
		return
	var target = player()
	_bob += delta * 2.5
	var goal := _home + Vector2(0, sin(_bob) * 6.0)
	if target:
		var offset: float = target.global_position.x - _home.x
		goal.x += clampf(offset, -LEASH, LEASH) * 0.5
		sprite.flip_h = target.global_position.x < global_position.x
		var to_player: Vector2 = target.get_node("player_collision").global_position - global_position
		if to_player.length() < SHOOT_RANGE:
			_shoot_timer -= delta
			if _shoot_timer <= 0.0:
				_shoot_timer = SHOOT_INTERVAL
				_spit(to_player)
	velocity = ((goal - global_position) * 3.0).limit_length(HOVER_SPEED)
	move_and_slide()


func _spit(to_player: Vector2) -> void:
	var fireball := Fireball.new()
	fireball.velocity = to_player.normalized() * Fireball.SPEED
	get_tree().current_scene.add_child(fireball)
	fireball.global_position = global_position + to_player.normalized() * 8.0
	sprite.play("spit")
	Sfx.play(self, "fireball")
