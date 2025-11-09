extends Control

@onready var _score_table: VBoxContainer = $"%ScoreTable"
@onready var _restart_button: Button = $"%RestartButton"
@onready var _menu_button: Button = $"%MenuButton"

var _current_level_path: String = ""

func _ready() -> void:
	# Add to group so pause manager can check if we're active
	add_to_group("game_over_active")
	
	_restart_button.pressed.connect(_on_restart_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_populate_scoreboard()

func set_current_level(level_path: String) -> void:
	_current_level_path = level_path

func _populate_scoreboard() -> void:
	# Remove existing rows (keep header)
	for child in _score_table.get_children():
		if child.name != "TableHeader":
			child.queue_free()
	
	# Get all characters and their scores
	var character_scores: Array[Dictionary] = []
	var characters := get_tree().get_nodes_in_group("characters")
	
	for node in characters:
		var character := node as CharacterController
		if character:
			# Get score from score counter
			var score := _get_character_score(character)
			character_scores.append({
				"character": character,
				"score": score,
				"name": GameSettings.get_character_display_name(character.character_asset_name),
				"is_player": character.is_player
			})
	
	# Sort by score (highest first)
	character_scores.sort_custom(func(a, b): return a.score > b.score)
	
	# Create rows
	for entry in character_scores:
		var row := _create_score_row(entry)
		_score_table.add_child(row)

func _get_character_score(character: CharacterController) -> int:
	# Try to get score from ScoreCounter
	var score_counter := get_tree().get_first_node_in_group("score_counter")
	if score_counter and score_counter.has_method("get_character_score"):
		return score_counter.get_character_score(character)
	return 0

func _create_score_row(entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	
	# Kills
	var kills_label := Label.new()
	kills_label.custom_minimum_size = Vector2(80, 0)
	kills_label.text = str(entry.score)
	kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kills_label.add_theme_font_size_override("font_size", 16)
	row.add_child(kills_label)
	
	# Character name
	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(150, 0)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text = entry.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	row.add_child(name_label)
	
	# Player indicator (Player or CPU text)
	var player_label := Label.new()
	player_label.custom_minimum_size = Vector2(100, 0)
	player_label.text = "Player" if entry.is_player else "CPU"
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_label.add_theme_font_size_override("font_size", 16)
	player_label.add_theme_color_override("font_color", Color.GREEN if entry.is_player else Color.RED)
	row.add_child(player_label)
	
	return row

func _on_restart_pressed() -> void:
	# Remove from group
	remove_from_group("game_over_active")
	
	# Remove this menu immediately
	queue_free()
	
	# Unpause before changing scene
	get_tree().paused = false
	
	if _current_level_path != "":
		get_tree().change_scene_to_file(_current_level_path)
	else:
		# Fallback to first level
		get_tree().change_scene_to_file("res://scenes/levels/level01.tscn")

func _on_menu_pressed() -> void:
	# Remove from group
	remove_from_group("game_over_active")
	
	# Remove this menu immediately
	queue_free()
	
	# Unpause before changing scene
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/start_menu.tscn")

