extends Control

const BACKGROUND = preload("res://Sprites/menu_background.jpg")
var start_button: Button
var starting := false

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := TextureRect.new()
	background.texture = BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	start_button = Button.new()
	start_button.name = "StartGame"
	start_button.text = "开始游戏"
	start_button.add_theme_font_size_override("font_size", 30)
	start_button.add_theme_color_override("font_color", Color(1, 0.95, 0.83))
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.18, 0.035, 0.035, 0.92) if state == "normal" else Color(0.4, 0.07, 0.04, 0.96)
		box.border_color = Color(1, 0.79, 0.45)
		box.set_border_width_all(2)
		box.set_corner_radius_all(4)
		start_button.add_theme_stylebox_override(state, box)
	start_button.pressed.connect(start_game)
	add_child(start_button)
	resized.connect(layout_menu)
	layout_menu()
	start_button.grab_focus()

func layout_menu():
	if not is_instance_valid(start_button): return
	var width := minf(290, size.x - 40)
	start_button.size = Vector2(width, 64)
	start_button.position = (size - start_button.size) * 0.5

func start_game():
	if starting: return
	starting = true
	start_button.disabled = true
	get_tree().set_meta("start_from_menu", true)
	get_tree().change_scene_to_file("res://first_level.tscn")
