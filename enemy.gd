extends CharacterBody2D
@export var move_speed:float = 80.0
@export var damage:float = 10.0
@export var attack_cd:float = 1.0
var attack_timer:float = 0.0
var player:CharacterBody2D
@export var hp:float = 30.0
var is_dead:bool = false
@export var damage_scene:PackedScene
@export var aura_drop_scene:PackedScene
var tween:Tween

func _ready():
	# 从主场景找Player
	player = get_parent().get_node_or_null("Player")
	global_position = get_random_screen_edge_pos()

func get_random_screen_edge_pos() -> Vector2:
	var cam = get_viewport().get_camera_2d()
	var view_rect = cam.get_viewport_rect()
	var cam_global = cam.global_position
	var offset = 80.0
	
	var side = randi() % 4
	match side:
		0: #上边外侧
			return Vector2(
				cam_global.x + randf_range(view_rect.position.x, view_rect.end.x),
				cam_global.y + view_rect.position.y - offset
			)
		1: #右边外侧
			return Vector2(
				cam_global.x + view_rect.end.x + offset,
				cam_global.y + randf_range(view_rect.position.y, view_rect.end.y)
			)
		2: #下边外侧
			return Vector2(
				cam_global.x + randf_range(view_rect.position.x, view_rect.end.x),
				cam_global.y + view_rect.end.y + offset
			)
		3: #左边外侧
			return Vector2(
				cam_global.x + view_rect.position.x - offset,
				cam_global.y + randf_range(view_rect.position.y, view_rect.end.y)
			)
	return cam_global

func _physics_process(delta):
	if is_dead:
		return
	
	if attack_timer > 0:
		attack_timer -= delta
	
	if player == null:
		return
	
	var dir_to_player = (player.global_position - global_position).normalized()
	velocity = dir_to_player * move_speed
	
	if dir_to_player.x > 0:
		$AnimatedSprite2D.play("run_right")
	elif dir_to_player.x < 0:
		$AnimatedSprite2D.play("run_left")
	
	move_and_slide()
	
	# 遍历碰撞检测，攻击玩家
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var hit_body = collision.get_collider()
		if hit_body == player and attack_timer <= 0:
			player.take_damage(damage)
			attack_timer = attack_cd
			break

func take_damage(amount:float):
	if is_dead:
		return
	
	hp -= amount
	print("怪物扣血：", amount, "剩余hp：", hp)
	if tween != null:
		tween.kill()
	tween = create_tween()
	tween.tween_property($AnimatedSprite2D, "modulate", Color(2,2,2), 0.08)
	tween.tween_property($AnimatedSprite2D, "modulate", Color(1,1,1), 0.12)
	
	if damage_scene != null:
		var dmg_text = damage_scene.instantiate()
		get_parent().add_child(dmg_text)
		dmg_text.text = str(amount)
		# 暴击伤害标黄
		if amount > 30:
			dmg_text.add_theme_color_override("font_color", Color(1,1,0))
		dmg_text.global_position = global_position + Vector2(0, -20)
	
	if hp <= 0:
		is_dead = true
		print("怪物死亡")
		if aura_drop_scene != null:
			var aura = aura_drop_scene.instantiate()
			get_parent().add_child(aura)
			aura.global_position = global_position
		call_deferred("_dead_cleanup")

func _dead_cleanup():
	queue_free()
