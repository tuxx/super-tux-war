extends Node

const SCORE_COUNTER_SCENE := preload("res://scenes/ui/score_counter.tscn")
const DEV_MENU_SCENE := preload("res://scenes/ui/dev_menu.tscn")
const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")

var _last_scene: Node = null
var _pause_menu: Control = null

func _ready() -> void:
	# Ensure we run even when paused and across scenes
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Hook centralized input toggles
	InputManager.pause_toggled.connect(_toggle_pause)


func _process(_delta: float) -> void:
	var cs := get_tree().current_scene
	if cs != _last_scene:
		_last_scene = cs
		_ensure_hud(cs)
		_ensure_dev_menu(cs)


func _input(_event: InputEvent) -> void:
	# Input handled centrally by InputManager; keep stub to avoid previous behavior
	pass


func _ensure_hud(root: Node) -> void:
	if root == null:
		return
	var hud := root.get_node_or_null("HUD")
	if hud == null:
		hud = CanvasLayer.new()
		hud.name = "HUD"
		root.add_child(hud)
	# Ensure ScoreCounter exists
	if hud.get_node_or_null("ScoreCounter") == null:
		var sc := SCORE_COUNTER_SCENE.instantiate()
		hud.add_child(sc)


func _ensure_dev_menu(root: Node) -> void:
	if root == null:
		return
	# Only in debug builds and only in level scenes (not menus)
	if not OS.is_debug_build():
		# Clean up if present from editor
		var existing_release := root.get_node_or_null("DevMenu")
		if existing_release:
			existing_release.queue_free()
		return
	
	# Don't show dev menu in UI scenes (menus)
	var scene_path := root.scene_file_path
	if scene_path.begins_with("res://scenes/ui/"):
		var existing := root.get_node_or_null("DevMenu")
		if existing:
			existing.queue_free()
		return
	
	if root.get_node_or_null("DevMenu") != null:
		return
	var dev := DEV_MENU_SCENE.instantiate()
	dev.name = "DevMenu"
	root.add_child(dev)


func _ensure_pause_menu() -> void:
	if is_instance_valid(_pause_menu):
		return
	var instance := PAUSE_MENU_SCENE.instantiate()
	var root := get_tree().current_scene
	var hud := root.get_node_or_null("HUD") if root else null
	if hud:
		hud.add_child(instance)
	else:
		root.add_child(instance)
	_pause_menu = instance as Control


func _toggle_pause() -> void:
	# Don't show pause menu in the start menu scene
	var current_scene := get_tree().current_scene
	if current_scene and current_scene.scene_file_path == "res://scenes/ui/start_menu.tscn":
		return
	
	if get_tree().paused:
		get_tree().paused = false
		if is_instance_valid(_pause_menu):
			_pause_menu.visible = false
	else:
		_ensure_pause_menu()
		if is_instance_valid(_pause_menu):
			_pause_menu.visible = true
		get_tree().paused = true


