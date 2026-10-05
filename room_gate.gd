extends StaticBody2D

var sealed := false
var barrier: CollisionShape2D
var horizontal := false
var gate_size := Vector2(440, 45)

func setup(rect: Rect2):
	position = rect.get_center()
	gate_size = rect.size
	horizontal = gate_size.x > gate_size.y
	collision_layer = 4
	collision_mask = 0
	barrier = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = gate_size
	barrier.shape = shape
	barrier.disabled = true
	add_child(barrier)
	queue_redraw()

func set_sealed(value: bool):
	sealed = value
	barrier.set_deferred("disabled", not value)
	queue_redraw()

func _draw():
	if not sealed:
		return
	draw_rect(Rect2(-gate_size * 0.5, gate_size), Color(0.56, 0.17, 0.76, 0.65))
	var extent := gate_size * 0.5
	for index in range(-4, 5):
		if horizontal:
			draw_line(Vector2(index * extent.x / 4.0, -extent.y), Vector2(index * extent.x / 4.0, extent.y), Color(0.95, 0.6, 1.0), 3.0)
		else:
			draw_line(Vector2(-extent.x, index * extent.y / 4.0), Vector2(extent.x, index * extent.y / 4.0), Color(0.95, 0.6, 1.0), 3.0)
