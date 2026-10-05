extends "res://enemy.gd"

const SHEET = preload("res://Sprites/arcane_archer/spritesheet.png")
const ARROW_SCRIPT = preload("res://enemy_arrow.gd")
var shot_timer := 1.0
var windup_left := 0.0
var locked_direction := Vector2.RIGHT
var shots_fired := 0

func _ready():
	super._ready()
	add_to_group("enemy")
	add_to_group("archer")
	scale = Vector2.ONE
	var sprite: AnimatedSprite2D = $AnimatedSprite2D
	sprite.scale = Vector2(4,4)
	sprite.offset = Vector2(0,-10)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for clip in [["idle",5,4,6.0,true], ["walk",2,7,10.0,true], ["shoot",3,7,12.0,false], ["death",1,8,12.0,false]]:
		frames.add_animation(clip[0])
		frames.set_animation_speed(clip[0], clip[3])
		frames.set_animation_loop(clip[0], clip[4])
		for index in range(clip[2]):
			var texture := AtlasTexture.new()
			texture.atlas = SHEET
			texture.region = Rect2(index * 64, clip[1] * 64, 64,64)
			frames.add_frame(clip[0],texture)
	sprite.sprite_frames = frames
	sprite.play("idle")

func apply_time_scaling(minutes: float):
	super.apply_time_scaling(minutes)
	max_hp *= 1.25
	hp = max_hp
	damage *= 0.8
	move_speed *= 1.1

func _physics_process(delta: float):
	if is_dead or not is_instance_valid(player) or player.is_dead: return
	var gm = get_parent().get_node_or_null("GameManager")
	if gm != null and gm.level_map != null and (not gm.game_started or gm.game_over): return
	shot_timer -= delta
	var to_player := player.global_position - global_position
	$AnimatedSprite2D.flip_h = to_player.x < 0.0
	if windup_left > 0.0:
		windup_left -= delta
		velocity = Vector2.ZERO
		queue_redraw()
		if windup_left <= 0.0:
			shoot_arrow()
			shot_timer = 1.75
		return
	queue_redraw()
	var visible_target := has_line_of_sight()
	if visible_target and to_player.length() < 850.0 and shot_timer <= 0.0:
		locked_direction = (to_player + player.velocity * 0.15).normalized()
		windup_left = 0.55
		$AnimatedSprite2D.play("shoot")
		$AnimatedSprite2D.set_frame_and_progress(0,0)
		return
	var direction := to_player.normalized()
	if to_player.length() < 330.0: direction = -direction
	elif visible_target and to_player.length() < 620.0: direction = Vector2.ZERO
	velocity = direction * move_speed
	$AnimatedSprite2D.play("walk" if direction != Vector2.ZERO else "idle")
	move_and_slide()
	if gm != null and gm.level_map != null and has_meta("room_id"):
		var bounds: Rect2 = gm.level_map.rooms[get_meta("room_id")].bounds.grow(-90)
		global_position = global_position.clamp(bounds.position,bounds.end)

func has_line_of_sight() -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 4)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func shoot_arrow():
	if not has_line_of_sight(): return
	var arrow := Node2D.new()
	arrow.set_script(ARROW_SCRIPT)
	get_parent().add_child(arrow)
	arrow.setup(global_position + locked_direction * 65, locked_direction, player, damage)
	shots_fired += 1

func take_damage(amount: float):
	if is_dead: return
	hp -= amount
	if tween != null: tween.kill()
	tween = create_tween()
	tween.tween_property($AnimatedSprite2D,"modulate",Color(2,2,2),0.06)
	tween.tween_property($AnimatedSprite2D,"modulate",Color.WHITE,0.12)
	if hp <= 0.0:
		is_dead = true
		collision_layer = 0
		collision_mask = 0
		$CollisionShape2D.set_deferred("disabled",true)
		remove_from_group("enemy")
		$AnimatedSprite2D.play("death")
		if aura_drop_scene != null:
			var aura = aura_drop_scene.instantiate()
			get_parent().add_child(aura)
			aura.global_position = global_position
		var death_tween := create_tween()
		death_tween.tween_interval(0.7)
		death_tween.tween_callback(queue_free)

func _draw():
	if windup_left <= 0 or is_dead: return
	draw_line(locked_direction*50,locked_direction*230,Color(0.85,0.3,1,0.55),2,true)
	draw_arc(Vector2.ZERO,52,locked_direction.angle()-0.6,locked_direction.angle()+0.6,12,Color(0.95,0.6,1,0.7),3,true)
