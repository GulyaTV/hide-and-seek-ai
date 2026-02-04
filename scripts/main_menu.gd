extends Control

## Main Menu for Hide and Seek with AI
## Inspired by OpenAI's experiment interface

signal mode_selected(game_mode: int)
signal settings_requested()
signal exit_requested()

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var ai_vs_ai_button: Button = $VBoxContainer/ModeButtons/AIVsAI
@onready var player_hide_ai_seek_button: Button = $VBoxContainer/ModeButtons/PlayerHideAISeek
@onready var player_seek_ai_hide_button: Button = $VBoxContainer/ModeButtons/PlayerSeekAIHide
@onready var settings_button: Button = $VBoxContainer/BottomButtons/Settings
@onready var exit_button: Button = $VBoxContainer/BottomButtons/Exit
@onready var version_label: Label = $VBoxContainer/VersionLabel

@onready var description_panel: Panel = $DescriptionPanel
@onready var description_label: Label = $DescriptionPanel/VBoxContainer/DescriptionLabel
@onready var back_button: Button = $DescriptionPanel/VBoxContainer/BackButton

var selected_mode: int = 0

func _ready():
	setup_ui()
	connect_signals()
	animate_title()

func setup_ui():
	title_label.text = "Hide and Seek with AI"
	version_label.text = "v1.0 - Inspired by OpenAI Research"
	
	# Настраиваем кнопки режимов
	ai_vs_ai_button.text = "🤖 AI vs AI"
	player_hide_ai_seek_button.text = "🙋 Player Hide vs AI Seek"
	player_seek_ai_hide_button.text = "🔍 Player Seek vs AI Hide"
	
	settings_button.text = "⚙️ Settings"
	exit_button.text = "🚪 Exit"
	
	# Изначально скрываем панель описания
	description_panel.visible = false

func connect_signals():
	ai_vs_ai_button.pressed.connect(_on_ai_vs_ai_pressed)
	player_hide_ai_seek_button.pressed.connect(_on_player_hide_ai_seek_pressed)
	player_seek_ai_hide_button.pressed.connect(_on_player_seek_ai_hide_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	back_button.pressed.connect(_on_back_pressed)

func animate_title():
	# Анимация заголовка
	var tween = create_tween()
	tween.set_loops()
	tween.set_parallel(true)
	
	# Пульсация
	tween.tween_property(title_label, "modulate:a", 0.7, 2.0)
	tween.tween_property(title_label, "modulate:a", 1.0, 2.0)
	
	# Легкое покачивание
	tween.tween_property(title_label, "position:x", title_label.position.x - 5, 3.0)
	tween.tween_property(title_label, "position:x", title_label.position.x + 5, 3.0)

func _on_ai_vs_ai_pressed():
	selected_mode = 0
	show_description("AI vs AI Mode", 
		"Watch two neural networks compete against each other!\n\n" +
		"• Multiple AI agents learn through reinforcement\n" +
		"• Evolutionary algorithms improve strategies\n" +
		"• Emergent behaviors and surprising tactics\n" +
		"• Real-time learning visualization\n\n" +
		"Inspired by OpenAI's hide-and-seek experiment where " +
		"AI agents discovered complex strategies like box surfing " +
		"and ramp building through self-play.")

func _on_player_hide_ai_seek_pressed():
	selected_mode = 1
	show_description("Player Hide vs AI Seek", 
		"Test your hiding skills against intelligent AI!\n\n" +
		"• You play as the hider\n" +
		"• AI seeker uses reinforcement learning\n" +
		"• AI learns from your strategies\n" +
		"• Progressive difficulty\n\n" +
		"Experience what it's like to be hunted by an AI " +
		"that's constantly learning and adapting to your playstyle!")

func _on_player_seek_ai_hide_pressed():
	selected_mode = 2
	show_description("Player Seek vs AI Hide", 
		"Hunt intelligent AI agents that learn to evade!\n\n" +
		"• You play as the seeker\n" +
		"• AI hiders develop creative strategies\n" +
		"• AI learns optimal hiding spots\n" +
		"• Track AI learning progress\n\n" +
		"Can you find AI agents that are learning to become " +
		"better hiders with each game? Watch as they develop " +
		"increasingly sophisticated escape strategies!")

func show_description(title: String, description: String):
	description_label.text = "[center][b]" + title + "[/b][/center]\n\n" + description
	description_panel.visible = true
	
	# Анимация появления панели
	var tween = create_tween()
	description_panel.modulate.a = 0.0
	description_panel.scale = Vector2(0.8, 0.8)
	tween.set_parallel(true)
	tween.tween_property(description_panel, "modulate:a", 1.0, 0.3)
	tween.tween_property(description_panel, "scale", Vector2.ONE, 0.3)

func _on_back_pressed():
	# Анимация исчезновения панели
	var tween = create_tween()
	tween.tween_property(description_panel, "modulate:a", 0.0, 0.3)
	tween.tween_property(description_panel, "scale", Vector2(0.8, 0.8), 0.3)
	tween.tween_callback(_hide_description_panel)

func _hide_description_panel():
	description_panel.visible = false
	description_panel.modulate.a = 1.0
	description_panel.scale = Vector2.ONE
	
	# Запускаем выбранный режим
	mode_selected.emit(selected_mode)

func _on_settings_pressed():
	settings_requested.emit()

func _on_exit_pressed():
	exit_requested.emit()

func show_loading_progress(progress: float):
	# Показываем прогресс загрузки
	if not has_node("LoadingPanel"):
		var loading_panel = create_loading_panel()
		add_child(loading_panel)
	
	var loading_panel = $LoadingPanel
	var progress_bar = loading_panel.get_node("VBoxContainer/ProgressBar")
	progress_bar.value = progress * 100

func create_loading_panel() -> Control:
	var panel = Panel.new()
	panel.name = "LoadingPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	panel.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var label = Label.new()
	label.text = "Loading AI Brains..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	var progress_bar = ProgressBar.new()
	progress_bar.name = "ProgressBar"
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = 0
	vbox.add_child(progress_bar)
	
	return panel

func hide_loading():
	if has_node("LoadingPanel"):
		$LoadingPanel.queue_free()

func show_error(message: String):
	# Показываем сообщение об ошибке
	var error_dialog = AcceptDialog.new()
	error_dialog.dialog_text = message
	add_child(error_dialog)
	error_dialog.popup_centered()

func show_ai_statistics(stats: Dictionary):
	# Показываем статистику AI
	var stats_window = Window.new()
	stats_window.title = "AI Learning Statistics"
	stats_window.size = Vector2(600, 400)
	stats_window.position = get_viewport().get_visible_rect().size / 2 - stats_window.size / 2
	
	var vbox = VBoxContainer.new()
	stats_window.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	
	# Заголовок
	var title = Label.new()
	title.text = "AI Learning Progress"
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	
	# Статистика
	for key in stats:
		var stat_label = Label.new()
		stat_label.text = str(key) + ": " + str(stats[key])
		vbox.add_child(stat_label)
	
	# Кнопка закрытия
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(stats_window.queue_free)
	vbox.add_child(close_button)
	
	add_child(stats_window)
	stats_window.popup_centered()
