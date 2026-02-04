extends CharacterBody2D

## Player Controller for Hide and Seek
## Handles player movement, interaction, and game mechanics

signal player_caught(seeker: Node2D)
signal hiding_spot_entered(spot: Node2D)
signal hiding_spot_exited(spot: Node2D)

@export var is_seeker: bool = false
@export var movement_speed: float = 200.0
@export var sprint_multiplier: float = 1.8
@export var vision_range: float = 200.0
@export var interaction_range: float = 50.0

var current_speed: float = movement_speed
var is_sprinting: bool = false
var is_hidden: bool = false
var current_hiding_spot: Node2D = null
var stamina: float = 100.0
var max_stamina: float = 100.0
var detected_entities: Array[Node2D] = []

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
@onready var debug_info: Label = $DebugInfo
@onready var vision_area: Area2D = $VisionArea

func _ready():
	setup_player()
	connect_signals()

func setup_player():
	# Настраиваем внешний вид в зависимости от роли
	update_appearance()
	
	# Настраиваем зону видимости
	if vision_area:
		vision_area.body_entered.connect(_on_vision_area_entered)
		vision_area.body_exited.connect(_on_vision_area_exited)
	
	print("Player initialized as ", "Seeker" if is_seeker else "Hider")

func connect_signals():
	# Подключаем сигналы для взаимодействия с ареной
	var arena = get_node_or_null("/root/GameManager/LevelInstance")
	if arena and arena.has_signal("hiding_spot_used"):
		arena.hiding_spot_used.connect(_on_hiding_spot_used)

func _physics_process(delta):
	if not is_inside_tree():
		return
	
	handle_input(delta)
	update_movement(delta)
	update_visibility()
	update_debug_info()

func handle_input(delta):
	var input_vector = Vector2.ZERO
	
	# Движение
	if Input.is_action_pressed("ui_up"):
		input_vector.y -= 1
	if Input.is_action_pressed("ui_down"):
		input_vector.y += 1
	if Input.is_action_pressed("ui_left"):
		input_vector.x -= 1
	if Input.is_action_pressed("ui_right"):
		input_vector.x += 1
	
	# Нормализуем вектор движения
	if input_vector.length() > 0:
		input_vector = input_vector.normalized()
	
	# Спринт
	is_sprinting = Input.is_action_pressed("player_sprint") and stamina > 0
	if is_sprinting:
		current_speed = movement_speed * sprint_multiplier
		stamina -= 30.0 * delta  # Расход выносливости
		stamina = max(0, stamina)
	else:
		current_speed = movement_speed
		stamina += 20.0 * delta  # Восстановление выносливости
		stamina = min(max_stamina, stamina)
	
	# Взаимодействие
	if Input.is_action_just_pressed("player_interact"):
		handle_interaction()
	
	# Применяем движение
	velocity = input_vector * current_speed
	move_and_slide()

func update_movement(_delta):
	# Обновляем анимацию в зависимости от движения
	if velocity.length() > 0:
		if sprite:
			sprite.modulate = Color.RED if is_seeker else Color.BLUE
	else:
		if sprite:
			sprite.modulate = Color.DARK_RED if is_seeker else Color.DARK_BLUE

func update_visibility():
	# Обновляем видимость в зависимости от роли и состояния
	var visibility_modifier = 1.0
	
	if not is_seeker:
		# Хайдеры могут быть менее заметны в укрытиях
		if is_hidden and current_hiding_spot:
			visibility_modifier = 0.3  # Сильно снижаем видимость в укрытии
		
		# Проверяем укрытия от препятствий
		var arena = get_node_or_null("/root/GameManager/LevelInstance")
		if arena and arena.has_method("get_visibility_modifier"):
			visibility_modifier *= arena.get_visibility_modifier(global_position)
	
	# Применяем модификатор видимости
	if sprite:
		sprite.modulate.a = visibility_modifier

func handle_interaction():
	if is_seeker:
		# Искатели могут взаимодействовать с объектами (например, открывать двери)
		try_open_doors()
	else:
		# Хайдеры могут прятаться в укрытиях
		try_hide()

func try_hide():
	if is_hidden:
		# Выходим из укрытия
		exit_hiding_spot()
	else:
		# Ищем ближайшее укрытие
		var arena = get_node_or_null("/root/GameManager/LevelInstance")
		if arena and arena.has_method("get_nearest_hiding_spot"):
			var nearest_spot = arena.get_nearest_hiding_spot(global_position)
			if nearest_spot != "":
				enter_hiding_spot(nearest_spot)

func enter_hiding_spot(spot_id: String):
	var arena = get_node_or_null("/root/GameManager/LevelInstance")
	if arena:
		var hiding_spots = arena.get("hiding_spots")
		if hiding_spots and hiding_spots.has(spot_id):
			var spot_data = hiding_spots[spot_id]
			current_hiding_spot = spot_data["node"]
			is_hidden = true
			
			# Делаем игрока менее заметным
			if sprite:
				sprite.modulate = Color.GREEN
				sprite.modulate.a = 0.3
			
			hiding_spot_entered.emit(current_hiding_spot)
			print("Player entered hiding spot: ", spot_id)

func exit_hiding_spot():
	if current_hiding_spot:
		is_hidden = false
		current_hiding_spot = null
		
		# Возвращаем нормальную видимость
		if sprite:
			sprite.modulate = Color.BLUE
			sprite.modulate.a = 1.0
		
		hiding_spot_exited.emit(current_hiding_spot)
		print("Player exited hiding spot")

func try_open_doors():
	# Ищем ближайшие двери для открытия
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = interaction_range
	query.transform = Transform2D(0, global_position)
	query.collision_mask = 8  # Предполагаем что у дверей маска 8
	
	var results = space_state.intersect_shape(query)
	for result in results:
		var collider = result.collider
		if collider.name.begins_with("InteractiveDoor"):
			open_door(collider)

func open_door(door: Node2D):
	# Анимация открытия двери
	var tween = create_tween()
	tween.tween_property(door, "modulate:a", 0.3, 0.5)
	
	# Отключаем collision на время
	var collision = door.get_node_or_null("CollisionShape2D")
	if collision:
		collision.set_deferred("disabled", true)
	
	# Автоматически закрываем дверь через 3 секунды
	await get_tree().create_timer(3.0).timeout
	tween.tween_property(door, "modulate:a", 1.0, 0.5)
	if collision:
		collision.set_deferred("disabled", false)

func _on_vision_area_entered(body: Node2D):
	if body != self and body.has_method("is_seeker"):
		detected_entities.append(body)
		
		# Если мы искатель и видим хайдера
		if is_seeker and not body.is_seeker:
			check_catch_condition(body)

func _on_vision_area_exited(body: Node2D):
	detected_entities.erase(body)

func check_catch_condition(target: Node2D):
	var distance = global_position.distance_to(target.global_position)
	var catch_distance = 30.0  # Расстояние для поимки
	
	if distance < catch_distance:
		catch_player(target)

func catch_player(target: Node2D):
	print("Player caught: ", target.name)
	player_caught.emit(target)
	
	# Отправляем сигнал в игровой менеджер
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_method("catch_hider"):
		game_manager.catch_hider(target, self)

func _on_hiding_spot_used(spot_id: String, user: Node2D):
	if user == self:
		print("Hiding spot confirmed: ", spot_id)

func update_debug_info():
	if debug_info and debug_info.visible:
		var info_text = "Player Debug Info:\n"
		info_text += "Role: " + ("Seeker" if is_seeker else "Hider") + "\n"
		info_text += "Position: " + str(global_position) + "\n"
		info_text += "Speed: " + str(current_speed) + "\n"
		info_text += "Sprinting: " + str(is_sprinting) + "\n"
		info_text += "Stamina: " + str(int(stamina)) + "/" + str(int(max_stamina)) + "\n"
		info_text += "Hidden: " + str(is_hidden) + "\n"
		info_text += "Detected: " + str(detected_entities.size()) + " entities"
		
		debug_info.text = info_text

func is_seeker() -> bool:
	return is_seeker

func get_detected_entities() -> Array[Node2D]:
	return detected_entities.duplicate()

func get_player_status() -> Dictionary:
	return {
		"is_seeker": is_seeker,
		"position": global_position,
		"is_hidden": is_hidden,
		"is_sprinting": is_sprinting,
		"stamina": stamina,
		"detected_count": detected_entities.size(),
		"current_speed": current_speed
	}

func set_role(seeker_role: bool):
	is_seeker = seeker_role
	update_appearance()

func update_appearance():
	if sprite:
		if is_seeker:
			sprite.modulate = Color.RED
			label.text = "Seeker"
		else:
			sprite.modulate = Color.BLUE
			label.text = "Hider"

func toggle_debug_mode():
	if debug_info:
		debug_info.visible = not debug_info.visible

func reset_player():
	# Сбрасываем состояние игрока
	position = Vector2.ZERO
	velocity = Vector2.ZERO
	is_sprinting = false
	is_hidden = false
	current_hiding_spot = null
	stamina = max_stamina
	detected_entities.clear()
	
	update_appearance()
	
	print("Player reset to initial state")
