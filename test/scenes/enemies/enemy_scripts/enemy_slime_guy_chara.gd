extends CharacterBody2D

@onready var ray_cast_right: RayCast2D = $RayCastRight
@onready var ray_cast_left: RayCast2D = $RayCastLeft
@onready var enemy_collision: CollisionShape2D = $enemy_collision

const SPEED = 60
const MAX_STAGGER := 30.0
const StaggerMeter = preload("res://scenes/combat/stagger_meter.gd")
var direction := 1 #1 is right, -1 is left
var HP := 3
var stagger_meter # stagger_meter.gd, created in _ready()

@onready var combat = get_tree().get_first_node_in_group("combat_manager")

func _ready() -> void:
	add_to_group("enemies")
	stagger_meter = StaggerMeter.new()
	stagger_meter.max_stagger = MAX_STAGGER
	stagger_meter.reset()
	stagger_meter.position = Vector2(0, -6)
	add_child(stagger_meter)
	
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# Frozen during a Stagger Break; the CombatManager moves us instead.
	if combat and combat.time_stopped:
		return
	velocity.x += 1*direction
	if ray_cast_right.is_colliding(): 
		# print("slime collision")
		direction = -1
	if ray_cast_left.is_colliding():
		direction = 1
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	move_and_slide()

func _on_killzone_body_entered(body: Node2D) -> void:
	print("body: " + body.name)
	if body.name.begins_with("sword"):
		print("slime collision with sword")
	direction *= -1

#func _on_killzone_area_entered(area: Area2D) -> void:
	#print("area: " + area.name)
	#if area.name.begins_with("sword"):
		#velocity.x = 0
		#velocity.y = -100
		#position.y += 50
		#print("slime area collision with sword")
	#direction *= -1


#func _on_killzone_area_shape_entered(area_rid: RID, area: Area2D, area_shape_index: int, local_shape_index: int) -> void:
	#print("killzone area shape entered")
	#print("killzone area shape name: " + area.name)
	#if area.name.begins_with("sword"):
		#velocity.x = 0
		#velocity.y -= 150
		#print("slime area collision with sword")

# Real-time hits deal no knockback; only Stagger Break attacks move enemies.
func apply_sword_hit(attack_data, _facing_left):
	#print("slime hit by sword from emitted event")
	apply_stagger(attack_data.get("stagger_damage", 0))


func apply_stagger(amount: float) -> void:
	if combat == null or combat.time_stopped:
		return
	if stagger_meter.take(amount):
		combat.start_stagger_break(self)
