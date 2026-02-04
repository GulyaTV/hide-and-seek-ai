extends Node

## Main Entry Point for Hide and Seek with AI
## Orchestrates the entire game experience

@onready var game_manager: Node = $GameManager
@onready var main_menu: Control = $MainMenu
@onready var ui_manager: Node = $UIManager

var current_scene: Node
var is_transitioning: bool = false

func _ready():
	print("Hide and Seek with AI - Main System Initialized")
	setup_connections()
	load_main_menu()

func setup_connections():
	# Подключаем сигналы главного меню
	if main_menu:
		main_menu.mode_selected.connect(_on_mode_selected)
		main_menu.settings_requested.connect(_on_settings_requested)
		main_menu.exit_requested.connect(_on_exit_requested)
	
	# Подключаем сигналы игрового менеджера
	if game_manager:
		game_manager.game_started.connect(_on_game_started)
		game_manager.game_ended.connect(_on_game_ended)
		game_manager.round_started.connect(_on_round_started)
		game_manager.round_ended.connect(_on_round_ended)

func load_main_menu():
	if current_scene:
		current_scene.queue_free()
	
	current_scene = main_menu
	add_child(main_menu)
	is_transitioning = false

func _on_mode_selected(game_mode: int):
	print("Mode selected: ", game_mode)
	start_game_with_mode(game_mode)

func start_game_with_mode(mode: int):
	if is_transitioning:
		return
	
	is_transitioning = true
	
	# Показываем прогресс загрузки
	if main_menu:
		main_menu.show_loading_progress(0.0)
	
	# Загружаем игру
	await get_tree().create_timer(0.5).timeout
	
	if main_menu:
		main_menu.show_loading_progress(0.3)
	
	# Инициализируем игровой менеджер
	if game_manager:
		game_manager.start_game(mode)
	
	if main_menu:
		main_menu.show_loading_progress(0.6)
	
	await get_tree().create_timer(0.5).timeout
	
	if main_menu:
		main_menu.show_loading_progress(1.0)
	
	await get_tree().create_timer(0.3).timeout
	
	# Переключаем на игровую сцену
	switch_to_game_scene()

func switch_to_game_scene():
	if main_menu and main_menu.get_parent():
		main_menu.queue_free()
		main_menu = null
	
	# Создаем игровую сцену
	var game_scene = preload("res://scenes/game_arena.tscn")
	if game_scene:
		current_scene = game_scene.instantiate()
		add_child(current_scene)
		print("Game scene loaded")
	else:
		# Создаем временную игровую сцену
		create_temporary_game_scene()
	
	is_transitioning = false

func create_temporary_game_scene():
	current_scene = Node2D.new()
	current_scene.name = "GameScene"
	add_child(current_scene)
	
	# Создаем HUD
	var hud = create_hud()
	current_scene.add_child(hud)
	
	print("Temporary game scene created")

func create_hud() -> Control:
	var hud = Control.new()
	hud.name = "HUD"
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Информационная панель
	var info_panel = Panel.new()
	info_panel.name = "InfoPanel"
	info_panel.position = Vector2(10, 10)
	info_panel.size = Vector2(300, 150)
	hud.add_child(info_panel)
	
	var info_label = Label.new()
	info_label.name = "InfoLabel"
	info_label.position = Vector2(10, 10)
	info_label.size = Vector2(280, 130)
	info_label.text = "Game Mode: AI vs AI\nRound: 1/5\nTime: 4:59\nScore: Hiders 0 - 0 Seekers"
	info_panel.add_child(info_label)
	
	# Кнопка возврата в меню
	var menu_button = Button.new()
	menu_button.name = "MenuButton"
	menu_button.text = "Back to Menu"
	menu_button.position = Vector2(10, 170)
	menu_button.size = Vector2(150, 40)
	menu_button.pressed.connect(_on_back_to_menu)
	hud.add_child(menu_button)
	
	# Кнопка паузы
	var pause_button = Button.new()
	pause_button.name = "PauseButton"
	pause_button.text = "Pause"
	pause_button.position = Vector2(170, 170)
	pause_button.size = Vector2(100, 40)
	pause_button.pressed.connect(_on_pause_game)
	hud.add_child(pause_button)
	
	return hud

func _on_back_to_menu():
	if game_manager:
		game_manager.restart_game()
	
	# Возвращаемся в главное меню
	var new_main_menu = preload("res://scenes/main_menu.tscn").instantiate()
	new_main_menu.script = preload("res://scripts/main_menu.gd")
	main_menu = new_main_menu
	setup_connections()
	load_main_menu()

func _on_pause_game():
	if game_manager:
		if game_manager.current_state == game_manager.GameState.PLAYING:
			game_manager.pause_game()
		elif game_manager.current_state == game_manager.GameState.PAUSED:
			game_manager.resume_game()

func _on_settings_requested():
	print("Settings requested")
	# TODO: Создать сцену настроек

func _on_exit_requested():
	print("Exiting game")
	get_tree().quit()

func _on_game_started(mode: String):
	print("Game started with mode: ", mode)
	update_hud_info()

func _on_game_ended(winner: String, reason: String):
	print("Game ended - Winner: ", winner, ", Reason: ", reason)
	show_game_over_screen(winner, reason)

func _on_round_started(round_number: int):
	print("Round ", round_number, " started")
	update_hud_info()

func _on_round_ended(winner: String, round_time: float):
	print("Round ended - Winner: ", winner, ", Time: ", round_time)
	update_hud_info()

func update_hud_info():
	if not current_scene:
		return
	
	var hud = current_scene.get_node_or_null("HUD")
	if not hud:
		return
	
	var info_label = hud.get_node_or_null("InfoPanel/InfoLabel")
	if info_label and game_manager:
		var status = game_manager.get_game_status()
		var minutes = int(status.round_time) / 60
		var seconds = int(status.round_time) % 60
		
		info_label.text = "Game Mode: %s\nRound: %d/%d\nTime: %d:%02d\nScore: Hiders %d - %d Seekers\nHiders: %d | Seekers: %d" % [
			status.game_mode,
			status.current_round,
			status.max_rounds,
			minutes,
			seconds,
			status.scores.hider,
			status.scores.seeker,
			status.hiders_count,
			status.seekers_count
		]

func show_game_over_screen(winner: String, reason: String):
	# Создаем экран окончания игры
	var game_over_panel = Panel.new()
	game_over_panel.name = "GameOverPanel"
	game_over_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	current_scene.add_child(game_over_panel)
	
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
	
	# Кнопки
	var button_container = HBoxContainer.new()
	vbox.add_child(button_container)
	
	var menu_button = Button.new()
	menu_button.text = "Main Menu"
	menu_button.pressed.connect(_on_back_to_menu)
	button_container.add_child(menu_button)
	
	var restart_button = Button.new()
	restart_button.text = "Play Again"
	restart_button.pressed.connect(_restart_game)
	button_container.add_child(restart_button)

func _restart_game():
	# Удаляем экран окончания игры
	if current_scene:
		var game_over_panel = current_scene.get_node_or_null("GameOverPanel")
		if game_over_panel:
			game_over_panel.queue_free()
	
	# Перезапускаем игру
	if game_manager:
		game_manager.restart_game()
		await get_tree().create_timer(1.0).timeout
		game_manager.start_game(game_manager.current_game_mode)

func _process(_delta):
	# Обновляем HUD в реальном времени
	if game_manager and game_manager.current_state == game_manager.GameState.PLAYING:
		update_hud_info()

func _input(event):
	# Глобальные горячие клавиши
	if event.is_action_pressed("restart_game"):
		if game_manager:
			game_manager.restart_game()
			await get_tree().create_timer(1.0).timeout
			game_manager.start_game(game_manager.current_game_mode)
	
	if event.is_action_pressed("ui_cancel"):  # ESC
		if current_scene and current_scene.name == "GameScene":
			_on_back_to_menu()
		elif current_scene and current_scene.name == "MainMenu":
			_on_exit_requested()
