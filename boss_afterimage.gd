extends Sprite2D

var life_left := 0.23

func setup(source: AnimatedSprite2D, tint: Color):
	texture = source.sprite_frames.get_frame_texture(source.animation, source.frame)
	flip_h = source.flip_h
	offset = source.offset
	global_transform = source.global_transform
	modulate = Color(tint, 0.45)
	z_index = 0
	add_to_group("boss_afterimage")

func _process(delta: float):
	life_left -= delta
	modulate.a = maxf(life_left / 0.23 * 0.45, 0.0)
	if life_left <= 0.0:
		queue_free()
