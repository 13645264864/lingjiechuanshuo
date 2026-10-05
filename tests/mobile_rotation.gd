extends SceneTree

var failures: Array[String] = []
var checks := 0
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

func resize_phone(dimensions: Vector2i):
	root.size = dimensions
	if capture_enabled: DisplayServer.window_set_size(dimensions)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.get_node("MobileDisplay").adapt_orientation()
	await ticks(5)

func capture(name: String):
	if not capture_enabled: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/" + name + ".png")

func run():
	create_timer(25).timeout.connect(func(): quit(2))
	capture_enabled = "--capture" in OS.get_cmdline_user_args()
	var menu = load("res://main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for dimensions in [Vector2i(1280,720), Vector2i(480,800), Vector2i(800,480)]:
		await resize_phone(dimensions)
		var expected := Vector2i(648,1152) if dimensions.x < dimensions.y else Vector2i(1152,648)
		check(root.content_scale_size == expected, "Rotation selects correct logical canvas " + str(dimensions))
		check(menu.start_button.get_global_rect().get_center().is_equal_approx(root.get_visible_rect().get_center()), "Scaled menu button stays centered " + str(dimensions))
		check(root.get_visible_rect().encloses(menu.start_button.get_global_rect()), "Menu button fits rotated display")
		await capture("phone-menu-"+str(dimensions.x))
	menu.start_button.pressed.emit()
	await ticks(5)
	var world = current_scene
	var gm = world.get_node("GameManager")
	for dimensions in [Vector2i(480,800),Vector2i(1280,720)]:
		await resize_phone(dimensions)
		gm.layout_controls()
		var viewport := root.get_visible_rect()
		for button in gm.buff_buttons:
			check(viewport.encloses(button.get_global_rect()), "Scaled upgrade choices fit rotated screen")
		check(gm.equipped_skill_label.text.contains("火球术（凡品）"), "Equipped technique is visible in rotated upgrade screen")
		check(gm.equipped_skill_label.get_global_rect().end.y < gm.buff_buttons[0].get_global_rect().position.y, "Technique title stays above cards after rotation")
		check(viewport.encloses(gm.dodge_button.get_global_rect()), "Scaled dodge button fits rotated screen")
		check(viewport.encloses(gm.sword_button.get_global_rect()), "Scaled sword button fits rotated screen")
		check(viewport.encloses(world.get_node("FirstLevelMap").minimap.get_global_rect()), "Scaled minimap fits rotated screen")
		check(not gm.dodge_button.get_global_rect().intersects(gm.sword_button.get_global_rect()), "Action buttons stay separated after rotation")
		await capture("phone-choices-"+str(dimensions.x))
	print("MOBILE_ROTATION_TEST_RESULT checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
