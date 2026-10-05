extends SceneTree

var checks := 0
var failures: Array[String] = []
var world
var map
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

func finish_choices():
	for index in range(8):
		if not gm.buff_panel.visible: break
		gm.buff_buttons[0].pressed.emit()
		await process_frame

func snapshot(name: String, center: Vector2, zoom: float):
	if not capture_enabled: return
	var camera = world.get_node("Camera2D")
	camera.set_process(false)
	camera.position = center
	camera.zoom = Vector2.ONE*zoom
	await ticks(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/"+name+".png")
	check(true,"Rendered "+name)

func run():
	create_timer(80.0).timeout.connect(func(): quit(2))
	capture_enabled = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1152,648)
	world = load("res://first_level.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await ticks(4)
	map = world.get_node("FirstLevelMap")
	player = world.get_node("Player")
	gm = world.get_node("GameManager")
	player.hp = 50000
	player.set_physics_process(false)
	check(map.rooms.size() == 7 and map.links.size() == 6,"Default scene is seven-room level")
	check(map.rooms[-1].boss,"Final room is boss room")
	check(get_nodes_in_group("training_dummy").is_empty(),"Practice dummy absent before sword unlock")
	var relic: Sprite2D = map.get_node("BossRelic")
	check(relic.offset == Vector2.ZERO and relic.z_index == -6,"Circular ruin is centered on ground beneath actors")
	check(get_nodes_in_group("enemy").is_empty(),"No room spawns before starting")
	check(gm.level_map == map and map.minimap != null,"Map and minimap bind to manager")
	check(map.rooms[0].bounds.has_point(player.position),"Player starts in first room")
	for link in map.links:
		check(link.to == link.from+1,"Layout is a connected ordered combat route")
		check(link.gate.sealed,"Forward doors initially locked")
		var corridor: Rect2i = link.tiles
		check(corridor.size.x > 0 and corridor.size.y > 0,"Corridors are nonempty")
		check(map.floor_cells.has(corridor.get_center()),"Corridors have traversable ground")
	gm.start_btn.pressed.emit()
	check(paused and gm.buff_panel.visible,"Initial upgrade modal pauses gameplay")
	await finish_choices()
	gm.player_buffs.clear()
	await ticks(3)
	check(map.active_room == 0 and map.rooms[0].entered,"First room starts after selection")
	check(get_nodes_in_group("enemy").size() == 4,"First room has four enemies")
	check(not get_nodes_in_group("archer").is_empty(),"First room includes supplied ranged archer")
	check(gm.spawn_timer.is_stopped(),"Minute/edge spawning disabled in stage")
	gm.player_buffs = {0:{"type":0,"lv":1,"mult":2,"name":"分裂"}}
	player.target_enemy = map.rooms[0].enemies[0]
	player.shoot_fireball()
	var stage_shots: Array = world.get_children().filter(func(node): return node.get_script() == load("res://fireball.gd"))
	check(stage_shots.size() == 3,"Stage player creates two split children")
	for shot in stage_shots:
		check(shot.speed == 210.0 and shot.damage == 18.0,"Stage split inherits main speed and damage")
		shot.queue_free()
	gm.player_buffs.clear()
	check(map.links[0].gate.sealed,"Combat seals room exit")
	check(not map.rooms[-1].entered,"Boss cannot spawn before route progression")
	var confined: Vector2 = map.constrain_position(Vector2(2000,0))
	check(map.rooms[0].bounds.has_point(confined),"Dodge cannot leave locked encounter")
	for enemy in get_nodes_in_group("enemy"):
		enemy.set_physics_process(false)
	await snapshot("stage-first-room",Vector2(0,0),0.52)

	# A real fireball hits the new layer-2 archer. This catches layer-mask regressions.
	var archer = get_nodes_in_group("archer")[0]
	player.position = archer.position-Vector2(150,0)
	player.target_enemy = archer
	var hp_before: float = archer.hp
	player.shoot_fireball()
	await ticks(40)
	check(archer.hp < hp_before,"Player fireball damages ranged small enemy")
	check(archer.get_node("AnimatedSprite2D").sprite_frames.get_frame_count("shoot") == 7,"Archer uses real bow windup frames")
	player.position = Vector2.ZERO
	archer.position = Vector2(-500,0)
	archer.shot_timer = 0
	archer.set_physics_process(true)
	hp_before = player.hp
	await ticks(105)
	check(archer.shots_fired > 0 and player.hp < hp_before,"Archer winds up and actual arrow hits stationary player")
	archer.set_physics_process(false)
	for arrow in get_nodes_in_group("enemy_arrow"): arrow.queue_free()
	await ticks(2)
	# Wall obstruction and invulnerable dash use the same arrow path.
	var wall := StaticBody2D.new()
	wall.collision_layer = 4
	wall.position = Vector2(-250,0)
	var collider := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(35,300)
	collider.shape = box
	wall.add_child(collider)
	world.add_child(wall)
	await ticks(2)
	check(not archer.has_line_of_sight(),"Archer does not shoot through cover")
	var arrow := Node2D.new()
	arrow.set_script(load("res://enemy_arrow.gd"))
	world.add_child(arrow)
	arrow.setup(Vector2(-450,0),Vector2.RIGHT,player,10)
	hp_before = player.hp
	await ticks(65)
	check(player.hp == hp_before and not is_instance_valid(arrow),"Physical wall stops arrow")
	wall.queue_free()
	await ticks(2)
	player.last_dir = Vector2.DOWN
	player.dodge()
	arrow = Node2D.new()
	arrow.set_script(load("res://enemy_arrow.gd"))
	world.add_child(arrow)
	arrow.setup(player.position-Vector2(25,0),Vector2.RIGHT,player,10)
	hp_before = player.hp
	await ticks(15)
	check(player.hp == hp_before,"Archer arrow respects dodge invulnerability")
	player._physics_process(0.5)
	await ticks(2)

	# Progress through every combat room; none is a chest/shop room.
	for room_index in range(6):
		if room_index > 0:
			player.position = map.rooms[room_index].bounds.get_center()
			await ticks(3)
		var room: Dictionary = map.rooms[room_index]
		check(room.entered and not room.boss and room.enemies.size() >= 4,"Room "+str(room_index+1)+" is a combat encounter")
		check(map.active_room == room_index,"Encounter tracks current active room")
		check(map.current_room == room_index,"Minimap current room follows player")
		var count: int = room.enemies.size()
		map.enter_room(room_index)
		check(room.enemies.size() == count,"Reentering does not duplicate enemies")
		for enemy in room.enemies:
			enemy.set_physics_process(false)
			enemy.take_damage(10000)
		await ticks(5)
		await finish_choices()
		check(room.cleared and map.active_room == -1,"Room clears after its enemies die")
		check(not map.links[room_index].gate.sealed,"Clear opens next route")
		check(not map.links[room_index].arrival_gate.sealed,"Clear unlocks next room entrance too")
		await ticks(50)
		if room_index == 0:
			player.position = Vector2(760,0)
			player.set_physics_process(true)
			player.fireball_timer = 1000
			Input.action_press("move_right")
			await ticks(650)
			Input.action_release("move_right")
			player.set_physics_process(false)
			check(map.current_room == 1 and map.rooms[1].entered,"Real movement crosses open corridor into next encounter")
			for enemy in map.rooms[1].enemies: enemy.set_physics_process(false)
	player.position = map.rooms[-1].bounds.get_center()-Vector2(700,0)
	await ticks(4)
	check(map.current_room == 6 and map.active_room == 6,"Final room entered")
	check(get_nodes_in_group("boss").size() == 1,"Final room spawns exactly one boss")
	var boss = get_nodes_in_group("boss")[0]
	boss.set_physics_process(false)
	check(boss.arena_bounds.has_area() and boss.room_id == 6,"Boss is bound to final room")
	await snapshot("stage-boss-room",map.rooms[-1].bounds.get_center(),0.43)
	boss.take_damage(boss.hp)
	await ticks(95)
	await finish_choices()
	check(map.rooms[-1].cleared,"Boss death clears final encounter")
	check(get_nodes_in_group("sword_drop").size() == 1,"First boss drops one persistent sword")
	var sword = get_nodes_in_group("sword_drop")[0]
	player.position = sword.position
	await ticks(4)
	check(player.sword_unlocked and gm.buff_panel.visible and paused,"Picking sword unlocks skill and dedicated upgrade modal")
	check(get_nodes_in_group("training_dummy").size() == 1,"Sword pickup spawns one practice enemy")
	var dummy = get_nodes_in_group("training_dummy")[0]
	check(dummy.is_in_group("enemy") and dummy.get_node("NameLabel").text == "练习人偶","Practice dummy has name label and enemy targeting group")
	check(not map.rooms[-1].enemies.has(dummy) and map.rooms[-1].cleared,"Practice dummy does not reopen completed encounter")
	map.spawn_training_dummy()
	check(get_nodes_in_group("training_dummy").size() == 1,"Practice dummy spawn is idempotent")
	for candidate in gm.temp_candidates:
		check(candidate.get("category","") == "sword","Unlock options are sword upgrades")
	gm.buff_buttons[0].pressed.emit()
	await process_frame
	check(not gm.sword_buffs.is_empty() and map.completed and map.portal.active,"First sword selection activates altar exit")
	await ticks(20)
	await finish_choices()
	check(not paused and not gm.game_over,"Reward selection returns to sword practice")
	player.find_nearest_enemy()
	check(player.target_enemy == dummy,"Player can automatically target practice dummy")
	var dummy_position: Vector2 = dummy.global_position
	var practice_hp: float = player.hp
	await ticks(10)
	check(dummy.global_position == dummy_position and player.hp == practice_hp,"Practice dummy remains stationary and does not attack")
	gm.player_buffs.clear()
	player.target_enemy = dummy
	var practice_hits: int = dummy.hit_count
	player.shoot_fireball()
	await ticks(100)
	check(dummy.hit_count > practice_hits,"Real fireball hits practice dummy without killing it")
	check(not dummy.is_dead and dummy.global_position == dummy_position,"Practice dummy remains stationary after projectile impact")
	player.hp = 88
	gm.sword_button.pressed.emit()
	check(player.sword_time_left == 10.0 and player.sword_cooldown_left == 50.0,"Virtual skill button starts 10s form and 50s cooldown")
	check(player.sword_visual.visible and not player.anim.visible,"Form uses smaller approved boss sprite")
	player.sword_visual.update_form(0.016)
	player.sword_visual.update_form(0.3)
	check(dummy.hit_count > 0,"Sword transformation targets and slashes practice dummy")
	await snapshot("stage-sword-form",map.rooms[-1].bounds.get_center(),0.55)
	dummy.take_damage(1.0e20)
	check(is_inf(dummy.hp) and not dummy.is_dead,"Practice dummy survives arbitrarily large damage")
	var skill_cd: float = player.sword_cooldown_left
	player.activate_sword_form()
	check(player.sword_cooldown_left == skill_cd,"Active/cooling skill cannot retrigger")
	# A live target validates transformed melee, wave and dodge damage.
	var target = load("res://enemy.tscn").instantiate()
	world.add_child(target)
	target.set_physics_process(false)
	target.position = player.position+Vector2(180,0)
	target.hp = 1000
	gm.sword_buffs = {0:1,1:1,2:1,3:1}
	player.sword_visual.attack_timer = 0.0
	player.sword_visual.blink_timer = 1.0
	player.sword_visual.update_form(0.016)
	player.sword_visual.update_form(0.3)
	check(target.hp < 1000,"Sword form performs actual melee damage")
	check(player.sword_visual.attack_timer < 0.8,"Combo upgrade accelerates attacks")
	check(world.get_children().any(func(node): return node.get_script() == load("res://sword_wave.gd")),"Sword energy upgrade emits real wave")
	player.sword_dash_hit.clear()
	target.position = player.position+Vector2(80,0)
	var target_hp: float = target.hp
	player.sword_visual.dash_strike()
	player.sword_visual.dash_strike()
	check(is_equal_approx(target.hp,target_hp-33.6),"Dash sword upgrade applies once per target per dodge")
	target.queue_free()
	player._physics_process(10.01)
	check(player.sword_time_left == 0 and player.anim.visible and not player.sword_visual.visible,"Form ends after 10 seconds")
	check(player.sword_cooldown_left > 39 and player.sword_cooldown_left < 41,"Cooldown continues from activation")
	check(player.hp == 88,"Transformation does not grant free healing")
	player._physics_process(40.3)
	check(player.sword_cooldown_left == 0,"50 second cooldown expires")
	Input.action_press("sword_form")
	player._physics_process(0.016)
	Input.action_release("sword_form")
	check(player.sword_time_left > 9.9,"Keyboard skill action shares activation path")
	player.end_sword_form()
	# Mobile layout checks actual rectangles and minimap, not just node existence.
	root.size = Vector2i(480,800)
	if capture_enabled:
		DisplayServer.window_set_size(Vector2i(480,800))
	await ticks(2)
	gm.layout_controls()
	gm.show_sword_choose()
	await ticks(2)
	for button in gm.buff_buttons:
		check(root.get_visible_rect().encloses(button.get_global_rect()),"Mobile upgrade card fits viewport")
	check(root.get_visible_rect().encloses(gm.sword_button.get_global_rect()),"Mobile skill button fits viewport")
	check(root.get_visible_rect().encloses(map.minimap.get_global_rect()),"Top-right minimap fits mobile viewport")
	check(not gm.sword_button.get_global_rect().intersects(gm.dodge_button.get_global_rect()),"Skill and dodge buttons do not overlap")
	check(root.get_visible_rect().encloses(gm.dodge_button.get_global_rect()),"Dodge button fits mobile viewport")
	await snapshot("stage-mobile",player.position,0.43)
	# Death must always supersede reward selection and still accept restart.
	player.dodge_invulnerability_left = 0
	player.is_invincible = false
	player.take_damage(player.hp)
	check(player.is_dead and gm.death_ui.visible and not gm.buff_panel.visible,"Death cancels pending sword upgrade")
	var previous = map
	gm.restart_btn.pressed.emit()
	await process_frame
	await process_frame
	check(not is_instance_valid(previous) and current_scene.has_node("FirstLevelMap"),"Restart reloads default first level")
	check(not current_scene.get_node("Player").sword_unlocked and current_scene.get_node("GameManager").sword_buffs.is_empty(),"Restart clears form unlock and sword upgrades")
	check(get_nodes_in_group("training_dummy").is_empty(),"Restart removes practice dummy")
	print("FIRST_LEVEL_MAP_TEST_RESULT checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
