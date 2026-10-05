extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize():
	run.call_deferred()

func check(condition: bool, message: String):
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func click(button: Button):
	var center := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = center
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func run():
	create_timer(15.0).timeout.connect(func(): quit(2))
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	# Both callback orders can occur within the same physics collision batch.
	for size in [Vector2i(1152, 648), Vector2i(480, 800)]:
		root.size = size
		for death_first in [false, true]:
			world = current_scene
			var gm = world.get_node("GameManager")
			var player = world.get_node("Player")
			player.set_physics_process(false)
			gm.start_game()
			gm.select_buff(0)
			gm.spawn_timer.stop()
			if death_first:
				player.take_damage(player.hp)
				player.add_aura(player.need_aura)
				check(player.realm == 1 and player.current_aura == 0.0, "Dead player ignores late aura pickup")
			else:
				player.add_aura(player.need_aura)
				check(gm.buff_panel.visible and player.realm == 2, "Living player can still upgrade")
				player.take_damage(player.hp)
			check(player.is_dead and paused and gm.game_over, "Death pauses combat")
			check(gm.death_ui.visible and not gm.buff_panel.visible, "Death closes upgrade overlay")
			var saved_buffs: Dictionary = gm.player_buffs.duplicate(true)
			# Pending upgrade UI and old button callbacks must not reopen or resume.
			gm.show_buff_choose()
			check(not gm.buff_panel.visible, "Late upgrade request stays closed")
			gm.select_buff(0)
			check(not gm.buff_panel.visible and gm.death_ui.visible, "Late upgrade callback cannot cover restart")
			check(gm.game_over and paused and gm.player_buffs == saved_buffs, "Late selection cannot undo death or grant buffs")
			gm.show_buff_choose()
			await process_frame
			check(gm.restart_btn.can_process(), "Restart receives input while paused")
			var button_rect: Rect2 = gm.restart_btn.get_global_rect()
			check(button_rect.size.y >= 60 and root.get_visible_rect().encloses(button_rect), "Restart button fits viewport " + str(size))
			await click(gm.restart_btn)
			await process_frame
			check(current_scene != world and not paused, "Real mouse click restarts after concurrent death/upgrade")
			if current_scene == world:
				gm.restart_game()
				await process_frame
				await process_frame
			var fresh_gm = current_scene.get_node("GameManager")
			check(not current_scene.get_node("Player").is_dead and fresh_gm.player_buffs.is_empty(), "Restart resets player and buffs")
			check(not fresh_gm.death_ui.visible and not fresh_gm.buff_panel.visible, "Restart removes both modal states")
	print("DEATH_LEVEL_UP_TEST_RESULT checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
