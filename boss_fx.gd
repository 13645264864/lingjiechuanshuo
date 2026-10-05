extends Node2D

## Lightweight procedural telegraph / after-image effect for the boss.
var mode: String = "telegraph"
var tint: Color = Color(0.8, 0.2, 1.0)
var radius: float = 100.0
var life_left: float = 0.5
var max_life: float = 0.5
var spin: float = 0.0

func setup(effect_mode: String, effect_color: Color, effect_radius: float, duration: float):
	mode = effect_mode
	tint = effect_color
	radius = effect_radius
	life_left = duration
	max_life = duration
	z_index = -2
	queue_redraw()

func _process(delta: float):
	life_left -= delta
	spin += delta * 3.0
	if life_left <= 0.0:
		queue_free()
	else:
		queue_redraw()

func _draw():
	var fade := clampf(life_left / maxf(max_life, 0.01), 0.0, 1.0)
	if mode == "afterimage":
		draw_circle(Vector2.ZERO, radius, Color(tint, 0.15 * fade))
		draw_arc(Vector2.ZERO, radius * 0.86, 0.0, TAU, 28, Color(tint, 0.55 * fade), 5.0)
		return
	if mode == "blink":
		for i in range(3):
			var rr := radius * (0.35 + float(i) * 0.25) + (1.0 - fade) * radius * 0.35
			draw_arc(Vector2.ZERO, rr, spin + i, spin + i + PI * 1.45, 20, Color(tint, 0.72 * fade), 4.0)
		return
	# Telegraph ring with a rotating broken arc and a bright center cross.
	draw_circle(Vector2.ZERO, radius, Color(tint, 0.08 * fade))
	draw_arc(Vector2.ZERO, radius, spin, spin + PI * 1.25, 24, Color(tint, 0.9 * fade), 5.0)
	draw_arc(Vector2.ZERO, radius * 0.72, spin + PI, spin + PI * 2.35, 24, Color(1.0, 0.75, 1.0, 0.7 * fade), 3.0)
	draw_line(Vector2(-radius * 0.22, 0), Vector2(radius * 0.22, 0), Color(tint, 0.8 * fade), 3.0)
	draw_line(Vector2(0, -radius * 0.22), Vector2(0, radius * 0.22), Color(tint, 0.8 * fade), 3.0)
