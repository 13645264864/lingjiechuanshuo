extends ColorRect

const END_MESSAGE := "感谢游戏，内测版流程已结束，后续流程持续更新中"
var message_label: Label
var replay_button: Button
var content: VBoxContainer
var transition_started := false
var ending_revealed := false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 30
	color = Color(0, 0, 0, 0)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 30)
	content.modulate.a = 0
	add_child(content)
	message_label = Label.new()
	message_label.text = END_MESSAGE.replace("，", "，\n")
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(message_label)
	replay_button = Button.new()
	replay_button.text = "重玩"
	replay_button.custom_minimum_size = Vector2(0, 60)
	replay_button.add_theme_font_size_override("font_size", 26)
	replay_button.disabled = true
	content.add_child(replay_button)
	resized.connect(layout_content)
	layout_content()
	hide()

func layout_content():
	if not is_instance_valid(content): return
	var mobile := size.x < 700
	var width := minf(680, maxf(size.x - 48, 180))
	message_label.add_theme_font_size_override("font_size", 25 if mobile else 32)
	content.position = Vector2((size.x - width) * 0.5, size.y * 0.38)
	content.size = Vector2(width, 180)

func begin_transition():
	if transition_started: return
	transition_started = true
	show()
	var fade := create_tween()
	fade.tween_property(self, "color:a", 1.0, 0.55)
	fade.tween_interval(0.15)
	fade.tween_callback(func(): ending_revealed = true; replay_button.disabled = false)
	fade.tween_property(content, "modulate:a", 1.0, 0.25)
	fade.tween_callback(replay_button.grab_focus)
