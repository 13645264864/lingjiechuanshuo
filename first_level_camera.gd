extends Camera2D

var player: Node2D

func _ready():
	player = get_parent().get_node("Player")
	zoom = Vector2(0.62, 0.62)

func _process(delta: float):
	var map = get_parent().get_node("FirstLevelMap")
	var bounds: Rect2 = map.world_bounds()
	var half := get_viewport_rect().size * 0.5 / zoom
	var target := player.global_position.clamp(bounds.position + half, bounds.end - half)
	global_position = global_position.lerp(target, 1.0 - exp(-8.0 * delta))
