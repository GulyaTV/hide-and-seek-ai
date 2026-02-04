extends Node2D

## Arena Manager for Hide and Seek
## Manages obstacles, hiding spots, and interactive elements

signal obstacle_destroyed(obstacle_id: String)
signal hiding_spot_used(spot_id: String, user: Node2D)

@export var arena_size: Vector2 = Vector2(1800, 1300)
@export var enable_dynamic_obstacles: bool = true
@export var obstacle_respawn_time: float = 30.0

var obstacles: Dictionary = {}
var hiding_spots: Dictionary = {}
var dynamic_elements: Array[Node2D] = []
var destroyed_obstacles: Array[Dictionary] = []

func _ready():
	setup_arena()
	print("Hide and Seek Arena initialized")

func setup_arena():
	# Инициализируем препятствия
	initialize_obstacles()
	
	# Инициализируем укрытия
	initialize_hiding_spots()
	
	# Настраиваем динамические элементы
	if enable_dynamic_obstacles:
		setup_dynamic_elements()

func initialize_obstacles():
	var obstacle_nodes = get_node_or_null("Obstacles")
	if not obstacle_nodes:
		return
	
	for i in range(obstacle_nodes.get_child_count()):
		var obstacle = obstacle_nodes.get_child(i)
		var obstacle_id = "obstacle_" + str(i)
		
		obstacles[obstacle_id] = {
			"node": obstacle,
			"position": obstacle.position,
			"size": get_obstacle_size(obstacle),
			"health": 100.0,
			"destructible": true,
			"respawn_timer": 0.0
		}
		
		# Добавляем collision detection
		if obstacle.has_signal("body_entered"):
			obstacle.body_entered.connect(_on_obstacle_collision.bind(obstacle_id))

func get_obstacle_size(obstacle: Node2D) -> Vector2:
	var collision_shape = obstacle.get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape is RectangleShape2D:
		return collision_shape.shape.size
	elif collision_shape and collision_shape.shape is CircleShape2D:
		var radius = collision_shape.shape.radius
		return Vector2(radius * 2, radius * 2)
	return Vector2(50, 50)

func initialize_hiding_spots():
	var spots_node = get_node_or_null("HidingSpots")
	if not spots_node:
		return
	
	for i in range(spots_node.get_child_count()):
		var spot = spots_node.get_child(i)
		var spot_id = "spot_" + str(i)
		
		hiding_spots[spot_id] = {
			"node": spot,
			"position": spot.position,
			"radius": get_spot_radius(spot),
			"occupied": false,
			"occupant": null,
			"visibility_bonus": 0.5,  # Снижение видимости на 50%
			"cooldown": 0.0
		}
		
		# Добавляем area detection
		if spot.has_signal("body_entered"):
			spot.body_entered.connect(_on_hiding_spot_entered.bind(spot_id))
		if spot.has_signal("body_exited"):
			spot.body_exited.connect(_on_hiding_spot_exited.bind(spot_id))

func get_spot_radius(spot: Area2D) -> float:
	var collision_shape = spot.get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape is CircleShape2D:
		return collision_shape.shape.radius
	return 30.0

func setup_dynamic_elements():
	# Создаем динамические элементы (движущиеся платформы, двери и т.д.)
	create_moving_platforms()
	create_interactive_doors()

func create_moving_platforms():
	# Создаем движущиеся платформы для усложнения геймплея
	var platform_positions = [
		Vector2(-200, 0),
		Vector2(200, 0),
		Vector2(0, -200),
		Vector2(0, 200)
	]
	
	for i in range(platform_positions.size()):
		var platform = create_moving_platform(platform_positions[i], i)
		dynamic_elements.append(platform)

func create_moving_platform(position: Vector2, index: int) -> Node2D:
	var platform = StaticBody2D.new()
	platform.name = "MovingPlatform_" + str(index)
	platform.position = position
	
	# Создаем collision
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(80, 20)
	collision.shape = shape
	platform.add_child(collision)
	
	# Создаем sprite
	var sprite = Sprite2D.new()
	sprite.modulate = Color(0.4, 0.4, 0.6, 1)
	platform.add_child(sprite)
	
	add_child(platform)
	
	# Добавляем движение
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(platform, "position:y", position.y + 100, 3.0)
	tween.tween_property(platform, "position:y", position.y - 100, 3.0)
	
	return platform

func create_interactive_doors():
	# Создаем интерактивные двери
	var door_positions = [
		Vector2(-400, 0),
		Vector2(400, 0)
	]
	
	for i in range(door_positions.size()):
		var door = create_interactive_door(door_positions[i], i)
		dynamic_elements.append(door)

func create_interactive_door(position: Vector2, index: int) -> Node2D:
	var door = StaticBody2D.new()
	door.name = "InteractiveDoor_" + str(index)
	door.position = position
	
	# Создаем collision
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(10, 80)
	collision.shape = shape
	door.add_child(collision)
	
	# Создаем sprite
	var sprite = Sprite2D.new()
	sprite.modulate = Color(0.6, 0.3, 0.3, 1)
	door.add_child(sprite)
	
	add_child(door)
	
	return door

func _physics_process(delta):
	update_dynamic_elements(delta)
	update_obstacle_respawn(delta)
	update_hiding_spots(delta)

func update_dynamic_elements(delta):
	# Обновляем динамические элементы
	for element in dynamic_elements:
		if element.has_method("update"):
			element.update(delta)

func update_obstacle_respawn(delta):
	# Обновляем таймеры респавна препятствий
	for obstacle_id in obstacles:
		var obstacle_data = obstacles[obstacle_id]
		if obstacle_data["respawn_timer"] > 0:
			obstacle_data["respawn_timer"] -= delta
			if obstacle_data["respawn_timer"] <= 0:
				respawn_obstacle(obstacle_id)

func update_hiding_spots(delta):
	# Обновляем кулдауны укрытий
	for spot_id in hiding_spots:
		var spot_data = hiding_spots[spot_id]
		if spot_data["cooldown"] > 0:
			spot_data["cooldown"] -= delta

func _on_obstacle_collision(obstacle_id: String, body: Node):
	if body is CharacterBody2D:
		var obstacle_data = obstacles[obstacle_id]
		if obstacle_data["destructible"] and obstacle_data["health"] > 0:
			damage_obstacle(obstacle_id, 10.0)

func damage_obstacle(obstacle_id: String, damage: float):
	var obstacle_data = obstacles[obstacle_id]
	obstacle_data["health"] -= damage
	
	if obstacle_data["health"] <= 0:
		destroy_obstacle(obstacle_id)

func destroy_obstacle(obstacle_id: String):
	var obstacle_data = obstacles[obstacle_id]
	obstacle_data["node"].visible = false
	obstacle_data["node"].set_process(false)
	
	# Добавляем в очередь на респавн
	destroyed_obstacles.append({
		"id": obstacle_id,
		"time": Time.get_time_dict_from_system()["second"],
		"respawn_time": obstacle_respawn_time
	})
	
	obstacle_destroyed.emit(obstacle_id)
	print("Obstacle destroyed: ", obstacle_id)

func respawn_obstacle(obstacle_id: String):
	var obstacle_data = obstacles[obstacle_id]
	obstacle_data["node"].visible = true
	obstacle_data["node"].set_process(true)
	obstacle_data["health"] = 100.0
	obstacle_data["respawn_timer"] = 0.0
	
	print("Obstacle respawned: ", obstacle_id)

func _on_hiding_spot_entered(spot_id: String, body: Node):
	if body is CharacterBody2D or body.has_method("is_seeker"):
		var spot_data = hiding_spots[spot_id]
		if not spot_data["occupied"]:
			occupy_hiding_spot(spot_id, body)

func _on_hiding_spot_exited(spot_id: String, body: Node):
	if body is CharacterBody2D or body.has_method("is_seeker"):
		var spot_data = hiding_spots[spot_id]
		if spot_data["occupant"] == body:
			vacate_hiding_spot(spot_id)

func occupy_hiding_spot(spot_id: String, user: Node2D):
	var spot_data = hiding_spots[spot_id]
	spot_data["occupied"] = true
	spot_data["occupant"] = user
	spot_data["cooldown"] = 2.0  # Кулдаун перед повторным использованием
	
	hiding_spot_used.emit(spot_id, user)
	print("Hiding spot occupied: ", spot_id, " by ", user.name)

func vacate_hiding_spot(spot_id: String):
	var spot_data = hiding_spots[spot_id]
	spot_data["occupied"] = false
	spot_data["occupant"] = null
	
	print("Hiding spot vacated: ", spot_id)

func get_available_hiding_spots() -> Array[String]:
	var available_spots: Array[String] = []
	
	for spot_id in hiding_spots:
		var spot_data = hiding_spots[spot_id]
		if not spot_data["occupied"] and spot_data["cooldown"] <= 0:
			available_spots.append(spot_id)
	
	return available_spots

func get_nearest_hiding_spot(position: Vector2) -> String:
	var nearest_spot = ""
	var min_distance = INF
	
	for spot_id in hiding_spots:
		var spot_data = hiding_spots[spot_id]
		if not spot_data["occupied"] and spot_data["cooldown"] <= 0:
			var distance = position.distance_to(spot_data["position"])
			if distance < min_distance:
				min_distance = distance
				nearest_spot = spot_id
	
	return nearest_spot

func get_obstacle_cover(position: Vector2) -> Vector2:
	var best_cover = Vector2.INF
	var min_distance = INF
	
	for obstacle_id in obstacles:
		var obstacle_data = obstacles[obstacle_id]
		if obstacle_data["health"] > 0:
			var distance = position.distance_to(obstacle_data["position"])
			if distance < min_distance and distance < 200:  # Максимальное расстояние для укрытия
				min_distance = distance
				best_cover = obstacle_data["position"]
	
	return best_cover

func is_position_covered(position: Vector2) -> bool:
	# Проверяет, находится ли позиция в укрытии
	for obstacle_id in obstacles:
		var obstacle_data = obstacles[obstacle_id]
		if obstacle_data["health"] > 0:
			var distance = position.distance_to(obstacle_data["position"])
			if distance < obstacle_data["size"].x / 2 + 20:  # Добавляем небольшой буфер
				return true
	
	return false

func get_visibility_modifier(position: Vector2) -> float:
	var modifier = 1.0
	
	# Проверяем укрытия
	for spot_id in hiding_spots:
		var spot_data = hiding_spots[spot_id]
		if spot_data["occupied"]:
			var distance = position.distance_to(spot_data["position"])
			if distance < spot_data["radius"]:
				modifier *= spot_data["visibility_bonus"]
	
	# Проверяем препятствия
	if is_position_covered(position):
		modifier *= 0.7  # Препятствия снижают видимость на 30%
	
	return modifier

func get_arena_status() -> Dictionary:
	var active_obstacles = 0
	var occupied_spots = 0
	
	for obstacle_id in obstacles:
		if obstacles[obstacle_id]["health"] > 0:
			active_obstacles += 1
	
	for spot_id in hiding_spots:
		if hiding_spots[spot_id]["occupied"]:
			occupied_spots += 1
	
	return {
		"total_obstacles": obstacles.size(),
		"active_obstacles": active_obstacles,
		"destroyed_obstacles": destroyed_obstacles.size(),
		"total_hiding_spots": hiding_spots.size(),
		"occupied_spots": occupied_spots,
		"available_spots": get_available_hiding_spots().size(),
		"dynamic_elements": dynamic_elements.size()
	}

func reset_arena():
	# Сбрасываем арену к исходному состоянию
	for obstacle_id in obstacles:
		var obstacle_data = obstacles[obstacle_id]
		obstacle_data["health"] = 100.0
		obstacle_data["node"].visible = true
		obstacle_data["node"].set_process(true)
		obstacle_data["respawn_timer"] = 0.0
	
	for spot_id in hiding_spots:
		var spot_data = hiding_spots[spot_id]
		spot_data["occupied"] = false
		spot_data["occupant"] = null
		spot_data["cooldown"] = 0.0
	
	destroyed_obstacles.clear()
	
	print("Arena reset to initial state")
