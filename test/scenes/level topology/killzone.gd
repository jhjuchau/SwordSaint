extends Area2D

@onready var timer: Timer = $Timer

#func _on_body_entered(body: Node2D) -> void:
	#print(body.name)
	##if body.name.begins_with("Player"):
		##print ("body ded")
		##timer.start()
#
#func _on_area_entered(area: Node2D) -> void:
	#
	##print("area ded")
	##timer.start()

func _on_timer_timeout() -> void:
	get_tree().reload_current_scene()
