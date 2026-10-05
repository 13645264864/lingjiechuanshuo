extends "res://touch_action_button.gd"

var player: CharacterBody2D

func _ready():
	tooltip_text = "剑魂附身"
	text = ""
	add_theme_stylebox_override("normal", _style(Color(0.13,0.08,0.2,0.88)))
	add_theme_stylebox_override("hover", _style(Color(0.25,0.12,0.4,0.95)))
	add_theme_stylebox_override("pressed", _style(Color(0.4,0.2,0.6,0.95)))
	add_theme_stylebox_override("disabled", _style(Color(0.1,0.12,0.12,0.7)))

func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.7,0.3,1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style

func _process(_delta: float):
	if not is_instance_valid(player): return
	visible = player.sword_unlocked and not player.is_dead and (not is_instance_valid(player.gm) or not player.gm.ending_in_progress)
	disabled = player.sword_cooldown_left > 0 or player.sword_time_left > 0
	queue_redraw()

func _draw():
	if not is_instance_valid(player): return
	var center := size*0.5
	var brightness := 0.4 if disabled else 1.0
	draw_colored_polygon(PackedVector2Array([center+Vector2(19,-28),center+Vector2(10,0),center+Vector2(-10,13),center+Vector2(-15,5)]),Color(0.85,0.55,1,brightness))
	draw_line(center+Vector2(-14,8),center+Vector2(-25,23),Color(1,0.78,0.35,brightness),5,true)
	draw_line(center+Vector2(-20,1),center+Vector2(-4,15),Color(0.78,0.3,1,brightness),5,true)
	var remaining: float = player.sword_time_left if player.sword_time_left > 0 else player.sword_cooldown_left
	if remaining > 0:
		var maximum := 10.0 if player.sword_time_left > 0 else 50.0
		draw_arc(center, minf(size.x,size.y)*0.44,-PI/2,-PI/2+TAU*remaining/maximum,48,Color(0.75,0.35,1),3,true)
		draw_string(get_theme_default_font(),Vector2(center.x-13,size.y-10),str(ceili(remaining)),HORIZONTAL_ALIGNMENT_CENTER,26,16,Color.WHITE)
