extends Node2D

## The title screen: the opening level's storm (sky, rain, lightning) behind the Sword
## Saint's silhouette on a crag, cloak streaming in the wind; the "SWORD SAINT" title
## card with a katana beneath it; and a menu: Play Game (the village), Training (the
## slime test area) and Exit. Both lead through the character select screen. The
## title theme (music.gd) is rendered on a thread and fades in once it's ready; it
## plays from the scene tree's root ("TitleMusic"), so it carries on through the
## character select screen (and is picked up again coming back).

const Storm = preload("res://scenes/opening/storm.gd")
const Music = preload("res://scenes/audio/music.gd")
const Sfx = preload("res://scenes/audio/sfx.gd")
const PlayerSprites = preload("res://scenes/player_sprites.gd")
const PlayerCloak = preload("res://scenes/player_cloak.gd")
const FONT := preload("res://assets/2D/brackeys_platformer_assets/fonts/PixelOperator8.ttf")

const SCREEN := Vector2(1152, 648)
const Characters = preload("res://scenes/characters/characters.gd")
const SELECT_SCENE := "res://scenes/characters/character_select.tscn"
const GAME_SCENE := "res://scenes/opening/opening.tscn"
const TRAINING_SCENE := "res://scenes/2D Game.tscn"
const TITLE := "SWORD SAINT"
const MENU_COLOR := Color(1.0, 0.85, 0.1)
const MUSIC_VOLUME := -7.0
const WIND := Vector2(230, -25) # The cloak's momentum: streaming back, to the left.
const TITLE_SHADER := """
shader_type canvas_item;
// Gold-to-ember vertical gradient on the letters; the outline and shadow keep their colour.
uniform vec4 top_color : source_color = vec4(1.0, 0.94, 0.6, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.95, 0.42, 0.12, 1.0);
uniform float top_y = 0.0;
uniform float bottom_y = 90.0;
varying float local_y;
void vertex() { local_y = VERTEX.y; }
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	if (COLOR.r > 0.5) {
		c.rgb = mix(top_color.rgb, bottom_color.rgb, clamp((local_y - top_y) / (bottom_y - top_y), 0.0, 1.0));
	}
	COLOR = c;
}
"""

var _music: AudioStreamPlayer
var _music_thread: Thread
var _buttons: Array[Button] = []
var _leaving := false
var _ready_for_input := false
var _quiet_focus := false
var _fade: ColorRect
var _figure_body: AnimatedSprite2D
var _figure_cloak: Sprite2D
var _time := 0.0
var _katana: Node2D


func _ready() -> void:
	_start_music() # First: it takes a few seconds, alongside building everything else.
	_add_menu_keys()
	add_child(Storm.new())
	_build_crag()
	var ui := CanvasLayer.new()
	ui.layer = 2
	add_child(ui)
	var title := _build_title(ui)
	_katana = _build_katana(ui)
	var menu := _build_menu(ui)
	_fade = ColorRect.new()
	_fade.size = SCREEN
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 5
	add_child(fade_layer)
	fade_layer.add_child(_fade)
	_reveal(title, menu)


func _process(delta: float) -> void:
	_time += delta
	# The cloak ripples in the wind, gusting a little.
	var gust := WIND * (1.0 + 0.15 * sin(_time * 1.7) + 0.08 * sin(_time * 4.3))
	_figure_cloak.texture = PlayerCloak.texture_for(gust, true, int(_time * PlayerCloak.RIPPLE_FPS))
	_figure_cloak.position = _figure_body.position + PlayerSprites.anchor(_figure_body.animation, _figure_body.frame)
	_katana.queue_redraw()
	if _music == null and _music_thread != null and not _music_thread.is_alive():
		_play_music(_music_thread.wait_to_finish())
		_music_thread = null


func _exit_tree() -> void:
	if _music_thread != null:
		_music_thread.wait_to_finish()


# --- Scenery ------------------------------------------------------------------

## A dark crag in the lower left with the Sword Saint standing on it, in silhouette.
func _build_crag() -> void:
	var crag := Polygon2D.new()
	crag.color = Color(0.05, 0.05, 0.08)
	crag.polygon = PackedVector2Array([Vector2(0, 470), Vector2(70, 455), Vector2(130, 468), Vector2(175, 446),
		Vector2(265, 452), Vector2(300, 486), Vector2(340, 520), Vector2(390, 560), Vector2(470, 600),
		Vector2(560, 648), Vector2(0, 648)])
	add_child(crag)
	var figure := Node2D.new()
	figure.position = Vector2(220, 449)
	figure.scale = Vector2(3, 3)
	figure.modulate = Color(0.07, 0.07, 0.11)
	add_child(figure)
	_figure_cloak = Sprite2D.new()
	figure.add_child(_figure_cloak)
	_figure_body = AnimatedSprite2D.new()
	_figure_body.sprite_frames = PlayerSprites.frames()
	_figure_body.position = PlayerSprites.ORIGIN_OFFSET
	_figure_body.play(&"idle")
	figure.add_child(_figure_body)
	_figure_cloak.position = _figure_body.position


func _build_title(ui: CanvasLayer) -> Label:
	var title := Label.new()
	title.text = TITLE
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 80)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color(0.18, 0.06, 0.04))
	title.add_theme_constant_override("outline_size", 16)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	title.add_theme_constant_override("shadow_offset_x", 6)
	title.add_theme_constant_override("shadow_offset_y", 7)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(SCREEN.x, 110)
	title.position = Vector2(0, 92)
	var shader := Shader.new()
	shader.code = TITLE_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("top_y", 18.0)
	material.set_shader_parameter("bottom_y", 92.0)
	title.material = material
	ui.add_child(title)
	return title


## A katana lying beneath the title: a gently curved blade with a bright edge and a
## glint that runs along it now and then, a gold guard, and a wrapped hilt.
func _build_katana(ui: CanvasLayer) -> Node2D:
	var katana := Node2D.new()
	katana.position = Vector2(SCREEN.x / 2.0, 222)
	katana.rotation = deg_to_rad(-3.0)
	katana.draw.connect(_draw_katana.bind(katana))
	ui.add_child(katana)
	return katana


func _draw_katana(katana: Node2D) -> void:
	var blade_from := -170.0
	var blade_to := 250.0
	var spine := PackedVector2Array()
	var edge := PackedVector2Array()
	var count := 24
	for i in count + 1:
		var t := float(i) / count
		var x := lerpf(blade_from, blade_to, t)
		var curve := -10.0 * t * t # Rises toward the tip.
		var width := lerpf(7.0, 4.0, t)
		if t > 0.93: # The kissaki: the tip sweeps up to a point.
			width *= (1.0 - t) / 0.07
		spine.append(Vector2(x, curve - width * 0.5))
		edge.append(Vector2(x, curve + width * 0.5))
	var blade := spine.duplicate()
	var reversed := edge.duplicate()
	reversed.reverse()
	blade.append_array(reversed)
	katana.draw_colored_polygon(blade, Color(0.72, 0.75, 0.82))
	katana.draw_polyline(edge, Color(0.97, 0.98, 1.0), 1.6)
	katana.draw_polyline(spine, Color(0.45, 0.48, 0.56), 1.2)
	# A glint sweeping along the blade every few seconds.
	var sweep := fmod(_time, 4.0) / 0.8
	if sweep < 1.0:
		var at := lerpf(blade_from, blade_to, sweep)
		var y := -10.0 * pow((at - blade_from) / (blade_to - blade_from), 2.0)
		for r in [7.0, 4.0]:
			katana.draw_line(Vector2(at - r, y), Vector2(at + r, y), Color(1, 1, 1, 0.9), 1.5)
			katana.draw_line(Vector2(at, y - r), Vector2(at, y + r), Color(1, 1, 1, 0.9), 1.5)
	# Habaki, tsuba, hilt with diamond wrapping, and the end cap.
	katana.draw_rect(Rect2(blade_from - 8, -5, 9, 10), Color(0.85, 0.68, 0.3))
	katana.draw_rect(Rect2(blade_from - 14, -13, 6, 26), Color(0.55, 0.42, 0.18))
	katana.draw_rect(Rect2(blade_from - 14, -13, 6, 26), Color(0.2, 0.14, 0.06), false, 1.0)
	var hilt := Rect2(blade_from - 100, -6, 86, 12)
	katana.draw_rect(hilt, Color(0.1, 0.1, 0.18))
	var x := hilt.position.x + 4.0
	while x < hilt.end.x - 6.0:
		katana.draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 5, -5), Vector2(x + 10, 0), Vector2(x + 5, 5)]),
			Color(0.62, 0.12, 0.12))
		x += 11.0
	katana.draw_rect(Rect2(hilt.position.x - 6, -7, 7, 14), Color(0.55, 0.42, 0.18))


func _build_menu(ui: CanvasLayer) -> VBoxContainer:
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 24
	var menu := VBoxContainer.new()
	menu.theme = theme
	menu.add_theme_constant_override("separation", 12)
	menu.custom_minimum_size = Vector2(300, 0)
	menu.position = Vector2((SCREEN.x - 300) / 2.0, 330)
	ui.add_child(menu)
	for entry in [["Play Game", _go.bind(GAME_SCENE)], ["Training", _go.bind(TRAINING_SCENE)], ["Exit", _exit]]:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_ALL
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.04, 0.05, 0.09, 0.82) if state != "focus" and state != "hover" else Color(0.1, 0.1, 0.16, 0.92)
			style.border_color = MENU_COLOR if state == "focus" else Color(0.35, 0.38, 0.5)
			style.set_border_width_all(2)
			style.set_corner_radius_all(3)
			style.set_content_margin_all(10)
			button.add_theme_stylebox_override(state, style)
		button.add_theme_color_override("font_color", Color(0.85, 0.87, 0.93))
		for color_name in ["font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			button.add_theme_color_override(color_name, MENU_COLOR)
		button.pressed.connect(entry[1])
		button.mouse_entered.connect(button.grab_focus)
		button.focus_entered.connect(func() -> void:
			if not _quiet_focus:
				Sfx.play(self, "menu_cursor"))
		menu.add_child(button)
		_buttons.append(button)
	menu.modulate.a = 0.0
	return menu


# --- Flow ---------------------------------------------------------------------

## Fades in from black, slides the title in, cuts a slash across it, then shows the menu.
func _reveal(title: Label, menu: VBoxContainer) -> void:
	title.modulate.a = 0.0
	_katana.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, 0.9)
	tween.parallel().tween_property(title, "modulate:a", 1.0, 0.7).set_delay(0.3)
	tween.parallel().tween_property(title, "position:y", title.position.y, 0.7).from(title.position.y - 24.0) \
		.set_delay(0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_slash_across_title)
	tween.tween_property(_katana, "modulate:a", 1.0, 0.25)
	tween.parallel().tween_property(_katana, "position:x", _katana.position.x, 0.35).from(_katana.position.x - 60.0) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(menu, "modulate:a", 1.0, 0.4)
	tween.tween_callback(func() -> void:
		_ready_for_input = true
		_quiet_focus = true
		_buttons[0].grab_focus()
		_quiet_focus = false)


## A bright streak cutting across the title, with a heavy slash sound.
func _slash_across_title() -> void:
	Sfx.play(self, "heavy_slash")
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	var streak := Line2D.new()
	streak.width = 6.0
	streak.default_color = Color(1, 1, 1, 0.95)
	streak.points = PackedVector2Array([Vector2(260, 175), Vector2(260, 175)])
	layer.add_child(streak)
	var tween := create_tween()
	tween.tween_method(func(x: float) -> void: streak.set_point_position(1, Vector2(x, 175 - (x - 260) * 0.12)), 260.0, 900.0, 0.12)
	tween.tween_property(streak, "width", 0.0, 0.25)
	tween.parallel().tween_property(streak, "modulate:a", 0.0, 0.25)
	tween.tween_callback(layer.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if _ready_for_input and not _leaving and get_viewport().gui_get_focus_owner() == null \
			and (event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down")):
		_buttons[0].grab_focus()


func _go(scene_path: String) -> void:
	if _leaving or not _ready_for_input:
		return
	_leaving = true
	Sfx.play(self, "menu_confirm")
	Characters.destination = scene_path
	await _fade_out(false)
	get_tree().change_scene_to_file(SELECT_SCENE)


func _exit() -> void:
	if _leaving or not _ready_for_input:
		return
	_leaving = true
	Sfx.play(self, "menu_confirm")
	await _fade_out()
	get_tree().quit()


func _fade_out(stop_music := true) -> void:
	for button in _buttons:
		button.focus_mode = Control.FOCUS_NONE
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.6)
	if _music and stop_music:
		tween.parallel().tween_property(_music, "volume_db", -40.0, 0.6)
	await tween.finished


# --- Music --------------------------------------------------------------------

func _start_music() -> void:
	_music = get_tree().root.get_node_or_null("TitleMusic") # Still playing from the select screen.
	if _music:
		return
	_music_thread = Thread.new()
	_music_thread.start(Music.title_theme)


func _play_music(stream: AudioStreamWAV) -> void:
	if _leaving:
		return
	_music = AudioStreamPlayer.new()
	_music.name = "TitleMusic"
	_music.stream = stream
	_music.volume_db = -30.0
	get_tree().root.add_child(_music)
	_music.play()
	create_tween().tween_property(_music, "volume_db", MUSIC_VOLUME, 1.5)


## W/S (as well as the arrows) move through the menu and E / Space / Enter choose,
## as in the game's own menus (see CombatManager._add_extra_keys()).
func _add_menu_keys() -> void:
	for binding in [["ui_up", KEY_W], ["ui_down", KEY_S], ["ui_accept", KEY_E]]:
		var event := InputEventKey.new()
		event.physical_keycode = binding[1]
		if not InputMap.action_has_event(binding[0], event):
			InputMap.action_add_event(binding[0], event)
