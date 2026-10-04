extends Area2D

## Ilyra's real-time Arcane Bolt: a small emerald bolt that flies straight ahead,
## hurting the first enemy it reaches (and cutting fireballs, like a sword), and
## bursting on terrain. Frozen while time is stopped.

const Sfx = preload("res://scenes/audio/sfx.gd")
const SPEED := 280.0
const LIFETIME := 0.9

var direction := 1.0
var data := {"damage": 1, "stagger_damage": 14}
var _age := 0.0
var combat


func _ready() -> void:
	name = "sword_area" # Fireballs it touches go out, as with the swords.
	combat = get_tree().get_first_node_in_group("combat_manager")
	collision_layer = 1
	collision_mask = 1
	var shape := CircleShape2D.new()
	shape.radius = 4.0
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if combat and combat.time_stopped:
		return
	_age += delta
	position.x += direction * SPEED * delta
	queue_redraw()
	if _age > LIFETIME:
		_burst()


func _draw() -> void:
	for i in 5:
		draw_circle(Vector2(-direction * (3.0 + i * 3.0), sin(_age * 30.0 + i) * 1.0), 2.5 - i * 0.4, Color(0.7, 0.4, 1.0, 0.5 - i * 0.08))
	draw_circle(Vector2.ZERO, 4.5, Color(0.35, 0.95, 0.5, 0.45))
	draw_circle(Vector2.ZERO, 3.0, Color(0.6, 1.0, 0.7))
	draw_circle(Vector2.ZERO, 1.3, Color(1, 1, 1))


func _on_area_entered(area: Area2D) -> void:
	var enemy := area.get_parent()
	if enemy and enemy.is_in_group("enemies") and enemy.has_method("apply_sword_hit"):
		Sfx.play(self, "hit")
		enemy.apply_sword_hit(data, direction < 0.0)
		_burst()


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("enemies") and body != (combat.player if combat else null):
		_burst()


func _burst() -> void:
	var sparks := CPUParticles2D.new()
	sparks.one_shot = true
	sparks.explosiveness = 0.9
	sparks.amount = 16
	sparks.lifetime = 0.35
	sparks.spread = 180.0
	sparks.initial_velocity_min = 30.0
	sparks.initial_velocity_max = 80.0
	sparks.gravity = Vector2.ZERO
	sparks.color = Color(0.5, 1.0, 0.65)
	get_tree().current_scene.add_child(sparks)
	sparks.global_position = global_position
	sparks.emitting = true
	get_tree().create_timer(0.8).timeout.connect(sparks.queue_free)
	queue_free()
