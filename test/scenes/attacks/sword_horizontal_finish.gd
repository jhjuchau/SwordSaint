extends Node2D

signal hit_enemy(enemy, attack_data)

var attack_data = {
	"x_velocity_change": 285,
	"y_velocity_change": -80,
	"damage": 1
}
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

#func _on_sword_hor_area_area_entered(area: Area2D) -> void:
	


func _on_sword_area_area_entered(area: Area2D) -> void:
	print("horizontal finisher: _area_entered() called")
	print("area: " + area.name)
	if area.get_parent().is_in_group("enemies"):
		print("enemy detected ("+area.name+"), emitting event")
		emit_signal("hit_enemy", area.get_parent(), attack_data)

#
#func _on_sword_area_area_shape_entered(area_rid: RID, area: Area2D, area_shape_index: int, local_shape_index: int) -> void:
	#print("horizontal finisher: area SHAPE called")
	#print("area: " + area.name)
	#if area.get_parent().is_in_group("enemies"):
		#print("enemy detected ("+area.name+"), emitting event")
		#emit_signal("hit_enemy", area.get_parent(), attack_data)
