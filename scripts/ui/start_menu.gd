extends Control

# Preload popup scenes
const LEVEL_SELECT_POPUP_SCENE := preload("res://scenes/ui/level_select_popup.tscn")
const CHARACTER_SELECT_POPUP_SCENE := preload("res://scenes/ui/character_select_popup.tscn")
const CPU_SELECT_POPUP_SCENE := preload("res://scenes/ui/cpu_select_popup.tscn")

# Main menu button
@onready var _new_game_button: Button = $PanelContainer/VBox/ContentHBox/Buttons/NewGameButton

# Level navigation buttons
@onready var _prev_level_button: Button = $"%PrevLevelButton"
@onready var _next_level_button: Button = $"%NextLevelButton"

# Clickable areas
@onready var _player_button: Button = $"%PlayerButton"
@onready var _cpu_button: Button = $"%CPUButton"

# Preview elements
@onready var _level_thumb: TextureRect = $"%LevelThumb"
@onready var _selected_level_label: Label = $"%SelectedLevelLabel"
@onready var _player_preview: TextureRect = $"%PlayerPreview"
@onready var _cpu_preview: TextureRect = $"%CPUPreview"

# Popup instances
var _level_select_popup: AcceptDialog = null
var _character_select_popup: AcceptDialog = null
var _cpu_select_popup: AcceptDialog = null

var _level_paths: Array[String] = []
var _selected_level_index: int = 0

# Simple web-focused debug logger (debug builds only)
var _debug_enabled: bool = OS.has_feature("web") and OS.is_debug_build()
var _debug_label: Label = null

func _log(message: String) -> void:
	print("[StartMenu] ", message)
	if _debug_enabled and is_instance_valid(_debug_label):
		var current := _debug_label.text
		if current.length() > 2000:
			current = current.substr(max(0, current.length() - 1500), 1500)
		_debug_label.text = current + ("\n" if current != "" else "") + message

func _ready() -> void:
	# Full-rect root
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if _debug_enabled:
		_debug_label = Label.new()
		_debug_label.name = "Debug"
		_debug_label.modulate = Color(1, 1, 1, 0.8)
		_debug_label.add_theme_font_size_override("font_size", 12)
		_debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_debug_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_debug_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_debug_label.custom_minimum_size = Vector2(600, 0)
		add_child(_debug_label)
		_log("Debug overlay enabled (web).")
	
	# Create popup instances
	_setup_popups()
	
	# Connect button signals
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_prev_level_button.pressed.connect(_on_prev_level_pressed)
	_next_level_button.pressed.connect(_on_next_level_pressed)
	_player_button.pressed.connect(_on_character_select_pressed)
	_cpu_button.pressed.connect(_on_cpu_select_pressed)
	
	_new_game_button.grab_focus()
	
	call_deferred("_populate_levels")
	call_deferred("_update_preview_displays")

func _setup_popups() -> void:
	# Instantiate level select popup
	_level_select_popup = LEVEL_SELECT_POPUP_SCENE.instantiate()
	add_child(_level_select_popup)
	
	# Instantiate character select popup
	_character_select_popup = CHARACTER_SELECT_POPUP_SCENE.instantiate()
	add_child(_character_select_popup)
	_setup_character_select_popup()
	
	# Instantiate CPU select popup
	_cpu_select_popup = CPU_SELECT_POPUP_SCENE.instantiate()
	add_child(_cpu_select_popup)
	_setup_cpu_select_popup()

func _setup_character_select_popup() -> void:
	# Load character previews
	var tux_preview: TextureRect = _character_select_popup.get_node("%TuxPreview")
	var beasty_preview: TextureRect = _character_select_popup.get_node("%BeastyPreview")
	var gopher_preview: TextureRect = _character_select_popup.get_node("%GopherPreview")
	
	tux_preview.texture = _load_character_idle_frame("tux")
	beasty_preview.texture = _load_character_idle_frame("beasty")
	gopher_preview.texture = _load_character_idle_frame("gopher")
	
	# Connect buttons
	var tux_btn: Button = _character_select_popup.get_node("%TuxButton")
	var beasty_btn: Button = _character_select_popup.get_node("%BeastyButton")
	var gopher_btn: Button = _character_select_popup.get_node("%GopherButton")
	
	tux_btn.pressed.connect(_on_player_character_selected.bind("tux"))
	beasty_btn.pressed.connect(_on_player_character_selected.bind("beasty"))
	gopher_btn.pressed.connect(_on_player_character_selected.bind("gopher"))
	
	# Update button states based on selection
	_update_character_select_buttons()

func _setup_cpu_select_popup() -> void:
	# Load character previews
	var tux_preview: TextureRect = _cpu_select_popup.get_node("%TuxPreview")
	var beasty_preview: TextureRect = _cpu_select_popup.get_node("%BeastyPreview")
	var gopher_preview: TextureRect = _cpu_select_popup.get_node("%GopherPreview")
	
	tux_preview.texture = _load_character_idle_frame("tux")
	beasty_preview.texture = _load_character_idle_frame("beasty")
	gopher_preview.texture = _load_character_idle_frame("gopher")
	
	# Connect character buttons
	var tux_btn: Button = _cpu_select_popup.get_node("%TuxButton")
	var beasty_btn: Button = _cpu_select_popup.get_node("%BeastyButton")
	var gopher_btn: Button = _cpu_select_popup.get_node("%GopherButton")
	
	tux_btn.pressed.connect(_on_cpu_character_selected.bind("tux"))
	beasty_btn.pressed.connect(_on_cpu_character_selected.bind("beasty"))
	gopher_btn.pressed.connect(_on_cpu_character_selected.bind("gopher"))
	
	# Connect count buttons
	var minus_btn: Button = _cpu_select_popup.get_node("%MinusButton")
	var plus_btn: Button = _cpu_select_popup.get_node("%PlusButton")
	
	minus_btn.pressed.connect(_on_cpu_count_minus_pressed)
	plus_btn.pressed.connect(_on_cpu_count_plus_pressed)
	
	# Update button states
	_update_cpu_select_buttons()
	_update_cpu_count_display()

func _on_new_game_pressed() -> void:
	# Load the selected level
	var level_to_load: String = ""
	if _selected_level_index >= 0 and _selected_level_index < _level_paths.size():
		level_to_load = _level_paths[_selected_level_index]
	elif _level_paths.size() > 0:
		level_to_load = _level_paths[0]
	else:
		level_to_load = "res://scenes/levels/level01.tscn"
	
	if level_to_load != "":
		get_tree().change_scene_to_file(level_to_load)

func _on_prev_level_pressed() -> void:
	if _level_paths.size() == 0:
		return
	_selected_level_index -= 1
	if _selected_level_index < 0:
		_selected_level_index = _level_paths.size() - 1
	_update_preview_displays()
	_update_level_navigation_buttons()

func _on_next_level_pressed() -> void:
	if _level_paths.size() == 0:
		return
	_selected_level_index += 1
	if _selected_level_index >= _level_paths.size():
		_selected_level_index = 0
	_update_preview_displays()
	_update_level_navigation_buttons()

func _on_character_select_pressed() -> void:
	_update_character_select_buttons()
	_character_select_popup.popup_centered()

func _on_cpu_select_pressed() -> void:
	_update_cpu_select_buttons()
	_update_cpu_count_display()
	_cpu_select_popup.popup_centered()

func _on_player_character_selected(character_name: String) -> void:
	GameSettings.set_player_character(character_name)
	_log("Player character changed to: %s" % character_name)
	_update_character_select_buttons()
	_update_preview_displays()

func _on_cpu_character_selected(character_name: String) -> void:
	GameSettings.set_cpu_character(character_name)
	_log("CPU character changed to: %s" % character_name)
	_update_cpu_select_buttons()
	_update_preview_displays()

func _on_cpu_count_minus_pressed() -> void:
	GameSettings.decrease_cpu_count()
	_update_cpu_count_display()

func _on_cpu_count_plus_pressed() -> void:
	GameSettings.increase_cpu_count()
	_update_cpu_count_display()

func _update_character_select_buttons() -> void:
	var tux_btn: Button = _character_select_popup.get_node("%TuxButton")
	var beasty_btn: Button = _character_select_popup.get_node("%BeastyButton")
	var gopher_btn: Button = _character_select_popup.get_node("%GopherButton")
	
	var selected := GameSettings.get_player_character()
	tux_btn.disabled = (selected == "tux")
	beasty_btn.disabled = (selected == "beasty")
	gopher_btn.disabled = (selected == "gopher")

func _update_cpu_select_buttons() -> void:
	var tux_btn: Button = _cpu_select_popup.get_node("%TuxButton")
	var beasty_btn: Button = _cpu_select_popup.get_node("%BeastyButton")
	var gopher_btn: Button = _cpu_select_popup.get_node("%GopherButton")
	
	var selected := GameSettings.get_cpu_character()
	tux_btn.disabled = (selected == "tux")
	beasty_btn.disabled = (selected == "beasty")
	gopher_btn.disabled = (selected == "gopher")

func _update_cpu_count_display() -> void:
	var count_label: Label = _cpu_select_popup.get_node("%CountDisplay")
	var minus_btn: Button = _cpu_select_popup.get_node("%MinusButton")
	var plus_btn: Button = _cpu_select_popup.get_node("%PlusButton")
	
	count_label.text = str(GameSettings.get_cpu_count())
	minus_btn.disabled = (GameSettings.get_cpu_count() <= GameSettings.MIN_CPU_COUNT)
	plus_btn.disabled = (GameSettings.get_cpu_count() >= GameSettings.MAX_CPU_COUNT)

func _populate_levels() -> void:
	_level_paths.clear()
	_log("Populate levels started.")
	var dir_path := "res://scenes/levels"
	
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	_log("DirAccess.get_files_at -> %d entries" % files.size())
	
	if files.is_empty():
		var dir := DirAccess.open(dir_path)
		_log("DirAccess.open(%s) -> %s" % [dir_path, str(dir != null)])
		if dir:
			dir.list_dir_begin()
			var entry_name := dir.get_next()
			while entry_name != "":
				if not dir.current_is_dir():
					files.append(entry_name)
				entry_name = dir.get_next()
			dir.list_dir_end()
		_log("DirAccess iteration -> %d entries" % files.size())
	
	if files.is_empty():
		for n in range(1, 21):
			var candidate := "level%02d.tscn" % n
			files.append(candidate)
		_log("Probed level names -> %d candidates" % files.size())
	
	files.sort()
	for file_name in files:
		var lower := String(file_name).to_lower()
		if not lower.ends_with(".tscn"):
			continue
		if not lower.begins_with("level"):
			continue
		var level_path := dir_path + "/" + file_name
		var exists := ResourceLoader.exists(level_path)
		if not exists:
			var test := load(level_path)
			if test != null:
				exists = true
		if exists:
			_level_paths.append(level_path)
	
	if _level_paths.size() == 0:
		_log("No filtered .tscn files. Falling back to probing level01..level20.")
		for n in range(1, 21):
			var candidate_path := "%s/level%02d.tscn" % [dir_path, n]
			_level_paths.append(candidate_path)
	
	_log("Filtered level paths -> %d" % _level_paths.size())
	
	if _level_paths.size() > 0:
		_selected_level_index = 0
	
	_update_level_navigation_buttons()

func _populate_level_select_popup() -> void:
	if not _level_select_popup:
		return
	
	var grid: GridContainer = _level_select_popup.get_node("%LevelGrid")
	if not grid:
		return
	
	# Clear existing children
	for child in grid.get_children():
		child.queue_free()
	
	# Create a card for each level
	for i in range(_level_paths.size()):
		var level_path := _level_paths[i]
		var card := _create_level_card(i, level_path)
		grid.add_child(card)

func _create_level_card(index: int, level_path: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(240, 180)
	
	var vbox := VBoxContainer.new()
	card.add_child(vbox)
	
	var btn := Button.new()
	btn.flat = true
	btn.custom_minimum_size = Vector2(240, 180)
	btn.pressed.connect(_on_level_card_selected.bind(index))
	card.add_child(btn)
	
	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(220, 140)
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(thumb)
	
	var label := Label.new()
	label.text = _resolve_level_display_name(level_path)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(label)
	
	# Load thumbnail
	var thumbnail := LevelThumbnails.get_thumbnail(level_path)
	if thumbnail:
		thumb.texture = thumbnail
	
	# Highlight selected level
	if index == _selected_level_index:
		var border := ReferenceRect.new()
		border.border_color = Color(1, 1, 0, 1)
		border.border_width = 3.0
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(border)
		border.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	return card

func _on_level_card_selected(index: int) -> void:
	_selected_level_index = index
	_level_select_popup.hide()
	_update_preview_displays()

func _resolve_level_display_name(level_path: String) -> String:
	var packed: PackedScene = load(level_path)
	if packed == null:
		return _fallback_display_name_from_path(level_path)
	
	var level_instance: Node = packed.instantiate()
	if level_instance == null:
		return _fallback_display_name_from_path(level_path)
	
	var level_name := ""
	var info_node: Node = level_instance.get_node_or_null("LevelInfo")
	if info_node:
		var candidate := str(info_node.get("level_name"))
		if candidate.strip_edges() != "":
			level_name = candidate
	
	level_instance.queue_free()
	
	if level_name == "":
		var base := level_path.get_file().get_basename()
		if base.begins_with("level"):
			level_name = "Level " + base.substr(5, base.length() - 5)
		else:
			level_name = base.capitalize()
	return level_name

func _fallback_display_name_from_path(level_path: String) -> String:
	var base := level_path.get_file().get_basename()
	if base.begins_with("level"):
		return "Level " + base.substr(5, base.length() - 5)
	return base.capitalize()

func _load_character_idle_frame(character_name: String) -> Texture2D:
	# Try both plural and singular spritesheet folder names
	var paths := [
		"res://assets/characters/%s/spritesheets/idle.png" % character_name,
		"res://assets/characters/%s/spritesheet/idle.png" % character_name
	]
	
	for path in paths:
		if ResourceLoader.exists(path):
			var full_texture := load(path) as Texture2D
			if full_texture:
				# Create AtlasTexture for first frame (0, 0, 32, 32)
				var atlas := AtlasTexture.new()
				atlas.atlas = full_texture
				atlas.region = Rect2(0, 0, 32, 32)
				return atlas
	
	return null

func _update_preview_displays() -> void:
	# Update level preview
	if _selected_level_index >= 0 and _selected_level_index < _level_paths.size():
		var level_path := _level_paths[_selected_level_index]
		_selected_level_label.text = _resolve_level_display_name(level_path)
		var thumbnail := LevelThumbnails.get_thumbnail(level_path)
		if thumbnail:
			_level_thumb.texture = thumbnail
		else:
			_level_thumb.texture = null
	else:
		_selected_level_label.text = "No Level Selected"
		_level_thumb.texture = null
	
	# Update player character preview
	var player_char := GameSettings.get_player_character()
	_player_preview.texture = _load_character_idle_frame(player_char)
	
	# Update CPU character preview
	var cpu_char := GameSettings.get_cpu_character()
	_cpu_preview.texture = _load_character_idle_frame(cpu_char)

func _update_level_navigation_buttons() -> void:
	# Enable/disable navigation buttons based on available levels
	var has_levels := _level_paths.size() > 0
	_prev_level_button.disabled = not has_levels
	_next_level_button.disabled = not has_levels
