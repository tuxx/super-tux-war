extends Control

@onready var _new_game_button: Button = $CenterContainer/PanelContainer/VBox/Buttons/NewGameButton

func _ready() -> void:
	# Full-rect root
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_new_game_button.pressed.connect(_on_new_game_pressed)


func _on_new_game_pressed() -> void:
	# Load the main level scene
	get_tree().change_scene_to_file("res://scenes/levels/tile_map.tscn")


