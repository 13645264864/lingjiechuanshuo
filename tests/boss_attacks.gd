extends SceneTree

var checks := 0
var failures: Array[String] = []
var world
var player
var boss
var gm

func _initialize():
	run.call_deferred()

func check(condition: bool, message: String):
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func ticks(count: int):
	for index in range(count):
		await physics_frame
		await process_frame

func reset_fight(position: Vector2):
	for action in ["move_left", "move_right", "move_up", "move_down", "dodge"]:
		Input.action_release(action)
	for group in ["boss", "boss_attack", "boss_projectile"]:
		for node in get_nodes_in_group(group):
			node.queue_free()
	await ticks(2)
	player.set_physics_process(false)
	player.dodge_time_left = 0.0
	player.dodge_invulnerability_left = 0.0
	player.dodge_timer = 0.0
	player.end_dodge()
	player.position = position
	player.velocity = Vector2.ZERO
	player.hp = 50000.0
	player.fireball_timer = 5000.0
	gm.spawn_boss(1)
	boss = get_nodes_in_group("boss")[0]
	boss.position = Vector2.ZERO
	boss.set_physics_process(false)
	await ticks(2)

func wait_until_lock():
	for index in range(80):
		if boss.state == boss.State.LOCK:
			return
		await ticks(1)
	check(false, "Boss reaches locked aim")

func run():
	create_timer(60.0).timeout.connect(func(): quit(2))
	world = load("res://main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await ticks(2)
	player = world.get_node("Player")
	gm = world.get_node("GameManager")
	gm.set_process(false)
	gm.spawn_timer.stop()
	await reset_fight(Vector2(750, 0))
	boss.begin_dash_pattern()
	player.position = Vector2(750, 180)
	boss._physics_process(0.1)
	check(boss.dash_direction.y > 0.1, "Aim follows moving target during windup")
	check(boss.dash_range >= 950.0 and boss.dash_range <= 1100.0, "Dash reaches through distant player")
	boss.change_state(boss.State.LOCK)
	var locked_direction: Vector2 = boss.dash_direction
	player.position = Vector2(600, -200)
	boss._physics_process(0.08)
	check(boss.dash_direction.is_equal_approx(locked_direction), "Direction stops tracking during final lock")
	check(boss.aim_duration + boss.lock_duration >= 0.7, "Dash warning provides reaction time")

	# Full physics at normal speed: continuous running away must not outrun dash.
	await reset_fight(Vector2(700, 0))
	player.set_physics_process(true)
	Input.action_press("move_right")
	boss.begin_dash_pattern()
	boss.set_physics_process(true)
	var hp_before: float = player.hp
	await ticks(100)
	check(player.hp < hp_before, "Long dash hits a player who only runs straight away")
	check(boss.dash_travelled >= boss.dash_min_range, "Boss actually traverses at least 650 units")
	check(boss.dash_has_hit and player.hp >= hp_before - boss.damage, "Dash sweep applies once instead of repeated contact damage")
	Input.action_release("move_right")

	# Late perpendicular dodge: fixed lock gives a reliable defensive response.
	await reset_fight(Vector2(700, 0))
	boss.begin_dash_pattern()
	boss.set_physics_process(true)
	await wait_until_lock()
	player.set_physics_process(true)
	Input.action_press("move_down")
	Input.action_press("dodge")
	await ticks(1)
	Input.action_release("dodge")
	hp_before = player.hp
	await ticks(95)
	check(player.hp == hp_before, "Perpendicular dodge after lock evades full dash and follow-up")
	check(boss.state == boss.State.RECOVER, "Missed attack still commits to recovery")
	Input.action_release("move_down")

	# Low frame rate uses a capsule sweep, so fast dashes cannot tunnel through.
	await reset_fight(Vector2(700, 0))
	boss.begin_dash_pattern()
	boss.start_next_dash()
	hp_before = player.hp
	boss.advance_dash(0.7)
	check(player.hp < hp_before, "Large physics step still hits a player along dash path")

	# The follow-up slash uses an actual physics query and a fixed facing cone.
	await reset_fight(Vector2(360, 0))
	hp_before = player.hp
	boss.spawn_zone("slash", Vector2.ZERO, 430.0, 20.0, 0.1, Vector2.RIGHT)
	await ticks(10)
	check(player.hp == hp_before - 20.0, "Stationary target in slash cone takes damage")
	await ticks(10)
	check(player.hp == hp_before - 20.0, "Slash cannot damage every frame")
	await reset_fight(Vector2(-360, 0))
	hp_before = player.hp
	boss.spawn_zone("slash", Vector2.ZERO, 430.0, 20.0, 0.1, Vector2.RIGHT)
	await ticks(12)
	check(player.hp == hp_before, "Behind the committed slash remains a safe counterattack position")

	await reset_fight(Vector2(650, 0))
	boss.launch_swords()
	var swords := get_nodes_in_group("boss_projectile")
	check(swords.size() == 3, "First phase launches three homing swords")
	var sword = swords[0]
	var old_angle: float = sword.velocity.angle()
	player.position = Vector2(650, 100)
	await ticks(3)
	check(absf(angle_difference(old_angle, sword.velocity.angle())) > 0.01, "Spirit swords turn toward target")
	check(absf(angle_difference(old_angle, sword.velocity.angle())) <= sword.turn_speed * 0.08, "Sword turning is bounded")
	await ticks(65)
	if is_instance_valid(sword):
		check(sword.homing_time == 0.0, "Sword tracking expires")
		var final_direction: Vector2 = sword.velocity.normalized()
		player.position = Vector2(-650, -200)
		await ticks(3)
		if is_instance_valid(sword):
			check(sword.velocity.normalized().is_equal_approx(final_direction), "Sword cannot turn indefinitely after tracking ends")

	await reset_fight(Vector2(600, 0))
	hp_before = player.hp
	boss.launch_swords()
	await ticks(110)
	check(player.hp < hp_before, "Homing swords actually collide and damage a stationary target")

	await reset_fight(Vector2(600, 0))
	player.velocity = Vector2(180, 0)
	boss.launch_rain()
	var marks := get_nodes_in_group("boss_attack")
	check(marks.size() == 3, "Sword rain marks current and predicted positions")
	var first_position: Vector2 = marks[0].position
	check(marks[1].position.x > first_position.x, "Sword rain anticipates running direction")
	player.position += Vector2(0, 280)
	hp_before = player.hp
	await ticks(70)
	check(player.hp == hp_before, "Changing direction escapes committed sword rain positions")
	await reset_fight(Vector2(600, 0))
	hp_before = player.hp
	boss.launch_rain()
	await ticks(70)
	check(player.hp < hp_before, "Standing inside rain mark takes damage")

	await reset_fight(Vector2(600, 0))
	boss.spawn_zone("mark", player.position, 120.0, 20.0, 0.06)
	player.last_dir = Vector2.DOWN
	player.dodge()
	hp_before = player.hp
	await ticks(10)
	check(player.hp == hp_before, "Dodge invulnerability rejects sword rain hit")

	# A genuine player fireball lands while boss is committed to recovery.
	await reset_fight(Vector2(190, 0))
	boss.change_state(boss.State.RECOVER)
	boss.set_physics_process(true)
	player.target_enemy = boss
	var boss_hp_before: float = boss.hp
	player.shoot_fireball()
	await ticks(20)
	check(boss.hp < boss_hp_before, "Player can land a real counterattack during recovery")
	check(boss.state == boss.State.RECOVER, "Recovery stays open for at least 0.75 seconds")

	await reset_fight(Vector2(600, 0))
	boss.launch_rain()
	boss.launch_swords()
	boss.take_damage(boss.hp)
	await ticks(2)
	check(get_nodes_in_group("boss_attack").is_empty() and get_nodes_in_group("boss_projectile").is_empty(), "Boss death cancels pending damaging attacks")
	print("BOSS_ATTACK_TEST_RESULT checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
