extends CharacterBody2D

@onready var player_sprite: AnimatedSprite2D = $player_sprite
@onready var charging_player_sprite: AnimatedSprite2D = $charging_player_sprite
@onready var sword_position: Marker2D = $SwordPosition
@onready var foot_position: Marker2D = $FootPosition
@onready var tp_floor_detect: RayCast2D = $TPFloorDetect
@onready var game_manager: Node2D = %GameManager

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
	charging_player_sprite.visible = false
	double_jump_instance = double_jump_scene.instantiate()
	tp_down_instance = tp_down_scene.instantiate()
	facing_left = true
	player_sprite.flip_h = true
	

func _physics_process(delta: float) -> void:
	
	if velocity.x == 0 and is_on_floor():
		player_sprite.play("idle")
	else:
		if is_on_floor() and (Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right")):
			player_sprite.play("run")
	
	# Handle Reset
	if Input.is_action_just_pressed("reset"):
		get_tree().reload_current_scene()
	# Add the gravity.
	if (Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("hor_finisher_shortcut")) and not is_attacking:
		attack()
		
	if Input.is_action_just_pressed("move_left"):
		if facing_left == false:
			player_sprite.flip_h = true
			charging_player_sprite.flip_h = true
			facing_left = true
			facing_right = false
		
	if Input.is_action_just_pressed("move_right"):
		if facing_right == false:
			player_sprite.flip_h = false
			charging_player_sprite.flip_h = false
			facing_right = true
			facing_left = false
			
	if Input.is_action_just_pressed("down") and !is_on_floor():
		if tp_floor_detect.is_colliding():
			var collision_point = tp_floor_detect.get_collision_point()
			
			print("colliding")
			print(collision_point)
			global_position = Vector2(global_position.x, collision_point.y+10)
			$FootPosition.add_child(tp_down_instance)
			var tp_particles = tp_down_instance.get_node("CPUParticles2D")
			tp_particles.emitting = true
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
	if Input.is_action_pressed("charge"):
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
	if !is_on_floor():
		velocity.y -= 50
	sword_instance = get_Attack_Instance_From_Interpreter()
	# sword_instance_hor = preload(ATTACKS["horizontal_1"].attackAssetPath).instantiate()
	#TODO: Figure out some kind of input interpretation to get the right attack object 
	#$SwordPosition.add_child(preload(ATTACKS["horizontal_1"].attackAssetPath).instantiate())
	$SwordPosition.add_child(sword_instance)
	
	if not sword_instance.is_connected("hit_enemy", Callable(self, "_on_sword_hit_enemy")):
		sword_instance.connect("hit_enemy", Callable(self, "_on_sword_hit_enemy"))
		
	var sword_sprite = sword_instance.get_node("AnimatedSprite2D")
	
	if facing_right:
		sword_position.position.x = 22
		sword_sprite.flip_h = true
		sword_instance.position.x = abs(sword_instance.position.x)
	else:
		sword_position.position.x = -10
		sword_sprite.flip_h = false
		sword_instance.position.x = -abs(sword_instance.position.x)
	
	sword_instance.visible = true
	sword_instance.get_node("AnimatedSprite2D").play("attack")
	for shape in sword_instance.get_node("sword_area").get_children():
		if shape is CollisionShape2D:
			shape.set_deferred("disabled", false)
	
	if not sword_instance.get_node("AnimatedSprite2D").is_connected("animation_finished", Callable(self, "_on_sword_animation_finished")):
		sword_instance.get_node("AnimatedSprite2D").connect("animation_finished", Callable(self, "_on_sword_animation_finished"))
		
		
func _on_sword_hit_enemy(enemy, attack_data):
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
