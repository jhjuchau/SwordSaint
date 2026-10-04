extends Node2D

## Loops a planned combo move (see CombatManager.ComboPlan) with translucent grey
## (or tinted) ghosts of the player and enemy, in the real positions it will play out
## at, while the real bodies stay frozen. The CombatManager runs two of these at once:
## one for the planned timeline, one for the highlighted move. Enemy projectiles
## (fireballs, earth spikes) the plan simulates are drawn as ghosts too.

const GrappleRope := preload("res://scenes/combat/grapple_rope.gd")
const Sparkle := preload("res://scenes/combat/sparkle.gd")
const SlashSprite := preload("res://scenes/attacks/slash_sprite.gd")
const PlayerSprites := preload("res://scenes/player_sprites.gd")
const PlayerCloak := preload("res://scenes/player_cloak.gd")
const StormLightning := preload("res://scenes/attacks/storm_lightning.gd")
const LightningBolt := preload("res://scenes/combat/lightning_bolt.gd")
const Kite := preload("res://scenes/combat/kite.gd")
const Spell := preload("res://scenes/combat/spell.gd")

const HOLD_FRAMES := 30 # Pause on the final pose before the loop restarts.
const GHOST_SHADER_CODE := """
shader_type canvas_item;
// Greyscale (times `tint`) and translucent, ignoring the node's own color.
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(0.4 + lum * 0.55) * tint.rgb, tex.a * 0.65);
}
"""
const SPARKLE_GHOST_MODULATE := Color(0.75, 0.75, 0.75, 0.55)

var _player # The real player, for its sprite frames, offsets and facing.
var _enemy
var _plan
var _frame := 0
var _start := {} # Optional starting pose overrides; see play().
var _anim := &"" # Player pose animating since frame _anim_start; "" = the still start frame.
var _anim_start := 0
var _material := ShaderMaterial.new()
var _player_ghost: Node2D
var _player_sprite: Sprite2D
var _cloak_sprite: Sprite2D
var _cloak := Vector2.ZERO
var _cloak_anim := &"" # The animation/frame the player ghost is showing, for the cloak's anchor.
var _cloak_frame := 0
var _sword_marker: Node2D
var _enemy_ghost: Node2D
var _enemy_sprite: Sprite2D
var _rope: Node2D
var _transient: Array[Node] = [] # Swords and sparkles spawned this loop.
## The real projectile nodes, matching the plan frames' "projectiles" states by index
## (they draw their own ghosts: see the interface in fireball.gd).
var projectiles: Array = []
var _projectile_sprites: Array[Sprite2D] = []
var _kite_sprite: Sprite2D # Dogood's kite, and its string to the ghost's hand.
var _spells: Array = [] # Ilyra's spells, by index.
var _tint := Color.WHITE
var _kite_string: Line2D


func _ready() -> void:
	top_level = true
	z_index = 4 # In front of the frozen originals.
	var shader := Shader.new()
	shader.code = GHOST_SHADER_CODE
	_material.shader = shader

	_player_ghost = Node2D.new()
	add_child(_player_ghost)
	_cloak_sprite = _make_sprite(_player_ghost) # Behind the body.
	_player_sprite = _make_sprite(_player_ghost)
	_sword_marker = Node2D.new()
	_player_ghost.add_child(_sword_marker)
	_enemy_ghost = Node2D.new()
	add_child(_enemy_ghost)
	_enemy_sprite = _make_sprite(_enemy_ghost)
	_rope = GrappleRope.new()
	_rope.ghost = true
	add_child(_rope)
	_kite_string = Line2D.new()
	_kite_string.width = 1.0
	_kite_string.default_color = Color(0.85, 0.85, 0.85, 0.5)
	add_child(_kite_string)
	_kite_sprite = _make_sprite(self)
	_kite_sprite.texture = Kite.kite_texture()
	hide()


## Loops `plan`, drawn in `tint`. By default the ghosts start from the real bodies'
## current pose; `start` can override it with any of {player, enemy (positions),
## facing_right, player_anim}, for a plan that begins later in the timeline.
func play(plan, player, enemy, tint := Color.WHITE, start := {}) -> void:
	_plan = plan
	_player = player
	_enemy = enemy
	_start = start
	_material.set_shader_parameter("tint", tint)
	_tint = tint
	_restart()
	show()


func stop() -> void:
	_plan = null
	_clear_transient()
	hide()


func _physics_process(_delta: float) -> void:
	if _plan == null:
		return
	if _frame <= _plan.frames.size():
		_show_frame(_frame)
	_frame += 1
	if _frame > _plan.frames.size() + HOLD_FRAMES:
		_restart()


## Back to the starting pose: the real bodies' current positions and sprites, with
## any overrides from play()'s `start`.
func _restart() -> void:
	_clear_transient()
	_frame = 0
	_anim = &""
	_player_ghost.global_position = _start.get("player", _player.global_position)
	_enemy_ghost.global_position = _start.get("enemy", _enemy.global_position)
	var player_sprite: AnimatedSprite2D = _player.player_sprite
	_copy_sprite(player_sprite, _player_sprite)
	_cloak = _start.get("cloak", _player.cloak.momentum)
	_cloak_anim = _start.get("player_anim", player_sprite.animation)
	_cloak_frame = 0 if _start.has("player_anim") else player_sprite.frame
	if _start.has("player_anim"):
		_player_sprite.texture = player_sprite.sprite_frames.get_frame_texture(_start.player_anim, 0)
	if _start.has("facing_right"):
		_player_sprite.flip_h = not _start.facing_right
	_sword_marker.position = _player.sword_position.position
	var enemy_sprite: AnimatedSprite2D = _enemy.get_node("AnimatedSprite2D")
	_copy_sprite(enemy_sprite, _enemy_sprite)
	_rope.hide()
	for sprite in _projectile_sprites:
		sprite.hide()
	_kite_sprite.hide()
	_kite_string.hide()
	for spell in _spells:
		spell.hide()


## Fires frame `index`'s events, then moves the ghosts to its positions (the extra
## index past the last frame only carries events).
func _show_frame(index: int) -> void:
	_animate_player(index)
	_update_cloak(index)
	for event in _plan.events.get(index, []):
		_play_event(event)
	if index >= _plan.frames.size():
		return
	var frame: Dictionary = _plan.frames[index]
	_player_ghost.global_position = frame.player
	_enemy_ghost.global_position = frame.enemy
	_cloak = frame.cloak
	_show_projectiles(frame.get("projectiles", []))
	_show_kite(frame.get("kite", {}))
	_show_spells(frame.get("spells", []))
	if frame.rope.is_empty():
		_rope.hide()
	else:
		_rope.show()
		_rope.from = frame.rope.from
		_rope.to = frame.rope.to
		_rope.sag = frame.rope.sag


## Visual events only; sounds and particle effects are left out of the preview.
func _play_event(event: Array) -> void:
	match event[0]:
		"sword":
			var instance: Node2D = event[1].instantiate()
			_sword_marker.add_child(instance)
			SlashSprite.apply_to(instance)
			_player.orient_sword(instance, _sword_marker, not _player_sprite.flip_h)
			instance.get_node("sword_area").monitoring = false
			if event.size() > 3 and event[3]:
				StormLightning.attach(instance, _material)
			var sprite: AnimatedSprite2D = instance.get_node("AnimatedSprite2D")
			sprite.material = _material
			sprite.animation_finished.connect(instance.queue_free)
			sprite.play(event[2])
			_transient.append(instance)
		"player_anim":
			_anim = event[1]
			_anim_start = _frame
			_animate_player(_frame)
		"face":
			_player_sprite.flip_h = not event[1]
		"spell_burst":
			if event[1] == "cloud":
				var strike := LightningBolt.new()
				strike.points = PackedVector2Array([event[2], event[3]])
				strike.ghost = true
				add_child(strike)
				_transient.append(strike)
		"lightning":
			var bolt := LightningBolt.new()
			bolt.points = PackedVector2Array(event.slice(1))
			bolt.ghost = true
			add_child(bolt)
			_transient.append(bolt)
		"sparkle":
			var sparkle := Sparkle.new()
			sparkle.global_position = event[1]
			if event.size() > 2:
				sparkle.size = event[2]
				sparkle.duration = event[3]
			sparkle.modulate = SPARKLE_GHOST_MODULATE
			add_child(sparkle)
			_transient.append(sparkle)


## Shows the frame of the current pose animation `index` physics frames in.
func _animate_player(index: int) -> void:
	if _anim == &"":
		return
	var frames: SpriteFrames = _player.player_sprite.sprite_frames
	var count := frames.get_frame_count(_anim)
	var frame := int((index - _anim_start) / float(Engine.physics_ticks_per_second) * frames.get_animation_speed(_anim))
	frame = frame % count if frames.get_animation_loop(_anim) else mini(frame, count - 1)
	_player_sprite.texture = frames.get_frame_texture(_anim, frame)
	_cloak_anim = _anim
	_cloak_frame = frame


## The ghost's cloak: hangs from the shown pose's anchor, shaped by the planned
## cloak momentum, rippling with the preview's own clock.
func _update_cloak(index: int) -> void:
	var facing_right := not _player_sprite.flip_h
	_cloak_sprite.visible = _player.sprites.cape_visible(_cloak_anim, _cloak_frame)
	var anchor: Vector2 = _player.sprites.anchor(_cloak_anim, _cloak_frame)
	if not facing_right:
		anchor.x = -anchor.x
	_cloak_sprite.position = _player_sprite.position + anchor
	_cloak_sprite.texture = PlayerCloak.texture_for(_cloak, facing_right,
		int(index / float(Engine.physics_ticks_per_second) * PlayerCloak.RIPPLE_FPS), _player.cloak.style)


func _show_spells(states: Array) -> void:
	for i in states.size():
		while _spells.size() <= i:
			var node := Spell.new()
			node.ghost = true
			node.tint = _tint
			add_child(node)
			_spells.append(node)
		_spells[i].show_state(states[i])
	for i in range(states.size(), _spells.size()):
		_spells[i].hide()


func _show_kite(kite: Dictionary) -> void:
	var shown: bool = not kite.is_empty() and kite.alive
	_kite_sprite.visible = shown
	_kite_string.visible = shown
	if shown:
		_kite_sprite.global_position = kite.pos
		var hand := _player_ghost.global_position + Vector2(4.0 if not _player_sprite.flip_h else -4.0, -24.0)
		_kite_string.points = PackedVector2Array([kite.pos + Vector2(0, 10), hand])


func _show_projectiles(states: Array) -> void:
	for i in states.size():
		if i >= projectiles.size() or not is_instance_valid(projectiles[i]):
			continue
		while _projectile_sprites.size() <= i:
			_projectile_sprites.append(_make_sprite(self))
		var sprite := _projectile_sprites[i]
		var state: Dictionary = states[i]
		var texture: Texture2D = projectiles[i].ghost_texture(state) if state.alive else null
		sprite.visible = texture != null
		if texture:
			sprite.texture = texture
			sprite.global_transform = projectiles[i].ghost_transform(state)


func _clear_transient() -> void:
	for node in _transient:
		if is_instance_valid(node):
			node.queue_free()
	_transient.clear()


func _make_sprite(parent: Node2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.material = _material
	parent.add_child(sprite)
	return sprite


## Shows `source`'s current (paused) frame on a ghost sprite.
func _copy_sprite(source: AnimatedSprite2D, target: Sprite2D) -> void:
	target.texture = source.sprite_frames.get_frame_texture(source.animation, source.frame)
	target.position = source.position
	target.flip_h = source.flip_h
	target.scale = source.scale
	target.offset = source.offset
	target.centered = source.centered
