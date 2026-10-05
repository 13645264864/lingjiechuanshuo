extends SceneTree

const FIREBALL = preload("res://fireball.tscn")
var failures: Array[String] = []
var checks := 0
var world
var player
var gm
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
	for index in range(count):
		await physics_frame
		await process_frame

func shots() -> Array:
	return world.get_children().filter(func(node): return node.get_script() == preload("res://fireball.gd"))

func clear_shots():
	for shot in shots(): shot.queue_free()
	await ticks(2)
	check(get_nodes_in_group("fireball_trail").is_empty(), "Removed procedural trail never creates nodes")

func capture():
	if not capture_enabled: return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(not image.is_empty(), "Rendered FB00 fireball view is nonempty")
	captures.append(image)

func launch(config: Dictionary, direction := Vector2.RIGHT):
	var main = FIREBALL.instantiate()
	main.setup(Vector2(-180, 0), direction, false, config)
	world.add_child(main)
	main.spawn_split_fireballs()
	return main

func run():
	create_timer(40.0).timeout.connect(func(): quit(2))
	capture_enabled = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1152, 648)
	world = load("res://main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await ticks(2)
	player = world.get_node("Player")
	player.set_physics_process(false)
	player.position = Vector2(-180, 0)
	gm = world.get_node("GameManager")
	gm.set_process(false)
	gm.start_btn.hide()
	gm.spawn_timer.stop()
	gm.dodge_button.hide()
	world.get_node("UI").hide()
	var camera = world.get_node("Camera2D")
	camera.set_process(false)
	camera.position = Vector2(30, 0)
	camera.zoom = Vector2(1.5, 1.5)
	var probe = launch({"speed_mult": 2.4})
	var frames: SpriteFrames = probe.anim.sprite_frames
	check(frames.get_frame_count("Fireball") == 5, "FB00 animation uses all five supplied frames")
	check(is_equal_approx(frames.get_animation_speed("Fireball"), 12.0), "FB00 animation has deliberate playback speed")
	for index in range(5):
		var texture: Texture2D = frames.get_frame_texture("Fireball", index)
		check(texture.get_size() == Vector2(64, 32), "FB00 frame has original 64x32 size " + str(index + 1))
		if index > 0:
			check(texture.get_image().get_data() != frames.get_frame_texture("Fireball", index - 1).get_image().get_data(), "FB00 frames are visually distinct")
	check(probe.anim.is_playing() and probe.anim.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "FB00 pixel animation plays with nearest filtering")
	check(get_nodes_in_group("fireball_trail").is_empty(), "Old generated flame tail is absent")
	probe.queue_free()
	await ticks(2)
	for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		var shot = launch({"speed_mult": 2.4}, direction)
		check(is_equal_approx(angle_difference(shot.anim.rotation, direction.angle()), 0.0), "Sprite rotates to actual flight direction " + str(direction))
		await ticks(8)
		check(shot.anim.frame != 0, "Five-frame animation advances while moving")
		shot.queue_free()
		await ticks(2)
	for count in [2, 3, 6, 12]:
		var main = launch({"split_count": count, "speed_mult": 2.4})
		check(shots().size() == count + 1, "Split count is preserved " + str(count))
		var directions: Array[Vector2] = [main.dir]
		for child in shots():
			if child == main: continue
			check(child.global_position.distance_to(main.global_position) >= 45.0, "Secondary starts separately")
			for existing in directions:
				check(absf(existing.angle_to(child.dir)) > deg_to_rad(10.0), "Split directions remain visibly separated")
			directions.append(child.dir)
			check(is_equal_approx(angle_difference(child.anim.rotation, child.dir.angle()), 0.0), "Every split FB00 animation faces its own direction")
			check(child.is_secondary and not child.enable_split and child.speed == main.speed, "Spread inherits config without recursive split")
		await ticks(35)
		check(get_nodes_in_group("fireball_trail").is_empty(), "Split volley has no added trail effects")
		await capture()
		await clear_shots()
	camera.zoom = Vector2(0.85, 0.85)
	launch({"split_count": 12, "speed_mult": 2.4, "enable_huge": true, "scale_mult": 4.2, "penetrate_count": 5})
	for shot in shots():
		check(shot.scale.is_equal_approx(Vector2.ONE * 4.2) and shot.max_penetrate == 5, "FB00 volley preserves giant collision and penetration")
	await ticks(25)
	await capture()
	await clear_shots()
	var enemy = load("res://enemy.tscn").instantiate()
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.scale = Vector2.ONE
	enemy.position = Vector2(0, 0)
	enemy.hp = 1000.0
	await ticks(2)
	var hit_shot = launch({"speed_mult": 4.8})
	await ticks(30)
	check(enemy.hp == 990.0 and not is_instance_valid(hit_shot), "New animation does not change collision damage")
	check(get_nodes_in_group("fireball_trail").is_empty(), "Impact leaves no detached generated trail")
	if capture_enabled and captures.size() == 5:
		var montage := Image.create(2304, 1944, false, Image.FORMAT_RGBA8)
		for index in range(5):
			captures[index].convert(Image.FORMAT_RGBA8)
			montage.blit_rect(captures[index], Rect2i(0, 0, 1152, 648), Vector2i((index % 2) * 1152, (index / 2) * 648))
		montage.save_png("res://.godot/fireball-fb00-check.png")
	print("FIREBALL_FB00_TEST_RESULT checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
