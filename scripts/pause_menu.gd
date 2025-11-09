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


func _unhandled_input(event: InputEvent) -> void:
	# Allow ESC to resume while the pause menu is visible
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_ESCAPE:
			_on_resume_pressed()


func _on_resume_pressed() -> void:
	visible = false
	get_tree().paused = false


func _on_new_game_pressed() -> void:
	# Unpause and restart the level
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/levels/tile_map.tscn")


