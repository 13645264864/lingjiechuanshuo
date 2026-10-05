extends Node2D

var direction := Vector2.RIGHT
var damage := 16.0
var life := 1.0
var hit_enemies: Array = []

func setup(origin: Vector2, aim: Vector2, hit_damage: float):
	position = origin
	direction = aim
	damage = hit_damage
	z_index = 2

func _physics_process(delta: float):
	life -= delta
	if life <= 0:
		queue_free()
		return
	var previous := global_position
	position += direction * 560 * delta
	var wall := PhysicsRayQueryParameters2D.create(previous,global_position,4)
	if not get_world_2d().direct_space_state.intersect_ray(wall).is_empty():
		queue_free()
		return
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy.is_dead and not hit_enemies.has(enemy) and global_position.distance_to(enemy.global_position) < 100:
			hit_enemies.append(enemy)
			enemy.take_damage(damage)
	queue_redraw()

func _draw():
	var angle := direction.angle()
	draw_arc(-direction*25,65,angle-0.9,angle+0.9,20,Color(0.8,0.3,1,life),10,true)
