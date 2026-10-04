extends Node2D

## Character select: a card for each character (portrait, name, epithet and a line
## about them) over the storm. Left/right (or A/D, or the mouse) to choose, E / Enter
## to confirm, Esc to go back to the title. The pick goes in Characters.selected, then
## it's on to Characters.destination (the village, or the training area). The title
## theme carries on from the title screen until the game starts.

const Characters = preload("res://scenes/characters/characters.gd")
const Portraits = preload("res://scenes/characters/portraits.gd")
const Storm = preload("res://scenes/opening/storm.gd")
const Sfx = preload("res://scenes/audio/sfx.gd")
const FONT := preload("res://assets/2D/brackeys_platformer_assets/fonts/PixelOperator8.ttf")

const SCREEN := Vector2(1152, 648)
const TITLE_SCENE := "res://scenes/title/title_screen.tscn"
const CARD_SIZE := Vector2(300, 440)
const GAP := 36.0
const GOLD := Color(1.0, 0.85, 0.3)
const ORDER := [Characters.SAINT, Characters.DOGOOD, Characters.ELF]

var _cards: Array[Button] = []
var _leaving := false
var _quiet_focus := false
var _fade: ColorRect


func _ready() -> void:
	add_child(Storm.new())
	var ui := CanvasLayer.new()
	ui.layer = 2
	add_child(ui)
	var dim := ColorRect.new()
	dim.size = SCREEN
	dim.color = Color(0, 0, 0, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(dim)
	var header := _label("CHOOSE YOUR FIGHTER", 32, GOLD)
	header.size = Vector2(SCREEN.x, 40)
	header.position = Vector2(0, 40)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_outline_color", Color(0.25, 0.08, 0.04))
	header.add_theme_constant_override("outline_size", 8)
	ui.add_child(header)
	var left := (SCREEN.x - CARD_SIZE.x * ORDER.size() - GAP * (ORDER.size() - 1)) / 2.0
	for i in ORDER.size():
		var card := _card(ORDER[i])
		card.position = Vector2(left + i * (CARD_SIZE.x + GAP), 108)
		ui.add_child(card)
		_cards.append(card)
	var hint := _label("Left / Right to choose    E / Enter to fight    Esc to go back", 12, Color(0.7, 0.74, 0.82))
	hint.size = Vector2(SCREEN.x, 20)
	hint.position = Vector2(0, 600)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(hint)
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 5
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.size = SCREEN
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.4)
	_quiet_focus = true
	_cards[ORDER.find(Characters.selected) if ORDER.has(Characters.selected) else 0].grab_focus()
	_quiet_focus = false


## A card: a button holding the portrait, name, epithet and blurb. Focused, it lifts
## and its border turns gold.
func _card(id: String) -> Button:
	var info: Dictionary = Characters.INFO[id]
	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.pivot_offset = CARD_SIZE / 2.0
	card.focus_mode = Control.FOCUS_ALL
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.06, 0.1, 0.92)
		style.border_color = GOLD if state in ["focus", "hover", "pressed"] else Color(0.3, 0.32, 0.42)
		style.set_border_width_all(4 if style.border_color == GOLD else 2)
		style.set_corner_radius_all(6)
		card.add_theme_stylebox_override(state, style)
	var frame := Panel.new()
	frame.position = Vector2(25, 20)
	frame.size = Vector2(250, 275)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0, 0, 0)
	frame_style.border_color = Color(0.5, 0.42, 0.24)
	frame_style.set_border_width_all(3)
	frame.add_theme_stylebox_override("panel", frame_style)
	card.add_child(frame)
	var portrait := TextureRect.new()
	portrait.texture = Portraits.portrait(id)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.position = Vector2(3, 3)
	portrait.size = Vector2(244, 269)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(portrait)
	var name_label := _label(info.name.to_upper(), 24, GOLD)
	name_label.position = Vector2(0, 308)
	name_label.size = Vector2(CARD_SIZE.x, 30)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name_label)
	var title := _label(info.title, 12, Color(0.75, 0.78, 0.88))
	title.position = Vector2(0, 342)
	title.size = Vector2(CARD_SIZE.x, 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(title)
	var blurb := _label(info.blurb, 10, Color(0.88, 0.88, 0.9))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART # (Before sizing, or it sizes to one long line.)
	blurb.position = Vector2(22, 370)
	blurb.size = Vector2(CARD_SIZE.x - 44, 60)
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(blurb)
	card.mouse_entered.connect(card.grab_focus)
	card.focus_entered.connect(func() -> void:
		if not _quiet_focus:
			Sfx.play(self, "menu_cursor")
		card.create_tween().tween_property(card, "scale", Vector2(1.04, 1.04), 0.1))
	card.focus_exited.connect(func() -> void: card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.1))
	card.pressed.connect(_choose.bind(id))
	return card


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("ui_cancel"):
		_leaving = true
		Sfx.play(self, "menu_cancel")
		await _fade_out(false)
		get_tree().change_scene_to_file(TITLE_SCENE)
	elif event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
		var focused := _cards.find(get_viewport().gui_get_focus_owner())
		var step := -1 if event.is_action_pressed("move_left") else 1
		_cards[clampi(focused + step, 0, _cards.size() - 1)].grab_focus()


func _choose(id: String) -> void:
	if _leaving:
		return
	_leaving = true
	Characters.selected = id
	Sfx.play(self, "heavy_slash")
	var card := _cards[ORDER.find(id)]
	var flash := card.create_tween()
	flash.tween_property(card, "modulate", Color(2.0, 2.0, 2.0), 0.08)
	flash.tween_property(card, "modulate", Color.WHITE, 0.25)
	await _fade_out(true)
	get_tree().change_scene_to_file(Characters.destination)


## Fades to black; leaving for the game, the title music fades out with it.
func _fade_out(stop_music: bool) -> void:
	for card in _cards:
		card.focus_mode = Control.FOCUS_NONE
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.6)
	var music := get_tree().root.get_node_or_null("TitleMusic")
	if stop_music and music:
		tween.parallel().tween_property(music, "volume_db", -40.0, 0.6)
	await tween.finished
	if stop_music and music:
		music.queue_free()
