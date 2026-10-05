extends CharacterBody2D

@export var base_hp: float = 900.0
@export var base_damage: float = 28.0
@export var base_speed: float = 165.0
@export var aura_drop_scene: PackedScene
@export var dash_speed: float = 1450.0
@export var dash_min_range: float = 650.0
@export var dash_max_range: float = 1100.0
@export var aim_duration: float = 0.56
@export var lock_duration: float = 0.16
@export var recovery_duration: float = 0.75

const PROJECTILE_SCRIPT = preload("res://boss_projectile.gd")
const ZONE_SCRIPT = preload("res://boss_attack_zone.gd")
const FX_SCRIPT = preload("res://boss_fx.gd")
const AFTERIMAGE_SCRIPT = preload("res://boss_afterimage.gd")
enum State { CHASE, AIM, LOCK, DASH, SLASH, RECOVER, SWORDS, RAIN, DEAD }

var hp: float
var max_hp: float
var damage: float
var move_speed: float
var player: CharacterBody2D
var boss_level := 1
var state: State = State.CHASE
var state_time := 0.0
var is_dead := false
var frenzy := false
var body_diameter := 320.0
var facing_direction := Vector2.RIGHT
var dash_direction := Vector2.RIGHT
var dash_range := 650.0
var dash_travelled := 0.0
var dash_origin := Vector2.ZERO
var dash_has_hit := false
var dash_from_charge := false
var afterimage_timer := 0.0
var attack_wait := 1.4
var attack_index := 0
var dash_hit_width := 140.0
var hit_flash := 0.0
var hurt_pose_left := 0.0
var slash_spawned := false
var sword_launched := false
var rain_spawned := false
var tween: Tween
var arena_bounds := Rect2()
var room_id := -1

func _ready():
	add_to_group("boss")
	add_to_group("enemy")
	$AnimatedSprite2D.set_action("idle", Vector2.RIGHT)

func setup_spawn(spawn_position: Vector2, target: CharacterBody2D, minute_level: int):
	global_position = spawn_position
	player = target
	boss_level = maxi(1, minute_level)
	max_hp = base_hp * pow(1.38, boss_level - 1)
	hp = max_hp
	damage = base_damage * pow(1.22, boss_level - 1)
	move_speed = base_speed * (1.0 + minf((boss_level - 1) * 0.04, 0.24))
	body_diameter = 320.0
	scale = Vector2.ONE
	$AnimatedSprite2D.scale = Vector2.ONE * body_diameter / maxf($AnimatedSprite2D.body_size, 1.0)
	$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
	$CollisionShape2D.shape.radius = body_diameter * 0.5
	$CollisionShape2D.scale = Vector2.ONE
	$Aura.radius = 240.0
	$Aura.scale = Vector2.ONE * body_diameter / 500.0

func _process(delta: float):
	var action := "idle"
	match state:
		State.CHASE: action = "walk" if velocity.length() > 1.0 else "idle"
		State.AIM, State.LOCK, State.SWORDS, State.RAIN: action = "cast"
		State.DASH: action = "dash"
		State.SLASH: action = "attack"
		State.DEAD: action = "death"
	if hurt_pose_left > 0.0 and state == State.CHASE:
		action = "hurt"
	$AnimatedSprite2D.set_action(action, facing_direction)
	$AnimatedSprite2D.set_energy(frenzy, action == "cast", hit_flash)
	$Aura.raging = frenzy
	$Aura.power = move_toward($Aura.power, 1.0 if action == "cast" else 0.0, delta * 5.0)

func _physics_process(delta: float):
	if is_dead or not is_instance_valid(player) or player.is_dead:
		return
	hurt_pose_left = maxf(hurt_pose_left - delta, 0.0)
	if not frenzy and hp <= max_hp * 0.45:
		frenzy = true
		spawn_fx("blink", Color(0.95, 0.18, 0.65), 280.0, 0.65)
	state_time += delta
	match state:
		State.CHASE:
			attack_wait -= delta
			var distance := global_position.distance_to(player.global_position)
			facing_direction = (player.global_position - global_position).normalized()
			velocity = facing_direction * move_speed * (1.12 if frenzy else 1.0)
			move_and_slide()
			if arena_bounds.has_area():
				global_position = global_position.clamp(arena_bounds.position, arena_bounds.end - Vector2.ONE)
			if attack_wait <= 0.0 and distance <= 1250.0:
				if distance < body_diameter * 0.5 + 170.0:
					begin_slash(false)
				else:
					match attack_index % 4:
						0, 2: begin_dash_pattern()
						1: begin_swords()
						3: begin_rain()
					attack_index += 1
		State.AIM:
			_update_dash_aim()
			if state_time >= aim_duration:
				change_state(State.LOCK)
		State.LOCK:
			if state_time >= lock_duration:
				start_next_dash()
		State.DASH:
			advance_dash(delta)
		State.SLASH:
			if not slash_spawned and state_time >= 0.08:
				slash_spawned = true
				spawn_zone("slash", global_position, body_diameter * 0.5 + 180.0, damage, 0.36, facing_direction)
			if state_time >= 0.62:
				change_state(State.RECOVER)
		State.RECOVER:
			if state_time >= recovery_duration:
				change_state(State.CHASE)
				attack_wait = 0.45 if frenzy else 0.8
		State.SWORDS:
			facing_direction = (player.global_position - global_position).normalized()
			if not sword_launched and state_time >= 0.55:
				sword_launched = true
				launch_swords()
			if state_time >= 0.85:
				change_state(State.RECOVER)
		State.RAIN:
			facing_direction = (player.global_position - global_position).normalized()
			if not rain_spawned and state_time >= 0.35:
				rain_spawned = true
				launch_rain()
			if state_time >= 1.3:
				change_state(State.RECOVER)
	queue_redraw()

func change_state(next: State):
	state = next
	state_time = 0.0
	velocity = Vector2.ZERO
	queue_redraw()

func begin_dash_pattern():
	change_state(State.AIM)
	dash_has_hit = false
	dash_from_charge = true
	dash_origin = global_position
	_update_dash_aim()

func _update_dash_aim():
	var predicted := player.global_position + player.velocity * 0.18
	dash_direction = (predicted - global_position).normalized()
	if dash_direction == Vector2.ZERO:
		dash_direction = facing_direction
	facing_direction = dash_direction
	dash_range = clampf(global_position.distance_to(predicted) + 240.0, dash_min_range, dash_max_range)

func start_next_dash():
	if arena_bounds.has_area():
		var limit := dash_range
		for axis in range(2):
			if absf(dash_direction[axis]) > 0.001:
				var edge := arena_bounds.end[axis] - 1.0 if dash_direction[axis] > 0.0 else arena_bounds.position[axis] + 1.0
				limit = minf(limit, (edge - global_position[axis]) / dash_direction[axis])
		dash_range = maxf(limit, 0.0)
	change_state(State.DASH)
	dash_origin = global_position
	dash_travelled = 0.0
	afterimage_timer = 0.0
	# The sweep is authoritative. Ignore bodies while dashing so the boss cannot
	# stop against a crowd before reaching the locked destination.
	collision_mask = 0
	# Remove layer 1 body blocking until the dash reaches its destination.
	collision_layer = 2
	spawn_fx("blink", Color(0.75, 0.24, 1.0), 220.0, 0.25)

func advance_dash(delta: float):
	var step := minf(dash_speed * delta, dash_range - dash_travelled)
	var previous := global_position
	global_position += dash_direction * step
	dash_travelled += step
	velocity = dash_direction * dash_speed
	if not dash_has_hit:
		var sweep := CapsuleShape2D.new()
		sweep.radius = dash_hit_width * 0.5
		sweep.height = step + dash_hit_width
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = sweep
		query.transform = Transform2D(dash_direction.angle() - PI * 0.5, (previous + global_position) * 0.5)
		query.collision_mask = player.normal_collision_layer
		for hit in get_world_2d().direct_space_state.intersect_shape(query, 128):
			if hit.collider == player:
				dash_has_hit = true
				player.take_damage(damage * 0.65)
				break
	afterimage_timer -= delta
	if afterimage_timer <= 0.0:
		afterimage_timer = 0.045
		spawn_afterimage()
	if dash_travelled >= dash_range - 0.1:
		collision_mask = 7 if arena_bounds.has_area() else 3
		collision_layer = 2 if room_id >= 0 else 3
		begin_slash(true)

func begin_slash(after_dash: bool):
	change_state(State.SLASH)
	slash_spawned = false
	dash_from_charge = after_dash
	# Keep the committed facing after a dash: no instant auto-turn behind player.
	if not after_dash:
		facing_direction = (player.global_position - global_position).normalized()
	$AnimatedSprite2D.set_action("attack", facing_direction)
	$AnimatedSprite2D.set_frame_and_progress(0, 0.0)

func begin_swords():
	change_state(State.SWORDS)
	sword_launched = false

func launch_swords():
	var aim := (player.global_position - global_position).normalized()
	var count := 4 if frenzy else 3
	for index in range(count):
		var direction := aim.rotated((index - (count - 1) * 0.5) * 0.42)
		var shot := Area2D.new()
		shot.set_script(PROJECTILE_SCRIPT)
		var collider := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 12.0
		collider.shape = circle
		shot.add_child(collider)
		get_parent().add_child(shot)
		shot.setup(global_position + direction * (body_diameter * 0.3), direction, 420.0, damage * 0.45, Color(0.72, 0.28, 1.0), 3.0)
		shot.enable_homing(player, 0.95, 1.8)
		shot.owner_boss = self

func begin_rain():
	change_state(State.RAIN)
	rain_spawned = false

func launch_rain():
	var origin := player.global_position
	var heading := player.velocity.normalized()
	if heading == Vector2.ZERO:
		heading = (origin - global_position).normalized()
	var count := 4 if frenzy else 3
	for index in range(count):
		# Commit each mark before impact; it never chases the player afterwards.
		var predicted := origin + heading * float(index) * 125.0
		spawn_zone("mark", predicted, 120.0, damage * 0.65, 0.65 + index * 0.22)

func spawn_zone(kind: String, origin: Vector2, radius: float, hit_damage: float, delay: float, direction := Vector2.RIGHT):
	var zone := Node2D.new()
	zone.set_script(ZONE_SCRIPT)
	get_parent().add_child(zone)
	zone.setup(self, player, origin, kind, radius, hit_damage, delay, direction)
	return zone

func spawn_fx(mode: String, color: Color, radius: float, duration: float):
	var fx := Node2D.new()
	fx.set_script(FX_SCRIPT)
	get_parent().add_child(fx)
	fx.global_position = global_position
	fx.setup(mode, color, radius, duration)

func spawn_afterimage():
	var ghost := Sprite2D.new()
	ghost.set_script(AFTERIMAGE_SCRIPT)
	get_parent().add_child(ghost)
	ghost.setup($AnimatedSprite2D, Color(1.0, 0.18, 0.65) if frenzy else Color(0.75, 0.25, 1.0))

func take_damage(amount: float):
	if is_dead:
		return
	hp -= amount
	if tween != null:
		tween.kill()
	hit_flash = 1.0
	hurt_pose_left = 0.16
	tween = create_tween()
	tween.tween_property(self, "hit_flash", 0.0, 0.16)
	if hp <= 0.0:
		is_dead = true
		change_state(State.DEAD)
		collision_layer = 0
		collision_mask = 0
		$CollisionShape2D.set_deferred("disabled", true)
		remove_from_group("enemy")
		remove_from_group("boss")
		$Aura.extinguishing = true
		$AnimatedSprite2D.set_action("death", facing_direction)
		var gm = get_parent().get_node_or_null("GameManager")
		if gm != null:
			gm.boss_defeated()
		var death_tween := create_tween()
		death_tween.tween_interval(1.15)
		death_tween.tween_property($AnimatedSprite2D, "modulate:a", 0.0, 0.25)
		death_tween.tween_callback(_finish_death)

func _finish_death():
	if room_id >= 0:
		var sword := Node2D.new()
		sword.set_script(preload("res://sword_drop.gd"))
		get_parent().add_child(sword)
		sword.global_position = global_position
	if aura_drop_scene != null:
		var aura = aura_drop_scene.instantiate()
		get_parent().add_child(aura)
		aura.global_position = global_position
		aura.aura_value = 80.0 + boss_level * 25.0
	queue_free()

func _draw():
	if state != State.AIM and state != State.LOCK:
		return
	var end := dash_direction * dash_range
	var normal := Vector2(-dash_direction.y, dash_direction.x) * dash_hit_width * 0.5
	var color := Color(1.0, 0.2, 0.65) if state == State.LOCK else Color(0.75, 0.28, 1.0)
	draw_colored_polygon(PackedVector2Array([normal, end + normal, end - normal, -normal]), Color(color, 0.12))
	draw_line(normal, end + normal, Color(color, 0.85), 2.0, true)
	draw_line(-normal, end - normal, Color(color, 0.85), 2.0, true)
	for index in range(int(dash_range / 90.0)):
		var position_on_path := dash_direction * (45.0 + index * 90.0)
		draw_polyline(PackedVector2Array([position_on_path - normal * 0.18, position_on_path + dash_direction * 16.0, position_on_path + normal * 0.18]), color, 2.0, true)
