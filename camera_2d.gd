extends Camera2D

# 地图边界
const MAP_LEFT = -1536
const MAP_RIGHT = 1536
const MAP_TOP = -1536
const MAP_BOTTOM = 1536

var player:Node2D

func _ready():
	# 获取父节点(Node2D)，然后找子节点Player
	player = get_parent().get_node("Player")

func _process(delta):
	if player == null:
		return
		
	var cam_half_w = get_viewport_rect().size.x * 0.5
	var cam_half_h = get_viewport_rect().size.y * 0.5
	
	var target_cam_pos = player.global_position
	
	# 限制相机范围，防止看到虚空
	target_cam_pos.x = clamp(target_cam_pos.x, MAP_LEFT + cam_half_w, MAP_RIGHT - cam_half_w)
	target_cam_pos.y = clamp(target_cam_pos.y, MAP_TOP + cam_half_h, MAP_BOTTOM - cam_half_h)

	global_position = lerp(global_position, target_cam_pos, 8.0 * delta)
