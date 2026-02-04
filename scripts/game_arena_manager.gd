extends Node2D

## Game Arena Manager
## Manages the game arena, UI, and coordinate with GameManager

signal arena_ready()
signal arena_reset()

@onready var arena: Node2D = $Arena
@onready var spawn_points: Node2D = $SpawnPoints
@onready var camera: Camera2D = $Camera2D
@onready var game_hud: Control = $UI/GameHUD

# UI Elements
@onready var mode_label: Label = $UI/GameHUD/TopPanel/TopContainer/GameInfo/ModeLabel
@onready var round_label: Label = $UI/GameHUD/TopPanel/TopContainer/GameInfo/RoundLabel
@onready var time_label: Label = $UI/GameHUD/TopPanel/TopContainer/GameInfo/TimeLabel
@onready var hiders_label: Label = $UI/GameHUD/TopPanel/TopContainer/ScoreInfo/HidersLabel
@onready var seekers_label: Label = $UI/GameHUD/TopPanel/TopContainer/ScoreInfo/SeekersLabel

@onready var menu_button: Button = $UI/GameHUD/BottomPanel/BottomContainer/MenuButton
@onready var pause_button: Button = $UI/GameHUD/BottomPanel/BottomContainer/PauseButton
@onready var restart_button: Button = $UI/GameHUD/BottomPanel/BottomContainer/RestartButton
@onready var debug_button: Button = $UI/GameHUD/BottomPanel/BottomContainer/DebugButton

@onready var ai_stats_panel: Panel = $UI/GameHUD/AIStats
@onready var stats_content: VBoxContainer = $UI/GameHUD/AIStats/StatsContainer/StatsList/StatsContent

@onready var pause_menu: Panel = $UI/GameHUD/PauseMenu
@onready var resume_button: Button = $UI/GameHUD/PauseMenu/PauseContainer/ResumeButton
@onready var main_menu_button: Button = $UI/GameHUD/PauseMenu/PauseContainer/MainMenuButton
@onready var quit_button: Button = $UI/GameHUD/PauseMenu/PauseContainer/QuitButton

var game_manager: Node
var is_paused: bool = false
var debug_mode: bool = false
var spawned_characters: Array[Node2D] = []

func _ready():
	setup_arena()
	connect_ui_signals()
	arena_ready.emit()
	print("Game Arena Manager initialized")

func setup_arena():
	# Настраиваем камеру
	if camera:
		camera.enabled = true
	
	# Настраиваем арену
	if arena:
		arena.name = "LevelInstance"
	
	print("Arena setup completed")

func connect_ui_signals():
	# Кнопки управления
	menu_button.pressed.connect(_on_menu_button_pressed)
	pause_button.pressed.connect(_on_pause_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)
	debug_button.pressed.connect(_on_debug_button_pressed)
	
	# Кнопки паузы
	resume_button.pressed.connect(_on_resume_button_pressed)
	main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)

func set_game_manager(manager: Node):
	game_manager = manager
	
	# Подключаем сигналы от игрового менеджера
	if game_manager:
		game_manager.game_started.connect(_on_game_started)
		game_manager.game_ended.connect(_on_game_ended)
		game_manager.round_started.connect(_on_round_started)
		game_manager.round_ended.connect(_on_round_ended)

func spawn_characters(player_character: Node2D, ai_agents: Array[Node2D]):
	# Очищаем предыдущих персонажей
	clear_spawned_characters()
	
	# Спавним персонажей на точках спавна
	var spawn_positions = get_spawn_positions()
	var spawn_index = 0
	
	# Спавним игрока
	if player_character:
		if spawn_index < spawn_positions.size():
			player_character.global_position = spawn_positions[spawn_index]
			spawn_index += 1
		add_child(player_character)
		spawned_characters.append(player_character)
	
	# Спавним AI агентов
	for ai in ai_agents:
		if spawn_index < spawn_positions.size():
			ai.global_position = spawn_positions[spawn_index]
			spawn_index += 1
		else:
			# Если точек спавна не хватает, используем случайные позиции
			ai.global_position = get_random_spawn_position()
		
		add_child(ai)
		spawned_characters.append(ai)
	
	print("Spawned ", spawned_characters.size(), " characters")

func get_spawn_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	
	if spawn_points:
		for child in spawn_points.get_children():
			if child is Marker2D:
				positions.append(child.global_position)
	
	return positions

func get_random_spawn_position() -> Vector2:
	return Vector2(
		randf_range(-800, 800),
		randf_range(-600, 600)
	)

func clear_spawned_characters():
	for character in spawned_characters:
		if character and character.get_parent():
			character.get_parent().remove_child(character)
			character.queue_free()
	spawned_characters.clear()

func _on_game_started(mode: String):
	update_mode_display(mode)
	reset_arena()

func _on_game_ended(winner: String, reason: String):
	show_game_over_screen(winner, reason)

func _on_round_started(round_number: int):
	update_round_display(round_number)

func _on_round_ended(winner: String, round_time: float):
	update_score_display()

func update_mode_display(mode: String):
	if mode_label:
		match mode:
			"0", "AI_VS_AI":
				mode_label.text = "Mode: AI vs AI"
			"1", "PLAYER_HIDE_AI_SEEK":
				mode_label.text = "Mode: Player Hide vs AI Seek"
			"2", "PLAYER_SEEK_AI_HIDE":
				mode_label.text = "Mode: Player Seek vs AI Hide"
			_:
				mode_label.text = "Mode: " + mode

func update_round_display(round_number: int):
	if round_label and game_manager:
		round_label.text = "Round: %d/%d" % [round_number, game_manager.max_rounds]

func update_time_display(time_left: float):
	if time_label:
		var minutes = int(time_left) / 60
		var seconds = int(time_left) % 60
		time_label.text = "Time: %d:%02d" % [minutes, seconds]

func update_score_display():
	if hiders_label and seekers_label and game_manager:
		var status = game_manager.get_game_status()
		hiders_label.text = "Hiders: %d" % status.scores.hider
		seekers_label.text = "Seekers: %d" % status.scores.seeker

func _process(_delta):
	if game_manager and game_manager.current_state == game_manager.GameState.PLAYING:
		update_time_display(game_manager.round_timer)
		update_ai_stats()

func update_ai_stats():
	if not debug_mode or not ai_stats_panel.visible:
		return
	
	# Очищаем предыдущую статистику
	for child in stats_content.get_children():
		child.queue_free()
	
	# Добавляем статистику для каждого AI персонажа
	for character in spawned_characters:
		if character.has_method("get_ai_status"):
			var status = character.get_ai_status()
			add_ai_stat_entry(status)

func add_ai_stat_entry(status: Dictionary):
	var container = VBoxContainer.new()
	stats_content.add_child(container)
	
	# Имя и роль
	var name_label = Label.new()
	name_label.text = "%s (%s)" % [status.name, "Seeker" if status.is_seeker else "Hider"]
	name_label.add_theme_font_size_override("font_size", 14)
	container.add_child(name_label)
	
	# Действие и уверенность
	var action_label = Label.new()
	action_label.text = "Action: %s (%.2f)" % [status.current_action, status.action_confidence]
	action_label.modulate = Color.GRAY
	container.add_child(action_label)
	
	# Состояние
	var state_label = Label.new()
	state_label.text = "State: %s" % status.current_state
	state_label.modulate = Color.YELLOW
	container.add_child(state_label)
	
	# Обучение
	if status.has("episode"):
		var learning_label = Label.new()
		learning_label.text = "Episode: %d, Reward: %.1f" % [status.episode, status.total_reward]
		learning_label.modulate = Color.GREEN
		container.add_child(learning_label)
	
	# Разделитель
	var separator = HSeparator.new()
	container.add_child(separator)

func _on_menu_button_pressed():
	get_tree().paused = true
	pause_menu.visible = true

func _on_pause_button_pressed():
	toggle_pause()

func _on_restart_button_pressed():
	if game_manager:
		game_manager.restart_game()
		await get_tree().create_timer(1.0).timeout
		game_manager.start_game(game_manager.current_game_mode)

func _on_debug_button_pressed():
	toggle_debug_mode()

func _on_resume_button_pressed():
	resume_game()

func _on_main_menu_button_pressed():
	get_tree().paused = false
	if game_manager:
		game_manager.restart_game()
	
	# Возвращаемся в главное меню
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("_on_back_to_menu"):
		main_scene._on_back_to_menu()

func _on_quit_button_pressed():
	get_tree().quit()

func toggle_pause():
	if is_paused:
		resume_game()
	else:
		pause_game()

func pause_game():
	is_paused = true
	get_tree().paused = true
	pause_menu.visible = true
	pause_button.text = "Resume"

func resume_game():
	is_paused = false
	get_tree().paused = false
	pause_menu.visible = false
	pause_button.text = "Pause"

func toggle_debug_mode():
	debug_mode = not debug_mode
	ai_stats_panel.visible = debug_mode
	
	# Включаем/выключаем debug info для персонажей
	for character in spawned_characters:
		if character.has_method("toggle_debug_mode"):
			character.toggle_debug_mode()
	
	print("Debug mode: ", "ON" if debug_mode else "OFF")

func show_game_over_screen(winner: String, reason: String):
	# Создаем экран окончания игры
	var game_over_panel = Panel.new()
	game_over_panel.name = "GameOverPanel"
	game_over_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_hud.add_child(game_over_panel)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_panel.add_child(vbox)
	
	# Заголовок
	var title_label = Label.new()
	title_label.text = "Game Over!"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title_label)
	
	# Победитель
	var winner_label = Label.new()
	winner_label.text = "Winner: " + winner
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(winner_label)
	
	# Причина
	var reason_label = Label.new()
	reason_label.text = reason
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(reason_label)
	
	# Статистика
	if game_manager:
		var status = game_manager.get_game_status()
		var stats_label = Label.new()
		stats_label.text = "Final Score - Hiders: %d, Seekers: %d" % [status.scores.hider, status.scores.seeker]
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(stats_label)
	
	# Кнопки
	var button_container = HBoxContainer.new()
	vbox.add_child(button_container)
	
	var menu_button = Button.new()
	menu_button.text = "Main Menu"
	menu_button.pressed.connect(_on_main_menu_button_pressed)
	button_container.add_child(menu_button)
	
	var restart_button = Button.new()
	restart_button.text = "Play Again"
	restart_button.pressed.connect(_on_restart_button_pressed)
	button_container.add_child(restart_button)

func reset_arena():
	# Сбрасываем арену к исходному состоянию
	if arena and arena.has_method("reset_arena"):
		arena.reset_arena()
	
	# Скрываем экран окончания игры
	var game_over_panel = game_hud.get_node_or_null("GameOverPanel")
	if game_over_panel:
		game_over_panel.queue_free()
	
	# Сбрасываем UI
	update_score_display()
	update_time_display(300.0)
	
	arena_reset.emit()
	print("Arena reset completed")

func get_arena_status() -> Dictionary:
	var status = {
		"is_paused": is_paused,
		"debug_mode": debug_mode,
		"spawned_characters": spawned_characters.size(),
		"arena_ready": arena != null
	}
	
	if arena and arena.has_method("get_arena_status"):
		var arena_status = arena.get_arena_status()
		status.merge(arena_status)
	
	return status
