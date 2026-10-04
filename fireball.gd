extends Area2D

@export var speed: float = 80.0
@export var damage: float = 10.0
@export var max_range: float = 450.0

var dir: Vector2
var spawn_pos: Vector2
var max_penetrate: int = 1
var penetrate_count: int = 0
var hit_enemy_list: Array = []
var enable_split: bool = false
var split_count: int = 0
var is_secondary: bool = false
var enable_huge: bool = false
var crit_rate: float = 0.05
var crit_mult: float = 2.05
var pending_scale_mod: float = 1.0
var buff_config: Dictionary = {}
var rng = RandomNumberGenerator.new()
var base_speed: float = -1.0
var pending_contacts: Array[Node2D] = []
var contact_batch_pending: bool = false

@onready var anim = $AnimatedSprite2D

# 配置快照由玩家传入；此方法不依赖火球已经进入场景树。
func setup(pos: Vector2, direction: Vector2, secondary: bool = false,
		config: Dictionary = {}, already_hit: Array = []):
	if base_speed < 0.0:
		base_speed = speed
	spawn_pos = pos
	position = pos
	dir = direction.normalized()
	is_secondary = secondary
	hit_enemy_list = already_hit.duplicate()
	penetrate_count = 0
	buff_config = config.duplicate(true)
	speed = base_speed * float(buff_config.get("speed_mult", 1.0))
	max_penetrate = maxi(1, int(buff_config.get("penetrate_count", 1)))
	split_count = 0 if is_secondary else int(buff_config.get("split_count", 0))
	enable_split = split_count > 0
	enable_huge = bool(buff_config.get("enable_huge", false))
	crit_rate = float(buff_config.get("crit_rate", 0.05))
	crit_mult = float(buff_config.get("crit_mult", 2.05))
	pending_scale_mod = float(buff_config.get("scale_mult", 1.0))
	rng.randomize()
	if is_node_ready():
		global_position = pos
		apply_visual_config()

func _ready():
	global_position = spawn_pos
	body_entered.connect(_on_body_hit)
	apply_visual_config()

func apply_visual_config():
	# 体型同时作用于图像和碰撞范围。
	scale = Vector2.ONE * pending_scale_mod
	anim.play("Fireball")

func _physics_process(delta):
	global_position += dir * speed * delta
	if global_position.distance_to(spawn_pos) > max_range:
		queue_free()

func _on_body_hit(body: Node2D):
	if is_queued_for_deletion() or hit_enemy_list.has(body):
		return
	if enable_huge:
		# 等本帧全部碰撞信号收集完成，再结算并决定是否销毁。
		if not pending_contacts.has(body):
			pending_contacts.append(body)
		if not contact_batch_pending:
			contact_batch_pending = true
			resolve_contact_batch.call_deferred()
		return
	damage_body(body)
	if penetrate_count >= max_penetrate:
		queue_free()

func resolve_contact_batch():
	for body in pending_contacts:
		damage_body(body)
	pending_contacts.clear()
	contact_batch_pending = false
	if penetrate_count >= max_penetrate:
		queue_free()

func damage_body(body: Node2D):
	if not is_instance_valid(body) or hit_enemy_list.has(body):
		return
	if not body.is_in_group("enemy") or not body.has_method("take_damage"):
		return
	if body.get("is_dead") == true:
		return
	hit_enemy_list.append(body)
	var final_dmg = damage
	if enable_huge and rng.randf() < crit_rate:
		final_dmg *= crit_mult
	body.take_damage(final_dmg)
	penetrate_count += 1

func spawn_split_fireballs():
	if is_secondary or split_count <= 0 or not is_instance_valid(get_parent()):
		return
	# 主火球发射时立即生成次级火球；次级火球继承速度、穿透和巨型效果，
	# 但 setup 中会把它们标记为 secondary，因此不会再次分裂。
	var container = get_parent()
	var start_angle = deg_to_rad(-45.0)
	var angle_step = deg_to_rad(90.0 / maxf(split_count - 1, 1))
	for i in range(split_count):
		var fb = load("res://fireball.tscn").instantiate()
		fb.setup(global_position, dir.rotated(start_angle + angle_step * i),
			true, buff_config)
		container.add_child(fb)
