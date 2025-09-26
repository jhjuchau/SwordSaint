extends Node

const ATTACKS = {
	"horizontal_1": {
		"damage": 10,
		"knockback": -100,
		"attackNodeName": "sword_hor_area",
		"attackAssetPath": "res://scenes/attacks/sword_horizontal.tscn"
	},
	"launch": {
		"damage": 10,
		"knockback": -500,
		"attackNodeName": "sword_launch_area",
		"attackAssetPath": "res://scenes/attacks/sword_launch.tscn"
	}
}

func get_attack(name):
	if ATTACKS.has(name):
		return ATTACKS[name]
	return null
