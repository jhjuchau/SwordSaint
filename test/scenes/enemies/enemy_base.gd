extends CharacterBody2D

## Shared by the opening level's enemies (mole, bat, boss): HP, a stagger meter, the
## hooks the player's attacks and the Stagger Break call (apply_sword_hit,
## apply_stagger, take_damage), freezing while time is stopped, and dying.
## Builds its own nodes (AnimatedSprite2D, enemy_collision, and a hurtbox the
## player's swords detect), so no scene file is needed.
##
## `comboable` enemies have a yellow stagger meter and open a Stagger Break when it
## empties. Others (small fry like the bat, not worth a combo) never do: their bar
## is a red HP bar instead, and real-time hits just wear down their HP.

signal died

const StaggerMeter = preload("res://scenes/combat/stagger_meter.gd")
const Sfx = preload("res://scenes/audio/sfx.gd")

const FLASH_SECONDS := 0.12
const HP_BAR_COLOR := Color(0.9, 0.2, 0.2)

var max_hp := 4
var hp := 4
var max_stagger := 30.0
var comboable := true
var dead := false
var stagger_meter # stagger_meter.gd
var combat
var sprite: AnimatedSprite2D
var enemy_collision: CollisionShape2D
var _flash := 0.0


## Creates the sprite, body, hurtbox and stagger bar. Offsets are for scale 1 and
## are multiplied by `size` (the boss is a scaled-up mole).
func _setup_body(frames: SpriteFrames, sprite_offset: Vector2, body_size: Vector2, body_offset: Vector2,
		bar_height: float, size := 1.0) -> void:
	add_to_group("enemies")
	combat = get_tree().get_first_node_in_group("combat_manager")
	sprite = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = frames
	sprite.position = sprite_offset * size
	sprite.scale = Vector2.ONE * size
	add_child(sprite)
	var shape := RectangleShape2D.new()
	shape.size = body_size * size
	enemy_collision = CollisionShape2D.new()
	enemy_collision.name = "enemy_collision"
	enemy_collision.shape = shape
	enemy_collision.position = body_offset * size
	add_child(enemy_collision)
	var hurtbox := Area2D.new()
	hurtbox.name = "hurtbox"
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	var hurt_shape := CollisionShape2D.new()
	hurt_shape.shape = shape
	hurt_shape.position = enemy_collision.position
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)
	hp = max_hp
	stagger_meter = StaggerMeter.new()
	stagger_meter.max_stagger = max_stagger if comboable else float(max_hp)
	if not comboable:
		stagger_meter.fill_color = HP_BAR_COLOR
	stagger_meter.reset()
	stagger_meter.position = Vector2(0, bar_height * size)
	add_child(stagger_meter)


func frozen() -> bool:
	return combat != null and combat.time_stopped


func player():
	return combat.player if combat else null


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	if sprite:
		sprite.modulate = Color(1.0, 0.45, 0.45) if _flash > 0.0 else Color.WHITE


## A real-time sword hit: damage, a red flash, and stagger.
func apply_sword_hit(attack_data, _facing_left) -> void:
	if dead or frozen():
		return
	take_damage(attack_data.get("damage", 1))
	_flinch()
	if not dead:
		apply_stagger(attack_data.get("stagger_damage", 0))


func apply_stagger(amount: float) -> void:
	if combat == null or combat.time_stopped or dead or not comboable:
		return
	if stagger_meter.take(amount):
		combat.start_stagger_break(self)


## Loses HP. In real time, dying happens at once; during a Stagger Break the
## CombatManager finishes it off when the break ends.
func take_damage(amount: int) -> void:
	if dead:
		return
	hp = maxi(hp - amount, 0)
	_flash = FLASH_SECONDS
	if not comboable:
		stagger_meter.stagger = hp
		stagger_meter.queue_redraw()
	if hp == 0 and not frozen():
		die()


func die() -> void:
	if dead:
		return
	dead = true
	died.emit()
	Sfx.play(self, "enemy_die")
	var poof := CPUParticles2D.new()
	poof.one_shot = true
	poof.explosiveness = 0.9
	poof.amount = 40
	poof.lifetime = 0.7
	poof.spread = 180.0
	poof.initial_velocity_min = 30.0
	poof.initial_velocity_max = 110.0
	poof.gravity = Vector2(0, -20)
	poof.damping_min = 60.0
	poof.damping_max = 120.0
	poof.scale_amount_min = 1.5
	poof.scale_amount_max = 4.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.82, 0.8, 0.9))
	ramp.set_color(1, Color(0.4, 0.38, 0.42, 0.0))
	poof.color_ramp = ramp
	get_tree().current_scene.add_child(poof)
	poof.global_position = enemy_collision.global_position
	poof.emitting = true
	get_tree().create_timer(1.5).timeout.connect(poof.queue_free)
	queue_free()


## Override for a hit reaction.
func _flinch() -> void:
	pass
