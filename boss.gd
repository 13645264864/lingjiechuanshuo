extends CharacterBody2D

@export var base_hp: float = 900.0
@export var base_damage: float = 28.0
@export var base_speed: float = 52.0
@export var attack_cd: float = 0.8
@export var dash_cd: float = 5.0
@export var aura_drop_scene: PackedScene

var hp: float
var max_hp: float
var damage: float
var move_speed: float
var player: CharacterBody2D
var boss_level: int = 1
var attack_timer: float = 0.0
var dash_timer: float = 2.0
var dash_time: float = 0.0
var dash_direction := Vector2.ZERO
var is_dead := false
var tween: Tween

func _ready():
	add_to_group("boss")
	add_to_group("enemy")
	$AnimatedSprite2D.play("run_right")

func setup_spawn(spawn_position: Vector2, target: CharacterBody2D, minute_level: int):
	global_position = spawn_position
	player = target
	boss_level = maxi(1, minute_level)
	var scale_factor = pow(1.38, boss_level - 1)
	max_hp = base_hp * scale_factor
	hp = max_hp
	damage = base_damage * pow(1.22, boss_level - 1)
	move_speed = base_speed * (1.0 + min((boss_level - 1) * 0.06, 0.48))
	# Boss is substantially larger than regular enemies and receives a violet-red skin.
	# The boss is about 3–4 times the regular enemy, with only a small
	# increase on later minutes so it remains readable on a phone screen.
	scale = Vector2.ONE * (3.2 + min(boss_level - 1, 4) * 0.2)
	$AnimatedSprite2D.modulate = Color(0.95, 0.34, 0.72)

func _physics_process(delta):
	if is_dead or player == null:
		return
	attack_timer = maxf(attack_timer - delta, 0.0)
	dash_timer = maxf(dash_timer - delta, 0.0)
	if dash_time > 0.0:
		dash_time -= delta
		velocity = dash_direction * move_speed * 5.0
	else:
		var to_player = player.global_position - global_position
		if to_player.length() > 1.0:
			dash_direction = to_player.normalized()
		velocity = dash_direction * move_speed
		if dash_timer <= 0.0:
			dash_time = 0.28
			dash_timer = dash_cd
			$AnimatedSprite2D.modulate = Color(1.0, 0.85, 1.0)
			var dash_tween = create_tween()
			dash_tween.tween_property($AnimatedSprite2D, "modulate", Color(0.95, 0.34, 0.72), 0.35)
	move_and_slide()
	if dash_direction.x >= 0.0:
		$AnimatedSprite2D.play("run_right")
	else:
		$AnimatedSprite2D.play("run_left")
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if collision.get_collider() == player and attack_timer <= 0.0:
			player.take_damage(damage)
			attack_timer = attack_cd
			break

func take_damage(amount: float):
	if is_dead:
		return
	hp -= amount
	if hp <= 0.0:
		is_dead = true
		var gm = get_parent().get_node_or_null("GameManager")
		if aura_drop_scene != null:
			var aura = aura_drop_scene.instantiate()
			get_parent().add_child(aura)
			aura.global_position = global_position
			aura.aura_value = 80.0 + boss_level * 25.0
		if gm != null and gm.has_method("boss_defeated"):
			gm.boss_defeated()
		queue_free()
