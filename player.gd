extends CharacterBody2D
const DODGE_FX_SCRIPT = preload("res://player_dodge_fx.gd")
const DODGE_VISUAL_SCRIPT = preload("res://player_dodge_visual.gd")
const SWORD_FORM_SCRIPT = preload("res://sword_form.gd")
var hp:float = 100.0
var max_hp:float =100.0
var is_dead:bool = false
@onready var anim = $AnimatedSprite2D
@onready var dodge_collision_shape:CollisionShape2D = $CollisionShape2D
var input_dir:Vector2 = Vector2.ZERO
var last_dir:Vector2 = Vector2.DOWN
@export var fireball_cd:float = 1.2
@export var fireball_range:float = 450.0
var fireball_timer:float = 0.0
@export var fireball_scene:PackedScene
var target_enemy:Node2D = null
@export var damage_scene:PackedScene #拖入DamageLabel场景
var tween:Tween
# ============ UI变量 ============
var hp_bar:ProgressBar
var cultivate_bar:ProgressBar
var cultivate_text:Label
# ============ 修炼灵气系统 ============
const BASE_AURA:float = 100.0    # 练气一层升二层需要灵气
const GROW_RATE:float = 1.2      # 每一级需求 = 上一级 *1.2
const MAX_REALM:int = 9           # 1练气一层 ~9练气大圆满
var realm:int = 1                 # 当前境界
var current_aura:float = 0.0      # 当前已经拥有灵气
var need_aura:float = BASE_AURA    # 升到下一级所需灵气

# 拿到GameManager引用
var gm:Node2D = null
var dodge_cooldown:float = 1.2
var dodge_timer:float = 0.0
var dodge_duration:float = 0.28
var dodge_time_left:float = 0.0
var dodge_speed:float = 1250.0
var is_invincible:bool = false
var dodge_direction:Vector2 = Vector2.DOWN
var normal_collision_layer:int = 1
var normal_collision_mask:int = 1
var dodge_trail_timer:float = 0.0
var dodge_invulnerability_left:float = 0.0
var dodge_landing_protection:float = 0.10
var dodge_trail_index:int = 0
var dodge_visual:Node2D
var sword_unlocked := false
var sword_time_left := 0.0
var sword_cooldown_left := 0.0
var sword_visual: Node2D
var sword_dash_hit: Array = []

func _ready():
	normal_collision_layer = collision_layer
	normal_collision_mask = collision_mask
	dodge_visual = Node2D.new()
	dodge_visual.set_script(DODGE_VISUAL_SCRIPT)
	dodge_visual.name = "DodgeVisual"
	dodge_visual.z_index = 1
	add_child(dodge_visual)
	sword_visual = Node2D.new()
	sword_visual.set_script(SWORD_FORM_SCRIPT)
	sword_visual.name = "SwordForm"
	add_child(sword_visual)
	gm = get_node_or_null("/root/Node2D/GameManager")
	print("gm节点 = ", gm)
	# 【重点】匹配节点层级
	hp_bar = get_node_or_null("/root/Node2D/UI/StatusBar/VBoxContainer/ProgressBar")
	cultivate_bar = get_node_or_null("/root/Node2D/UI/StatusBar/VBoxContainer/cultivate_bar")
	cultivate_text = get_node_or_null("/root/Node2D/UI/StatusBar/VBoxContainer/cultivate_text")
	print("hp_bar = ", hp_bar)
	print("cultivate_bar = ", cultivate_bar)
	print("cultivate_text = ", cultivate_text)
	# 加判断防止空节点崩溃
	if hp_bar != null:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
	if cultivate_bar != null and cultivate_text != null:
		update_cultivate_ui()

func _physics_process(delta):
	if is_dead:
		return
	if is_instance_valid(gm) and gm.level_map != null and (not gm.game_started or gm.game_over):
		velocity = Vector2.ZERO
		return
	sword_cooldown_left = maxf(sword_cooldown_left-delta,0.0)
	sword_visual.auto_guard_left = maxf(sword_visual.auto_guard_left - delta, 0.0)
	input_dir = movement_input()
	if Input.is_action_just_pressed("sword_form"):
		activate_sword_form()
	if sword_time_left > 0.0:
		sword_time_left = maxf(sword_time_left-delta,0.0)
		if sword_time_left > 0.0: sword_visual.update_form(delta)
		if sword_time_left <= 0.0: end_sword_form()
	dodge_invulnerability_left = maxf(dodge_invulnerability_left - delta, 0.0)
	is_invincible = dodge_invulnerability_left > 0.0
	dodge_timer = maxf(dodge_timer - delta, 0.0)
	input_dir = movement_input()
	if Input.is_action_just_pressed("dodge"):
		dodge()
	if dodge_time_left > 0.0:
		var step := minf(delta, dodge_time_left)
		dodge_time_left = maxf(dodge_time_left - delta, 0.0)
		var progress := 1.0 - dodge_time_left / dodge_duration
		dodge_visual.update_pose(progress)
		dodge_trail_timer -= delta
		if dodge_trail_timer <= 0.0:
			dodge_trail_timer = 0.03
			spawn_dodge_afterimage()
		# Fast grounded acceleration, then ease down before returning to movement.
		var speed_factor := 0.45 + 0.65 * sin(progress * PI)
		velocity = dodge_direction * dodge_speed * speed_factor * step / maxf(delta, 0.0001)
		move_and_slide()
		var map = get_parent().get_node_or_null("FirstLevelMap")
		if map != null:
			global_position = map.constrain_position(global_position)
		if sword_time_left > 0:
			sword_visual.dash_strike()
		if dodge_time_left <= 0.0:
			end_dodge()
		return
	if sword_time_left > 0.0:
		sword_visual.follow_target(delta)
		return
	fireball_timer -= delta
	if fireball_timer <= 0 and sword_time_left <= 0.0:
		find_nearest_enemy()
		if target_enemy != null:
			shoot_fireball()
			fireball_timer = fireball_cd
	#玩家移动
	input_dir = movement_input()
	if input_dir != Vector2.ZERO:
		last_dir = input_dir
		velocity = input_dir * 180
		anim.play("run_" + last_dir_to_anim_name(input_dir))
	else:
		velocity = Vector2.ZERO
		anim.play("idle_" + last_dir_to_anim_name(last_dir))
	move_and_slide()
	var level = get_parent().get_node_or_null("FirstLevelMap")
	if level != null:
		global_position = level.constrain_position(global_position)

func last_dir_to_anim_name(dir:Vector2)->String:
	if absf(dir.x) > absf(dir.y):
		return "right" if dir.x > 0.0 else "left"
	return "down" if dir.y >= 0.0 else "up"

func movement_input() -> Vector2:
	var keyboard := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var touch: Vector2 = gm.touch_move if is_instance_valid(gm) else Vector2.ZERO
	return (keyboard + touch).limit_length()

func find_nearest_enemy():
	var all_enemies = get_tree().get_nodes_in_group("enemy")
	var min_dist = fireball_range
	target_enemy = null
	for enemy in all_enemies:
		if enemy.is_dead:
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			target_enemy = enemy

func shoot_fireball():
	var dir_vector = target_enemy.global_position - global_position
	if dir_vector == Vector2.ZERO:
		return
	dir_vector = dir_vector.normalized()
	
	var fb = fireball_scene.instantiate()
	if is_instance_valid(gm) and gm.level_map != null:
		fb.speed = 210.0
		fb.damage = 18.0
	var buff_config:Dictionary = {}
	if is_instance_valid(gm):
		buff_config = gm.get_fireball_config()
	# 入树前初始化，通过参数传入技能，避免火球查找不到场景节点。
	fb.setup(global_position, dir_vector, false, buff_config)
	get_parent().add_child(fb)
	# 分裂在发射瞬间发生，而不是等主火球命中敌人后才发生。
	if fb.enable_split:
		fb.spawn_split_fireballs()
	print("发射火球")

func take_damage(amount:float):
	if is_dead or is_invincible or dodge_time_left > 0.0 or dodge_invulnerability_left > 0.0:
		return
	hp -= amount
	print("怪物攻击玩家，扣血：", amount,"剩余玩家血量：", hp)
	if hp_bar != null:
		hp_bar.value = hp #同步更新血条
	
	#====主角闪白====
	if tween != null:
		tween.kill()
	tween = create_tween()
	tween.tween_property(anim, "modulate", Color(2,2,2), 0.05)
	tween.tween_property(anim, "modulate", Color(1,1,1),0.15)
	#====主角头顶弹出伤害数字，增加空判断====
	if damage_scene != null:
		var dmg_label = damage_scene.instantiate()
		get_parent().add_child(dmg_label)
		dmg_label.global_position = global_position + Vector2(0,-20)
		dmg_label.text = str(amount)
	
	if hp <= 0:
		die()

func dodge():
	if is_instance_valid(gm) and gm.level_map != null and (not gm.game_started or gm.game_over): return
	if is_dead or dodge_timer > 0.0 or dodge_time_left > 0.0:
		return
	dodge_timer = dodge_cooldown
	dodge_time_left = dodge_duration
	dodge_invulnerability_left = dodge_duration + dodge_landing_protection
	dodge_trail_timer = 0.0
	dodge_trail_index = 0
	is_invincible = true
	# Disable both script damage and physics contacts for the complete dash.
	# This makes the invulnerability independent of collision callback order.
	collision_layer = 0
	collision_mask = 0
	dodge_collision_shape.set_deferred("disabled", true)
	var current_input := movement_input()
	dodge_direction = current_input if current_input != Vector2.ZERO else input_dir.normalized()
	if dodge_direction == Vector2.ZERO:
		dodge_direction = last_dir.normalized()
	if dodge_direction == Vector2.ZERO:
		dodge_direction = Vector2.DOWN
	last_dir = dodge_direction
	sword_dash_hit.clear()
	play_dodge_pose()

func play_dodge_pose():
	if tween != null:
		tween.kill()
	anim.modulate = Color.WHITE
	anim.pause()
	if sword_time_left > 0.0:
		dodge_visual.visible = false
		anim.visible = false
		return
	dodge_visual.begin(anim, dodge_direction)
	anim.visible = false

func spawn_dodge_afterimage():
	if sword_time_left > 0.0:
		var ghost := Sprite2D.new()
		ghost.set_script(preload("res://boss_afterimage.gd"))
		get_parent().add_child(ghost)
		ghost.setup(sword_visual.sprite,Color(0.7,0.3,1))
		return
	var ghost := Node2D.new()
	ghost.set_script(DODGE_FX_SCRIPT)
	get_parent().add_child(ghost)
	var color := Color(0.04, 1.0, 0.88) if dodge_trail_index % 2 == 0 else Color(1.0, 0.12, 0.72)
	ghost.setup(dodge_visual.pose, color)
	dodge_trail_index += 1

func end_dodge():
	dodge_time_left = 0.0
	is_invincible = dodge_invulnerability_left > 0.0
	collision_layer = normal_collision_layer
	collision_mask = normal_collision_mask
	dodge_collision_shape.set_deferred("disabled", false)
	dodge_visual.visible = false
	anim.visible = sword_time_left <= 0.0
	anim.play("idle_" + last_dir_to_anim_name(dodge_direction))

func die():
	if sword_time_left > 0.0: end_sword_form()
	is_dead = true
	print("玩家死亡")
	modulate = Color(0.6,0.6,0.6,1)
	if gm != null:
		gm.game_die()
	else:
		print("警告：找不到GameManager节点！")

func unlock_sword_form():
	if is_dead or sword_unlocked: return
	sword_unlocked = true
	if is_instance_valid(gm):
		if gm.level_map != null:
			gm.level_map.spawn_training_dummy()
		gm.show_sword_choose()

func activate_sword_form():
	if is_dead or not sword_unlocked or sword_time_left > 0.0 or sword_cooldown_left > 0.0:
		return
	if is_instance_valid(gm) and (gm.game_over or not gm.game_started): return
	sword_time_left = 10.0
	sword_cooldown_left = 50.0
	sword_visual.visible = true
	sword_visual.attack_timer = 0
	sword_visual.begin_form()
	dodge_visual.visible = false
	anim.visible = false
	dodge_invulnerability_left = maxf(dodge_invulnerability_left,0.2)
	is_invincible = true

func end_sword_form():
	sword_time_left = 0
	sword_visual.visible = false
	sword_visual.strike_left = 0
	sword_visual.pose_left = 0
	anim.visible = true
	if not is_dead:
		dodge_invulnerability_left = maxf(dodge_invulnerability_left,0.15)

# ============ 灵气相关函数 ============
func add_aura(amount:float):
	if is_dead or (is_instance_valid(gm) and gm.run_ended):
		return
	if realm >= MAX_REALM:
		print("已达到练气大圆满！")
		return
	
	current_aura += amount
	print("吸收灵气：", amount, " 当前灵气 ", current_aura, "/", need_aura)
	
	while current_aura >= need_aura and realm < MAX_REALM:
		current_aura -= need_aura
		realm += 1
		need_aura *= GROW_RATE
		print("突破！境界提升：", get_realm_name(realm))
		show_breakthrough()
		#突破，打开buff三选一弹窗
		if gm != null:
			gm.show_buff_choose()
	
	update_cultivate_ui()

func show_breakthrough():
	for previous in get_tree().get_nodes_in_group("breakthrough_fx"):
		if previous.player == self: previous.get_parent().queue_free()
	var layer := CanvasLayer.new()
	layer.layer = 2
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_parent().add_child(layer)
	var effect := Node2D.new()
	effect.set_script(preload("res://breakthrough_fx.gd"))
	layer.add_child(effect)
	effect.setup(self)

func update_cultivate_ui():
	if cultivate_bar == null or cultivate_text == null:
		return
	cultivate_bar.max_value = need_aura
	cultivate_bar.value = current_aura
	cultivate_text.text = get_realm_name(realm)

func get_realm_name(lv:int) -> String:
	match lv:
		1: return "练气一层"
		2: return "练气二层"
		3: return "练气三层"
		4: return "练气四层"
		5: return "练气五层"
		6: return "练气六层"
		7: return "练气七层"
		8: return "练气八层"
		9: return "练气大圆满"
	return "未知境界"
