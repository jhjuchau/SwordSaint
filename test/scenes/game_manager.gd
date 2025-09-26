extends Node

var score = 0;

@onready var swing_label: Label = $swingLabel



# Called when the node enters the scene tree for the first time.
func add_score():
	score += 1
	swing_label.text = "You've swung " + str(score) + " times"
