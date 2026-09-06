class_name DiceButton
extends Button

const FACES := ["", "⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]

var die_index: int = -1
var die_value: int = 1


func setup(index: int, value: int) -> void:
	die_index = index
	die_value = value
	text = FACES[value]
	tooltip_text = "骰子 %d：%d 点" % [index + 1, value]
	custom_minimum_size = Vector2(96, 104)
	add_theme_font_size_override("font_size", 62)
	add_theme_color_override("font_color", Color("2a2119"))
	add_theme_color_override("font_hover_color", Color("2a2119"))
	add_theme_color_override("font_pressed_color", Color("2a2119"))
	add_theme_stylebox_override("normal", _make_style(Color("d8c9a3"), Color("4a3825"), 2))
	add_theme_stylebox_override("hover", _make_style(Color("eadcb7"), Color("9b7437"), 3))
	add_theme_stylebox_override("pressed", _make_style(Color("e5ce91"), Color("d6a84a"), 4))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func set_selected_state(selected: bool) -> void:
	button_pressed = selected
	modulate = Color("fff0bd") if selected else Color.WHITE
	z_index = 2 if selected else 0


func animate_landing(target_position: Vector2, delay: float, angle: float, final_scale: float) -> void:
	disabled = true
	pivot_offset = custom_minimum_size * 0.5
	position = Vector2(target_position.x, -150.0)
	rotation = angle - 1.7
	scale = Vector2.ONE * 0.55
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target_position, 0.5).set_delay(delay)
	tween.tween_property(self, "rotation", angle, 0.62).set_delay(delay)
	tween.tween_property(self, "scale", Vector2.ONE * final_scale, 0.5).set_delay(delay)
	tween.chain().tween_callback(func() -> void: disabled = false)


func _make_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.02, 0.01, 0.0, 0.75)
	style.shadow_size = 9
	style.shadow_offset = Vector2(0, 6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
