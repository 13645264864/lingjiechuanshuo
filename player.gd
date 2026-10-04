extends CharacterBody2D
var hp:float = 100.0
var max_hp:float =100.0
var is_dead:bool = false
@onready var anim = $AnimatedSprite2D
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

func _ready():
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
	fireball_timer -= delta
	if fireball_timer <= 0:
		find_nearest_enemy()
		if target_enemy != null:
			shoot_fireball()
			fireball_timer = fireball_cd
	#玩家移动
	input_dir = Input.get_vector("move_left","move_right","move_up","move_down")
	input_dir = input_dir.normalized()
	if input_dir != Vector2.ZERO:
		last_dir = input_dir
		velocity = input_dir * 180
		if input_dir.y > 0:
			anim.play("run_down")
		elif input_dir.y < 0:
			anim.play("run_up")
		elif input_dir.x >0:
			anim.play("run_right")
		else:
			anim.play("run_left")
	else:
		velocity = Vector2.ZERO
		anim.play("idle_" + last_dir_to_anim_name(last_dir))
	move_and_slide()

func last_dir_to_anim_name(dir:Vector2)->String:
	if dir == Vector2.DOWN: return "down"
	if dir == Vector2.UP: return "up"
	if dir == Vector2.RIGHT: return "right"
	if dir == Vector2.LEFT: return "left"
	return "down"

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
	var buff_config:Dictionary = {}
	if is_instance_valid(gm):
		buff_config = gm.get_fireball_config()
	# 入树前初始化，通过参数传入技能，避免火球查找不到场景节点。
	fb.setup(global_position, dir_vector, false, buff_config)
	get_parent().add_child(fb)
	print("发射火球")

func take_damage(amount:float):
	if is_dead:
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

func die():
	is_dead = true
	print("玩家死亡")
	modulate = Color(0.6,0.6,0.6,1)
	if gm != null:
		gm.game_die()
	else:
		print("警告：找不到GameManager节点！")

# ============ 灵气相关函数 ============
func add_aura(amount:float):
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
		#突破，打开buff三选一弹窗
		if gm != null:
			gm.show_buff_choose()
	
	update_cultivate_ui()

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
