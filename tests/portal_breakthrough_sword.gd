extends SceneTree

const END_MESSAGE := "感谢游戏，内测版流程已结束，后续流程持续更新中"
var checks := 0
var failures: Array[String] = []
var world
var map
var player
var gm
var dummy
var capture_enabled := false

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

func finish_choices():
	for index in range(12):
		if not gm.buff_panel.visible: break
		gm.buff_buttons[0].pressed.emit()
		await process_frame

func snapshot(name: String):
	if not capture_enabled: return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(not image.is_empty(), "Rendered " + name)
	image.save_png("res://.godot/" + name + ".png")

func click(button: Button):
	var center := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = center
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func run():
	create_timer(60.0).timeout.connect(func(): quit(2))
	capture_enabled = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1152, 648)
	world = load("res://first_level.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await ticks(4)
	map = world.get_node("FirstLevelMap")
	player = world.get_node("Player")
	gm = world.get_node("GameManager")
	player.set_physics_process(false)
	player.hp = 5000
	gm.game_started = true
	gm.start_btn.hide()
	gm.spawn_timer.stop()
	gm.set_process(false)
	map.set_physics_process(false)
	var camera = world.get_node("Camera2D")
	camera.set_process(false)
	camera.position = player.position
	camera.zoom = Vector2.ONE * 0.8
	player.add_aura(player.need_aura)
	check(player.realm == 2 and paused and gm.buff_panel.visible, "Breakthrough triggers real upgrade selection")
	var effects := get_nodes_in_group("breakthrough_fx")
	check(effects.size() == 1, "Breakthrough creates one gold effect")
	var effect = effects[0]
	check(effect.announcement.text == "突破了！" and effect.can_process(), "Large breakthrough notice processes during pause")
	check(effect.gold.texture != null and effect.gold.material != null, "Gold overlay copies whole player sprite")
	var old_age: float = effect.age
	await ticks(10)
	check(effect.age > old_age and paused, "Breakthrough animation advances under upgrade pause")
	await snapshot("breakthrough-feedback")
	await ticks(105)
	check(get_nodes_in_group("breakthrough_fx").is_empty(), "Gold effect and announcement expire while paused")
	await finish_choices()
	check(not paused, "Upgrade selection still resumes combat")
	# Multiple breakthroughs refresh the effect rather than leaving overlapping text.
	player.add_aura(player.need_aura * 3.0)
	await ticks(2)
	check(get_nodes_in_group("breakthrough_fx").size() == 1, "Multiple realm increases have one refreshed effect")
	await finish_choices()
	await ticks(100)
	check(get_nodes_in_group("breakthrough_fx").is_empty(), "Refreshed effects clean up")

	# Establish a cleared final room without replaying the already-covered stage.
	for room in map.rooms:
		room.entered = true
		room.cleared = true
	for link in map.links:
		link.gate.set_sealed(false)
		link.arrival_gate.set_sealed(false)
	map.active_room = -1
	map.current_room = 6
	var arena: Rect2 = map.rooms[-1].bounds
	player.position = arena.get_center() + Vector2(500, 200)
	camera.position = arena.get_center()
	camera.zoom = Vector2.ONE * 0.5
	map.spawn_portal()
	check(get_nodes_in_group("altar_portal").size() == 1 and not map.portal.active, "Boss reward altar initially has inactive blue portal")
	check(map.portal.position.is_equal_approx(map.get_node("BossRelic").global_position), "Blue effect stays on grounded circular altar")
	player.position = map.portal.position
	await ticks(3)
	check(not gm.ending_in_progress, "Uncollected sword prevents portal transition")
	player.position = arena.get_center() + Vector2(500, 200)
	player.unlock_sword_form()
	await finish_choices()
	check(map.completed and map.portal.active and not paused, "Sword reward activates exit without a blocking completion modal")
	dummy = map.training_dummy
	check(is_instance_valid(dummy), "Practice dummy retained after reward")
	await snapshot("blue-altar-portal")
	gm.sword_buffs.clear()
	player.position = dummy.position + Vector2(820, 0)
	player.input_dir = Vector2.ZERO
	player.last_dir = Vector2.LEFT
	player.fireball_timer = 10000
	player.set_physics_process(true)
	gm.sword_button.pressed.emit()
	var form = player.sword_visual
	var start_position: Vector2 = player.position
	var hp_before: float = player.hp
	var hits_before: int = dummy.hit_count
	var blinks_before: int = form.blink_count
	var waves_before: int = form.wave_count
	var slashes_before: int = form.slash_count
	await ticks(22)
	check(form.blink_count > blinks_before and player.position.distance_to(start_position) > 400, "No movement input needed for long auto blink")
	check(player.position.distance_to(dummy.position) < 300 and form.target_enemy == dummy, "Auto pursuit reaches practice target")
	check(form.wave_count > waves_before, "Base form automatically releases sword wave without upgrades")
	check(form.slash_count > slashes_before and dummy.hit_count > hits_before, "Auto blink/strike causes actual target damage")
	check(player.hp == hp_before, "Automatic movement preserves player HP")
	await snapshot("sword-auto-pursuit")
	# Reposition target to validate continuous pursuit and cooldown-limited blinking.
	dummy.position -= Vector2(0, 650)
	var distance_before: float = player.position.distance_to(dummy.position)
	await ticks(35)
	check(player.position.distance_to(dummy.position) < distance_before, "Moving enemy is followed automatically")
	check(form.blink_count == blinks_before + 1, "Blink cooldown prevents repeated teleport spam")
	await ticks(115)
	dummy.position = player.position - Vector2(650, 0)
	await ticks(3)
	check(form.blink_count > blinks_before + 1, "Blink retriggers after 2.5 second interval against distant target")
	check(form.wave_count >= waves_before + 2 and form.slash_count >= slashes_before + 2, "All three autonomous attacks repeat")
	player.set_physics_process(false)
	var flash_origin: Vector2 = player.position
	var invalid_position: Vector2 = map.rooms[0].bounds.get_center()
	check(not map.safe_sword_position(invalid_position), "Flash cannot cross into another room")
	check(not map.safe_sword_position(map.portal.position), "Flash cannot land in altar trigger circle")
	# A real physical blocker prohibits teleport and selects no through-wall target.
	var wall := StaticBody2D.new()
	wall.collision_layer = 4
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(500, 40)
	collider.shape = shape
	wall.add_child(collider)
	wall.position = player.position + Vector2(0, -200)
	world.add_child(wall)
	dummy.position = player.position + Vector2(0, -450)
	await ticks(2)
	check(not form.has_line_of_sight(dummy), "Wall hides targets from sword auto-selection")
	check(not form.blink_to_target(dummy) and player.position == flash_origin, "Flash cannot pass through a wall")
	wall.queue_free()
	await ticks(2)
	# Direction input has priority over automatic pursuit.
	player.set_physics_process(true)
	form.blink_timer = 0
	Input.action_press("move_right")
	var before_manual: Vector2 = player.position
	var blink_before_manual: int = form.blink_count
	await ticks(10)
	Input.action_release("move_right")
	check(player.position.x > before_manual.x and form.blink_count == blink_before_manual, "Manual movement temporarily overrides blink pursuit")
	player.set_physics_process(false)
	# Portal blocks auto movement and requires exiting before normal re-entry.
	player.position = map.portal.position
	await ticks(3)
	check(not gm.ending_in_progress and map.portal.blocked_until_exit, "Transformed/automatic movement cannot accidentally exit level")
	player.end_sword_form()
	form.auto_guard_left = 0
	await ticks(3)
	check(not gm.ending_in_progress, "Form ending inside portal cannot instantly transport")
	player.position = map.portal.position + Vector2(220, 0)
	await ticks(3)
	check(not map.portal.blocked_until_exit, "Leaving trigger re-arms portal")
	player.position = map.portal.position
	await ticks(2)
	check(gm.ending_in_progress and gm.run_ended and paused, "Normal re-entry triggers terminal transition once")
	check(gm.beta_end_screen.visible and not gm.beta_end_screen.ending_revealed, "Exit starts with gradual blackout before text")
	await ticks(65)
	check(gm.beta_end_screen.color.a == 1.0 and gm.beta_end_screen.ending_revealed, "Black screen reveal finishes while game paused")
	check(not world.get_node("UI").visible and not map.minimap.visible, "Terminal screen removes combat HUD")
	check(gm.beta_end_screen.message_label.text.replace("\n", "") == END_MESSAGE, "Beta ending preserves requested exact message")
	check(not gm.beta_end_screen.replay_button.disabled and gm.beta_end_screen.replay_button.text == "重玩", "Replay button works while paused")
	gm.show_buff_choose()
	check(not gm.buff_panel.visible, "Late upgrade cannot cover terminal ending")
	await snapshot("beta-ending-desktop")
	root.size = Vector2i(480, 800)
	if capture_enabled: DisplayServer.window_set_size(Vector2i(480, 800))
	await ticks(4)
	check(root.get_visible_rect().encloses(gm.beta_end_screen.content.get_global_rect()), "Ending message and replay fit mobile viewport")
	await snapshot("beta-ending-mobile")
	var old_world = world
	await click(gm.beta_end_screen.replay_button)
	await ticks(3)
	check(current_scene != old_world and not paused, "Actual replay click reloads first level and unpauses")
	check(not current_scene.get_node("Player").sword_unlocked and not current_scene.get_node("GameManager").ending_in_progress, "Replay clears sword/portal terminal state")
	check(get_nodes_in_group("altar_portal").is_empty(), "Replay removes old blue portal")
	print("PORTAL_SWORD_TEST_RESULT checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
