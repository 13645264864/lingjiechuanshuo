extends Node2D

const TEXTURE = preload("res://Sprites/arcane_archer/projectile.png")
var direction := Vector2.RIGHT
var target: CharacterBody2D
var damage := 8.0
var speed := 460.0
var life_left := 3.0
var travelled := 0.0

func setup(origin: Vector2, aim: Vector2, victim: CharacterBody2D, hit_damage: float):
	position = origin
	direction = aim.normalized()
	target = victim
	damage = hit_damage
	add_to_group("enemy_arrow")
	z_index = 2
	queue_redraw()

func _physics_process(delta: float):
	life_left -= delta
	if life_left <= 0 or not is_instance_valid(target) or target.is_dead:
		queue_free()
		return
	var gm = get_parent().get_node_or_null("GameManager")
	if gm != null and gm.level_map != null and gm.game_over: return
	var previous := global_position
	global_position += direction * speed * delta
	travelled += speed * delta
	var query := PhysicsRayQueryParameters2D.create(previous,global_position,5)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if hit.collider == target: target.take_damage(damage)
		queue_free()
	queue_redraw()

func _draw():
	draw_line(-direction * 50,Vector2.ZERO,Color(0.82,0.24,1,0.35),5,true)
	draw_set_transform(Vector2.ZERO,direction.angle(),Vector2(2.4,2.4))
	draw_texture(TEXTURE,-TEXTURE.get_size()*0.5)
