extends CharacterBody2D

@onready var player_sprite: AnimatedSprite2D = $player_sprite
@onready var charging_player_sprite: AnimatedSprite2D = $charging_player_sprite
@onready var sword_position: Marker2D = $SwordPosition
@onready var foot_position: Marker2D = $FootPosition
@onready var tp_floor_detect: RayCast2D = $TPFloorDetect
@onready var game_manager: Node2D = %GameManager
@onready var combat = %CombatManager

const Sfx = preload("res://scenes/audio/sfx.gd")
const SlashSprite = preload("res://scenes/attacks/slash_sprite.gd")
const StormLightning = preload("res://scenes/attacks/storm_lightning.gd")
const PlayerSprites = preload("res://scenes/player_sprites.gd")
const PlayerCloak = preload("res://scenes/player_cloak.gd")
const Characters = preload("res://scenes/characters/characters.gd")
const DogoodSprites = preload("res://scenes/characters/dogood_sprites.gd")
const ElfSprites = preload("res://scenes/characters/elf_sprites.gd")
const ArcaneBolt = preload("res://scenes/attacks/arcane_bolt.gd")
const Sparkle = preload("res://scenes/combat/sparkle.gd")

# Dogood's real-time attacks: slower and heavier than the Saint's swings. Each winds
# up for `startup` seconds, hits in `box` (from his feet, facing right) for `active`
# seconds, and he's committed until `total`. `lunge`: px/s he steps forward while
# it's active.
const DOGOOD_ATTACKS := {
	"flash_chop": {"anim": &"flash_chop", "startup": 0.18, "active": 0.09, "total": 0.45,
		"box": Rect2(6, -32, 28, 28), "damage": 1, "stagger_damage": 12, "sound": "hit", "flash": true},
	"big_boot": {"anim": &"big_boot", "startup": 0.3, "active": 0.15, "total": 0.7,
		"box": Rect2(8, -44, 34, 40), "damage": 2, "stagger_damage": 18, "sound": "heavy_hit", "lunge": 60.0},
	"headbutt": {"anim": &"headbutt", "startup": 0.25, "active": 0.1, "total": 0.6,
		"box": Rect2(4, -40, 24, 34), "damage": 2, "stagger_damage": 15, "sound": "heavy_hit", "lunge": 40.0},
}
# Ilyra's: a staff swing, and an Arcane Bolt fired from the orb ("projectile").
const ELF_ATTACKS := {
	"staff_swing": {"anim": &"staff_swing", "startup": 0.12, "active": 0.1, "total": 0.38,
		"box": Rect2(6, -36, 32, 32), "damage": 1, "stagger_damage": 10, "sound": "hit"},
	"arcane_bolt": {"anim": &"arcane_bolt", "startup": 0.18, "active": 0.0, "total": 0.45, "projectile": true,
		"box": Rect2(26, -12, 0, 0), "damage": 1, "stagger_damage": 14, "sound": "hit"},
}

# The body pose (see player_sprites.gd) each real-time sword attack plays.
const ATTACK_POSES := {
	"res://scenes/attacks/sword_horizontal.tscn": &"slash",
	"res://scenes/attacks/sword_launch.tscn": &"uppercut",
	"res://scenes/attacks/sword_horizontal_finish.tscn": &"heavy",
	"res://scenes/attacks/sword_launch_alex.tscn": &"heavy",
}

const SPEED = 250.0
const JUMP_VELOCITY = -275.0
const ATTACKS = {
	"horizontal_1": {
		"damage": 10,
		"knockback": -100,
		"attackNodeName": "sword_hor_area",
		"attackAssetPath": "res://scenes/attacks/sword_horizontal.tscn"
	},
	"horizontal_finish": {
		"attackAssetPath": "res://scenes/attacks/sword_horizontal_finish.tscn"
	},
	"launch": {
		"damage": 10,
		"knockback": -500,
		"attackNodeName": "sword_launch_area",
		"attackAssetPath": "res://scenes/attacks/sword_launch.tscn"
	},
	"alex_sword": {
		"attackAssetPath": "res://scenes/attacks/sword_launch_alex.tscn"	
	},
	
}


#var sword_scene_hor = preload("res://scenes/attacks/sword_horizontal.tscn")
#var sword_scene_launch = preload("res://scenes/attacks/sword_launch.tscn")
var sword_scene = preload("res://scenes/attacks/sword_horizontal.tscn")

var double_jump_scene = preload("res://scenes/attacks/double_jump.tscn")
var double_jump_instance = null

var tp_down_scene = preload("res://scenes/attacks/tp_air_to_ground.tscn")
var tp_down_instance = null

var sword_instance = null
var cloak # player_cloak.gd
var was_airborne := false

const MAX_HP := 10
const INVULNERABLE_SECONDS := 1.0
const REEL_SECONDS := 0.4
var hp := MAX_HP
var dead := false
var input_locked := false # Cutscenes.
var _reel_time := 0.0
var _invulnerable_time := 0.0
## Active buffs: name -> seconds left (see CombatManager.BUFFS). They run down in
## real time only.
var buffs := {}
## Who this is (see characters.gd): their sprite set (frames(), anchor(), ...), the
## Stagger Break intro animation, and the moves the CombatManager offers.
var character: String = Characters.selected
var sprites = PlayerSprites
var intro_animation := &"meditate"
var _move: Dictionary = {} # Dogood's real-time attack in progress, or {}.
var _move_time := 0.0
var _hitbox: Area2D
var _hit_enemies := []
#var sword_instance_launch = null
var attackLib = null
var is_attacking = false
var facing_left = true
var facing_right = false
var isCharging = false
var doubleJumpAvailable = true

func _ready() -> void:
	#sword_instance_hor = preload(ATTACKS["horizontal_1"].attackAssetPath).instantiate()
	#sword_instance_launch = sword_scene_launch.instantiate()
	# var sword_scene_launch = preload("res://scenes/attacks/sword_launch.tscn").instantiate()
	# The character art is generated in code (player_sprites.gd), replacing the
	# placeholder frames in player.tscn.
	if character == Characters.DOGOOD:
		sprites = DogoodSprites
		intro_animation = &"intro"
	elif character == Characters.ELF:
		sprites = ElfSprites
		intro_animation = &"intro"
	player_sprite.sprite_frames = sprites.frames()
	player_sprite.position = sprites.ORIGIN_OFFSET
	player_sprite.play("idle")
	charging_player_sprite.sprite_frames = sprites.frames()
	charging_player_sprite.position = sprites.ORIGIN_OFFSET
	charging_player_sprite.play("charge")
	# The robe's (or cape's) tail is its own layer, drawn just behind the body.
	cloak = PlayerCloak.new()
	cloak.player = self
	cloak.style = character
	add_child(cloak)
	move_child(cloak, player_sprite.get_index())
	charging_player_sprite.visible = false
	double_jump_instance = double_jump_scene.instantiate()
	tp_down_instance = tp_down_scene.instantiate()
	facing_left = true
	player_sprite.flip_h = true
	# Generate the slash animations now, rather than hitching on each one's first swing.
	for arc in SlashSprite.ARCS:
		SlashSprite.frames_for(arc)
	

func _physics_process(delta: float) -> void:
	# Handle Reset
	if Input.is_action_just_pressed("reset"):
		get_tree().reload_current_scene()
	
	# Time is stopped during a Stagger Break; the CombatManager moves the player instead.
	if combat.time_stopped:
		return
	for buff in buffs.keys():
		buffs[buff] -= delta
		if buffs[buff] <= 0.0:
			buffs.erase(buff)

	# Flicker while briefly invulnerable after a hit.
	_invulnerable_time = maxf(_invulnerable_time - delta, 0.0)
	player_sprite.modulate.a = 0.45 if _invulnerable_time > 0.0 and int(_invulnerable_time * 16.0) % 2 == 0 else 1.0
	# Reeling from a hit, dead, or in a cutscene: no control, just gravity and friction.
	if dead or input_locked or _reel_time > 0.0:
		_reel_time = maxf(_reel_time - delta, 0.0)
		if not is_on_floor():
			velocity += get_gravity() * 0.8 * delta
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 4.0 * delta)
		if input_locked and _reel_time <= 0.0 and is_on_floor() and player_sprite.animation != &"idle":
			player_sprite.play("idle")
		move_and_slide()
		return
	
	# Attack poses play out undisturbed; otherwise pick the movement animation.
	# Landing plays out after touching down, but any movement (or a jump or an attack)
	# cuts it short.
	if not is_attacking:
		var moving := Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right")
		if not is_on_floor():
			player_sprite.play("jump" if velocity.y < 0 else "fall")
		elif was_airborne:
			player_sprite.play("land")
		elif moving:
			player_sprite.play("run")
			# The run is timed for full speed; slow it down to match while accelerating.
			player_sprite.speed_scale = clampf(absf(velocity.x) / SPEED, 0.3, 1.0)
		elif player_sprite.animation == &"land" and player_sprite.is_playing():
			pass
		else:
			player_sprite.play("idle")
	if player_sprite.animation != &"run":
		player_sprite.speed_scale = 1.0
	was_airborne = not is_on_floor()
	
	# Add the gravity.
	if (Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("hor_finisher_shortcut")) and not is_attacking:
		if character == Characters.DOGOOD or character == Characters.ELF:
			_start_wrestler_attack()
		else:
			attack()
	if not _move.is_empty():
		_update_wrestler_attack(delta)
		return
		
	if Input.is_action_just_pressed("move_left"):
		face(false)
		
	if Input.is_action_just_pressed("move_right"):
		face(true)
			
	if Input.is_action_just_pressed("down") and !is_on_floor() and character == Characters.SAINT:
		if tp_floor_detect.is_colliding():
			var collision_point = tp_floor_detect.get_collision_point()
			
			print("colliding")
			print(collision_point)
			global_position = Vector2(global_position.x, collision_point.y+10)
			play_tp_down_effect()
			velocity.y = 0
			
		
	if not is_on_floor():
		velocity += get_gravity()*.8 * delta
	
	# Handle jump and double jump
	# =====
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	
	if Input.is_action_just_pressed("jump") and !is_on_floor() and doubleJumpAvailable:
		player_sprite.play("jump")
		$FootPosition.add_child(double_jump_instance)
		var dj_particles = double_jump_instance.get_node("CPUParticles2D")
		dj_particles.emitting = true
		#dj_particles.one_shot = true
		double_jump_instance.visible = true
		velocity.y /= 2
		velocity.y += JUMP_VELOCITY
		doubleJumpAvailable = false
		
	if is_on_floor():
		doubleJumpAvailable = true	
	
	# Handle charge
	# =====
	if Input.is_action_pressed("charge") and character == Characters.SAINT:
		player_sprite.visible = false
		charging_player_sprite.visible = true
		isCharging = true
	
	if Input.is_action_just_released("charge"):
		player_sprite.visible = true
		charging_player_sprite.visible = false
		isCharging = false
		
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	#var direction := Input.get_axis("ui_left", "ui_right")
	var direction := Input.get_axis("move_left", "move_right")
	
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func attack():
	is_attacking = true
	Sfx.play(self, "swing")
	sword_instance = get_Attack_Instance_From_Interpreter()
	# sword_instance_hor = preload(ATTACKS["horizontal_1"].attackAssetPath).instantiate()
	#TODO: Figure out some kind of input interpretation to get the right attack object 
	#$SwordPosition.add_child(preload(ATTACKS["horizontal_1"].attackAssetPath).instantiate())
	$SwordPosition.add_child(sword_instance)
	SlashSprite.apply_to(sword_instance)
	
	if not sword_instance.is_connected("hit_enemy", Callable(self, "_on_sword_hit_enemy")):
		sword_instance.connect("hit_enemy", Callable(self, "_on_sword_hit_enemy"))
		
	_orient_sword(sword_instance)
	if has_buff("storm"):
		StormLightning.attach(sword_instance)
	player_sprite.play(ATTACK_POSES.get(sword_instance.scene_file_path, &"slash"))
	
	sword_instance.visible = true
	sword_instance.get_node("AnimatedSprite2D").play("attack")
	for shape in sword_instance.get_node("sword_area").get_children():
		if shape is CollisionShape2D:
			shape.set_deferred("disabled", false)
	
	if not sword_instance.get_node("AnimatedSprite2D").is_connected("animation_finished", Callable(self, "_on_sword_animation_finished")):
		sword_instance.get_node("AnimatedSprite2D").connect("animation_finished", Callable(self, "_on_sword_animation_finished"))
		
		
# Checked against the floor directly, so it stays accurate while time is stopped
# (is_on_floor() only updates during move_and_slide()).
func is_airborne() -> bool:
	return not test_move(global_transform, Vector2(0, 1))

func face(right: bool) -> void:
	facing_right = right
	facing_left = not right
	player_sprite.flip_h = not right
	charging_player_sprite.flip_h = not right

# Points a sword scene the way the player is facing.
func _orient_sword(instance: Node2D) -> void:
	orient_sword(instance, sword_position, facing_right)

# Points a sword scene parented to `marker` (the player's SwordPosition, or a ghost
# preview's copy of it) to the right or left.
static func orient_sword(instance: Node2D, marker: Node2D, right: bool) -> void:
	var sword_sprite = instance.get_node("AnimatedSprite2D")
	if right:
		marker.position.x = 22
		sword_sprite.flip_h = true
		instance.position.x = abs(instance.position.x)
	else:
		marker.position.x = -10
		sword_sprite.flip_h = false
		instance.position.x = -abs(instance.position.x)

# Plays a visual-only sword swing for a combo-phase attack; the CombatManager resolves the hit.
# `storm`: with the Storm buff's lightning (decided when the combo was planned).
func play_combo_sword(scene: PackedScene, animation: StringName, storm := false) -> void:
	var instance: Node2D = scene.instantiate()
	sword_position.add_child(instance)
	SlashSprite.apply_to(instance)
	_orient_sword(instance)
	if storm:
		StormLightning.attach(instance)
	instance.get_node("sword_area").set_deferred("monitoring", false)
	var sprite: AnimatedSprite2D = instance.get_node("AnimatedSprite2D")
	sprite.animation_finished.connect(instance.queue_free)
	sprite.play(animation)

func add_buff(buff: String, seconds: float) -> void:
	buffs[buff] = maxf(buffs.get(buff, 0.0), seconds)


func has_buff(buff: String) -> bool:
	return buffs.get(buff, 0.0) > 0.0


func play_tp_down_effect() -> void:
	Sfx.play(self, "tp")
	if tp_down_instance.get_parent() == null:
		foot_position.add_child(tp_down_instance)
	tp_down_instance.get_node("CPUParticles2D").restart()

## Hit in real time by an enemy attack from `from`: knocked back, reeling, -1 HP,
## then briefly invulnerable.
func take_hit(from: Vector2) -> void:
	if dead or _invulnerable_time > 0.0 or combat.time_stopped:
		return
	_invulnerable_time = INVULNERABLE_SECONDS
	_reel_time = REEL_SECONDS
	is_attacking = false
	velocity = Vector2(160.0 * (1.0 if global_position.x >= from.x else -1.0), -140.0)
	player_sprite.play("reel")
	Sfx.play(self, "player_hit")
	_lose_hp()


## Hit during a planned combo (when it plays out): the combo carries on, so no
## knockback; the reel pose comes from the plan.
func combo_hit() -> void:
	Sfx.play(self, "player_hit")
	_lose_hp()


func _lose_hp() -> void:
	hp = maxi(hp - 1, 0)
	if hp == 0 and not dead:
		dead = true
		player_sprite.play("reel")
		# Back to the start of the level.
		get_tree().create_timer(2.0).timeout.connect(get_tree().reload_current_scene)


func _on_sword_hit_enemy(enemy, attack_data):
	Sfx.play(self, "hit")
	print("on_sword_hit_enemy() called")
	print("enemy: " + enemy.name)
	enemy.apply_sword_hit(attack_data, facing_left)
	
func _on_sword_animation_finished():
	is_attacking = false
	# Hide the sword after the animation
	if sword_instance != null:
		sword_instance.visible = false
	for shape in sword_instance.get_node("sword_area").get_children():
		if shape is CollisionShape2D:
			shape.set_deferred("disabled", true)
			
func _on_double_jump_finished():
	if double_jump_instance != null:
		double_jump_instance.visible = false
	for shape in double_jump_instance.get_node("double_jump_area").get_children():
		if shape is CollisionShape2D:
			shape.set_deferred("disabled", true)

# --- Dogood's real-time attacks ------------------------------------------------

## Dogood: attack alone, Flash Chop; moving (or V), Big Boot; holding Z, Headbutt.
## Ilyra: Staff Swing; holding Z (or V), Arcane Bolt.
func _start_wrestler_attack() -> void:
	if character == Characters.ELF:
		var bolt := Input.is_action_pressed("charge") or Input.is_action_pressed("hor_finisher_shortcut")
		_move = ELF_ATTACKS["arcane_bolt" if bolt else "staff_swing"]
	else:
		var id := "flash_chop"
		if Input.is_action_pressed("charge"):
			id = "headbutt"
		elif Input.is_action_pressed("hor_finisher_shortcut") or Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
			id = "big_boot"
		_move = DOGOOD_ATTACKS[id]
	game_manager.add_score()
	_move_time = 0.0
	_hit_enemies.clear()
	is_attacking = true
	player_sprite.play(_move.anim)


## Committed to the attack: he stands his ground (stepping in while it's active), and
## its hitbox is out only during the active window.
func _update_wrestler_attack(delta: float) -> void:
	var before := _move_time
	_move_time += delta
	var active_from: float = _move.startup
	var active_to: float = _move.startup + _move.active
	if before < active_from and _move_time >= active_from:
		Sfx.play(self, "swing")
		if _move.get("projectile", false):
			var shot := ArcaneBolt.new()
			shot.direction = 1.0 if facing_right else -1.0
			shot.data = {"damage": _move.damage, "stagger_damage": _move.stagger_damage}
			get_tree().current_scene.add_child(shot)
			shot.global_position = global_position + Vector2(_move.box.position.x * shot.direction, _move.box.position.y)
		else:
			_open_hitbox()
		if _move.get("flash", false):
			var flash := Sparkle.new()
			flash.size = 9.0
			flash.duration = 0.18
			get_tree().current_scene.add_child(flash)
			flash.global_position = global_position + Vector2((_move.box.end.x - 6.0) * (1.0 if facing_right else -1.0), _move.box.get_center().y)
	if before < active_to and _move_time >= active_to:
		_close_hitbox()
	var lunge: float = _move.get("lunge", 0.0) if _move_time >= active_from and _move_time < active_to else 0.0
	velocity.x = lunge * (1.0 if facing_right else -1.0) if lunge > 0.0 else move_toward(velocity.x, 0.0, SPEED * 6.0 * delta)
	if not is_on_floor():
		velocity += get_gravity() * 0.8 * delta
	move_and_slide()
	if _move_time >= _move.total:
		_close_hitbox()
		_move = {}
		is_attacking = false


func _open_hitbox() -> void:
	_close_hitbox()
	_hitbox = Area2D.new()
	_hitbox.name = "sword_area" # So it cuts fireballs, like the Saint's swords.
	_hitbox.collision_layer = 1
	_hitbox.collision_mask = 1
	var box: Rect2 = _move.box
	var shape := RectangleShape2D.new()
	shape.size = box.size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = Vector2(box.get_center().x * (1.0 if facing_right else -1.0), box.get_center().y)
	_hitbox.add_child(collider)
	add_child(_hitbox)
	_hitbox.area_entered.connect(_on_wrestler_hit)


func _close_hitbox() -> void:
	if _hitbox and is_instance_valid(_hitbox):
		_hitbox.queue_free()
	_hitbox = null


func _on_wrestler_hit(area: Area2D) -> void:
	var enemy := area.get_parent()
	if not enemy.is_in_group("enemies") or enemy in _hit_enemies:
		return
	_hit_enemies.append(enemy)
	Sfx.play(self, _move.sound)
	enemy.apply_sword_hit({"damage": _move.damage, "stagger_damage": _move.stagger_damage}, facing_left)


func get_Attack_Instance_From_Interpreter() -> Node:
	game_manager.add_score()
	if Input.is_action_pressed("hor_finisher_shortcut"):
		return preload(ATTACKS["horizontal_finish"].attackAssetPath).instantiate()
	if(!isCharging):
		return preload(ATTACKS["horizontal_1"].attackAssetPath).instantiate()
	else:
		if (Input.is_action_pressed("down")):
			print("alex sword")
			return preload(ATTACKS["alex_sword"].attackAssetPath).instantiate()
		if Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
			return preload(ATTACKS["horizontal_finish"].attackAssetPath).instantiate()
		return preload(ATTACKS["launch"].attackAssetPath).instantiate()
