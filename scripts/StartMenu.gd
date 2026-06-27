extends Control

@onready var start_game_btn: Button = $VBoxContainer/StartGameButton
@onready var settings_btn: Button = $VBoxContainer/SettingsButton
@onready var achievements_btn: Button = $VBoxContainer/AchievementsButton

func _ready() -> void:
	start_game_btn.pressed.connect(_on_start_game)
	settings_btn.pressed.connect(_on_settings)
	achievements_btn.pressed.connect(_on_achievements)

func _on_start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/Settings.tscn")

func _on_achievements() -> void:
	get_tree().change_scene_to_file("res://scenes/Achievements.tscn")