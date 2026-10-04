extends Control

# Godot4 使用 @onready
@onready var hp_bar = $VBoxContainer/ProgressBar
@onready var cultivate_bar = $VBoxContainer/cultivate_bar
@onready var cultivate_text = $VBoxContainer/cultivate_text

# 状态栏数据
var max_hp = 100.0
var hp = 100.0

const BASE_AURA:float = 100.0
const GROW_RATE:float = 1.2
const MAX_REALM:int = 9
var realm:int = 1
var current_aura:float = 0.0
var need_aura:float = BASE_AURA


func _ready():
	refresh_ui()


# 外部调用：更新血量，玩家受伤时调用
func set_hp(new_hp:float, new_max_hp:float):
	hp = new_hp
	max_hp = new_max_hp
	refresh_ui()


# 外部调用：增加灵气，拾取灵气时调用
func add_aura(amount:float):
	if realm >= MAX_REALM:
		return
	
	current_aura += amount
	
	while current_aura >= need_aura and realm < MAX_REALM:
		current_aura -= need_aura
		realm +=1
		need_aura *= GROW_RATE
	
	refresh_ui()


# 刷新所有UI显示
func refresh_ui():
	# 更新血条
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	
	# 更新修为条+文字
	cultivate_bar.max_value = need_aura
	cultivate_bar.value = current_aura
	cultivate_text.text = get_realm_name(realm)


func get_realm_name(lv:int) -> String:
	match lv:
		1: return "练气一层"
		2: return "练气二层"
		3: return "练气三层"
		4: return "练气四层"
		5: return "练气五层"
		6: return "练气六层"
		7: return "练气七层"
		8: return "练气八层"
		9: return "练气大圆满"
	return "未知境界"
