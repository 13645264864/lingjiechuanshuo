extends Node2D

var collected := false
var phase := 0.0

func _ready():
	add_to_group("sword_drop")
	z_index = 1

func _physics_process(delta: float):
	phase += delta
	queue_redraw()
	if collected: return
	var player = get_parent().get_node_or_null("Player")
	var gm = get_parent().get_node_or_null("GameManager")
	if player == null or player.is_dead or (gm != null and gm.game_over): return
	if player.global_position.distance_to(global_position) < 100.0:
		collected = true
		player.unlock_sword_form()
		queue_free()

func _draw():
	var lift := sin(phase * 3.0) * 5.0
	draw_circle(Vector2.ZERO,40,Color(0.65,0.2,1,0.12))
	draw_arc(Vector2.ZERO,45,0,TAU,32,Color(0.85,0.5,1,0.75),3,true)
	draw_line(Vector2(0,-180),Vector2.ZERO,Color(0.78,0.3,1,0.15),22,true)
	draw_colored_polygon(PackedVector2Array([Vector2(0,-90+lift),Vector2(9,-40+lift),Vector2(0,-12+lift),Vector2(-9,-40+lift)]),Color(0.88,0.65,1.0))
	draw_line(Vector2(0,-18+lift),Vector2(0,15+lift),Color(1,0.85,0.4),6,true)
	draw_line(Vector2(-20,-18+lift),Vector2(20,-18+lift),Color(0.8,0.3,1),6,true)
