extends Control

const GAME_SCENE := "res://scenes/world1-sandbox.tscn"

@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/ExitButton

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	play_button.grab_focus()

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_exit_pressed() -> void:
	get_tree().quit()
