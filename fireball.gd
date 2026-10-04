extends Area2D
@export var speed: float = 80.0
@export var damage: float = 10.0
@export var max_range: float = 450.0
@export var no_collide_distance: float = 1.0
var dir: Vector2
var spawn_pos: Vector2
@onready var anim = $AnimatedSprite2D
# Buff变量
var max_penetrate: int = 1
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
	max_penetrate = 1
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
	var config:Dictionary = gm.get_fireball_config()
	max_penetrate = int(config.penetrate_count)
	if not is_secondary:
		split_count = int(config.split_count)
		enable_split = split_count > 0
	enable_huge = bool(config.enable_huge)
	crit_rate = float(config.crit_rate)
	crit_mult = float(config.crit_mult)
	speed *= float(config.speed_mult)
	pending_scale_mod = float(config.scale_mult)
	print("火球加载技能：速度×", config.speed_mult, "穿透", max_penetrate,
		"分裂", split_count, "巨型", enable_huge)

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
