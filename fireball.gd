extends Area2D
@export var speed: float = 80.0
@export var damage: float = 10.0
@export var max_range: float = 450.0
@export var no_collide_distance: float = 1.0
var dir: Vector2
var spawn_pos: Vector2
@onready var anim = $AnimatedSprite2D
# Buff变量
var max_penetrate: int = 0
var penetrate_count: int = 0
var hit_enemy_list: Array = []
var enable_split: bool = false
var split_count: int = 0
var is_secondary: bool = false
var enable_huge: bool = false
# 暴击档位
var crit_rate:float = 0.05
var crit_mult:float = 2.05
var rng = RandomNumberGenerator.new()
# 临时存储缩放倍率，等ready后再应用
var pending_scale_mod:float = 1.0

func setup(pos: Vector2, direction: Vector2, secondary: bool = false):
	spawn_pos = pos
	global_position = pos
	dir = direction.normalized()
	is_secondary = secondary
	hit_enemy_list.clear()
	penetrate_count = 0
	# 重置buff相关变量，每次生成火球清空
	max_penetrate = 0
	enable_split = false
	split_count = 0
	enable_huge = false
	crit_rate = 0.05
	crit_mult = 2.05
	pending_scale_mod = 1.0
	# 随机数初始化
	rng.randomize()
	# 火球创建时读取buff
	load_buff_from_gm()

func _ready():
	body_entered.connect(_on_body_hit)
	# ready之后anim才不为空，在这里重置scale
	anim.scale = Vector2(1,1)
	anim.scale *= pending_scale_mod

# 单独抽函数：读取GameManager的buff
func load_buff_from_gm():
	var gm = get_node_or_null("/root/Node2D/GameManager")
	if gm == null:
		print("找不到GameManager")
		return
	var speed_mod = 1.0
	var scale_mod = 1.0
	# 强制重置标记，清除上一个火球残留buff状态
	enable_split = false
	enable_huge = false
	max_penetrate = 0
	
	for buff_type in gm.player_buffs:
		var buff = gm.player_buffs[buff_type]
		var q_mult = buff.mult
		var q_idx = 0
		match q_mult:
			2: q_idx = 0
			3: q_idx = 1
			6: q_idx = 2
			10: q_idx = 3
			
		match buff_type:
			0: #分裂 BuffType.SPLIT
				if not is_secondary:
					enable_split = true
					var base = 2
					match q_idx:
						0: split_count = base
						1: split_count = int(base *1.5)
						2: split_count = int(base *1.5 *2)
						3: split_count = int(base *1.5 *2 *2)
					print("✅分裂buff加载成功，数量：",split_count)
					
			1: #高速 BuffType.SPEED
				var base_speed = 1.6
				match q_idx:
					0: speed_mod *= base_speed
					1: speed_mod *= base_speed *1.5
					2: speed_mod *= base_speed *3
					3: speed_mod *= base_speed *6
					
			2: #穿透 BuffType.PENETRATE
				var base_p = 3
				match q_idx:
					0: max_penetrate = base_p
					1: max_penetrate = int(base_p *1.5)
					2: max_penetrate = int(base_p *3)
					3: max_penetrate = int(base_p *6)
					
			3: #巨型暴击 BuffType.BIG_FIRE
				enable_huge = true
				scale_mod = 1.8
				match q_idx:
					0:
						crit_rate = 0.05
						crit_mult = 2.05
					1:
						crit_rate = 0.10
						crit_mult = 2.10
					2:
						crit_rate = 0.20
						crit_mult = 2.20
					3:
						crit_rate = 0.40
						crit_mult = 2.40
	speed *= speed_mod
	pending_scale_mod = scale_mod

func _physics_process(delta):
	global_position += dir * speed * delta
	var travel_dist = global_position.distance_to(spawn_pos)
	if travel_dist > max_range:
		queue_free()

func _on_body_hit(body:Node2D):
	var travel_dist = global_position.distance_to(spawn_pos)
	if travel_dist < no_collide_distance:
		return
	if hit_enemy_list.has(body):
		return
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		hit_enemy_list.append(body)
		
		# 暴击判定
		var final_dmg = damage
		if enable_huge:
			if rng.randf() < crit_rate:
				final_dmg = damage * crit_mult
				print("【暴击触发】倍率：",crit_mult)
		print("击中敌人，伤害：",final_dmg," enable_split = ",enable_split)
		body.take_damage(final_dmg)
		penetrate_count += 1
		
		if enable_split and not is_secondary:
			create_split_fireball()
			
		if penetrate_count >= max_penetrate:
			queue_free()

func create_split_fireball():
	print("🔥开始生成次级火球")
	var start_angle = deg_to_rad(-45)
	var angle_step = deg_to_rad(90 / max(split_count - 1, 1))
	for i in range(split_count):
		var ang = start_angle + angle_step * i
		var new_dir = dir.rotated(ang)
		var fb = preload("res://fireball.tscn").instantiate()
		fb.setup(global_position, new_dir, true)
		get_parent().add_child(fb)
