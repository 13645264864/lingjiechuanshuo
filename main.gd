extends Node2D

@export var enemy_scene:PackedScene
@export var max_enemy: int = 12
@export var base_spawn_count:int = 2
@export var spawn_interval:float = 4.0

var game_time:float = 0.0
var spawn_timer:Timer

func _ready():
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_spawn_batch)
	add_child(spawn_timer)

func _process(delta):
	game_time += delta

func get_current_spawn_count() ->int:
	var minutes = game_time / 60.0
	var rate = pow(1.2, minutes)
	var count = base_spawn_count * rate
	return max(1, round(count))

func _spawn_batch():
	var alive = get_tree().get_nodes_in_group("enemy").size()
	if alive >= max_enemy:
		return
	
	var spawn_num = get_current_spawn_count()
	print("游戏时间：",game_time,"秒，本次刷怪数量：",spawn_num)
	
	for i in spawn_num:
		var alive_now = get_tree().get_nodes_in_group("enemy").size()
		if alive_now >= max_enemy:
			break
		var enemy = enemy_scene.instantiate()
		add_child(enemy)
