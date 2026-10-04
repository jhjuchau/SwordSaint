extends Node2D

signal hit_enemy(enemy, attack_data)

var attack_data = {
	"x_velocity_change": 5,
	"y_velocity_change": -450,
	"damage": 1,
	"stagger_damage": 10 # Enemies have 30 stagger, so 3 hits cause a Stagger Break.
}
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_sword_launch_area_area_entered(area: Area2D) -> void:
	print("launch _area_entered() called")
	if area.get_parent().is_in_group("enemies"):
		print("enemy detected ("+area.name+"), emitting event")
		emit_signal("hit_enemy", area.get_parent(), attack_data)


func _on_sword_area_area_entered(area: Area2D) -> void:
	print("launch _area_entered() called")
	if area.get_parent().is_in_group("enemies"):
		print("enemy detected ("+area.name+"), emitting event")
		emit_signal("hit_enemy", area.get_parent(), attack_data)
