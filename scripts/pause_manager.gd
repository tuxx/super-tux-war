extends Node

var _pause_menu: Control

func _ready() -> void:
	# Receive input even when the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Try to find the pause menu robustly
	_pause_menu = get_node_or_null("../HUD/PauseMenu")
	if _pause_menu == null:
		var scene := get_tree().current_scene
		if scene:
			_pause_menu = scene.get_node_or_null("HUD/PauseMenu")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_ESCAPE:
			_toggle_pause()
			get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	if get_tree().paused:
		get_tree().paused = false
		if is_instance_valid(_pause_menu):
			_pause_menu.visible = false
	else:
		if is_instance_valid(_pause_menu):
			_pause_menu.visible = true
		get_tree().paused = true
