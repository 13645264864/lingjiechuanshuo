extends SceneTree

var failures: Array[String] = []
var checks: int = 0
var world
var gm
var player
const FIREBALL = preload("res://fireball.tscn")
const ENEMY = preload("res://enemy.tscn")
const SPLIT_COUNTS = [2, 3, 6, 12]
const SPEED_MULTS = [1.6, 2.4, 4.8, 9.6]
const HIT_COUNTS = [3, 5, 9, 18]
const CRIT_RATES = [0.05, 0.10, 0.20, 0.40]
const CRIT_MULTS = [2.05, 2.10, 2.20, 2.40]
const QUALITY_MULTS = [2, 3, 6, 10]

func _initialize():
	run.call_deferred()

func check(condition: bool, message: String):
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func buff(kind: int, quality: int) -> Dictionary:
	return {"type": kind, "lv": quality + 1, "mult": QUALITY_MULTS[quality],
		"name": ["分裂", "高速", "穿透", "巨型火球"][kind]}

func choose(kind: int, quality: int, button_index: int = 0):
	gm.temp_candidates = [buff(0, 0), buff(0, 0), buff(0, 0)]
	gm.temp_candidates[button_index] = buff(kind, quality)
	gm.buff_panel.visible = true
	gm.game_over = true
	gm.buff_buttons[button_index].pressed.emit()
	check(gm.player_buffs.has(kind), "Button must store selected skill")
	check(not gm.buff_panel.visible and not gm.game_over, "Choosing must close the panel")

func spawn_enemy(pos: Vector2):
	var enemy = ENEMY.instantiate()
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.scale = Vector2.ONE
	enemy.global_position = pos
	enemy.hp = 1000.0
	return enemy

func shoot(target):
	player.target_enemy = target
	player.shoot_fireball()
	return world.get_children().back()

func projectiles() -> Array:
	var result: Array = []
	for child in world.get_children():
		if child.get_script() == preload("res://fireball.gd"):
			result.append(child)
	return result

func clear_combat():
	for child in world.get_children():
		if child.get_script() == preload("res://fireball.gd") or child.is_in_group("enemy"):
			child.queue_free()
	await process_frame

func run():
	# Even a failed test must terminate rather than leave Godot running forever.
	create_timer(45.0).timeout.connect(func(): quit(2))
	world = load("res://main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	gm = world.get_node("GameManager")
	player = world.get_node("Player")
	player.set_physics_process(false)
	gm.set_process(false)
	gm.rebuild_buff_buttons()
	var target = spawn_enemy(Vector2(400, 0))
	var baseline = shoot(target)
	check(baseline.speed == 80.0 and baseline.max_penetrate == 1,
		"Unmodified projectile must keep its base stats")
	check(baseline.scale == Vector2.ONE and baseline.anim.is_playing(), "Base animation must play")
	baseline.queue_free()
	await process_frame

	# Actual button signal -> selected dictionary -> player -> projectile, for all 16 choices.
	for kind in range(4):
		for quality in range(4):
			gm.player_buffs.clear()
			choose(kind, quality, (kind + quality) % 3)
			var shot = shoot(target)
			match kind:
				0:
					check(shot.enable_split and shot.split_count == SPLIT_COUNTS[quality], "Split quality")
				1:
					check(is_equal_approx(shot.speed, 80.0 * SPEED_MULTS[quality]), "Speed quality")
				2:
					check(shot.max_penetrate == HIT_COUNTS[quality], "Penetration quality")
				3:
					check(shot.enable_huge and shot.scale.is_equal_approx(Vector2.ONE * 1.8), "Giant visual scale")
					check(is_equal_approx(shot.crit_rate, CRIT_RATES[quality]), "Critical probability")
					check(is_equal_approx(shot.crit_mult, CRIT_MULTS[quality]), "Critical damage")
					var shape = shot.get_node("CollisionShape2D")
					check(shape.global_scale.is_equal_approx(Vector2.ONE * 1.8), "Giant collision scale")
			shot.queue_free()
			await process_frame
	await clear_combat()
	print("PASS: all buttons and 16 buff qualities reach the real player projectile")

	# Real physics: speed buff changes distance traveled in the same time.
	gm.player_buffs.clear()
	target = spawn_enemy(Vector2(400, 0))
	target.collision_layer = 0
	var slow = shoot(target)
	choose(1, 1)
	var fast = shoot(target)
	for i in range(24):
		await physics_frame
	check(is_instance_valid(fast) and is_instance_valid(slow), "Movement projectiles must still exist")
	if is_instance_valid(fast) and is_instance_valid(slow):
		print("MOVEMENT_END slow=", slow.position, " fast=", fast.position)
		check(fast.position.x > slow.position.x * 2.2, "Speed must alter movement, not just a stored number")
	await clear_combat()

	# Real body_entered signals: baseline stops after one enemy; penetration damages three.
	for penetrate in [false, true]:
		gm.player_buffs = {1: buff(1, 1)}
		if penetrate:
			choose(2, 0)
		var targets: Array = []
		for x in [90, 160, 230]:
			targets.append(spawn_enemy(Vector2(x, 0)))
		var shot = shoot(targets[0])
		await create_timer(1.5).timeout
		check(is_equal_approx(targets[0].hp, 990), "First enemy must take damage")
		for i in [1, 2]:
			check(is_equal_approx(targets[i].hp, 990 if penetrate else 1000), "Real penetration hit limit")
		check(not is_instance_valid(shot), "Projectile must disappear after its hit limit")
		await clear_combat()
	print("PASS: real movement and penetration collisions")

	# Real collision spawns children; children inherit all other buffs and cannot split recursively.
	gm.player_buffs.clear()
	for kind in range(4):
		choose(kind, 1)
	target = spawn_enemy(Vector2(90, 0))
	var primary = shoot(target)
	primary.crit_rate = 0.0
	await create_timer(0.7).timeout
	var secondary_count = 0
	for shot in projectiles():
		if not shot.is_secondary:
			continue
		secondary_count += 1
		check(not shot.enable_split, "Secondary must not split recursively")
		check(is_equal_approx(shot.speed, 192) and shot.max_penetrate == 5, "Secondary inherits speed/penetration")
		check(shot.enable_huge and shot.scale.is_equal_approx(Vector2.ONE * 1.8), "Secondary inherits giant buff")
		check(shot.hit_enemy_list.has(target), "Secondary must not immediately re-hit source enemy")
	check(secondary_count == 3, "Split must spawn exactly three secondary projectiles")
	check(primary.penetrate_count == 1 and target.hp == 990, "Source hit must deal damage once")
	await clear_combat()
	print("PASS: actual collision splitting and combined buffs")

	# Split alone queues the parent for deletion in the collision frame. Children must survive it.
	gm.player_buffs = {1: buff(1, 1)}
	choose(0, 0)
	target = spawn_enemy(Vector2(90, 0))
	var split_only = shoot(target)
	await create_timer(0.7).timeout
	check(not is_instance_valid(split_only), "Split-only primary must stop after one hit")
	check(projectiles().size() == 2, "Deferred children must survive parent deletion")
	var child = projectiles().front()
	var next_target = spawn_enemy(child.global_position + child.dir * 40)
	await create_timer(0.4).timeout
	check(next_target.hp < 1000, "Secondary projectile must actually damage another enemy")
	await clear_combat()
	print("PASS: split-only parent cleanup and secondary damage")

	# Force each RNG branch, keeping the real damage path and collision callback.
	gm.player_buffs = {1: buff(1, 1), 3: buff(3, 3)}
	target = spawn_enemy(Vector2(90, 0))
	var critical = shoot(target)
	critical.crit_rate = 1.0
	await create_timer(0.7).timeout
	check(is_equal_approx(target.hp, 976), "Critical must apply 10 * 2.4 damage")
	await clear_combat()
	gm.player_buffs = {1: buff(1, 1), 3: buff(3, 3)}
	target = spawn_enemy(Vector2(90, 0))
	var regular = shoot(target)
	regular.crit_rate = 0.0
	await create_timer(0.7).timeout
	check(is_equal_approx(target.hp, 990), "Non-critical giant must apply normal damage")
	await clear_combat()
	print("PASS: real critical/noncritical damage")

	# Exercise the normal start/breakthrough UI and automatic targeting/firing.
	gm.player_buffs.clear()
	gm.start_btn.pressed.emit()
	gm.spawn_timer.stop()
	check(gm.game_started and gm.buff_panel.visible, "Start must open initial skill choice")
	choose(3, 0)
	player.add_aura(player.need_aura)
	check(player.realm == 2 and gm.buff_panel.visible, "Breakthrough must open skill choice")
	choose(1, 1)
	target = spawn_enemy(Vector2(300, 0))
	target.collision_layer = 0
	player.fireball_timer = 0.0
	player.set_physics_process(true)
	for i in range(3):
		await physics_frame
	player.set_physics_process(false)
	check(not projectiles().is_empty(), "Normal physics loop must automatically fire")
	for shot in projectiles():
		check(is_equal_approx(shot.speed, 192) and shot.enable_huge, "Automatic fire must combine selected buffs")
	await clear_combat()
	print("PASS: start, breakthrough, auto targeting and shooting")

	# Capture both rendered states when launched with -- --capture on a graphics backend.
	if "--capture" in OS.get_cmdline_user_args():
		gm.player_buffs.clear()
		target = spawn_enemy(Vector2(300, 0))
		target.collision_layer = 0
		var original = shoot(target)
		original.set_physics_process(false)
		original.global_position = Vector2(-100, 0)
		choose(3, 0)
		var giant = shoot(target)
		giant.set_physics_process(false)
		giant.global_position = Vector2(100, 0)
		await RenderingServer.frame_post_draw
		var image = root.get_texture().get_image()
		image.save_png("res://.godot/buff-visual-check.png")
		await clear_combat()

	# Fireballs are owned by the current scene and must be cleared on restart.
	gm.player_buffs = {0: buff(0, 1), 1: buff(1, 1)}
	target = spawn_enemy(Vector2(400, 0))
	var old_projectile = shoot(target)
	gm.restart_btn.pressed.emit()
	await process_frame
	await process_frame
	check(not is_instance_valid(old_projectile), "Restart must remove previous projectiles")
	check(current_scene.get_node("GameManager").player_buffs.is_empty(), "Restart must reset selected skills")
	current_scene.queue_free()
	await process_frame
	print("BUFF_TEST_RESULT checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
