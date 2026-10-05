extends Node2D

const TILE := 128
const GRASS = preload("res://Sprites/cainos/TX Tileset Grass.png")
const STONE = preload("res://Sprites/cainos/TX Tileset Stone Ground.png")
const WALL = preload("res://Sprites/cainos/TX Tileset Wall.png")
const PROPS = preload("res://Sprites/cainos/TX Props.png")
const PLANTS = preload("res://Sprites/cainos/TX Plant.png")
const GROUND_DETAIL_SCRIPT = preload("res://first_level_ground.gd")
const GATE_SCRIPT = preload("res://room_gate.gd")
const ARCHER_SCENE = preload("res://archer.tscn")
const MINIMAP_SCRIPT = preload("res://level_minimap.gd")
const TRAINING_DUMMY_SCENE = preload("res://training_dummy.tscn")
const PORTAL_SCRIPT = preload("res://altar_portal.gd")

var rooms: Array[Dictionary] = []
var links: Array[Dictionary] = []
var floor_cells: Dictionary = {}
var blockers: Array[Rect2] = []
var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var decoration_root: Node2D
var current_room := -1
var active_room := -1
var started := false
var completed := false
var minimap: Control
var player: CharacterBody2D
var manager: Node2D
var training_dummy: CharacterBody2D
var portal: Node2D

func _ready():
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	y_sort_enabled = true
	build_layout()
	build_floor()
	build_walls()
	build_decorations()
	build_gates()
	setup_level.call_deferred()

func build_layout():
	# Six combat rooms in a connected route. The seeded variant changes the
	# final turn; the boss is always the final node of the graph.
	var turn := -1 if randi() % 2 == 0 else 1
	var grid: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, -1), Vector2i(2, -1), Vector2i(2, 0), Vector2i(3, 0), Vector2i(3, turn)]
	for index in range(grid.size()):
		var boss_room := index == grid.size() - 1
		var size := Vector2i(22, 14) if boss_room else Vector2i(16, 10)
		var center := grid[index] * Vector2i(29, 23)
		var tiles := Rect2i(center - size / 2, size)
		rooms.append({"id": index, "grid": grid[index], "tiles": tiles,
			"bounds": room_rect(tiles), "boss": boss_room, "entered": false, "cleared": false,
			"enemies": [], "gates": []})
	for index in range(rooms.size() - 1):
		var from: Rect2i = rooms[index].tiles
		var to: Rect2i = rooms[index + 1].tiles
		var corridor: Rect2i
		var gate_rect: Rect2
		var arrival_gate_rect: Rect2
		if from.get_center().x != to.get_center().x:
			corridor = Rect2i(from.end.x, from.get_center().y - 2, to.position.x - from.end.x, 4)
			gate_rect = Rect2(corridor.position.x * TILE - 16, corridor.position.y * TILE, 32, 4 * TILE)
			arrival_gate_rect = Rect2(to.position.x*TILE-16,corridor.position.y*TILE,32,4*TILE)
		else:
			var upper := from if from.get_center().y < to.get_center().y else to
			var lower := to if from.get_center().y < to.get_center().y else from
			corridor = Rect2i(from.get_center().x - 2, upper.end.y, 4, lower.position.y - upper.end.y)
			var doorway_y := from.position.y if to.get_center().y < from.get_center().y else from.end.y
			gate_rect = Rect2(corridor.position.x * TILE, doorway_y * TILE - 16, 4 * TILE, 32)
			var arrival_y := to.end.y if to.get_center().y < from.get_center().y else to.position.y
			arrival_gate_rect = Rect2(corridor.position.x*TILE,arrival_y*TILE-16,4*TILE,32)
		links.append({"from": index, "to": index + 1, "tiles": corridor, "gate_rect": gate_rect,"arrival_gate_rect":arrival_gate_rect})

func world_bounds() -> Rect2:
	var bounds: Rect2 = rooms[0].bounds
	for room in rooms:
		bounds = bounds.merge(room.bounds)
	return bounds.grow(1600.0)

func room_rect(room: Rect2i) -> Rect2:
	return Rect2(Vector2(room.position) * TILE, Vector2(room.size) * TILE)

func make_layer(layer_name: String, textures: Array[Texture2D], order: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.z_index = order
	layer.scale = Vector2(4, 4)
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(32, 32)
	for index in range(textures.size()):
		var source := TileSetAtlasSource.new()
		source.texture = textures[index]
		source.texture_region_size = Vector2i(32, 32)
		for x in range(textures[index].get_width() / 32):
			for y in range(textures[index].get_height() / 32):
				source.create_tile(Vector2i(x, y))
		tiles.add_source(source, index)
	layer.tile_set = tiles
	add_child(layer)
	return layer

func build_floor():
	var garden := make_layer("OuterGarden", [GRASS], -10)
	garden.modulate = Color(0.52, 0.65, 0.55)
	var bounds := world_bounds()
	for x in range(floori(bounds.position.x / TILE), ceili(bounds.end.x / TILE)):
		for y in range(floori(bounds.position.y / TILE), ceili(bounds.end.y / TILE)):
			garden.set_cell(Vector2i(x, y), 0, Vector2i(posmod(x * 3 + y, 8), posmod(y * 5 + x, 4)))
	floor_layer = make_layer("Ground", [GRASS, STONE], -8)
	var areas: Array[Rect2i] = []
	for room in rooms:
		areas.append(room.tiles)
	for link in links:
		areas.append(link.tiles)
	for area in areas:
		for x in range(area.position.x, area.end.x):
			for y in range(area.position.y, area.end.y):
				var cell := Vector2i(x, y)
				floor_cells[cell] = true
				floor_layer.set_cell(cell, 0, Vector2i(posmod(x + y * 3, 8), posmod(y + x, 4)))
	var paved: Array[Rect2] = []
	for room in rooms:
		var center: Vector2i = room.tiles.get_center()
		var size := Vector2i(14, 8) if room.boss else Vector2i(10, 6)
		var area := Rect2i(center - size / 2, size)
		paved.append(room_rect(area))
		for x in range(area.position.x, area.end.x):
			for y in range(area.position.y, area.end.y):
				var column := 0 if x == area.position.x else (2 if x == area.end.x - 1 else 1)
				var row := 0 if y == area.position.y else (2 if y == area.end.y - 1 else 1)
				floor_layer.set_cell(Vector2i(x, y), 1, Vector2i(column, row))
	# The corridors use small stone stepping tiles, clearly visible between rooms.
	for link in links:
		var area: Rect2i = link.tiles
		for x in range(area.position.x, area.end.x):
			for y in range(area.position.y, area.end.y):
				floor_layer.set_cell(Vector2i(x, y), 0, Vector2i(4 + posmod(x, 2), 4 + posmod(y, 2)))
	var ground := Node2D.new()
	ground.set_script(GROUND_DETAIL_SCRIPT)
	ground.z_index = -7
	add_child(ground)
	ground.setup(paved)

func build_walls():
	wall_layer = make_layer("BoundaryStone", [WALL], -5)
	var border: Dictionary = {}
	for cell in floor_cells:
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + step
			if not floor_cells.has(neighbor):
				border[neighbor] = true
	for cell in border:
		var tile := Vector2i(5, 1)
		if floor_cells.has(cell + Vector2i.UP): tile = Vector2i(5, 3)
		elif floor_cells.has(cell + Vector2i.RIGHT): tile = Vector2i(4, 2)
		elif floor_cells.has(cell + Vector2i.LEFT): tile = Vector2i(7, 2)
		wall_layer.set_cell(cell, 0, tile)
		add_blocker(Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE)))

func add_blocker(rect: Rect2):
	var wall := StaticBody2D.new()
	wall.collision_layer = 4
	wall.collision_mask = 0
	wall.position = rect.get_center()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	wall.add_child(collider)
	add_child(wall)
	blockers.append(rect)

func prop(texture: Texture2D, crop: Rect2, location: Vector2, blocks := false, footprint := Vector2(65, 50), grounded := false):
	var sprite := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = crop
	sprite.texture = atlas
	sprite.scale = Vector2(4, 4)
	sprite.position = location
	sprite.offset = Vector2.ZERO if grounded else Vector2(0,-crop.size.y*0.5)
	if grounded:
		sprite.z_index = -6
		sprite.name = "BossRelic"
		add_child(sprite)
	else:
		decoration_root.add_child(sprite)
	if blocks: add_blocker(Rect2(location - footprint * 0.5, footprint))

func build_decorations():
	decoration_root = Node2D.new()
	decoration_root.y_sort_enabled = true
	add_child(decoration_root)
	for room in rooms:
		var bounds: Rect2 = room.bounds
		for x in [bounds.position.x + 190, bounds.end.x - 190]:
			for y in [bounds.position.y + 280, bounds.end.y - 130]:
				prop(PROPS, Rect2(352, 160, 32, 96), Vector2(x, y), true, Vector2(90, 75))
		prop(PLANTS, Rect2(8, 12, 128, 144), bounds.position + Vector2(-200, -180))
		prop(PLANTS, Rect2(8, 12, 128, 144), bounds.end + Vector2(200, 320))
		if room.boss:
			prop(PROPS, Rect2(352, 270, 96, 72), bounds.get_center()+Vector2(0,-300),false,Vector2.ZERO,true)
			prop(PROPS, Rect2(448, 16, 48, 80), bounds.position + Vector2(400, 460), true)
		else:
			prop(PROPS, Rect2(160, 16, 32, 32), bounds.position + Vector2(400, 290), true, Vector2(90, 65))
			prop(PROPS, Rect2(160, 150, 32, 40), bounds.end - Vector2(420, 180), true)
			prop(PLANTS, Rect2(92, 190, 36, 40), bounds.end - Vector2(300, 90))

func build_gates():
	for link in links:
		var gate := StaticBody2D.new()
		gate.set_script(GATE_SCRIPT)
		add_child(gate)
		gate.setup(link.gate_rect)
		link.gate = gate
		rooms[link.from].gates.append(gate)
		var arrival := StaticBody2D.new()
		arrival.set_script(GATE_SCRIPT)
		add_child(arrival)
		arrival.setup(link.arrival_gate_rect)
		link.arrival_gate = arrival
		rooms[link.to].gates.append(arrival)
		# Unvisited rooms stay locked from the preceding side until it is cleared.
		gate.set_sealed(true)
		arrival.set_sealed(true)

func setup_level():
	var world := get_parent()
	world.y_sort_enabled = true
	world.get_node("Background").hide()
	world.get_node("starsky").hide()
	player = world.get_node("Player")
	player.position = rooms[0].bounds.get_center()
	player.collision_mask = 6
	player.normal_collision_mask = 6
	world.get_node("Camera2D").position = player.position
	manager = world.get_node("GameManager")
	manager.level_map = self
	minimap = Control.new()
	minimap.set_script(MINIMAP_SCRIPT)
	minimap.name = "Minimap"
	manager.canvas.add_child(minimap)
	minimap.setup(self)
	manager.canvas.move_child(manager.death_ui, manager.canvas.get_child_count() - 1)
	current_room = 0
	if get_tree().has_meta("start_from_menu"):
		get_tree().remove_meta("start_from_menu")
		manager.start_game()

func _physics_process(_delta: float):
	if not is_instance_valid(manager) or not manager.game_started or manager.game_over:
		return
	if not started:
		started = true
		enter_room(0)
	for room in rooms:
		if room.bounds.has_point(player.global_position):
			current_room = room.id
			if not room.entered and (room.id == 0 or rooms[room.id - 1].cleared):
				enter_room(room.id)
			break
	if active_room >= 0:
		var room: Dictionary = rooms[active_room]
		var alive := false
		for enemy in room.enemies:
			if is_instance_valid(enemy) and not enemy.is_dead:
				alive = true
				break
		if not alive:
			clear_room(active_room)
	minimap.queue_redraw()

func enter_room(index: int):
	var room: Dictionary = rooms[index]
	if room.entered: return
	room.entered = true
	active_room = index
	for gate in room.gates: gate.set_sealed(true)
	# A room's combat starts only when entered; no shooting through unopened rooms.
	if room.boss:
		manager.spawn_boss(1, room.bounds.get_center() + Vector2(460, 0))
		var boss = get_tree().get_first_node_in_group("boss")
		boss.arena_bounds = room.bounds.grow(-220.0)
		boss.collision_mask = 6
		boss.collision_layer = 2
		boss.room_id = index
		room.enemies.append(boss)
	else:
		var count := 4 + mini(index, 3)
		for number in range(count):
			var is_archer := number % 3 == 1
			var enemy = ARCHER_SCENE.instantiate() if is_archer else manager.enemy_template.instantiate()
			get_parent().add_child(enemy)
			var angle := TAU * float(number) / count + 0.35
			var offset := Vector2(cos(angle) * 610, sin(angle) * 360)
			enemy.setup_spawn(room.bounds.get_center() + offset, player, index * 0.35)
			enemy.collision_layer = 2
			enemy.collision_mask = 7
			enemy.set_meta("room_id", index)
			room.enemies.append(enemy)
	manager.timer_label.text = "断剑遗庭 · " + ("剑魔庭院" if room.boss else "战斗房 " + str(index + 1))

func clear_room(index: int):
	var room: Dictionary = rooms[index]
	if room.cleared: return
	room.cleared = true
	active_room = -1
	for gate in room.gates: gate.set_sealed(false)
	for link in links:
		if link.from == index: link.arrival_gate.set_sealed(false)
	# Projectiles vanish when the encounter ends, so a cleared room is safe.
	for arrow in get_tree().get_nodes_in_group("enemy_arrow"):
		arrow.queue_free()
	if not room.boss:
		player.add_aura(60.0)
	else:
		manager.timer_label.text = "断剑遗庭 · 剑魂待拾取"
		spawn_portal()

func complete_level():
	completed = true
	manager.timer_label.text = "第一关完成 · 剑魂已获得"
	if is_instance_valid(portal): portal.activate()

func spawn_portal():
	if is_instance_valid(portal): return
	portal = Node2D.new()
	portal.set_script(PORTAL_SCRIPT)
	get_parent().add_child(portal)
	portal.setup(self, get_node("BossRelic").global_position)

func safe_sword_position(candidate: Vector2) -> bool:
	if not floor_cells.has(Vector2i(floori(candidate.x / TILE), floori(candidate.y / TILE))): return false
	if not constrain_position(candidate).is_equal_approx(candidate): return false
	# Stay in the same room; blink cannot bypass walls or a sealed encounter gate.
	var source_room := -1
	var destination_room := -1
	for room in rooms:
		if room.bounds.has_point(player.global_position): source_room = room.id
		if room.bounds.has_point(candidate): destination_room = room.id
	if source_room < 0 or source_room != destination_room: return false
	if is_instance_valid(portal) and candidate.distance_to(portal.global_position) < portal.trigger_radius + 45: return false
	var obstacle := PhysicsRayQueryParameters2D.create(player.global_position, candidate, 4)
	if not get_world_2d().direct_space_state.intersect_ray(obstacle).is_empty(): return false
	var shape := CircleShape2D.new()
	shape.radius = 75.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, candidate)
	query.collision_mask = 6
	query.exclude = [player.get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 64).is_empty()

func spawn_training_dummy():
	if is_instance_valid(training_dummy) or not player.sword_unlocked or not rooms[-1].cleared:
		return
	var bounds: Rect2 = rooms[-1].bounds.grow(-200.0)
	var toward_center := (bounds.get_center() - player.global_position).normalized()
	if toward_center == Vector2.ZERO:
		toward_center = Vector2.RIGHT
	training_dummy = TRAINING_DUMMY_SCENE.instantiate()
	get_parent().add_child(training_dummy)
	training_dummy.global_position = (player.global_position + toward_center * 260.0).clamp(bounds.position, bounds.end)

func constrain_position(value: Vector2, margin: float = 85.0) -> Vector2:
	if active_room >= 0:
		var bounds: Rect2 = rooms[active_room].bounds.grow(-margin)
		return value.clamp(bounds.position, bounds.end)
	var cell := Vector2i(floori(value.x / TILE), floori(value.y / TILE))
	if floor_cells.has(cell):
		var point := value
		if not floor_cells.has(cell + Vector2i.LEFT): point.x = maxf(point.x, cell.x * TILE + margin)
		if not floor_cells.has(cell + Vector2i.RIGHT): point.x = minf(point.x, (cell.x + 1) * TILE - margin)
		if not floor_cells.has(cell + Vector2i.UP): point.y = maxf(point.y, cell.y * TILE + margin)
		if not floor_cells.has(cell + Vector2i.DOWN): point.y = minf(point.y, (cell.y + 1) * TILE - margin)
		return point
	var nearest := Vector2.ZERO
	var best := INF
	var areas: Array[Rect2] = []
	for room in rooms: areas.append(room.bounds)
	for link in links: areas.append(room_rect(link.tiles))
	for area in areas:
		var inner := area.grow(-margin)
		var candidate := value.clamp(inner.position, inner.end)
		var distance := candidate.distance_squared_to(value)
		if distance < best:
			best = distance
			nearest = candidate
	return nearest
