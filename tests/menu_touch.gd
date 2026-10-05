extends SceneTree

var checks := 0
var failures: Array[String] = []
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

func touch(index: int, point: Vector2, pressed: bool):
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	root.push_input(event, true)

func drag(index: int, point: Vector2):
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	root.push_input(event, true)

func resize_window(dimensions: Vector2i):
	root.size = dimensions
	if capture_enabled: DisplayServer.window_set_size(dimensions)
	await ticks(3)

func capture(name: String):
	if not capture_enabled: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/" + name + ".png")

func run():
	create_timer(30).timeout.connect(func(): quit(2))
	capture_enabled = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1152, 648)
	var menu = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(menu)
	current_scene = menu
	await ticks(3)
	check(menu.name == "MainMenu", "Default startup is main menu")
	check(menu.get_children().filter(func(child): return child is Button).size() == 1, "Menu has only start button")
	check(root.get_visible_rect().encloses(menu.start_button.get_global_rect()), "Start button fits screen")
	check(menu.start_button.get_global_rect().get_center().is_equal_approx(root.get_visible_rect().get_center()), "Start button is centered in landscape")
	check(ProjectSettings.get_setting("display/window/handheld/orientation") == DisplayServer.SCREEN_SENSOR, "Android orientation follows device rotation")
	await capture("main-menu")
	await resize_window(Vector2i(480, 800))
	check(menu.start_button.get_global_rect().get_center().is_equal_approx(root.get_visible_rect().get_center()), "Start button stays centered in portrait")
	await capture("main-menu-portrait")
	await resize_window(Vector2i(1152, 648))
	menu.start_button.pressed.emit()
	await ticks(4)
	check(current_scene.has_node("FirstLevelMap"), "Start enters first level")
	var world = current_scene
	var gm = world.get_node("GameManager")
	var player = world.get_node("Player")
	check(gm.game_started and gm.buff_panel.visible and paused and not gm.start_btn.visible, "Menu click starts level without second start screen")
	gm.buff_buttons[0].pressed.emit()
	await ticks(3)
	for enemy in get_nodes_in_group("enemy"):
		enemy.set_physics_process(false)
	player.fireball_timer = 10000
	var joystick = gm.touch_joystick
	var center := Vector2(230, 400)
	var before: Vector2 = player.position
	check(not joystick.visible, "Floating joystick is hidden until a touch starts")
	touch(0, center, true)
	check(joystick.get_global_rect().get_center().is_equal_approx(center), "Joystick appears at first finger position")
	check(gm.touch_move == Vector2.ZERO, "Initial touch establishes neutral origin")
	drag(0, center + Vector2(55, 4))
	await ticks(10)
	check(gm.touch_move.x > 0.7 and joystick.touch_index == 0, "Touch joystick owns movement finger")
	check(player.position.x > before.x + 10, "Joystick moves player through actual physics")
	check(player.anim.animation == &"run_right", "Mostly horizontal touch with vertical noise uses right animation")
	# Second finger can use the existing dodge button while first stays down.
	touch(1, gm.dodge_button.get_global_rect().get_center(), true)
	touch(1, gm.dodge_button.get_global_rect().get_center(), false)
	await ticks(2)
	check(player.dodge_time_left > 0 and player.dodge_direction.x > 0.8, "Dodge follows joystick heading")
	check(joystick.touch_index == 0, "Action button does not cancel movement finger")
	touch(1, center + Vector2(0, -50), true)
	touch(1, center + Vector2(0, -50), false)
	check(joystick.touch_index == 0, "Extra touch cannot steal movement finger")
	touch(0, center, false)
	await ticks(2)
	check(gm.touch_move == Vector2.ZERO and joystick.touch_index == -1 and not joystick.visible, "Finger release stops movement and hides joystick")
	await ticks(25)
	for sample in [[Vector2(-55, 6), &"run_left"], [Vector2(6, -55), &"run_up"], [Vector2(-6, 55), &"run_down"]]:
		var new_origin := Vector2(350, 400)
		touch(0, new_origin, true)
		check(joystick.origin == new_origin, "New gesture uses new floating origin")
		drag(0, new_origin + sample[0])
		await ticks(3)
		check(player.anim.animation == sample[1], "Joystick selects directional animation " + str(sample[1]))
		touch(0, new_origin, false)
		await ticks(2)
	touch(0, center, true)
	drag(0, center + Vector2(-55, 0))
	await ticks(3)
	gm.show_buff_choose()
	await ticks(2)
	check(gm.touch_move == Vector2.ZERO, "Upgrade pause releases held joystick")
	gm.buff_buttons[0].pressed.emit()
	await ticks(2)
	touch(0, center, true)
	drag(0, center + Vector2(55, 4))
	await ticks(3)
	await capture("mobile-controls")
	await resize_window(Vector2i(480, 800))
	check(gm.touch_move == Vector2.ZERO and joystick.touch_index == -1 and not joystick.visible, "Rotation clears active touch so movement cannot stick")
	check(root.get_visible_rect().encloses(gm.dodge_button.get_global_rect()), "Dodge button follows portrait layout")
	check(root.get_visible_rect().encloses(world.get_node("FirstLevelMap").minimap.get_global_rect()), "Minimap follows portrait layout")
	var portrait_origin := Vector2(130, 580)
	touch(0, portrait_origin, true)
	drag(0, portrait_origin + Vector2(-50, 3))
	await ticks(3)
	check(player.anim.animation == &"run_left", "Left animation still works after rotating to portrait")
	await capture("floating-controls-portrait")
	touch(0, portrait_origin, false)
	await resize_window(Vector2i(1152, 648))
	touch(0, Vector2(950, 400), true)
	check(joystick.touch_index == -1, "Right-hand action zone does not start joystick")
	touch(0, Vector2(950, 400), false)
	check(gm.touch_move == Vector2.ZERO, "Control cleanup resets touch state")
	print("MENU_TOUCH_TEST_RESULT checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
