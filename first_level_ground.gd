extends Node2D

var rooms: Array[Rect2] = []

func setup(room_rects: Array[Rect2]):
	rooms = room_rects
	queue_redraw()

func _draw():
	for room in rooms:
		var inner := room.grow(-12.0)
		var tile := 128.0
		for x in range(floori(inner.position.x / tile) + 1, floori(inner.end.x / tile) + 1):
			draw_line(Vector2(x * tile, inner.position.y), Vector2(x * tile, inner.end.y), Color(0.3, 0.32, 0.3, 0.16), 2.0)
		for y in range(floori(inner.position.y / tile) + 1, floori(inner.end.y / tile) + 1):
			draw_line(Vector2(inner.position.x, y * tile), Vector2(inner.end.x, y * tile), Color(0.3, 0.32, 0.3, 0.16), 2.0)
		for index in range(5):
			var point := inner.position + Vector2(inner.size.x * (index + 0.5) / 5.0, inner.size.y * (0.3 if index % 2 == 0 else 0.7))
			draw_polyline(PackedVector2Array([point, point + Vector2(15, 12), point + Vector2(10, 29), point + Vector2(23, 38)]), Color(0.25, 0.27, 0.26, 0.23), 2.0)
