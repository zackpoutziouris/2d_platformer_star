extends CanvasLayer

const MAIN_MENU_SCENE := "res://scenes/menus/MainMenu.tscn"

@onready var retry_button: Button = $CenterContainer/VBoxContainer/RetryButton
@onready var main_menu_button: Button = $CenterContainer/VBoxContainer/MainMenuButton

func _ready() -> void:
	hide()
	retry_button.pressed.connect(_on_retry_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		player.died.connect(_on_player_died)

func _on_player_died() -> void:
	show()
	retry_button.grab_focus()

func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
