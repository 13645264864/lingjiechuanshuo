extends Control

var map: Node2D
var boss_icon_center := Vector2.ZERO
var current_marker := Vector2.ZERO

func setup(level: Node2D):
	map = level
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -212
	offset_right = -12
	offset_top = 12
	offset_bottom = 142
	queue_redraw()

func _draw():
	if not is_instance_valid(map): return
	draw_style_box(_background(), Rect2(Vector2.ZERO, size))
	var min_grid := Vector2i(0, -1)
	var step := Vector2(45, 35)
	var origin := Vector2(25, 22)
	for link in map.links:
		var from := origin + Vector2(map.rooms[link.from].grid - min_grid) * step
		var to := origin + Vector2(map.rooms[link.to].grid - min_grid) * step
		draw_line(from, to, Color(0.45, 0.5, 0.48), 3.0, true)
	for room in map.rooms:
		var center := origin + Vector2(room.grid - min_grid) * step
		var fill := Color(0.23, 0.26, 0.25)
		if room.entered: fill = Color(0.44, 0.47, 0.43)
		if room.cleared: fill = Color(0.21, 0.52, 0.4)
		var rect := Rect2(center - Vector2(13, 10), Vector2(26, 20))
		draw_rect(rect, fill)
		draw_rect(rect, Color(0.7, 0.73, 0.68), false, 1.0)
		if room.boss:
			boss_icon_center = center
			# Small horned skull, distinct from the current-room position dot.
			draw_colored_polygon(PackedVector2Array([center + Vector2(-8,-7), center + Vector2(-5,-3), center + Vector2(5,-3), center + Vector2(8,-7), center + Vector2(6,5), center + Vector2(0,8), center + Vector2(-6,5)]), Color(0.84,0.45,1.0))
			draw_circle(center + Vector2(-3,1), 1.5, Color(0.13,0.07,0.2))
			draw_circle(center + Vector2(3,1), 1.5, Color(0.13,0.07,0.2))
		if room.id == map.current_room:
			current_marker = center
			draw_rect(rect.grow(3), Color(0.35,1.0,0.85), false, 2.0)
			draw_circle(center + Vector2(0, -15), 3.0, Color(0.8,1.0,0.9))

func _background() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.1, 0.09, 0.88)
	box.border_color = Color(0.36,0.44,0.4)
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	return box
