extends CharacterBody2D

## AI Controller for Hide and Seek
## Integrates neural network with character movement and behavior

signal ai_decision_made(action: String, confidence: float)
signal ai_learning_progress(episode: int, reward: float)
signal ai_state_changed(state: String)

const AIAgent = preload("res://ai/ai_agent.gd")

@export var is_seeker: bool = false
@export var ai_name: String = "AI_Agent"
@export var movement_speed: float = 150.0
@export var vision_range: float = 200.0
@export var decision_frequency: float = 0.5  # Решения принимаются каждые 0.5 секунды

var ai_agent
var current_action: String = "STAY"
var action_confidence: float = 0.0
var decision_timer: float = 0.0
var detected_entities: Array[Node2D] = []
var current_target: Node2D = null
var path_to_target: Array[Vector2] = []
var current_state: String = "IDLE"

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
@onready var debug_info: Label = $DebugInfo
@onready var vision_area: Area2D = $VisionArea
@onready var decision_indicator: Node2D = $DecisionIndicator
@onready var thinking_indicator: Node2D = $ThinkingIndicator

func _ready():
	setup_ai()
	connect_signals()
	print("AI Controller '", ai_name, "' initialized as ", "Seeker" if is_seeker else "Hider")

func setup_ai():
	# Создаем AI агент
	ai_agent = preload("res://ai/ai_agent.gd").new()
	ai_agent.is_seeker = is_seeker
	ai_agent.ai_name = ai_name
	ai_agent.movement_speed = movement_speed
	ai_agent.vision_range = vision_range
	
	# Подключаем сигналы AI агента
	ai_agent.action_chosen.connect(_on_ai_action_chosen)
	ai_agent.learning_completed.connect(_on_ai_learning_completed)
	
	# Настраиваем зону видимости
	if vision_area:
		vision_area.body_entered.connect(_on_vision_area_entered)
		vision_area.body_exited.connect(_on_vision_area_exited)
	
	# Обновляем внешний вид
	update_appearance()

func connect_signals():
	# Подключаем сигналы для взаимодействия с ареной
	var arena = get_node_or_null("/root/GameManager/LevelInstance")
	if arena and arena.has_signal("hiding_spot_used"):
		arena.hiding_spot_used.connect(_on_hiding_spot_used)

func _physics_process(delta):
	if not is_inside_tree():
		return
	
	decision_timer += delta
	
	# Принимаем решения с заданной частотой
	if decision_timer >= decision_frequency:
		make_ai_decision()
		decision_timer = 0.0
	
	# Выполняем текущее действие
	execute_current_action(delta)
	
	# Обновляем состояние
	update_ai_state(delta)

func make_ai_decision():
	if not ai_agent:
		return
	
	# Показываем индикатор мышления
	show_thinking_indicator()
	
	# AI агент принимает решение
	ai_agent._physics_process(get_physics_process_delta_time())
	
	# Скрываем индикатор мышления
	hide_thinking_indicator()

func _on_ai_action_chosen(action: String, confidence: float):
	current_action = action
	action_confidence = confidence
	
	# Показываем индикатор решения
	show_decision_indicator(action, confidence)
	
	# Отправляем сигнал
	ai_decision_made.emit(action, confidence)
	
	print(ai_name, " chose action: ", action, " (confidence: ", confidence, ")")

func execute_current_action(delta):
	match current_action:
		"MOVE_UP":
			move_in_direction(Vector2.UP, delta)
		"MOVE_DOWN":
			move_in_direction(Vector2.DOWN, delta)
		"MOVE_LEFT":
			move_in_direction(Vector2.LEFT, delta)
		"MOVE_RIGHT":
			move_in_direction(Vector2.RIGHT, delta)
		"MOVE_UP_LEFT":
			move_in_direction(Vector2(-1, -1).normalized(), delta)
		"MOVE_UP_RIGHT":
			move_in_direction(Vector2(1, -1).normalized(), delta)
		"MOVE_DOWN_LEFT":
			move_in_direction(Vector2(-1, 1).normalized(), delta)
		"MOVE_DOWN_RIGHT":
			move_in_direction(Vector2(1, 1).normalized(), delta)
		"STAY":
			velocity = Vector2.ZERO
		"HIDE":
			execute_hide_behavior()
		"SEEK":
			execute_seek_behavior()
		"INTERACT":
			execute_interact_behavior()
	
	# Применяем движение
	move_and_slide()

func move_in_direction(direction: Vector2, delta: float):
	velocity = direction * movement_speed
	
	# Ограничиваем движение в пределах арены
	var arena_bounds = Rect2(Vector2(-900, -650), Vector2(1800, 1300))
	var next_position = global_position + velocity * delta
	
	if not arena_bounds.has_point(next_position):
		velocity = Vector2.ZERO

func execute_hide_behavior():
	if is_seeker:
		return  # Искатели не прячутся
	
	# Ищем ближайшее укрытие
	var arena = get_node_or_null("/root/GameManager/LevelInstance")
	if arena and arena.has_method("get_nearest_hiding_spot"):
		var nearest_spot = arena.get_nearest_hiding_spot(global_position)
		if nearest_spot != "":
			move_to_hiding_spot(nearest_spot)
		else:
			# Если укрытий нет, ищем укрытие за препятствиями
			var cover = arena.get_obstacle_cover(global_position)
			if cover != Vector2.INF:
				move_to_position(cover)

func execute_seek_behavior():
	if not is_seeker:
		return  # Хайдеры не ищут
	
	# Ищем ближайшего хайдера
	var nearest_hider = find_nearest_hider()
	if nearest_hider:
		current_target = nearest_hider
		move_to_target()
	else:
		# Если хайдеров не видно, исследуем область
		explore_area()

func execute_interact_behavior():
	# Взаимодействие с окружением
	if is_seeker:
		try_open_doors()
	else:
		try_use_environment()

func move_to_hiding_spot(spot_id: String):
	var arena = get_node_or_null("/root/GameManager/LevelInstance")
	if arena:
		var hiding_spots = arena.get("hiding_spots")
		if hiding_spots and hiding_spots.has(spot_id):
			var spot_data = hiding_spots[spot_id]
			move_to_position(spot_data["position"])

func move_to_target():
	if current_target:
		move_to_position(current_target.global_position)

func move_to_position(target_position: Vector2):
	var direction = (target_position - global_position).normalized()
	velocity = direction * movement_speed

func explore_area():
	# Исследуем случайные точки на карте
	var random_target = Vector2(
		randf_range(-800, 800),
		randf_range(-600, 600)
	)
	move_to_position(random_target)

func find_nearest_hider() -> Node2D:
	var nearest_hider = null
	var min_distance = INF
	
	for entity in detected_entities:
		if entity.has_method("is_seeker_role") and not entity.is_seeker_role():
			var distance = global_position.distance_to(entity.global_position)
			if distance < min_distance:
				min_distance = distance
				nearest_hider = entity
	
	return nearest_hider

func try_open_doors():
	# Поиск и открытие дверей
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 50.0
	query.transform = Transform2D(0, global_position)
	query.collision_mask = 8
	
	var results = space_state.intersect_shape(query)
	for result in results:
		var collider = result.collider
		if collider.name.begins_with("InteractiveDoor"):
			interact_with_door(collider)

func try_use_environment():
	# Использование окружения для получения преимущества
	var arena = get_node_or_null("/root/GameManager/LevelInstance")
	if arena and arena.has_method("get_obstacle_cover"):
		var cover = arena.get_obstacle_cover(global_position)
		if cover != Vector2.INF:
			move_to_position(cover)

func interact_with_door(door: Node2D):
	# AI взаимодействует с дверью
	var tween = create_tween()
	tween.tween_property(door, "modulate:a", 0.3, 0.5)
	
	var collision = door.get_node_or_null("CollisionShape2D")
	if collision:
		collision.set_deferred("disabled", true)
	
	await get_tree().create_timer(2.0).timeout
	tween.tween_property(door, "modulate:a", 1.0, 0.5)
	if collision:
		collision.set_deferred("disabled", false)

func _on_vision_area_entered(body: Node2D):
	if body != self and body.has_method("is_seeker"):
		detected_entities.append(body)
		
		# Даем награду AI за обнаружение
		if ai_agent:
			if is_seeker and not body.is_seeker:
				ai_agent.give_reward(5.0)  # Награда за нахождение хайдера
			elif not is_seeker and body.is_seeker:
				ai_agent.give_reward(-2.0)  # Штраф за обнаружение искателем

func _on_vision_area_exited(body: Node2D):
	detected_entities.erase(body)

func _on_hiding_spot_used(spot_id: String, user: Node2D):
	if user == self:
		# Награда за успешное использование укрытия
		if ai_agent and not is_seeker:
			ai_agent.give_reward(3.0)
		print(ai_name, " used hiding spot: ", spot_id)

func _on_ai_learning_completed(reward: float, episode: int):
	ai_learning_progress.emit(episode, reward)
	print(ai_name, " learning completed - Episode: ", episode, ", Reward: ", reward)

func update_ai_state(delta):
	# Обновляем состояние AI на основе текущих условий
	var new_state = determine_ai_state()
	
	if new_state != current_state:
		current_state = new_state
		ai_state_changed.emit(current_state)
		
		# Даем награды/штрафы за смену состояния
		if ai_agent:
			match current_state:
				"HUNTING":
					if is_seeker:
						ai_agent.give_reward(1.0)
				"HIDING":
					if not is_seeker:
						ai_agent.give_reward(1.0)
				"ESCAPING":
					if not is_seeker:
						ai_agent.give_reward(2.0)
				"SEARCHING":
					if is_seeker:
						ai_agent.give_reward(0.5)

func determine_ai_state() -> String:
	if is_seeker:
		if detected_entities.size() > 0:
			return "HUNTING"
		else:
			return "SEARCHING"
	else:
		if detected_entities.size() > 0:
			var has_seekers = false
			for entity in detected_entities:
				if entity.is_seeker_role():
					has_seekers = true
					break
			
			if has_seekers:
				return "ESCAPING"
			else:
				return "HIDING"
		else:
			return "EXPLORING"

func show_decision_indicator(action: String, confidence: float):
	if not decision_indicator:
		return
	
	decision_indicator.visible = true
	
	# Показываем стрелку в направлении действия
	var arrow = decision_indicator.get_node_or_null("Arrow")
	if arrow:
		var direction = Vector2.ZERO
		match action:
			"MOVE_UP": direction = Vector2.UP
			"MOVE_DOWN": direction = Vector2.DOWN
			"MOVE_LEFT": direction = Vector2.LEFT
			"MOVE_RIGHT": direction = Vector2.RIGHT
			"MOVE_UP_LEFT": direction = Vector2(-1, -1).normalized()
			"MOVE_UP_RIGHT": direction = Vector2(1, -1).normalized()
			"MOVE_DOWN_LEFT": direction = Vector2(-1, 1).normalized()
			"MOVE_DOWN_RIGHT": direction = Vector2(1, 1).normalized()
			"HIDE": direction = Vector2.DOWN
			"SEEK": direction = Vector2.UP
			_: direction = Vector2.ZERO
		
		if direction != Vector2.ZERO:
			arrow.rotation = direction.angle()
			arrow.modulate.a = confidence

func hide_decision_indicator():
	if decision_indicator:
		decision_indicator.visible = false

func show_thinking_indicator():
	if thinking_indicator:
		thinking_indicator.visible = true
		
		# Анимируем точки
		var dots = thinking_indicator.get_node_or_null("Dots")
		if dots:
			var tween = create_tween()
			tween.set_loops()
			
			for i in range(3):
				var dot = dots.get_child(i)
				tween.tween_property(dot, "modulate:a", 1.0, 0.3)
				tween.tween_property(dot, "modulate:a", 0.3, 0.3)
				tween.tween_delay(0.2)

func hide_thinking_indicator():
	if thinking_indicator:
		thinking_indicator.visible = false

func update_appearance():
	if sprite:
		if is_seeker:
			sprite.modulate = Color.ORANGE
			label.text = "AI Seeker"
		else:
			sprite.modulate = Color.YELLOW
			label.text = "AI Hider"

func update_debug_info():
	if debug_info and debug_info.visible:
		var info_text = ai_name + " Debug Info:\n"
		info_text += "Role: " + ("Seeker" if is_seeker else "Hider") + "\n"
		info_text += "State: " + current_state + "\n"
		info_text += "Action: " + current_action + "\n"
		info_text += "Confidence: " + str(action_confidence) + "\n"
		info_text += "Position: " + str(global_position) + "\n"
		info_text += "Detected: " + str(detected_entities.size()) + " entities"
		
		if ai_agent:
			var status = ai_agent.get_ai_status()
			info_text += "\nEpisode: " + str(status.episode)
			info_text += "\nTotal Reward: " + str(status.total_reward)
		
		debug_info.text = info_text

func is_seeker_role() -> bool:
	return is_seeker

func get_ai_status() -> Dictionary:
	var base_status = {
		"name": ai_name,
		"is_seeker": is_seeker,
		"position": global_position,
		"current_action": current_action,
		"action_confidence": action_confidence,
		"current_state": current_state,
		"detected_count": detected_entities.size()
	}
	
	if ai_agent:
		var ai_status = ai_agent.get_ai_status()
		base_status.merge(ai_status)
	
	return base_status

func toggle_debug_mode():
	if debug_info:
		debug_info.visible = not debug_info.visible

func reset_ai():
	# Сбрасываем состояние AI
	position = Vector2.ZERO
	velocity = Vector2.ZERO
	current_action = "STAY"
	action_confidence = 0.0
	current_target = null
	detected_entities.clear()
	current_state = "IDLE"
	
	# Сбрасываем AI агент
	if ai_agent:
		ai_agent.total_reward = 0.0
		ai_agent.episode_count = 0
	
	update_appearance()
	
	print(ai_name, " reset to initial state")

func save_ai_brain() -> Dictionary:
	if ai_agent:
		return ai_agent.save_brain()
	return {}

func load_ai_brain(data: Dictionary):
	if ai_agent:
		ai_agent.load_brain(data)
		print(ai_name, " brain loaded successfully")
