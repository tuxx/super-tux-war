extends Node

var _pause_menu: Control
const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")

func _ready() -> void:
	# Receive input even when the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Do not require PauseMenu to exist in scenes; we'll create it on demand


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
		_ensure_pause_menu()
		if is_instance_valid(_pause_menu):
			_pause_menu.visible = true
		get_tree().paused = true


func _ensure_pause_menu() -> void:
	if is_instance_valid(_pause_menu):
		return
	var instance := PAUSE_MENU_SCENE.instantiate()
	# Prefer adding to HUD CanvasLayer if present for proper overlay ordering
	var root := get_tree().current_scene
	var hud := root.get_node_or_null("HUD") if root else null
	if hud:
		hud.add_child(instance)
	else:
		# Fallback: add next to manager
		get_parent().add_child(instance)
	_pause_menu = instance as Control
