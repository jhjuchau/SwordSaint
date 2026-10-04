extends Node2D

## The opening level: a stormy village street with moles and bats, then a stepped
## climb up a small mountain to a snowy summit where the Burrow King waits. Reaching
## the summit plays a short cutscene, then the boss fight starts.
##
## The level is built in code: terrain from a height map (_surface_row) using the
## tileset from level_1.tscn, plus the backdrop, weather, enemies and UI.

const Mole = preload("res://scenes/enemies/mole.gd")
const Bat = preload("res://scenes/enemies/bat.gd")
const Storm = preload("res://scenes/opening/storm.gd")
const VillageBackdrop = preload("res://scenes/opening/village_backdrop.gd")
const DialogueBox = preload("res://scenes/opening/dialogue_box.gd")
const FONT := preload("res://assets/2D/brackeys_platformer_assets/fonts/PixelOperator8.ttf")

const TILE := 18
const COLUMNS := 240
const ROWS := 44
const VILLAGE_ROW := 30 # The village street's surface row.
const SUMMIT_ROW := 14
const MOUNTAIN_START := 130 # First column of the climb.
const SUMMIT_START := 158 # First column of the summit.
# The climb: [first column, surface row] steps, two tiles up every four columns.
const CLIMB := [[130, 28], [134, 26], [138, 24], [142, 22], [146, 20], [150, 18], [154, 16], [SUMMIT_START, SUMMIT_ROW]]
const SNOW_LINE := 18 # Surfaces at or above this row are snowy.

const MOLE_COLUMNS := [32, 74, 112]
const BAT_SPOTS := [[52, 110.0], [92, 140.0], [141, 80.0]] # [column, height above its ground]
const BOSS_COLUMN := 176

const BOSS_NAME := "Burrow King"
const BOSS_LINE := "I fucked up ur village lmao"
const PLAYER_NAME := "Sword Saint"
const PLAYER_LINE := "Made by Claude Code"

var boss
var _cutscene_started := false
var _dialogue
var _boss_bar: Control
var _boss_fill: ColorRect

@onready var player = %Player


func _ready() -> void:
	# Everything in the level goes behind the player.
	var world := Node2D.new()
	world.name = "World"
	add_child(world)
	move_child(world, 0)
	var gloom := CanvasModulate.new()
	gloom.color = Color(0.68, 0.72, 0.86)
	add_child(gloom)
	add_child(Storm.new())
	var backdrop := VillageBackdrop.new()
	backdrop.ground_y = VILLAGE_ROW * TILE
	backdrop.village_end = MOUNTAIN_START * TILE
	world.add_child(backdrop)
	world.add_child(_build_terrain())
	_spawn_enemies(world)
	_build_summit_trigger(world)
	_build_boss_bar()
	_dialogue = DialogueBox.new()
	add_child(_dialogue)

	player.global_position = Vector2(5 * TILE, VILLAGE_ROW * TILE - 1)
	player.face(true)
	var camera: Camera2D = player.get_node("Camera2D")
	camera.limit_left = 0
	camera.limit_right = COLUMNS * TILE
	camera.limit_top = -300
	camera.limit_bottom = ROWS * TILE


func _process(_delta: float) -> void:
	if _boss_bar.visible and is_instance_valid(boss):
		_boss_fill.size.x = 400.0 * boss.hp / boss.max_hp


# --- Terrain -----------------------------------------------------------------

## The row of the ground's surface in column `c` (0 = a wall to the top).
func _surface_row(c: int) -> int:
	if c < 2 or c >= COLUMNS - 2:
		return 0
	if (c >= 58 and c <= 61) or (c >= 100 and c <= 103):
		return VILLAGE_ROW - 2 # A couple of raised spots along the street.
	var row := VILLAGE_ROW
	for step in CLIMB:
		if c >= step[0]:
			row = step[1]
	return row


func _build_terrain() -> TileMapLayer:
	var layer := TileMapLayer.new()
	var source_level: Node = load("res://scenes/level_1.tscn").instantiate()
	layer.tile_set = source_level.get_node("TileMapLayer").tile_set
	source_level.free()
	for c in COLUMNS:
		var top := _surface_row(c)
		for r in range(top, ROWS):
			var atlas := Vector2i(posmod(c * 7 + r * 3, 4), 6 + posmod(c + r, 2)) # Dirt.
			if r == top and top > 0:
				atlas = Vector2i(1, 4) if top <= SNOW_LINE else Vector2i(1, 0) # Snow / grass.
			layer.set_cell(Vector2i(c, r), 0, atlas)
	# A floating ledge over the street.
	for c in range(88, 93):
		layer.set_cell(Vector2i(c, VILLAGE_ROW - 5), 0, Vector2i(1, 0))
	return layer


func _ground_y(c: int) -> float:
	return _surface_row(c) * TILE - 1.0


# --- Enemies -----------------------------------------------------------------

func _spawn_enemies(world: Node2D) -> void:
	for c in MOLE_COLUMNS:
		var mole := Mole.new()
		mole.position = Vector2(c * TILE, _ground_y(c))
		world.add_child(mole)
	for spot in BAT_SPOTS:
		var bat := Bat.new()
		bat.position = Vector2(spot[0] * TILE, _ground_y(spot[0]) - spot[1])
		world.add_child(bat)
	boss = Mole.new()
	boss.boss = true
	boss.active = false # Waits for the cutscene.
	boss.facing = -1.0
	boss.position = Vector2(BOSS_COLUMN * TILE, _ground_y(BOSS_COLUMN))
	world.add_child(boss)
	boss.died.connect(_on_boss_died)


# --- The summit cutscene and boss fight --------------------------------------

func _build_summit_trigger(world: Node2D) -> void:
	var trigger := Area2D.new()
	trigger.collision_layer = 0
	trigger.collision_mask = 2 # The player.
	var shape := RectangleShape2D.new()
	shape.size = Vector2(TILE, SUMMIT_ROW * TILE + 300)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	trigger.add_child(collider)
	trigger.position = Vector2((SUMMIT_START + 3) * TILE, SUMMIT_ROW * TILE - shape.size.y / 2.0)
	world.add_child(trigger)
	trigger.body_entered.connect(_on_summit_reached)


func _on_summit_reached(body: Node) -> void:
	if body != player or _cutscene_started:
		return
	_cutscene_started = true
	player.input_locked = true
	await get_tree().create_timer(0.6).timeout
	boss.facing = signf(player.global_position.x - boss.global_position.x)
	# Pan the camera to frame both of them while they talk.
	var camera: Camera2D = player.get_node("Camera2D")
	var home := camera.position
	var pan := camera.create_tween().set_trans(Tween.TRANS_SINE)
	pan.tween_property(camera, "position:x", home.x + (boss.global_position.x - player.global_position.x) / 2.0, 0.8)
	await pan.finished
	await _dialogue.say(BOSS_NAME, BOSS_LINE)
	await _dialogue.say(PLAYER_NAME, PLAYER_LINE)
	pan = camera.create_tween().set_trans(Tween.TRANS_SINE)
	pan.tween_property(camera, "position:x", home.x, 0.5)
	player.input_locked = false
	boss.active = true
	_boss_bar.show()


func _build_boss_bar() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	_boss_bar = VBoxContainer.new()
	_boss_bar.position = Vector2(376, 588)
	_boss_bar.hide()
	layer.add_child(_boss_bar)
	var label := Label.new()
	label.text = BOSS_NAME.to_upper()
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.6))
	_boss_bar.add_child(label)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(400, 12)
	_boss_bar.add_child(bar)
	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.6)
	back.size = Vector2(400, 12)
	bar.add_child(back)
	_boss_fill = ColorRect.new()
	_boss_fill.color = Color(0.85, 0.2, 0.2)
	_boss_fill.size = Vector2(400, 12)
	bar.add_child(_boss_fill)


func _on_boss_died() -> void:
	_boss_bar.hide()
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2(0, 230)
	box.custom_minimum_size = Vector2(1152, 0)
	layer.add_child(box)
	for line in [["VICTORY", 64, Color(1.0, 0.8, 0.3)], ["The storm begins to clear...", 16, Color(0.85, 0.9, 1.0)]]:
		var label := Label.new()
		label.text = line[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", FONT)
		label.add_theme_font_size_override("font_size", line[1])
		label.add_theme_color_override("font_color", line[2])
		label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.05))
		label.add_theme_constant_override("outline_size", 8)
		box.add_child(label)
	box.modulate.a = 0.0
	box.create_tween().tween_property(box, "modulate:a", 1.0, 1.0)
