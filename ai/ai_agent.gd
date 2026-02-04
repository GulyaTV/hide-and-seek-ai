extends Node2D

## AI Agent for Hide and Seek
## Uses reinforcement learning inspired by OpenAI's approach

class_name AIAgent

signal action_chosen(action: String, confidence: float)
signal learning_completed(reward: float, episode: int)

enum ActionType {
	MOVE_UP,
	MOVE_DOWN,
	MOVE_LEFT,
	MOVE_RIGHT,
	MOVE_UP_LEFT,
	MOVE_UP_RIGHT,
	MOVE_DOWN_LEFT,
	MOVE_DOWN_RIGHT,
	STAY,
	HIDE,
	SEEK,
	INTERACT
}

@export var is_seeker: bool = false
@export var ai_name: String = "AI_Agent"
@export var learning_rate: float = 0.001
@export var exploration_rate: float = 0.1
@export var discount_factor: float = 0.95
@export var memory_size: int = 10000
@export var batch_size: int = 32

var neural_network: NeuralNetwork
var experience_replay: Array[Dictionary] = []
var current_state: Array[float] = []
var last_action: int = -1
var last_state: Array[float] = []
var episode_count: int = 0
var total_reward: float = 0.0
var exploration_decay: float = 0.995

# Параметры состояния
var vision_range: float = 200.0
var movement_speed: float = 150.0
var position_history: Array[Vector2] = []
var detected_entities: Array[Node2D] = []
var hiding_spots: Array[Vector2] = []

func _ready():
	initialize_ai()
	print("AI Agent '", ai_name, "' initialized as ", "Seeker" if is_seeker else "Hider")

func initialize_ai():
	# Создаем нейронную сеть
	# Вход: позиция, здоровье, видимые объекты, время раунда
	# Выход: вероятности действий
	var input_size = 20  # Позиция (2) + здоровье (1) + видимые объекты (10) + время (1) + мета-данные (6)
	var hidden_layers = [64, 32, 16]
	var output_size = ActionType.size()
	
	var layer_sizes = [input_size]
	layer_sizes.append_array(hidden_layers)
	layer_sizes.append(output_size)
	
	neural_network = NeuralNetwork.new(layer_sizes)
	neural_network.learning_rate = learning_rate

func _physics_process(delta):
	if not is_inside_tree():
		return
	
	# Обновляем состояние
	update_state()
	
	# Выбираем действие
	var action = choose_action()
	execute_action(action, delta)
	
	# Обучаемся
	if last_action >= 0 and experience_replay.size() > batch_size:
		train_network()

func update_state():
	# Собираем текущее состояние
	current_state.clear()
	
	# Позиция (нормализованная)
	var arena_size = Vector2(2000, 1500)
	current_state.append(global_position.x / arena_size.x)
	current_state.append(global_position.y / arena_size.y)
	
	# Здоровье/статус
	current_state.append(1.0)  # Всегда здоров в базовой версии
	
	# Видимые объекты (до 5 объектов)
	var visible_entities = get_visible_entities()
	for i in range(5):
		if i < visible_entities.size():
			var entity = visible_entities[i]
			var distance = global_position.distance_to(entity.global_position)
			var angle = global_position.angle_to_point(entity.global_position)
			current_state.append(distance / vision_range)
			current_state.append(angle / TAU)
		else:
			current_state.append(0.0)
			current_state.append(0.0)
	
	# Время раунда
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		current_state.append(game_manager.round_timer / 300.0)  # Нормализованное время
	else:
		current_state.append(0.0)
	
	# Мета-данные
	current_state.append(1.0 if is_seeker else 0.0)  # Роль
	current_state.append(float(experience_replay.size()) / memory_size)  # Опыт
	current_state.append(exploration_rate)  # Уровень исследования
	current_state.append(float(episode_count) / 1000.0)  # Эпизоды
	current_state.append(total_reward / 100.0)  # Общая награда
	current_state.append(randf())  # Случайность для разнообразия

func get_visible_entities() -> Array[Node2D]:
	var entities: Array[Node2D] = []
	var space_state = get_world_2d().direct_space_state
	
	# Проверяем все объекты в зоне видимости
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = vision_range
	query.shape = shape
	query.transform = Transform2D(0, global_position)
	query.collision_mask = 1  # Предполагаем что у персонажей маска 1
	
	var results = space_state.intersect_shape(query)
	for result in results:
		var collider = result.collider
		if collider != self and collider.has_method("is_seeker"):
			entities.append(collider)
	
	return entities

func choose_action() -> int:
	# Epsilon-greedy стратегия
	if randf() < exploration_rate:
		# Случайное действие (исследование)
		last_action = randi() % ActionType.size()
		action_chosen.emit(ActionType.keys()[last_action], exploration_rate)
	else:
		# Действие от нейросети (эксплуатация)
		var output = neural_network.forward(current_state)
		
		# Выбираем действие с максимальной вероятностью
		var max_value = output[0]
		var max_index = 0
		for i in range(1, output.size()):
			if output[i] > max_value:
				max_value = output[i]
				max_index = i
		
		last_action = max_index
		action_chosen.emit(ActionType.keys()[last_action], max_value)
	
	return last_action

func execute_action(action: int, delta: float):
	var move_vector = Vector2.ZERO
	
	match action:
		ActionType.MOVE_UP:
			move_vector = Vector2(0, -1)
		ActionType.MOVE_DOWN:
			move_vector = Vector2(0, 1)
		ActionType.MOVE_LEFT:
			move_vector = Vector2(-1, 0)
		ActionType.MOVE_RIGHT:
			move_vector = Vector2(1, 0)
		ActionType.MOVE_UP_LEFT:
			move_vector = Vector2(-1, -1).normalized()
		ActionType.MOVE_UP_RIGHT:
			move_vector = Vector2(1, -1).normalized()
		ActionType.MOVE_DOWN_LEFT:
			move_vector = Vector2(-1, 1).normalized()
		ActionType.MOVE_DOWN_RIGHT:
			move_vector = Vector2(1, 1).normalized()
		ActionType.STAY:
			move_vector = Vector2.ZERO
		ActionType.HIDE:
			execute_hide_action()
		ActionType.SEEK:
			execute_seek_action()
		ActionType.INTERACT:
			execute_interact_action()
	
	# Применяем движение
	if move_vector != Vector2.ZERO:
		global_position += move_vector * movement_speed * delta
		
		# Ограничиваем движение в пределах арены
		global_position.x = clamp(global_position.x, -900, 900)
		global_position.y = clamp(global_position.y, -650, 650)
		
		# Сохраняем историю позиций
		position_history.append(global_position)
		if position_history.size() > 100:
			position_history.pop_front()

func execute_hide_action():
	if is_seeker:
		return  # Искатели не прячутся
	
	# Ищем ближайшее укрытие
	var nearest_cover = find_nearest_hiding_spot()
	if nearest_cover != Vector2.INF:
		# Двигаемся к укрытию
		var direction = (nearest_cover - global_position).normalized()
		global_position += direction * movement_speed * get_physics_process_delta_time()

func execute_seek_action():
	if not is_seeker:
		return  # Хайдеры не ищут
	
	# Ищем ближайшего хайдера
	var nearest_hider = find_nearest_hider()
	if nearest_hider:
		# Двигаемся к хайдеру
		var direction = (nearest_hider.global_position - global_position).normalized()
		global_position += direction * movement_speed * get_physics_process_delta_time()

func execute_interact_action():
	# Взаимодействие с окружением
	# Например: открывать двери, активировать ловушки и т.д.
	pass

func find_nearest_hiding_spot() -> Vector2:
	# Простая реализация - ищем статические объекты
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 300.0
	query.transform = Transform2D(0, global_position)
	
	var results = space_state.intersect_shape(query)
	var nearest_spot = Vector2.INF
	var min_distance = INF
	
	for result in results:
		var collider = result.collider
		if collider is StaticBody2D:
			var distance = global_position.distance_to(collider.global_position)
			if distance < min_distance:
				min_distance = distance
				nearest_spot = collider.global_position
	
	return nearest_spot

func find_nearest_hider() -> Node2D:
	var entities = get_visible_entities()
	var nearest_hider = null
	var min_distance = INF
	
	for entity in entities:
		if entity.has_method("is_seeker") and not entity.is_seeker:
			var distance = global_position.distance_to(entity.global_position)
			if distance < min_distance:
				min_distance = distance
				nearest_hider = entity
	
	return nearest_hider

func give_reward(reward: float, done: bool = false):
	total_reward += reward
	
	# Сохраняем опыт
	if last_state.size() > 0 and last_action >= 0:
		var experience = {
			"state": last_state.duplicate(),
			"action": last_action,
			"reward": reward,
			"next_state": current_state.duplicate(),
			"done": done
		}
		
		experience_replay.append(experience)
		
		# Ограничиваем размер памяти
		if experience_replay.size() > memory_size:
			experience_replay.pop_front()
	
	# Обновляем параметры обучения
	if done:
		episode_count += 1
		exploration_rate = max(0.01, exploration_rate * exploration_decay)
		learning_completed.emit(reward, episode_count)
	
	# Сохраняем текущее состояние
	last_state = current_state.duplicate()

func train_network():
	if experience_replay.size() < batch_size:
		return
	
	# Выбираем случайный батч из опыта
	var batch = []
	for i in range(batch_size):
		var random_index = randi() % experience_replay.size()
		batch.append(experience_replay[random_index])
	
	# Обучаем сеть на батче
	for experience in batch:
		var state = experience["state"]
		var action = experience["action"]
		var reward = experience["reward"]
		var next_state = experience["next_state"]
		var done = experience["done"]
		
		# Вычисляем целевые значения Q-learning
		var target_output = neural_network.forward(state)
		var next_output = neural_network.forward(next_state)
		
		var max_next_q = next_output[0]
		for value in next_output:
			if value > max_next_q:
				max_next_q = value
		
		var target_q = reward
		if not done:
			target_q += discount_factor * max_next_q
		
		# Обновляем Q-значение для выбранного действия
		var target = target_output.duplicate()
		target[action] = target_q
		
		# Обучаем сеть
		neural_network.backward(target, state)

func get_ai_status() -> Dictionary:
	return {
		"name": ai_name,
		"is_seeker": is_seeker,
		"position": global_position,
		"episode": episode_count,
		"total_reward": total_reward,
		"exploration_rate": exploration_rate,
		"experience_count": experience_replay.size(),
		"last_action": ActionType.keys()[last_action] if last_action >= 0 else "None"
	}

func save_brain() -> Dictionary:
	return {
		"neural_network": neural_network.save_to_dict(),
		"experience_replay": experience_replay,
		"episode_count": episode_count,
		"total_reward": total_reward,
		"exploration_rate": exploration_rate
	}

func load_brain(data: Dictionary):
	if data.has("neural_network"):
		neural_network.load_from_dict(data["neural_network"])
	if data.has("experience_replay"):
		experience_replay = data["experience_replay"]
	if data.has("episode_count"):
		episode_count = data["episode_count"]
	if data.has("total_reward"):
		total_reward = data["total_reward"]
	if data.has("exploration_rate"):
		exploration_rate = data["exploration_rate"]

func evolve_from(parent_brain: Dictionary):
	# Эволюция от родительского мозга
	load_brain(parent_brain)
	neural_network.mutate(0.2, 0.5)  # Мутация с высокой вероятностью
	exploration_rate = min(0.5, exploration_rate * 1.5)  # Увеличиваем исследование
