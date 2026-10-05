extends SceneTree

var checks := 0
var failures: Array[String] = []
var world: Node2D
var player
var captures: Array[Image] = []
var capture_enabled := false

func _initialize():
	run.call_deferred()

func check(condition: bool, message: String):
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func ticks(count: int):
	for i in range(count):
		await physics_frame
		await process_frame

func release_input():
	for action in ["move_left", "move_right", "move_up", "move_down", "dodge"]:
		Input.action_release(action)

func spawn_shot(origin: Vector2, direction: Vector2, speed := 500.0):
	var shot := Area2D.new()
	shot.set_script(load("res://boss_projectile.gd"))
	var collider := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	collider.shape = circle
	shot.add_child(collider)
	world.add_child(shot)
	shot.setup(origin, direction, speed, 12.0, Color.MAGENTA, 1.0)
	return shot

func capture_view():
	if not capture_enabled:
		return
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	check(not screenshot.is_empty(), "Rendered dodge image is nonempty")
	captures.append(screenshot)

func run():
	create_timer(20.0).timeout.connect(func(): quit(2))
	capture_enabled = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1152, 648)
	world = load("res://main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await ticks(2)
	player = world.get_node("Player")
	player.hp = 5000.0
	player.max_hp = 5000.0
	player.fireball_timer = 1000.0
	var gm = world.get_node("GameManager")
	gm.set_process(false)
	gm.spawn_timer.stop()
	gm.start_btn.hide()
	gm.dodge_button.hide()
	world.get_node("UI").hide()
	var camera: Camera2D = world.get_node("Camera2D")
	camera.set_process(false)
	camera.position = Vector2(360, 0)
	camera.zoom = Vector2.ONE * 1.1
	var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
	var saved_transform := sprite.transform
	var blocker = load("res://enemy.tscn").instantiate()
	world.add_child(blocker)
	blocker.set_physics_process(false)
	blocker.position = Vector2(90, 0)
	await ticks(2)

	# Movement and Shift arrive together, while the previous facing was up.
	player.last_dir = Vector2.UP
	Input.action_press("move_right")
	Input.action_press("dodge")
	await ticks(1)
	Input.action_release("dodge")
	Input.action_release("move_right")
	check(player.dodge_direction == Vector2.RIGHT, "Dash reads current direction on the same frame as Shift")
	check(player.is_invincible and player.dodge_collision_shape.disabled, "Dash activates ghost collision and invulnerability")
	check(not sprite.visible and player.dodge_visual.visible, "Dash uses independent pose instead of running sprite")
	var hp_before: float = player.hp
	for frame in range(15):
		player.take_damage(25.0)
		await ticks(1)
	check(player.hp == hp_before, "Damage is rejected throughout takeoff and flight")
	check(player.position.x > blocker.position.x, "Physical dash passes through enemy")
	check(get_nodes_in_group("dodge_afterimage").size() >= 3, "Dash leaves multiple world-space afterimages")
	await ticks(3)
	check(player.dodge_time_left == 0.0 and sprite.visible and not player.dodge_visual.visible, "Landing restores walking visuals")
	check(player.is_invincible, "Landing retains a brief protection window")
	player.take_damage(25.0)
	check(player.hp == hp_before, "Landing protection rejects damage")
	await ticks(7)
	check(not player.is_invincible, "Invulnerability expires with physics time")
	check(sprite.transform.is_equal_approx(saved_transform), "Dash does not rotate or resize normal sprite")
	check(player.collision_layer == player.normal_collision_layer and not player.dodge_collision_shape.disabled, "Normal collision is restored")
	player.take_damage(25.0)
	check(player.hp == hp_before - 25.0, "Damage resumes after protection expires")
	blocker.queue_free()
	await ticks(2)

	# Real Area2D collision: an overlapping boss shot during the dash is ignored.
	player.dodge_timer = 0.0
	player.input_dir = Vector2.ZERO
	player.last_dir = Vector2.RIGHT
	player.dodge()
	hp_before = player.hp
	spawn_shot(player.position, Vector2.RIGHT, player.dodge_speed)
	await ticks(5)
	check(player.hp == hp_before, "Actual boss projectile cannot damage a dodging player")
	await ticks(25)
	for child in world.get_children():
		if child.get_script() == load("res://boss_projectile.gd"):
			child.queue_free()
	await ticks(2)
	hp_before = player.hp
	spawn_shot(player.position - Vector2(100, 0), Vector2.RIGHT)
	await ticks(18)
	check(player.hp == hp_before - 12.0, "Actual boss projectile deals damage after invulnerability")

	# Four-direction visual snapshots at the flight apex.
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		release_input()
		player.position = Vector2(360, 0)
		player.dodge_timer = 0.0
		player.input_dir = Vector2.ZERO
		player.last_dir = direction
		gm.dodge_button.pressed.emit()
		await ticks(9)
		check(player.dodge_direction == direction and player.dodge_visual.visible, "Mobile button leaps in facing direction " + str(direction))
		check(player.dodge_visual.pose.position.is_equal_approx(sprite.position), "Dash stays grounded " + str(direction))
		check(player.global_position.distance_to(Vector2(360,0)) > 140.0, "Long dash covers more distance " + str(direction))
		check(absf(player.dodge_visual.pose.rotation) <= 0.13, "Character stays upright " + str(direction))
		var ghosts := get_nodes_in_group("dodge_afterimage")
		check(not ghosts.is_empty(), "Directional dash generates silhouettes")
		if not ghosts.is_empty():
			var ghost_pose = ghosts[0].get_child(0)
			check((player.global_position - ghost_pose.global_position).dot(direction) > 0.0, "Afterimage is behind movement " + str(direction))
		await capture_view()
		await ticks(25)
		check(get_nodes_in_group("dodge_afterimage").is_empty(), "Afterimages clean up after dash")

	if capture_enabled and captures.size() == 4:
		var output := Image.create(2304, 1296, false, Image.FORMAT_RGBA8)
		for index in range(4):
			captures[index].convert(Image.FORMAT_RGBA8)
			output.blit_rect(captures[index], Rect2i(0, 0, 1152, 648), Vector2i((index % 2) * 1152, (index / 2) * 648))
		output.save_png("res://.godot/dodge-motion-check.png")
		print("DODGE_CAPTURE res://.godot/dodge-motion-check.png")
	release_input()
	print("DODGE_TEST_RESULT checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
