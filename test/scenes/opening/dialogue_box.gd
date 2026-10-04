extends CanvasLayer

## Cutscene speech: a box along the bottom of the screen with the speaker's name and
## their line, typed out. E / Space / Enter finishes the typing, then continues; a
## finished line also continues by itself after a few seconds.

const FONT := preload("res://assets/2D/brackeys_platformer_assets/fonts/PixelOperator8.ttf")
const CHARACTERS_PER_SECOND := 30.0
const AUTO_CONTINUE := 3.5

var _panel: PanelContainer
var _speaker: Label
var _text: Label


func _ready() -> void:
	layer = 4
	_panel = PanelContainer.new()
	_panel.position = Vector2(176, 468)
	_panel.custom_minimum_size = Vector2(800, 120)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.92)
	style.border_color = Color(0.42, 0.66, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	_speaker = _label(Color(1.0, 0.85, 0.3))
	box.add_child(_speaker)
	_text = _label(Color.WHITE)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(770, 0)
	box.add_child(_text)
	var hint := _label(Color(0.55, 0.6, 0.7))
	hint.text = "E / Space"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(hint)
	_panel.hide()


## Shows `line` from `speaker` and returns once the player continues.
func say(speaker: String, line: String) -> void:
	_speaker.text = speaker
	_text.text = line
	_text.visible_ratio = 0.0
	_panel.show()
	var typing := create_tween()
	typing.tween_property(_text, "visible_ratio", 1.0, line.length() / CHARACTERS_PER_SECOND)
	var waited := 0.0
	await get_tree().process_frame # Ignore the key press that may have started this.
	while true:
		await get_tree().process_frame
		var pressed := Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("attack")
		if _text.visible_ratio < 1.0:
			if pressed:
				typing.kill()
				_text.visible_ratio = 1.0
			continue
		waited += get_process_delta_time()
		if pressed or waited > AUTO_CONTINUE:
			break
	_panel.hide()


func _label(color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	return label
