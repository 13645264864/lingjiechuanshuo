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
	check(boss.scale.x > 8.0 and boss.get_node("CollisionShape2D").shape.radius == 13.0, "Boss is substantially larger")
	check(gm.boss_bar.visible and gm.boss_bar.max_value == boss.max_hp, "Boss bar is visible and linked")
	check(boss.get_node("AnimatedSprite2D").sprite_frames != world.get_node("Player/AnimatedSprite2D").sprite_frames, "Boss has an independent sprite skin")
	gm._process(0.0)
	check(root.get_tree().get_nodes_in_group("boss").size() == 1, "Boss does not duplicate in same minute")

	# Shift action and mobile button share the same dash method and invulnerability state.
	player.input_dir = Vector2.RIGHT
	player.last_dir = Vector2.RIGHT
	var before = player.global_position
	player.dodge()
	check(player.is_invincible and player.dodge_time_left > 0.0, "Dodge starts invulnerability")
	player._physics_process(0.1)
	check(player.global_position.x > before.x, "Dodge moves in current direction")
	await create_timer(0.3).timeout
	check(not player.is_invincible, "Dodge invulnerability ends")
	player.dodge_timer = 0.0
	gm.dodge_button.pressed.emit()
	check(player.is_invincible, "Mobile dodge button triggers same dodge")

	print("SYSTEM_TEST_RESULT checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
