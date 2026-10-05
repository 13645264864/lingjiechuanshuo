extends SceneTree

var failures := 0
var checks := 0

func _initialize():
	run.call_deferred()

func check(condition: bool, message: String):
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func run():
	create_timer(20).timeout.connect(func(): quit(2))
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	var gm = world.get_node("GameManager")
	gm.set_process(false)
	var player = world.get_node("Player")
	player.set_physics_process(false)
	player.global_position = Vector2(500, 0)
	player.velocity = Vector2.ZERO
	var enemy = load("res://enemy.tscn").instantiate()
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.global_position = Vector2(200, 0)
	enemy.rush_cooldown = 0.0
	await physics_frame
	enemy._physics_process(1.0 / 60.0)
	check(enemy.rush_phase == "windup", "Enemy telegraphs before rushing")
	check(enemy.velocity == Vector2.ZERO, "Windup holds enemy still")
	var locked = enemy.rush_direction
	player.global_position += Vector2(0, 250)
	for index in range(28):
		await physics_frame
		enemy._physics_process(1.0 / 60.0)
	check(enemy.rush_direction == locked, "Sidestepping does not redirect committed rush")
	var origin = enemy.global_position
	for index in range(30):
		await physics_frame
		enemy._physics_process(1.0 / 60.0)
	check(enemy.global_position.distance_to(origin) > 250, "Rush covers a threatening distance")
	check(enemy.rush_phase == "recover", "Rush leaves a recovery opening")
	check(enemy.rush_cooldown > 2.0, "Enemy cannot immediately rush again")
	for index in range(40):
		await physics_frame
		enemy._physics_process(1.0 / 60.0)
	check(enemy.rush_phase == "chase", "Enemy resumes pursuit after recovery")
	enemy.global_position = Vector2(200, 0)
	player.global_position = Vector2(500, 0)
	var wall := StaticBody2D.new()
	wall.collision_layer = 4
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(20, 800)
	shape.shape = rectangle
	wall.add_child(shape)
	world.add_child(wall)
	wall.global_position = (enemy.global_position + player.global_position) / 2.0
	await physics_frame
	await process_frame
	await physics_frame
	check(not enemy.rush_has_line_of_sight(), "Walls prevent starting a rush through obstacles")
	world.queue_free()
	await process_frame
	print("ENEMY_RUSH_TEST_RESULT checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
