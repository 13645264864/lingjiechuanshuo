extends Node2D

var map: Node2D
var active := false
var triggered := false
var blocked_until_exit := false
var phase := 0.0
var trigger_radius := 100.0
var particles := CPUParticles2D.new()

func setup(level: Node2D, origin: Vector2):
	map = level
	position = origin
	z_index = 1
	add_to_group("altar_portal")
	particles.amount = 52
	particles.lifetime = 1.3
	particles.direction = Vector2.UP
	particles.spread = 12.0
	particles.gravity = Vector2(0, -28)
	particles.initial_velocity_min = 55
	particles.initial_velocity_max = 110
	particles.scale_amount_min = 0.4
	particles.scale_amount_max = 1.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(95, 22)
	var image := Image.create(8, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(8):
			var distance := absf((x - 3.5) / 3.5) + absf((y - 7.5) / 7.5)
			image.set_pixel(x, y, Color(0.25, 0.75, 1, maxf(1.0 - distance, 0)))
	particles.texture = ImageTexture.create_from_image(image)
	var fade := Gradient.new()
	fade.set_color(0, Color(0.5, 0.85, 1, 0.9))
	fade.set_color(1, Color(0.1, 0.5, 1, 0))
	particles.color_ramp = fade
	add_child(particles)
	queue_redraw()

func activate():
	active = true
	if is_instance_valid(map.player):
		blocked_until_exit = map.player.global_position.distance_to(global_position) <= trigger_radius + 30.0

func _process(delta: float):
	phase += delta
	queue_redraw()

func _physics_process(_delta: float):
	if not active or triggered or not is_instance_valid(map): return
	var player = map.player
	var gm = map.manager
	if not is_instance_valid(player) or player.is_dead or gm.game_over or gm.run_ended: return
	var distance: float = player.global_position.distance_to(global_position)
	if player.sword_time_left > 0 or player.sword_visual.auto_guard_left > 0:
		if distance <= trigger_radius + 30: blocked_until_exit = true
		return
	if distance > trigger_radius + 30:
		blocked_until_exit = false
	if distance <= trigger_radius and not blocked_until_exit:
		triggered = true
		gm.show_beta_ending()

func _draw():
	var pulse := 0.8 + sin(phase * 3) * 0.2
	var strength := 1.0 if active else 0.6
	for ring in range(3):
		var radius := 80.0 + ring * 23.0
		var points := PackedVector2Array()
		var offset := phase * (0.8 if ring % 2 == 0 else -0.65)
		for index in range(48):
			var angle := offset + index * TAU / 47.0
			points.append(Vector2(cos(angle) * radius, sin(angle) * radius * 0.42))
		draw_polyline(points, Color(0.1, 0.62, 1, (0.8 - ring * 0.15) * strength), 5.0, true)
	for index in range(12):
		var angle := phase * 0.8 + index * TAU / 12.0
		var point := Vector2(cos(angle) * 108, sin(angle) * 45)
		draw_line(point, point + Vector2(0, -10), Color(0.55, 0.9, 1, strength), 3, true)
	# Translucent column, brightest around the floor; it never changes altar height.
	for index in range(6):
		var x := (index - 2.5) * 22.0
		draw_line(Vector2(x, -170), Vector2(x, 8), Color(0.18, 0.65, 1, 0.14 * pulse * strength), 28, true)
	draw_line(Vector2(-60, 0), Vector2(60, 0), Color(0.65, 0.9, 1, 0.65 * pulse * strength), 4, true)
