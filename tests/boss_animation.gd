extends SceneTree

var checks := 0
var failures: Array[String] = []
var world
var boss
var player
var gm
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

func run():
	create_timer(90.0).timeout.connect(func(): quit(2))
	capture_enabled = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1152, 648)
	world = load("res://main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await ticks(2)
	gm = world.get_node("GameManager")
	gm.game_started = true
	gm.game_over = false
	gm.set_process(false)
	gm.start_btn.hide()
	gm.spawn_timer.stop()
	gm.dodge_button.hide()
	world.get_node("UI").hide()
	player = world.get_node("Player")
	player.set_physics_process(false)
	player.position = Vector2(550, 100)
	player.hp = 50000.0
	gm.spawn_boss(1)
	boss = get_nodes_in_group("boss")[0]
	boss.position = Vector2.ZERO
	boss.set_physics_process(false)
	var camera = world.get_node("Camera2D")
	camera.set_process(false)
	camera.position = Vector2(250, 0)
	camera.zoom = Vector2(0.72, 0.72)
	var sprite = boss.get_node("AnimatedSprite2D")
	var frames: SpriteFrames = sprite.sprite_frames
	var clips := {"idle": 9, "walk": 6, "attack": 12, "dash": 6, "cast": 4, "hurt": 5, "death": 23}
	for action in clips:
		check(frames.has_animation(action) and frames.get_frame_count(action) == clips[action], "Approved NightBorne multi-frame " + action)
		var first: Texture2D = frames.get_frame_texture(action, 0)
		var last: Texture2D = frames.get_frame_texture(action, clips[action] - 1)
		check(first.get_image().get_data() != last.get_image().get_data(), "Actual sprite pose changes in " + action)
	var image: Image = frames.get_frame_texture("idle", 0).get_image()
	check(image.get_pixel(0, 0).a == 0.0 and image.get_used_rect().size != Vector2i.ZERO, "Approved sprite has transparent padding")
	check(is_equal_approx(sprite.body_size * sprite.scale.x, boss.body_diameter), "Visible silhouette matches intended boss size")
	for direction in [Vector2.RIGHT, Vector2.LEFT]:
		boss.facing_direction = direction
		boss.velocity = direction * 60.0
		await ticks(2)
		var before: int = sprite.frame
		await ticks(9)
		check(sprite.animation == &"walk" and sprite.frame != before, "Movement animation advances " + str(direction))
		check(sprite.flip_h == (direction.x < 0.0), "Sprite faces movement " + str(direction))
	boss.facing_direction = Vector2.RIGHT
	boss.velocity = Vector2.ZERO
	boss.begin_dash_pattern()
	await ticks(8)
	check(sprite.animation == &"cast" and boss.get_node("Aura").power > 0.5, "Aimed dash has distinct powered-up pose")
	boss.start_next_dash()
	await ticks(2)
	check(sprite.animation == &"dash", "Dash uses accelerated running clip")
	boss.spawn_afterimage()
	check(get_nodes_in_group("boss_afterimage").size() == 1, "Dash creates matching silhouette")
	boss.begin_slash(true)
	await ticks(7)
	check(sprite.animation == &"attack", "Slash plays full authored sword animation")
	boss.hp = boss.max_hp * 0.4
	boss._physics_process(0.016)
	await ticks(2)
	check(boss.frenzy and sprite.material.get_shader_parameter("rage") == 1.0, "Low HP activates rage glow")
	await ticks(20)
	check(get_nodes_in_group("boss_afterimage").is_empty(), "Afterimages expire")
	boss.take_damage(boss.hp)
	await ticks(40)
	check(boss.is_dead and sprite.animation == &"death", "Death plays authored 23-frame explosion")
	check(not boss.is_in_group("enemy") and boss.get_node("CollisionShape2D").disabled, "Dying boss cannot block or be targeted")
	check(not gm.boss_bar.visible, "Death hides HP bar")
	await ticks(50)
	check(not is_instance_valid(boss), "Death cleans up after animation")
	var aura_count := 0
	for child in world.get_children():
		if child.get_script() == load("res://aura_drop.gd"):
			aura_count += 1
	check(aura_count == 1, "Death drops exactly one aura")
	gm.spawn_boss(1)
	boss = get_nodes_in_group("boss")[0]
	boss.position = Vector2.ZERO
	var observed: Dictionary = {}
	if capture_enabled:
		DirAccess.make_dir_recursive_absolute("res://.godot/nightborne-animation-frames")
	# A moving target outside melee range exercises all ranged patterns naturally.
	for index in range(1440):
		player.position = boss.position + Vector2.from_angle(index / 180.0) * 680.0
		if index == 800:
			boss.take_damage(boss.max_hp * 0.6)
		await ticks(1)
		observed[boss.state] = true
		if capture_enabled and index % 12 == 0:
			camera.position = (player.position + boss.position) * 0.5 + Vector2(0, -100)
			camera.zoom = Vector2(0.48, 0.48)
			await RenderingServer.frame_post_draw
			var screenshot := root.get_texture().get_image()
			screenshot.save_png("res://.godot/nightborne-animation-frames/frame_%03d.png" % (index / 12))
	for state in [boss.State.AIM, boss.State.LOCK, boss.State.DASH, boss.State.SLASH, boss.State.RECOVER, boss.State.SWORDS, boss.State.RAIN]:
		check(observed.has(state), "Automatic combat reaches state " + str(state))
	print("BOSS_ANIMATION_TEST_RESULT checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
