extends Node

## Hide and Seek with AI - Game Manager
## Inspired by OpenAI's Hide and Seek experiment

signal game_started(game_mode: String)
signal game_ended(winner: String, reason: String)
signal round_started(round_number: int)
signal round_ended(winner: String, round_time: float)

enum GameMode {
	AI_VS_AI,        # Нейросеть (Hide) vs Нейросеть (Seek)
	PLAYER_HIDE_AI_SEEK,  # Игрок (Hide) vs Нейросеть (Seek)
	PLAYER_SEEK_AI_HIDE   # Игрок (Seek) vs Нейросеть (Hide)
}

enum GameState {
	MENU,
	PLAYING,
	PAUSED,
	ROUND_END,
	GAME_END
}

@export var current_game_mode: GameMode = GameMode.AI_VS_AI
@export var current_state: GameState = GameState.MENU
@export var max_rounds: int = 5
@export var round_time: float = 300.0  # 5 минут на раунд
@export var hide_seek_distance: float = 50.0

var current_round: int = 0
var round_timer: float = 0.0
var game_timer: float = 0.0
var scores: Dictionary = {"hider": 0, "seeker": 0}
var player_character: Node2D
var ai_agents: Array[Node2D] = []
var level_instance: Node2D

func _ready():
	print("Hide and Seek with AI - Game Manager Initialized")
	
	# Подключаем сигналы
	game_started.connect(_on_game_started)
	game_ended.connect(_on_game_ended)
	round_started.connect(_on_round_started)
	round_ended.connect(_on_round_ended)

func _process(delta):
	match current_state:
		GameState.PLAYING:
			update_game_logic(delta)
		GameState.ROUND_END:
			round_timer -= delta
			if round_timer <= 0:
				start_next_round()

func start_game(mode: GameMode):
	current_game_mode = mode
	current_state = GameState.PLAYING
	current_round = 0
	scores = {"hider": 0, "seeker": 0}
	
	print("Starting game with mode: ", GameMode.keys()[mode])
	game_started.emit(GameMode.keys()[mode])
	
	load_level()
	spawn_characters()
	start_next_round()

func load_level():
	# Загружаем уровень для пряток
	var level_scene = preload("res://levels/hide_and_seek_arena.tscn")
	if level_scene:
		level_instance = level_scene.instantiate()
		add_child(level_instance)
		print("Level loaded successfully")
	else:
		# Создаем временный уровень если сцена не найдена
		create_temporary_level()

func create_temporary_level():
	level_instance = Node2D.new()
	level_instance.name = "TemporaryLevel"
	add_child(level_instance)
	
	# Создаем границы арены
	var arena_size = Vector2(2000, 1500)
	
	# Создаем стены
	create_wall(Vector2(-arena_size.x/2, -arena_size.y/2), Vector2(arena_size.x, 20))
	create_wall(Vector2(-arena_size.x/2, arena_size.y/2 - 20), Vector2(arena_size.x, 20))
	create_wall(Vector2(-arena_size.x/2, -arena_size.y/2), Vector2(20, arena_size.y))
	create_wall(Vector2(arena_size.x/2 - 20, -arena_size.y/2), Vector2(20, arena_size.y))
	
	# Создаем укрытия
	create_obstacle(Vector2(-300, -200), Vector2(100, 100))
	create_obstacle(Vector2(300, 200), Vector2(80, 120))
	create_obstacle(Vector2(0, -400), Vector2(150, 60))
	create_obstacle(Vector2(-500, 300), Vector2(120, 80))
	create_obstacle(Vector2(400, -300), Vector2(90, 90))
	
	print("Temporary level created with obstacles")

func create_wall(position: Vector2, size: Vector2):
	var wall = StaticBody2D.new()
	wall.position = position
	
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	wall.add_child(collision)
	
	var sprite = Sprite2D.new()
	sprite.texture = create_colored_texture(size, Color.GRAY)
	wall.add_child(sprite)
	
	level_instance.add_child(wall)

func create_obstacle(position: Vector2, size: Vector2):
	var obstacle = StaticBody2D.new()
	obstacle.position = position
	
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	obstacle.add_child(collision)
	
	var sprite = Sprite2D.new()
	sprite.texture = create_colored_texture(size, Color.DARK_GREEN)
	obstacle.add_child(sprite)
	
	level_instance.add_child(obstacle)

func create_colored_texture(size: Vector2, color: Color) -> ImageTexture:
	var image = Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	image.fill(color)
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func spawn_characters():
	# Очищаем предыдущих персонажей
	clear_characters()
	
	match current_game_mode:
		GameMode.AI_VS_AI:
			spawn_ai_hiders(3)
			spawn_ai_seekers(2)
		GameMode.PLAYER_HIDE_AI_SEEK:
			spawn_player_as_hider()
			spawn_ai_seekers(2)
		GameMode.PLAYER_SEEK_AI_HIDE:
			spawn_player_as_seeker()
			spawn_ai_hiders(3)

func spawn_player_as_hider():
	var player_scene = preload("res://scenes/player_character.tscn")
	if player_scene:
		player_character = player_scene.instantiate()
		player_character.position = Vector2(0, 0)
		level_instance.add_child(player_character)
		print("Player spawned as hider")

func spawn_player_as_seeker():
	var player_scene = preload("res://scenes/player_character.tscn")
	if player_scene:
		player_character = player_scene.instantiate()
		player_character.position = Vector2(0, 0)
		player_character.is_seeker = true
		level_instance.add_child(player_character)
		print("Player spawned as seeker")

func spawn_ai_hiders(count: int):
	var ai_scene = preload("res://scenes/ai_character.tscn")
	for i in range(count):
		if ai_scene:
			var ai = ai_scene.instantiate()
			ai.position = get_random_spawn_position()
			ai.is_seeker = false
			ai.ai_name = "Hider_" + str(i)
			level_instance.add_child(ai)
			ai_agents.append(ai)
	print("Spawned ", count, " AI hiders")

func spawn_ai_seekers(count: int):
	var ai_scene = preload("res://scenes/ai_character.tscn")
	for i in range(count):
		if ai_scene:
			var ai = ai_scene.instantiate()
			ai.position = get_random_spawn_position()
			ai.is_seeker = true
			ai.ai_name = "Seeker_" + str(i)
			level_instance.add_child(ai)
			ai_agents.append(ai)
	print("Spawned ", count, " AI seekers")

func get_random_spawn_position() -> Vector2:
	var arena_size = Vector2(800, 600)
	return Vector2(
		randf_range(-arena_size.x/2, arena_size.x/2),
		randf_range(-arena_size.y/2, arena_size.y/2)
	)

func clear_characters():
	if player_character:
		player_character.queue_free()
		player_character = null
	
	for ai in ai_agents:
		if ai:
			ai.queue_free()
	ai_agents.clear()

func start_next_round():
	current_round += 1
	round_timer = round_time
	
	if current_round > max_rounds:
		end_game()
		return
	
	print("Starting round ", current_round)
	round_started.emit(current_round)
	
	# Даем время на спавн и подготовку
	await get_tree().create_timer(3.0).timeout
	
	# Начинаем раунд
	current_state = GameState.PLAYING

func update_game_logic(delta):
	round_timer -= delta
	game_timer += delta
	
	# Проверяем условия победы
	check_win_conditions()
	
	# Проверяем время раунда
	if round_timer <= 0:
		end_round("time_out")

func check_win_conditions():
	var hiders = get_all_hiders()
	var seekers = get_all_seekers()
	
	# Проверяем, все ли хайдеры найдены
	if hiders.size() == 0:
		end_round("seekers_win")
		return
	
	# Проверяем, осталось ли время для хайдеров
	if round_timer <= 0:
		end_round("hiders_win")
		return
	
	# Проверяем расстояния между хайдерами и искателями
	for hider in hiders:
		for seeker in seekers:
			var distance = hider.position.distance_to(seeker.position)
			if distance < hide_seek_distance:
				# Хайдер найден!
				catch_hider(hider, seeker)
				break

func get_all_hiders() -> Array[Node2D]:
	var hiders: Array[Node2D] = []
	
	if player_character and not player_character.is_seeker:
		hiders.append(player_character)
	
	for ai in ai_agents:
		if not ai.is_seeker:
			hiders.append(ai)
	
	return hiders

func get_all_seekers() -> Array[Node2D]:
	var seekers: Array[Node2D] = []
	
	if player_character and player_character.is_seeker:
		seekers.append(player_character)
	
	for ai in ai_agents:
		if ai.is_seeker:
			seekers.append(ai)
	
	return seekers

func catch_hider(hider: Node2D, seeker: Node2D):
	print(hider.name if hider.name != "" else "Unknown", " was caught by ", seeker.name if seeker.name != "" else "Unknown")
	
	# Удаляем пойманного хайдера
	if hider == player_character:
		player_character.visible = false
		player_character.set_process(false)
	else:
		ai_agents.erase(hider)
		hider.queue_free()
	
	# Даем очки искателю
	scores["seeker"] += 1

func end_round(reason: String):
	current_state = GameState.ROUND_END
	
	var winner = ""
	match reason:
		"seekers_win":
			winner = "Seekers"
			scores["seeker"] += 2
		"hiders_win":
			winner = "Hiders"
			scores["hider"] += 2
		"time_out":
			winner = "Hiders (Time Out)"
			scores["hider"] += 1
	
	print("Round ended: ", winner, " won!")
	round_ended.emit(winner, round_time)
	
	# Показываем результаты раунда
	round_timer = 5.0  # Пауза между раундами

func end_game():
	current_state = GameState.GAME_END
	
	var winner = "Hiders" if scores["hider"] > scores["seeker"] else "Seekers"
	var reason = "Final Score - Hiders: " + str(scores["hider"]) + ", Seekers: " + str(scores["seeker"])
	
	print("Game ended: ", winner, " win! ", reason)
	game_ended.emit(winner, reason)

func restart_game():
	clear_characters()
	if level_instance:
		level_instance.queue_free()
		level_instance = null
	
	current_state = GameState.MENU
	current_round = 0
	scores = {"hider": 0, "seeker": 0}

func pause_game():
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED

func resume_game():
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING

func get_game_status() -> Dictionary:
	return {
		"game_mode": GameMode.keys()[current_game_mode],
		"state": GameState.keys()[current_state],
		"current_round": current_round,
		"max_rounds": max_rounds,
		"round_time": round_timer,
		"scores": scores,
		"hiders_count": get_all_hiders().size(),
		"seekers_count": get_all_seekers().size()
	}

# Signal handlers
func _on_game_started(mode: String):
	print("Game started with mode: ", mode)

func _on_game_ended(winner: String, reason: String):
	print("Game ended - Winner: ", winner, ", Reason: ", reason)

func _on_round_started(round_number: int):
	print("Round ", round_number, " started")

func _on_round_ended(winner: String, round_time: float):
	print("Round ended - Winner: ", winner, ", Time: ", round_time)
