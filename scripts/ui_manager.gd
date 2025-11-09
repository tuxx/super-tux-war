extends Node

const SCORE_COUNTER_SCENE := preload("res://scenes/ui/score_counter.tscn")
const DEV_MENU_SCENE := preload("res://scenes/ui/dev_menu.tscn")

var _last_scene: Node = null

func _ready() -> void:
	# Ensure we run even when paused and across scenes
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	var cs := get_tree().current_scene
	if cs != _last_scene:
		_last_scene = cs
		_ensure_hud(cs)
		_ensure_dev_menu(cs)


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
	# Only in debug builds
	if not OS.is_debug_build():
		# Clean up if present from editor
		var existing_release := root.get_node_or_null("DevMenu")
		if existing_release:
			existing_release.queue_free()
		return
	if root.get_node_or_null("DevMenu") != null:
		return
	var dev := DEV_MENU_SCENE.instantiate()
	dev.name = "DevMenu"
	root.add_child(dev)


