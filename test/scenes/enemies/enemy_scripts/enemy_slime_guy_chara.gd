extends CharacterBody2D

@onready var ray_cast_right: RayCast2D = $RayCastRight
@onready var ray_cast_left: RayCast2D = $RayCastLeft
@onready var enemy_collision: CollisionShape2D = $enemy_collision

const SPEED = 60
var direction := 1 #1 is right, -1 is left

func _ready() -> void:
	add_to_group("enemies")
	
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
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

func apply_sword_hit(attack_data, facing_left):
	#print("slime hit by sword from emitted event")
	velocity.x = 0
	velocity.y /= 2 
	velocity.y += attack_data.y_velocity_change
