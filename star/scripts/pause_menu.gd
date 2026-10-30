extends CanvasLayer

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"

@onready var resume_button: Button = $CenterContainer/VBoxContainer/ResumeButton
@onready var main_menu_button: Button = $CenterContainer/VBoxContainer/MainMenuButton

func _ready() -> void:
	# Keep running while the tree is paused, so this node can unpause it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	resume_button.pressed.connect(resume)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if get_tree().paused:
			resume()
		else:
			pause()
		get_viewport().set_input_as_handled()

func pause() -> void:
	get_tree().paused = true
	show()
	resume_button.grab_focus()

func resume() -> void:
	get_tree().paused = false
	hide()

func _on_main_menu_pressed() -> void:
	# Always unpause before leaving, or the main menu loads frozen.
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
