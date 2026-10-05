extends Node2D

const VISUAL_SCRIPT = preload("res://boss_animated_sprite.gd")
const WAVE_SCRIPT = preload("res://sword_wave.gd")
var player: CharacterBody2D
var sprite: AnimatedSprite2D
var attack_timer := 0.0
var pose_left := 0.0
var strike_left := 0.0
var strike_direction := Vector2.RIGHT
var upgrades: Dictionary = {}
var blink_timer := 0.0
var wave_timer := 0.0
var target_enemy: CharacterBody2D
var auto_guard_left := 0.0
var blink_count := 0
var slash_count := 0
var wave_count := 0

func _ready():
	player = get_parent()
	sprite = AnimatedSprite2D.new()
	sprite.set_script(VISUAL_SCRIPT)
	add_child(sprite)
	sprite.scale = Vector2.ONE * 155.0 / sprite.body_size / player.scale.x
	visible = false

func update_form(delta: float):
	upgrades = player.gm.sword_buffs if is_instance_valid(player.gm) else {}
	attack_timer -= delta
	blink_timer = maxf(blink_timer - delta, 0)
	wave_timer = maxf(wave_timer - delta, 0)
	target_enemy = nearest_enemy(3000.0)
	pose_left = maxf(pose_left - delta,0)
	if strike_left > 0:
		strike_left -= delta
		if strike_left <= 0: resolve_slash()
	if player.dodge_time_left > 0:
		sprite.set_action("dash",player.dodge_direction)
		return
	if is_instance_valid(target_enemy) and player.input_dir == Vector2.ZERO:
		if blink_timer <= 0 and player.global_position.distance_to(target_enemy.global_position) > 190:
			blink_to_target(target_enemy)
	if is_instance_valid(target_enemy) and wave_timer <= 0:
		launch_waves((target_enemy.global_position - player.global_position).normalized())
		wave_timer = 2.0
	if attack_timer <= 0:
		var enemy = nearest_enemy(460.0)
		if enemy != null:
			strike_direction = (enemy.global_position-player.global_position).normalized()
			strike_left = 0.28
			pose_left = 0.6
			attack_timer = 0.8 / (1.0 + int(upgrades.get(1,0))*0.18)
			sprite.set_action("attack",strike_direction)
			sprite.set_frame_and_progress(0,0)
	if pose_left > 0: sprite.set_action("attack",strike_direction)
	else: sprite.set_action("walk" if player.input_dir != Vector2.ZERO else "idle",player.last_dir)
	queue_redraw()

func begin_form():
	blink_timer = 0
	wave_timer = 0
	strike_left = 0
	pose_left = 0
	target_enemy = null

func has_line_of_sight(enemy: Node2D) -> bool:
	if is_instance_valid(player.gm) and player.gm.level_map != null:
		var same_room := false
		for room in player.gm.level_map.rooms:
			if room.bounds.has_point(player.global_position) and room.bounds.has_point(enemy.global_position):
				same_room = true
				break
		if not same_room: return false
	var ray := PhysicsRayQueryParameters2D.create(player.global_position, enemy.global_position, 4)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func blink_to_target(enemy: CharacterBody2D) -> bool:
	var away := (player.global_position - enemy.global_position).normalized()
	if away == Vector2.ZERO: away = Vector2.LEFT
	var level = player.gm.level_map if is_instance_valid(player.gm) else null
	var stand_off := 175.0
	var collider := enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider != null and collider.shape is CircleShape2D:
		stand_off = maxf(stand_off, collider.shape.radius * collider.global_scale.x + 85.0)
	for angle in [0.0, 0.5, -0.5, 1.0, -1.0, PI]:
		var candidate: Vector2 = enemy.global_position + away.rotated(angle) * stand_off
		if level != null:
			if not level.safe_sword_position(candidate): continue
		else:
			var shape := CircleShape2D.new()
			shape.radius = 75
			var query := PhysicsShapeQueryParameters2D.new()
			query.shape = shape
			query.transform = Transform2D(0, candidate)
			query.collision_mask = 6
			query.exclude = [player.get_rid()]
			if not get_world_2d().direct_space_state.intersect_shape(query, 64).is_empty(): continue
		spawn_blink_effect(player.global_position)
		player.global_position = candidate
		spawn_blink_effect(candidate)
		strike_direction = (enemy.global_position - candidate).normalized()
		player.last_dir = strike_direction
		player.sword_dash_hit.clear()
		player.dodge_invulnerability_left = maxf(player.dodge_invulnerability_left, 0.18)
		player.is_invincible = true
		blink_timer = 2.5
		auto_guard_left = 0.3
		blink_count += 1
		dash_strike(320.0)
		return true
	blink_timer = 0.4
	return false

func spawn_blink_effect(origin: Vector2):
	var effect := Node2D.new()
	effect.set_script(preload("res://boss_fx.gd"))
	player.get_parent().add_child(effect)
	effect.global_position = origin
	effect.setup("blink", Color(0.7, 0.3, 1), 100.0, 0.25)

func follow_target(_delta: float):
	var desired: Vector2 = player.input_dir
	if desired == Vector2.ZERO and is_instance_valid(target_enemy) and not target_enemy.is_dead:
		var toward := target_enemy.global_position - player.global_position
		if toward.length() > 180: desired = toward.normalized()
		player.last_dir = toward.normalized()
		auto_guard_left = 0.3
	if desired != Vector2.ZERO: player.last_dir = desired
	player.velocity = desired * (260.0 if player.input_dir == Vector2.ZERO else 180.0)
	player.move_and_slide()
	if is_instance_valid(player.gm) and player.gm.level_map != null:
		player.global_position = player.gm.level_map.constrain_position(player.global_position)

func launch_waves(direction: Vector2):
	var damage := 32.0 * (1.0 + int(upgrades.get(0, 0)) * 0.3)
	var count := 1 + int(upgrades.get(2, 0))
	for index in range(count):
		var wave := Node2D.new()
		wave.set_script(WAVE_SCRIPT)
		player.get_parent().add_child(wave)
		wave.setup(player.global_position, direction.rotated((index - (count - 1) * 0.5) * 0.18), damage * 0.5)
		wave_count += 1

func nearest_enemy(radius: float):
	var nearest = null
	var best := radius
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.is_dead: continue
		if not has_line_of_sight(enemy): continue
		var distance: float = player.global_position.distance_to(enemy.global_position)
		if distance < best:
			best = distance
			nearest = enemy
	return nearest

func resolve_slash():
	if player.sword_time_left <= 0 or player.is_dead: return
	var damage := 32.0 * (1.0 + int(upgrades.get(0,0))*0.3)
	slash_count += 1
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.is_dead: continue
		var offset: Vector2 = enemy.global_position - player.global_position
		if offset.length() < 380.0 and (offset.length() < 90 or offset.normalized().dot(strike_direction) > -0.15):
			var obstruction := PhysicsRayQueryParameters2D.create(player.global_position,enemy.global_position,4)
			if get_world_2d().direct_space_state.intersect_ray(obstruction).is_empty():
				enemy.take_damage(damage)
	if int(upgrades.get(2, 0)) > 0: launch_waves(strike_direction)

func dash_strike(hit_radius: float = 145.0):
	var damage := 24.0 * (1.0 + int(upgrades.get(3,0))*0.4)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy.is_dead and not player.sword_dash_hit.has(enemy) and player.global_position.distance_to(enemy.global_position) < hit_radius and has_line_of_sight(enemy):
			player.sword_dash_hit.append(enemy)
			enemy.take_damage(damage)

func _draw():
	if pose_left <= 0.0 or strike_left > 0: return
	var radius := 250.0 / player.scale.x
	var angle := strike_direction.angle()
	draw_arc(Vector2.ZERO,radius,angle-1.15,angle+1.15,32,Color(0.85,0.35,1,minf(pose_left*3,0.8)),12,true)
