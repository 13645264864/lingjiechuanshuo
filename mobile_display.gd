extends Node

func _ready():
	if not OS.has_feature("mobile"): return
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)
	get_window().size_changed.connect(adapt_orientation)
	adapt_orientation()

func adapt_orientation():
	var window := get_window()
	var base := Vector2i(648, 1152) if window.size.x < window.size.y else Vector2i(1152, 648)
	if window.content_scale_size != base:
		window.content_scale_size = base
