extends Control

var manager: Node2D
var touch_index := -1
var direction := Vector2.ZERO
var radius := 66.0
var origin := Vector2.ZERO

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2.ONE * (radius + 12) * 2
	hide()
	get_viewport().size_changed.connect(release)

func _process(_delta: float):
	if not is_instance_valid(manager): return
	if manager.game_over or not manager.game_started or manager.run_ended:
		release()

func _input(event: InputEvent):
	if not is_instance_valid(manager) or manager.game_over or not manager.game_started or manager.run_ended: return
	if event is InputEventScreenTouch:
		if event.pressed and touch_index < 0 and can_start_at(event.position):
			touch_index = event.index
			origin = event.position
			position = origin - size * 0.5
			direction = Vector2.ZERO
			manager.touch_move = Vector2.ZERO
			show()
			queue_redraw()
		elif not event.pressed and event.index == touch_index:
			release()
	elif event is InputEventScreenDrag and event.index == touch_index:
		update_direction(event.position)

func can_start_at(point: Vector2) -> bool:
	var viewport := get_viewport_rect().size
	if point.x < 0 or point.x > viewport.x * 0.5 or point.y < viewport.y * 0.28 or point.y > viewport.y:
		return false
	return true

func update_direction(point: Vector2):
	direction = ((point - origin) / radius).limit_length()
	if direction.length() < 0.15: direction = Vector2.ZERO
	manager.touch_move = direction
	queue_redraw()

func release():
	touch_index = -1
	direction = Vector2.ZERO
	if is_instance_valid(manager): manager.touch_move = Vector2.ZERO
	hide()
	queue_redraw()

func _notification(what: int):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: release()

func _draw():
	var center := size * 0.5
	draw_circle(center, radius + 7, Color(0.04, 0.1, 0.08, 0.5))
	draw_arc(center, radius, 0, TAU, 48, Color(0.65, 0.85, 0.78, 0.7), 2, true)
	for index in range(4):
		var aim := Vector2.from_angle(index * PI / 2)
		var normal := Vector2(-aim.y, aim.x)
		var point := center + aim * 48
		draw_polyline(PackedVector2Array([point - aim * 6 + normal * 6, point, point - aim * 6 - normal * 6]), Color(0.8, 0.95, 0.9, 0.65), 2, true)
	draw_circle(center + direction * 44, 23, Color(0.25, 0.58, 0.45, 0.8))
	draw_arc(center + direction * 44, 23, 0, TAU, 32, Color(0.7, 1, 0.9, 0.85), 2, true)
