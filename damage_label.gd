extends Label

@export var move_up_speed:float = -80.0
@export var life_time:float = 1.0
var timer:float = 0.0

func _ready():
	add_theme_font_size_override("font_size", 30)

func _process(delta):
	timer += delta
	global_position.y += move_up_speed * delta
	modulate.a = 1.0 - timer/life_time
	
	if timer >= life_time:
		queue_free()
