extends SceneTree

var failures: Array[String] = []
var checks := 0
var world
var gm
var player

func _initialize():
	run.call_deferred()

func check(value: bool, message: String):
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func run():
	create_timer(20.0).timeout.connect(func(): quit(2))
	world = load("res://main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	gm = world.get_node("GameManager")
	player = world.get_node("Player")
	gm.rebuild_buff_buttons()
	gm.game_started = true
	gm.game_over = false
	gm.spawn_timer.stop()
	gm.game_time = 60.0

	# Regular enemy starts outside the actual camera view and away from the player.
	gm._spawn_batch()
	var enemies = root.get_tree().get_nodes_in_group("enemy")
	check(enemies.size() == gm.base_spawn, "Spawn batch count")
	var half = world.get_viewport().get_visible_rect().size * 0.5 / maxf(abs(world.get_viewport().get_camera_2d().global_scale.x), 0.01)
	for enemy in enemies:
		var offset = enemy.global_position - player.global_position
		check(abs(offset.x) > half.x or abs(offset.y) > half.y, "Enemy must begin outside camera view")
		check(offset.length() > 300.0, "Enemy must not spawn on player")
		check(enemy.hp == enemy.max_hp and enemy.hp > 30.0, "Enemy receives time-scaled HP")
		check(enemy.damage > 10.0 and enemy.move_speed > 80.0, "Enemy receives time-scaled damage/speed")

	# Boss trigger, stats, independent sprite, and giant collision body.
	gm.game_time = 60.0
	gm._process(0.0)
	var bosses = root.get_tree().get_nodes_in_group("boss")
	check(bosses.size() == 1, "Exactly one boss at minute one")
	var boss = bosses[0]
	check(boss.max_hp == 900.0 and boss.damage == 28.0, "Boss first-minute stats")
	var boss_texture = boss.get_node("AnimatedSprite2D").sprite_frames.get_frame_texture("run_right", 0)
	var boss_sprite_diameter = boss_texture.get_width() * boss.get_node("AnimatedSprite2D").global_scale.x
	var boss_collision_diameter = boss.get_node("CollisionShape2D").shape.radius * 2.0 * boss.get_node("CollisionShape2D").global_scale.x
	check(boss.scale == Vector2.ONE and boss_sprite_diameter >= 440.0 and boss_sprite_diameter <= 620.0, "Boss sprite is 3-4 times regular size")
	check(abs(boss_sprite_diameter - boss_collision_diameter) < 20.0, "Boss sprite and collider have matching size")
	check(gm.boss_bar.visible and gm.boss_bar.max_value == boss.max_hp, "Boss bar is visible and linked")
	check(boss.get_node("AnimatedSprite2D").sprite_frames != world.get_node("Player/AnimatedSprite2D").sprite_frames, "Boss has an independent sprite skin")
	player.set_physics_process(false)
	for enemy in root.get_tree().get_nodes_in_group("enemy"):
		if enemy != boss:
			enemy.set_physics_process(false)
	gm._process(0.0)
	check(root.get_tree().get_nodes_in_group("boss").size() == 1, "Boss does not duplicate in same minute")

	# Shift action and mobile button share the same dash method and invulnerability state.
	player.input_dir = Vector2.RIGHT
	player.last_dir = Vector2.RIGHT
	var blocker = load("res://enemy.tscn").instantiate()
	world.add_child(blocker)
	blocker.set_physics_process(false)
	blocker.global_position = player.global_position + Vector2(110, 0)
	var before = player.global_position
	player.dodge()
	await physics_frame
	check(player.is_invincible and player.dodge_time_left > 0.0 and player.collision_layer == 0 and player.collision_mask == 0 and player.dodge_collision_shape.disabled, "Dodge starts invulnerability and ghost collision")
	for frame in range(20):
		player._physics_process(0.016)
	check(player.global_position.x > blocker.global_position.x, "Dodge passes through enemy body")
	await create_timer(0.3).timeout
	check(not player.is_invincible and player.collision_layer == player.normal_collision_layer and not player.dodge_collision_shape.disabled, "Dodge invulnerability and ghost collision end")
	player.dodge_timer = 0.0
	gm.dodge_button.pressed.emit()
	check(player.is_invincible, "Mobile dodge button triggers same dodge")

	print("SYSTEM_TEST_RESULT checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
