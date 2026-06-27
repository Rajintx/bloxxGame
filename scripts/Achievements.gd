extends Control

@onready var back_btn: Button = $BackButton

func _ready() -> void:
	back_btn.pressed.connect(_on_back)

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/StartMenu.tscn")