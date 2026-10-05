extends AnimatedSprite2D

const SKIN_SHADER = preload("res://boss_skin.gdshader")
const SHEET = preload("res://Sprites/nightborne/NightBorne.png")
const CLIPS = [
	["idle", 0, 0, 9, 9.0, true], ["walk", 1, 0, 6, 12.0, true],
	["dash", 1, 0, 6, 24.0, true], ["attack", 2, 0, 12, 20.0, false],
	["cast", 2, 2, 4, 6.0, true], ["hurt", 3, 0, 5, 24.0, false],
	["death", 4, 0, 23, 20.0, false]
]
var body_size := 0.0

func _ready():
	sprite_frames = SpriteFrames.new()
	sprite_frames.remove_animation("default")
	for clip in CLIPS:
		var key := StringName(clip[0])
		sprite_frames.add_animation(key)
		sprite_frames.set_animation_loop(key, clip[5])
		sprite_frames.set_animation_speed(key, clip[4])
		for index in range(clip[3]):
			var frame_texture := AtlasTexture.new()
			frame_texture.atlas = SHEET
			frame_texture.region = Rect2((index + clip[2]) * 80, clip[1] * 80, 80, 80)
			sprite_frames.add_frame(key, frame_texture)
	# Compatibility with the existing spawn/size regression test.
	for side in ["left", "right"]:
		var key := StringName("run_" + side)
		sprite_frames.add_animation(key)
		for index in range(6):
			sprite_frames.add_frame(key, sprite_frames.get_frame_texture("walk", index))
	var skin := ShaderMaterial.new()
	skin.shader = SKIN_SHADER
	material = skin
	var image := sprite_frames.get_frame_texture("idle", 0).get_image()
	var bounds := image.get_used_rect()
	body_size = maxf(bounds.size.x, bounds.size.y)
	# The armor's center is below the cell's center; align it with the hurtbox.
	offset = Vector2(0, -11)
	play("idle")

func set_action(action: String, direction: Vector2):
	if absf(direction.x) > 0.1:
		flip_h = direction.x < 0.0
	if animation != StringName(action):
		play(action)

func set_energy(raging: bool, charging: bool, flash: float):
	material.set_shader_parameter("rage", 1.0 if raging else 0.0)
	material.set_shader_parameter("charge", 1.0 if charging else 0.0)
	material.set_shader_parameter("hit_flash", flash)
