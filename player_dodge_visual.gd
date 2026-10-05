extends Node2D

var pose := Polygon2D.new()
var ground_shadow := Polygon2D.new()
var direction := Vector2.DOWN
var sprite_frames: SpriteFrames
var animation_name: StringName
var elapsed_ratio := 0.0
var original_position := Vector2.ZERO
var original_scale := Vector2.ONE

func _ready():
	ground_shadow.color = Color(0.02,0.06,0.09,0.18)
	add_child(ground_shadow)
	add_child(pose)
	visible = false

func begin(source: AnimatedSprite2D, dash_direction: Vector2):
	direction = dash_direction
	sprite_frames = source.sprite_frames
	animation_name = StringName("run_" + _facing(direction))
	original_position = source.position
	original_scale = source.scale
	visible = true
	update_pose(0.0)

func _facing(value: Vector2) -> String:
	if absf(value.x) > absf(value.y):
		return "right" if value.x > 0 else "left"
	return "down" if value.y >= 0 else "up"

func update_pose(progress: float):
	elapsed_ratio = clampf(progress,0,1)
	# Hold the authored forward-running pose for the entire grounded dash.
	pose.texture = sprite_frames.get_frame_texture(animation_name,0)
	var size := pose.texture.get_size()
	pose.polygon = PackedVector2Array([-size*0.5,Vector2(size.x*0.5,-size.y*0.5),size*0.5,Vector2(-size.x*0.5,size.y*0.5)])
	pose.uv = PackedVector2Array([Vector2.ZERO,Vector2(size.x,0),size,Vector2(0,size.y)])
	pose.position = original_position
	pose.scale = original_scale
	pose.rotation = 0
	var shadow := PackedVector2Array()
	for index in range(24):
		var angle := TAU*index/24.0
		shadow.append(Vector2(cos(angle)*43,sin(angle)*9))
	ground_shadow.polygon = shadow
	ground_shadow.position = original_position+Vector2(0,size.y*0.44*original_scale.y)
