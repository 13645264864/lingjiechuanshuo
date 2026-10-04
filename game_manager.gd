extends Node2D
@export var base_spawn:int = 2
@export var max_enemy:int = 30
@export var spawn_interval:float = 4.0
@export var enemy_template:PackedScene
@export var boss_template:PackedScene
var game_time:float = 0.0
var game_over:bool = false
var spawn_timer:Timer
var game_started:bool = false
var rng = RandomNumberGenerator.new()

enum BuffType {
	SPLIT,
	SPEED,
	PENETRATE,
	BIG_FIRE
}

var quality_config = [
	{"weight":70, "mult":2, "lv":1, "color":Color(1,1,1)},
	{"weight":15, "mult":3, "lv":2, "color":Color(0.2,0.5,1)},
	{"weight":10, "mult":6, "lv":3, "color":Color(0.7,0.2,0.9)},
	{"weight":5, "mult":10,"lv":4, "color":Color(1,0.65,0)}
]
var buff_base = [
	{"name":"分裂", "desc":"发射时同时射出次级火球"},
	{"name":"高速", "desc":"火球飞行速度提升"},
	{"name":"穿透", "desc":"火球可以穿透敌人"},
	{"name":"巨型火球", "desc":"扩大火球和群体命中范围，提升暴击"}
]

var player_buffs:Dictionary = {}
var canvas:CanvasLayer
var timer_label:Label
var death_ui:ColorRect
var death_text:Label
var restart_btn:Button
var start_btn:Button
var buff_panel:ColorRect
var buff_buttons:Array[Button] = []
# 全局临时候选列表，不再放按钮元数据
var temp_candidates:Array = []
var boss_count:int = 0
var boss_bar:ProgressBar
var boss_name_label:Label
var dodge_button:Button

func get_total_buff_stats() -> Dictionary:
	var stat = {
		"split_mult":1.0,
		"speed_mult":1.0,
		"penetrate_mult":1.0,
		"crit_mult":1.0
	}
	print("\n==== 汇总Buff（覆盖机制，每种最多一条） ====")
	for buff_type in player_buffs:
		var buff = player_buffs[buff_type]
		var q_mult = buff.mult
		var buff_name = buff.name
		print("  【",buff_name,"】倍率 ×",q_mult)
		match buff_type:
			BuffType.SPLIT:
				stat.split_mult = q_mult
			BuffType.SPEED:
				stat.speed_mult = q_mult
			BuffType.PENETRATE:
				stat.penetrate_mult = q_mult
			BuffType.BIG_FIRE:
				stat.crit_mult = q_mult
	print("==== 汇总完成：",stat,"\n")
	return stat

# 火球生成时读取的最终属性。所有技能效果在这里统一计算，避免
# 火球脚本和选技能逻辑各自维护一套倍率。
func get_fireball_config() -> Dictionary:
	var config = {
		"speed_mult": 1.0,
		"penetrate_count": 1,
		"split_count": 0,
		"enable_huge": false,
		"crit_rate": 0.05,
		"crit_mult": 2.05,
		"scale_mult": 1.0
	}

	for buff_type in player_buffs:
		var buff:Dictionary = player_buffs[buff_type]
		var q_mult:int = int(buff.get("mult", 2))
		match int(buff_type):
			BuffType.SPLIT:
				var split_level := _quality_index(q_mult)
				var split_values = [2, 3, 6, 12]
				config.split_count = split_values[split_level]
			BuffType.SPEED:
				var speed_level := _quality_index(q_mult)
				var speed_values = [1.6, 2.4, 4.8, 9.6]
				config.speed_mult = speed_values[speed_level]
			BuffType.PENETRATE:
				var penetrate_level := _quality_index(q_mult)
				var penetrate_values = [3, 5, 9, 18]
				config.penetrate_count = penetrate_values[penetrate_level]
			BuffType.BIG_FIRE:
				var crit_level := _quality_index(q_mult)
				var crit_rates = [0.05, 0.10, 0.20, 0.40]
				var crit_multipliers = [2.05, 2.10, 2.20, 2.40]
				var scale_values = [1.8, 2.4, 3.2, 4.2]
				config.enable_huge = true
				config.scale_mult = scale_values[crit_level]
				config.crit_rate = crit_rates[crit_level]
				config.crit_mult = crit_multipliers[crit_level]

	return config

func _quality_index(q_mult:int) -> int:
	match q_mult:
		2: return 0
		3: return 1
		6: return 2
		10: return 3
	return 0

func _ready():
	rng.randomize()
	canvas = CanvasLayer.new()
	add_child(canvas)
	
	start_btn = Button.new()
	start_btn.text = "开始游戏"
	var start_theme = Theme.new()
	start_theme.default_font_size = 60
	start_btn.theme = start_theme
	start_btn.anchor_left = 0.5
	start_btn.anchor_right = 0.5
	start_btn.anchor_top = 0.5
	start_btn.anchor_bottom = 0.5
	start_btn.offset_left = -200
	start_btn.offset_top = -40
	start_btn.offset_right = 200
	start_btn.offset_bottom = 40
	start_btn.pressed.connect(start_game)
	canvas.add_child(start_btn)
	
	timer_label = Label.new()
	timer_label.horizontal_alignment = 1
	timer_label.anchor_left = 0
	timer_label.anchor_right = 1.0
	var timer_theme = Theme.new()
	timer_theme.default_font_size = 48
	timer_label.theme = timer_theme
	timer_label.visible = false
	canvas.add_child(timer_label)
	
	death_ui = ColorRect.new()
	death_ui.color = Color(0,0,0,0.75)
	death_ui.anchor_left = 0
	death_ui.anchor_top = 0
	death_ui.anchor_right = 1.0
	death_ui.anchor_bottom =1.0
	death_ui.visible = false
	canvas.add_child(death_ui)
	
	death_text = Label.new()
	death_text.text = "寄"
	death_text.horizontal_alignment = 1
	death_text.vertical_alignment = 1
	death_text.anchor_left =0
	death_text.anchor_right =1.0
	death_text.anchor_top =0
	death_text.anchor_bottom =1
	var large_font = Theme.new()
	large_font.default_font_size = 120
	death_text.theme = large_font
	death_text.modulate = Color(0.5,0,0)
	death_ui.add_child(death_text)
	
	restart_btn = Button.new()
	restart_btn.text = "重来"
	var btn_theme = Theme.new()
	btn_theme.default_font_size = 60
	restart_btn.theme = btn_theme
	restart_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	restart_btn.anchor_left = 0.5
	restart_btn.anchor_right = 0.5
	restart_btn.anchor_top =0.5
	restart_btn.anchor_bottom =0.5
	restart_btn.offset_left = -600
	restart_btn.offset_top = 120
	restart_btn.offset_right = 600
	restart_btn.offset_bottom = 20
	restart_btn.pressed.connect(restart_game)
	death_ui.add_child(restart_btn)
	
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.autostart = false
	spawn_timer.timeout.connect(_spawn_batch)
	add_child(spawn_timer)
	
	buff_panel = ColorRect.new()
	buff_panel.color = Color(0,0,0,0.85)
	buff_panel.anchor_right = 1
	buff_panel.anchor_bottom =1
	buff_panel.visible = false
	canvas.add_child(buff_panel)
	create_boss_ui()
	create_mobile_dodge_button()

func create_boss_ui():
	boss_name_label = Label.new()
	boss_name_label.text = "紫霄蚀界尊"
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.anchor_left = 0.2
	boss_name_label.anchor_right = 0.8
	boss_name_label.offset_top = 58
	boss_name_label.offset_bottom = 92
	boss_name_label.add_theme_font_size_override("font_size", 28)
	boss_name_label.modulate = Color(1.0, 0.35, 0.8)
	boss_name_label.visible = false
	canvas.add_child(boss_name_label)
	boss_bar = ProgressBar.new()
	boss_bar.anchor_left = 0.15
	boss_bar.anchor_right = 0.85
	boss_bar.offset_top = 92
	boss_bar.offset_bottom = 122
	boss_bar.show_percentage = false
	boss_bar.visible = false
	canvas.add_child(boss_bar)

func create_mobile_dodge_button():
	dodge_button = Button.new()
	dodge_button.text = "闪避\nSHIFT"
	dodge_button.custom_minimum_size = Vector2(130, 90)
	dodge_button.anchor_left = 1.0
	dodge_button.anchor_top = 1.0
	dodge_button.anchor_right = 1.0
	dodge_button.anchor_bottom = 1.0
	dodge_button.offset_left = -170
	dodge_button.offset_top = -130
	dodge_button.offset_right = -30
	dodge_button.offset_bottom = -30
	dodge_button.add_theme_font_size_override("font_size", 22)
	dodge_button.pressed.connect(_on_dodge_pressed)
	canvas.add_child(dodge_button)

func _on_dodge_pressed():
	var player = get_parent().get_node_or_null("Player")
	if player != null and player.has_method("dodge"):
		player.dodge()

func rebuild_buff_buttons():
	for old_btn in buff_buttons:
		old_btn.queue_free()
	buff_buttons.clear()
	
	var w = 300
	var h = 180
	var gap = 60
	var total = w*3 + gap*2
	for i in range(3):
		var btn=Button.new()
		btn.custom_minimum_size=Vector2(w,h)
		var sx=(1152-total)/2
		var px=sx+i*(w+gap)
		btn.position=Vector2(px,648/2-h/2)
		var t=Theme.new()
		t.default_font_size=24
		btn.theme=t
		btn.pressed.connect(func(idx = i): select_buff(idx))
		buff_panel.add_child(btn)
		buff_buttons.append(btn)

func roll_one_buff():
	var available_types:Array = []
	for t in BuffType.values():
		if not player_buffs.has(t):
			available_types.append(t)
		else:
			var existing_buff = player_buffs[t]
			if existing_buff.lv < 4:
				available_types.append(t)
	print("available_types = ", available_types)
	if available_types.is_empty():
		print("所有buff已满级，无可用buff")
		return null
		
	var picked_index = rng.randi_range(0, available_types.size() - 1)
	var picked_type = available_types[picked_index]
	print("picked_type = ", picked_type)
	
	var min_lv = 1
	if player_buffs.has(picked_type):
		min_lv = player_buffs[picked_type].lv + 1
	
	var available_quality:Array = []
	var total_weight = 0
	for q in quality_config:
		if q.lv >= min_lv:
			available_quality.append(q)
			total_weight += q.weight
	if total_weight <= 0:
		return null
	
	var roll = rng.randi_range(0, total_weight - 1)
	var sum =0
	var selected_q
	for q in available_quality:
		sum += q.weight
		if roll < sum:
			selected_q = q
			break
	if selected_q == null:
		selected_q = available_quality.back()
	
	if picked_type <0 or picked_type >= buff_base.size():
		print("ERROR picked_type越界！值：",picked_type)
		return null
	var base = buff_base[picked_type]
	var new_buff = {
		"type": picked_type,
		"mult": selected_q.mult,
		"lv": selected_q.lv,
		"color": selected_q.color,
		"name": base.name,
		"desc": base.desc
	}
	print("[ROLL]抽到buff：",new_buff.name,"等级",new_buff.lv,"倍率×",new_buff.mult)
	return new_buff

func show_buff_choose():
	temp_candidates.clear()
	print("\n==== 开始roll3个候选buff ====")
	var try_count = 0
	while temp_candidates.size() < 3 and try_count < 20:
		var b = roll_one_buff()
		if b != null:
			temp_candidates.append(b)
		try_count += 1
	while temp_candidates.size() <3:
		var fallback_buff = {
			"type": BuffType.SPLIT,
			"mult":1,
			"lv":0,
			"color":Color(0.3,0.3,0.3),
			"name":"已满级",
			"desc":"没有更多buff可以获取"
		}
		temp_candidates.append(fallback_buff)
	
	rebuild_buff_buttons()
	
	for i in range(3):
		var buff = temp_candidates[i]
		var line1 = buff.name
		var line2 = "等级Lv"+str(buff.lv)+" 倍率 ×" + str(buff.mult)
		var line3 = buff.desc
		var text = line1 + "\n" + line2 + "\n" + line3
		buff_buttons[i].text = text
		buff_buttons[i].modulate = buff.color
		# 删掉set元数据！！！这里不再存任何东西在按钮

	buff_panel.visible = true
	game_over = true

func select_buff(index:int):
	print("点击buff按钮，index=", index)
	# 两层边界保护
	if index < 0 or index >= buff_buttons.size():
		print("index超出按钮数组范围")
		buff_panel.visible = false
		game_over = false
		return
	if index < 0 or index >= temp_candidates.size():
		print("index超出候选数组范围")
		buff_panel.visible = false
		game_over = false
		return
		
	var selected = temp_candidates[index]
	if selected.lv == 0:
		buff_panel.visible = false
		game_over = false
		return
	player_buffs[selected.type] = selected
	print("\n【选中Buff存入字典】", selected)
	print("当前player_buffs = ", player_buffs)
	var stat = get_total_buff_stats()
	buff_panel.visible = false
	game_over = false

func start_game():
	game_started = true
	start_btn.visible = false
	timer_label.visible = true
	spawn_timer.start()
	show_buff_choose()

func _process(delta):
	if not game_started or game_over:
		return
	game_time += delta
	var minute_level := int(floor(game_time / 60.0))
	if minute_level > boss_count:
		boss_count = minute_level
		spawn_boss(boss_count)
	var total_sec:int = floor(game_time)
	var minute:int = total_sec / 60
	var second:int = total_sec % 60
	var time_str = str(minute).pad_zeros(2) + ":" + str(second).pad_zeros(2)
	timer_label.text = time_str

func _spawn_batch():
	if game_over:
		return
	print("准备生成怪物，模板：", enemy_template)
	if enemy_template == null:
		print("模板是空！")
		return
		
	var alive_enemies = get_tree().get_nodes_in_group("enemy")
	if alive_enemies.size() >= max_enemy:
		return
	
	for _i in range(base_spawn):
		var new_enemy = enemy_template.instantiate()
		new_enemy.add_to_group("enemy")
		get_parent().add_child(new_enemy)
		new_enemy.setup_spawn(get_safe_spawn_position(), get_parent().get_node("Player"), game_time / 60.0)

func get_safe_spawn_position() -> Vector2:
	var player = get_parent().get_node("Player")
	var camera = get_viewport().get_camera_2d()
	var camera_scale = maxf(abs(camera.global_scale.x), 0.01)
	var half_size = get_viewport_rect().size * 0.5 / camera_scale
	var margin := 180.0
	var side = rng.randi_range(0, 3)
	var pos = player.global_position
	match side:
		0: pos += Vector2(rng.randf_range(-half_size.x, half_size.x), -half_size.y - margin)
		1: pos += Vector2(half_size.x + margin, rng.randf_range(-half_size.y, half_size.y))
		2: pos += Vector2(rng.randf_range(-half_size.x, half_size.x), half_size.y + margin)
		3: pos += Vector2(-half_size.x - margin, rng.randf_range(-half_size.y, half_size.y))
	return pos

func spawn_boss(level:int):
	if boss_template == null:
		return
	for boss in get_tree().get_nodes_in_group("boss"):
		if not boss.is_dead:
			return
	var boss = boss_template.instantiate()
	get_parent().add_child(boss)
	boss.setup_spawn(get_safe_spawn_position(), get_parent().get_node("Player"), level)
	boss_bar.max_value = boss.max_hp
	boss_bar.value = boss.hp
	boss_bar.visible = true
	boss_name_label.text = "紫霄蚀界尊 · 第 " + str(level) + " 劫"
	boss_name_label.visible = true

func boss_defeated():
	if boss_bar != null:
		boss_bar.visible = false
	if boss_name_label != null:
		boss_name_label.visible = false

func _physics_process(_delta):
	for boss in get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(boss) and boss_bar != null:
			boss_bar.value = boss.hp

func game_die():
	game_over = true
	death_ui.visible = true
	get_tree().paused = true

func restart_game():
	get_tree().paused = false
	get_tree().reload_current_scene()
