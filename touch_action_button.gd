extends Button

func _input(event: InputEvent):
	# ScreenTouch is handled directly so a second finger works while the joystick
	# owns the first finger; mouse emulation alone only covers one pointer.
	if event is InputEventScreenTouch and event.pressed and not disabled and is_visible_in_tree():
		if get_global_rect().has_point(event.position):
			pressed.emit()
