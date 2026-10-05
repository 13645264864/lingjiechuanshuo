extends Area2D

## Boss-only projectile. It is deliberately drawn in code so the boss can
## create several distinct attack patterns without adding a texture pack.
var velocity: Vector2 = Vector2.ZERO
var damage: float = 12.0
var life_left: float = 4.0
var tint: Color = Color(0.72, 0.2, 1.0)
var trail: Array[Vector2] = []
var trail_timer: float = 0.0
var homing_target: CharacterBody2D
var homing_time := 0.0
var turn_speed := 0.0
var is_sword := false
var owner_boss: Node2D

func setup(origin: Vector2, direction: Vector2, speed: float, hit_damage: float, color: Color, lifetime: float = 4.0):
	global_position = origin
	velocity = direction.normalized() * speed
	damage = hit_damage
	tint = color
	life_left = lifetime
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	body_entered.connect(_on_body_entered)
	queue_redraw()

func enable_homing(target: CharacterBody2D, duration: float, max_turn_speed: float):
	homing_target = target
	homing_time = duration
	turn_speed = max_turn_speed
	is_sword = true
	add_to_group("boss_projectile")

func _physics_process(delta: float):
	if is_sword and (not is_instance_valid(owner_boss) or owner_boss.is_dead):
		queue_free()
		return
	life_left -= delta
	if life_left <= 0.0:
		queue_free()
		return
	if homing_time > 0.0 and is_instance_valid(homing_target) and not homing_target.is_dead:
		homing_time = maxf(homing_time - delta, 0.0)
		var aim := (homing_target.global_position - global_position).angle()
		var turn := clampf(angle_difference(velocity.angle(), aim), -turn_speed * delta, turn_speed * delta)
		velocity = velocity.rotated(turn)
	var previous := global_position
	global_position += velocity * delta
	if is_sword and is_instance_valid(homing_target):
		var sweep := CapsuleShape2D.new()
		sweep.radius = 12.0
		sweep.height = previous.distance_to(global_position) + 24.0
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = sweep
		query.transform = Transform2D(velocity.angle() - PI * 0.5, (previous + global_position) * 0.5)
		query.collision_mask = homing_target.normal_collision_layer
		for result in get_world_2d().direct_space_state.intersect_shape(query, 128):
			if result.collider == homing_target:
				_on_body_entered(homing_target)
				break
	trail_timer -= delta
	if trail_timer <= 0.0:
		trail_timer = 0.035
		trail.push_front(Vector2.ZERO)
		if trail.size() > 7:
			trail.pop_back()
		queue_redraw()

func _on_body_entered(body: Node):
	if is_queued_for_deletion():
		return
	if body != null and not body.is_in_group("enemy") and body.has_method("take_damage") and not body.is_dead:
		body.take_damage(damage)
		queue_free()

func _draw():
	for i in range(trail.size()):
		var alpha := 0.24 * (1.0 - float(i) / maxf(float(trail.size()), 1.0))
		draw_circle(trail[i] - velocity.normalized() * float(i) * 5.0, 8.0 - i * 0.7, Color(tint, alpha))
	if is_sword:
		var direction := velocity.normalized()
		var normal := Vector2(-direction.y, direction.x)
		var blade := PackedVector2Array([direction * 32.0, normal * 5.0, -direction * 18.0, -normal * 5.0])
		draw_colored_polygon(blade, Color(0.95, 0.8, 1.0))
		draw_line(-direction * 24.0, direction * 27.0, tint, 3.0, true)
		draw_line(-direction * 15.0 + normal * 12.0, -direction * 15.0 - normal * 12.0, tint, 4.0, true)
		return
	draw_circle(Vector2.ZERO, 9.0, Color(tint, 0.28))
	draw_circle(Vector2.ZERO, 4.5, Color(1.0, 0.9, 1.0, 0.98))
	draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 20, Color(tint, 0.75), 2.0)
