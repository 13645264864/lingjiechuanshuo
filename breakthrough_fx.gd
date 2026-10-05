extends Node2D

const GOLD_SHADER = preload("res://breakthrough_glow.gdshader")
var player: CharacterBody2D
var age := 0.0
var duration := 1.5
var gold := Sprite2D.new()
var announcement := Label.new()
var screen_scale := 1.0

func setup(target: CharacterBody2D):
	player = target
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("breakthrough_fx")
	var material := ShaderMaterial.new()
	material.shader = GOLD_SHADER
	gold.material = material
	add_child(gold)
	announcement.text = "突破了！"
	announcement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	announcement.add_theme_color_override("font_color", Color(1, 0.87, 0.24))
	announcement.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.01))
	announcement.add_theme_constant_override("outline_size", 6)
	add_child(announcement)
	update_visual()

func _process(delta: float):
	age += delta
	if age >= duration or not is_instance_valid(player) or player.is_dead:
		get_parent().queue_free()
		return
	update_visual()

func update_visual():
	var camera_transform := get_viewport().get_canvas_transform()
	position = camera_transform * player.global_position
	screen_scale = camera_transform.get_scale().x
	var source: AnimatedSprite2D = player.sword_visual.sprite if player.sword_time_left > 0 else player.anim
	gold.texture = source.sprite_frames.get_frame_texture(source.animation, source.frame)
	gold.offset = source.offset
	gold.flip_h = source.flip_h
	gold.global_transform = camera_transform * source.global_transform
	var fade := clampf((duration - age) / 0.45, 0, 1)
	gold.material.set_shader_parameter("strength", fade * (0.4 + maxf(sin(age * 15), 0) * 0.4))
	gold.visible = not (is_instance_valid(player.gm) and player.gm.buff_panel.visible and age >= 0.4)
	var mobile := get_viewport_rect().size.x < 700
	announcement.add_theme_font_size_override("font_size", 30 if mobile else 44)
	announcement.modulate.a = fade
	var width := 170.0 if mobile else 240.0
	var viewport := get_viewport_rect().size
	var wanted := position + Vector2(80 * screen_scale, -100 * screen_scale - age * 22)
	if is_instance_valid(player.gm) and player.gm.buff_panel.visible and not player.gm.buff_buttons.is_empty():
		wanted.y = minf(wanted.y, player.gm.buff_buttons[0].global_position.y - 70)
	wanted.x = clampf(wanted.x, 12, maxf(viewport.x - width - 12, 12))
	wanted.y = clampf(wanted.y, 12, maxf(viewport.y - 65, 12))
	announcement.global_position = wanted
	queue_redraw()

func _draw():
	if is_instance_valid(player.gm) and player.gm.buff_panel.visible and age >= 0.4: return
	var fade := clampf((duration - age) / 0.45, 0, 1)
	for index in range(20):
		var angle := TAU * index / 20.0
		var distance := (40 + fmod(age * 90 + index * 13, 95)) * screen_scale
		var point := Vector2(cos(angle) * distance, sin(angle) * distance * 0.65 - age * 15 * screen_scale)
		draw_line(point, point + Vector2(0, -12 * screen_scale), Color(1, 0.81, 0.18, 0.8 * fade), 3, true)
	for ring in range(2):
		var radius := (60 + ring * 20 + age * 30) * screen_scale
		draw_arc(Vector2.ZERO, radius, age + ring, age + ring + PI * 1.5, 48, Color(1, 0.76, 0.12, 0.35 * fade), 4, true)
