extends "res://enemy.gd"

var hit_count := 0
var total_damage := 0.0
var idle_tint := Color(0.7, 0.8, 0.75)

func _ready():
	super._ready()
	add_to_group("training_dummy")
	hp = INF
	max_hp = INF
	damage = 0.0
	move_speed = 0.0
	aura_drop_scene = null
	collision_layer = 2
	collision_mask = 0
	$AnimatedSprite2D.play("run_right")
	$AnimatedSprite2D.pause()
	$AnimatedSprite2D.modulate = idle_tint
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = "练习人偶"
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size = Vector2(160, 32)
	name_label.scale = Vector2.ONE / scale
	name_label.position = Vector2(-80, -120) / scale
	name_label.z_index = 3
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.92))
	name_label.add_theme_color_override("font_outline_color", Color(0.05, 0.12, 0.08))
	name_label.add_theme_constant_override("outline_size", 4)
	add_child(name_label)

func _physics_process(_delta: float):
	velocity = Vector2.ZERO

func take_damage(amount: float):
	if amount <= 0.0:
		return
	hit_count += 1
	total_damage += amount
	# A practice target never enters enemy.gd's finite-HP death/reward path.
	hp = INF
	if tween != null:
		tween.kill()
	tween = create_tween()
	tween.tween_property($AnimatedSprite2D, "modulate", Color(2, 2, 2), 0.06)
	tween.tween_property($AnimatedSprite2D, "modulate", idle_tint, 0.14)
	if damage_scene != null:
		var damage_text = damage_scene.instantiate()
		get_parent().add_child(damage_text)
		damage_text.text = str(snappedf(amount, 0.1))
		damage_text.global_position = global_position + Vector2(0, -85)
