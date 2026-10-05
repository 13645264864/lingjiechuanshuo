extends Node2D

var radius := 235.0
var phase := 0.0
var power := 0.0
var raging := false
var extinguishing := false
var sparks := CPUParticles2D.new()

func _ready():
	sparks.amount = 38
	sparks.lifetime = 0.7
	sparks.direction = Vector2.UP
	sparks.spread = 25.0
	sparks.gravity = Vector2(0, -40)
	sparks.initial_velocity_min = 30.0
	sparks.initial_velocity_max = 75.0
	sparks.scale_amount_min = 0.7
	sparks.scale_amount_max = 1.25
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	var points := PackedVector2Array()
	for index in range(64):
		var angle := TAU * float(index) / 64.0
		points.append(Vector2(cos(angle) * radius, 120 + sin(angle) * radius * 0.42))
	sparks.emission_points = points
	var image := Image.create(12, 24, false, Image.FORMAT_RGBA8)
	for y in range(24):
		for x in range(12):
			var distance := absf((x - 5.5) / 5.5) + absf((y - 11.5) / 11.5)
			image.set_pixel(x, y, Color(0.45, 1.0, 0.88, maxf(1.0 - distance, 0.0)))
	sparks.texture = ImageTexture.create_from_image(image)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.65))
	fade.set_color(1, Color(1, 1, 1, 0))
	sparks.color_ramp = fade
	add_child(sparks)

func _process(delta: float):
	phase += delta * (1.5 if raging else 0.65)
	if extinguishing:
		sparks.emitting = false
		modulate.a = maxf(modulate.a - delta * 1.4, 0.0)
	sparks.color = Color(1.0, 0.16, 0.62) if raging else Color(0.78, 0.35, 1.0)
	queue_redraw()

func _draw():
	var cyan := Color(0.65, 0.2, 1.0, 0.3 + power * 0.38)
	var gold := Color(0.85, 0.65, 1.0, 0.4 + power * 0.45)
	if raging:
		cyan = Color(1.0, 0.16, 0.62, 0.5 + power * 0.4)
	var center := Vector2(0, 120)
	var polygon := PackedVector2Array()
	for i in range(64):
		var angle := TAU * float(i) / 64.0
		polygon.append(center + Vector2(cos(angle), sin(angle) * 0.42) * radius)
	draw_polyline(polygon + PackedVector2Array([polygon[0]]), Color(cyan, 0.14), 10.0, true)
	draw_polyline(polygon + PackedVector2Array([polygon[0]]), cyan, 2.0, true)
	for i in range(12):
		var angle := phase + float(i) * TAU / 12.0
		var radial := Vector2(cos(angle), sin(angle) * 0.42)
		var tangent := Vector2(-sin(angle), cos(angle) * 0.42)
		var point := center + radial * radius * 0.82
		draw_line(point - tangent * 7.0, point + tangent * 7.0, gold, 2.0, true)
		draw_line(point - radial * 10.0, point + radial * 10.0, gold, 2.0, true)
	for i in range(6):
		var angle := -phase * 0.8 + float(i) * TAU / 6.0
		var point := center + Vector2(cos(angle), sin(angle) * 0.42) * radius * 1.02
		var star := PackedVector2Array([point + Vector2(0, -22), point + Vector2(6, 0), point + Vector2(0, 9), point + Vector2(-6, 0)])
		draw_colored_polygon(star, gold)
	# Six floating sword shards echo the approved purple-blade silhouette.
	var crown := Vector2(0, -90)
	for index in range(6):
		var angle := phase * 0.3 + float(index) * TAU / 6.0
		var tip := crown + Vector2(cos(angle) * 170, sin(angle) * 100)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -32), tip + Vector2(5, 0), tip + Vector2(0, 14), tip + Vector2(-5, 0)]), Color(cyan, 0.55 + power * 0.4))
		draw_line(tip + Vector2(0, -28), tip + Vector2(0, 10), gold, 2.0, true)
	if power > 0.0:
		for i in range(5):
			var angle := phase * 2.0 + i * TAU / 5.0
			var point := Vector2.from_angle(angle) * radius * 0.5
			draw_line(point, point + Vector2(0, -35 - power * 30), Color(cyan, power * 0.45), 3.0, true)
