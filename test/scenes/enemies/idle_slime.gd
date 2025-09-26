extends CharacterBody2D

@onready var ray_cast_right: RayCast2D = $RayCastRight
@onready var ray_cast_left: RayCast2D = $RayCastLeft
@onready var enemy_collision: CollisionShape2D = $enemy_collision

const SPEED = 60
var direction := 1 #1 is right, -1 is left
var HP := 3

func _ready() -> void:
	add_to_group("enemies")
	
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	#velocity.x += 1*direction
	if ray_cast_right.is_colliding(): 
		direction = -1
	if ray_cast_left.is_colliding():
		direction = 1
	if not is_on_floor():
		velocity += get_gravity()*.8 * delta
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0, 4)
	move_and_slide()

func _on_killzone_body_entered(body: Node2D) -> void:
	print("body: " + body.name)
	if body.name.begins_with("sword"):
		print("slime collision with sword")
	direction *= -1


#func _on_killzone_area_shape_entered(_area_rid: RID, area: Area2D, _area_shape_index: int, _local_shape_index: int) -> void:
	#print("killzone area shape entered")
	#print("killzone area shape name: " + area.name)
	#if area.name.begins_with("sword"):
		#velocity.x = 0
		#velocity.y -= 150
		#print("slime area collision with sword")

func apply_sword_hit(attack_data, facing_left):
	print("idle slime hit")
	print(attack_data)
	print("facing_left: ", facing_left)
	print(attack_data.x_velocity_change)
	print(attack_data.x_velocity_change/2)
	var applied_velocity = attack_data.x_velocity_change
	if facing_left:
		applied_velocity *= -1
	HP -=1
	#if HP <= 0 :
		#print("idle slime defeated")
		#queue_free()
	if not is_on_floor():
		velocity.x += applied_velocity
	#take less horizontal knockback if on floor		
	else:
		velocity.x += applied_velocity / 2

	print("newly calculated velocity.x: ", velocity.x)
	velocity.y /= 6
	velocity.y += attack_data.y_velocity_change
