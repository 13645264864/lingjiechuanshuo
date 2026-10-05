extends Node2D

# Fixed world-space ground telegraph and its matching one-shot physics query.
var owner_boss: Node2D
var target: CharacterBody2D
var kind := "mark"
var radius := 130.0
var direction := Vector2.RIGHT
var spread := PI * 0.85
var damage := 18.0
var delay := 0.65
var duration := 0.25
var age := 0.0
var resolved := false
var color := Color(0.78, 0.28, 1.0)

func setup(source: Node2D, victim: CharacterBody2D, position_world: Vector2, attack_kind: String, attack_radius: float, hit_damage: float, warning_time: float, facing := Vector2.RIGHT):
	owner_boss = source
	target = victim
	global_position = position_world
	kind = attack_kind
	radius = attack_radius
	damage = hit_damage
	delay = warning_time
	direction = facing.normalized()
	z_index = 0
	add_to_group("boss_attack")

func _physics_process(delta: float):
	if not is_instance_valid(owner_boss) or owner_boss.is_dead or not is_instance_valid(target):
		queue_free()
		return
	age += delta
	if not resolved and age >= delay:
		resolved = true
		resolve_hit()
	if age >= delay + duration:
		queue_free()
	queue_redraw()

func resolve_hit():
	if target.is_dead:
		return
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = target.normal_collision_layer
	for result in get_world_2d().direct_space_state.intersect_shape(query, 128):
		if result.collider == target:
			var offset := target.global_position - global_position
			if kind == "mark" or kind == "ring" or offset.length() < 60.0 or direction.dot(offset.normalized()) >= cos(spread * 0.5):
				target.take_damage(damage)
			return

func _draw():
	var progress := clampf(age / maxf(delay, 0.001), 0.0, 1.0)
	var opacity := maxf(1.0 - (age - delay) / duration, 0.0) if resolved else 1.0
	var tint := Color(color, opacity)
	if kind == "slash":
		var start := direction.angle() - spread * 0.5
		var arc := PackedVector2Array([Vector2.ZERO])
		for index in range(33):
			arc.append(Vector2.from_angle(start + spread * index / 32.0) * radius)
		draw_colored_polygon(arc, Color(tint, (0.38 if resolved else 0.1) * opacity))
		draw_arc(Vector2.ZERO, radius, start, start + spread, 40, tint, 14.0 if resolved else 3.0, true)
		if resolved:
			draw_arc(Vector2.ZERO, radius * 0.9, start, start + spread, 40, Color(0.92, 0.82, 1.0, opacity), 5.0, true)
		else:
			draw_line(Vector2.ZERO, arc[1], tint, 2.0, true)
			draw_line(Vector2.ZERO, arc[-1], tint, 2.0, true)
		return
	draw_circle(Vector2.ZERO, radius, Color(tint, (0.35 if resolved else 0.08) * opacity))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, tint, 8.0 if resolved else 2.0, true)
	draw_arc(Vector2.ZERO, radius * progress, 0, TAU, 48, Color(tint, opacity * 0.4), 2.0, true)
	for index in range(4):
		var axis := Vector2.from_angle(index * PI / 2.0)
		draw_line(axis * radius * 0.72, axis * radius, tint, 3.0, true)
	if resolved and kind == "mark":
		var height := 150.0 * opacity
		draw_line(Vector2(0, -height), Vector2.ZERO, Color(tint, opacity * 0.5), 24.0, true)
		draw_line(Vector2(0, -height), Vector2.ZERO, Color(1, 0.85, 1, opacity), 5.0, true)
