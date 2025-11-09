extends Node

const SCORE_COUNTER_SCENE := preload("res://scenes/ui/score_counter.tscn")

var _last_scene: Node = null

func _ready() -> void:
	# Ensure we run even when paused and across scenes
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	var cs := get_tree().current_scene
	if cs != _last_scene:
		_last_scene = cs
		_ensure_hud(cs)


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


