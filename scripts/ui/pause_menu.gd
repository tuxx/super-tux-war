extends Control

@onready var _resume_button: Button = $CenterContainer/PanelContainer/VBox/Buttons/ResumeButton
@onready var _new_game_button: Button = $CenterContainer/PanelContainer/VBox/Buttons/NewGameButton

func _ready() -> void:
	# Ensure the pause menu covers the screen and still processes while paused
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	_resume_button.pressed.connect(_on_resume_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	visibility_changed.connect(_on_visibility_changed)


func _unhandled_input(event: InputEvent) -> void:
	# Allow ESC to resume while the pause menu is visible
	if not visible:
		return
	if event.is_pressed() and not event.is_echo():
		if Input.is_action_pressed("ui_cancel") or Input.is_action_pressed("pause"):
			_on_resume_pressed()


func _on_resume_pressed() -> void:
	visible = false
	get_tree().paused = false


func _on_new_game_pressed() -> void:
	# Unpause and return to the main menu
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/start_menu.tscn")


func _on_visibility_changed() -> void:
	if visible:
		_resume_button.grab_focus()

