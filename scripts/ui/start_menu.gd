extends Control

# Preload popup scenes
const CHARACTER_SELECT_POPUP_SCENE := preload("res://scenes/ui/character_select_popup.tscn")
const CPU_SELECT_POPUP_SCENE := preload("res://scenes/ui/cpu_select_popup.tscn")

# Main menu button
@onready var _new_game_button: Button = $PanelContainer/VBox/ContentHBox/Buttons/NewGameButton

# Level navigation buttons
@onready var _prev_level_button: Button = $"%PrevLevelButton"
@onready var _next_level_button: Button = $"%NextLevelButton"

# Kills to win controls
@onready var _decrease_kills_button: Button = $"%DecreaseKillsButton"
@onready var _increase_kills_button: Button = $"%IncreaseKillsButton"
@onready var _kills_display: Label = $"%KillsDisplay"

# Clickable areas
@onready var _player_button: Button = $"%PlayerButton"
@onready var _cpu_button: Button = $"%CPUButton"

# Preview elements
@onready var _level_thumb: TextureRect = $"%LevelThumb"
@onready var _selected_level_label: Label = $"%SelectedLevelLabel"
@onready var _player_preview: TextureRect = $"%PlayerPreview"
@onready var _cpu_preview: TextureRect = $"%CPUPreview"

# Popup instances
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
	_decrease_kills_button.pressed.connect(_on_decrease_kills_pressed)
	_increase_kills_button.pressed.connect(_on_increase_kills_pressed)
	_player_button.pressed.connect(_on_character_select_pressed)
	_cpu_button.pressed.connect(_on_cpu_select_pressed)
	
	_new_game_button.grab_focus()
	
	call_deferred("_populate_levels")
	call_deferred("_update_preview_displays")
	call_deferred("_update_kills_display")

func _setup_popups() -> void:
	# Instantiate character select popup
	_character_select_popup = CHARACTER_SELECT_POPUP_SCENE.instantiate()
	add_child(_character_select_popup)
	_setup_character_select_popup()
	
	# Instantiate CPU select popup
	_cpu_select_popup = CPU_SELECT_POPUP_SCENE.instantiate()
	add_child(_cpu_select_popup)
	_setup_cpu_select_popup()

func _setup_character_select_popup() -> void:
	_setup_character_popup_common(
		_character_select_popup,
		_on_player_character_selected
	)
	_update_character_select_buttons()

func _setup_cpu_select_popup() -> void:
	_setup_character_popup_common(
		_cpu_select_popup,
		_on_cpu_character_selected
	)
	
	# Connect count buttons
	var minus_btn: Button = _cpu_select_popup.get_node("%MinusButton")
	var plus_btn: Button = _cpu_select_popup.get_node("%PlusButton")
	
	minus_btn.pressed.connect(_on_cpu_count_minus_pressed)
	plus_btn.pressed.connect(_on_cpu_count_plus_pressed)
	
	# Update button states
	_update_cpu_select_buttons()
	_update_cpu_count_display()

func _setup_character_popup_common(popup: AcceptDialog, on_select_callback: Callable) -> void:
	# Generic setup for character selection popups
	for char_name in GameSettings.AVAILABLE_CHARACTERS:
		var preview_name := "%s%sPreview" % [char_name.capitalize(), ""]
		var button_name := "%s%sButton" % [char_name.capitalize(), ""]
		
		var preview: TextureRect = popup.get_node("%" + preview_name)
		var button: Button = popup.get_node("%" + button_name)
		
		if preview:
			preview.texture = _load_character_idle_frame(char_name)
		
		if button:
			button.pressed.connect(on_select_callback.bind(char_name))

func _on_new_game_pressed() -> void:
	# Load the selected level
	var level_to_load: String = ""
	if _selected_level_index >= 0 and _selected_level_index < _level_paths.size():
		level_to_load = _level_paths[_selected_level_index]
	elif _level_paths.size() > 0:
		level_to_load = _level_paths[0]
	else:
		level_to_load = ResourcePaths.SCENE_LEVEL_01
	
	if level_to_load != "":
		GameStateManager.start_match(level_to_load)

func _on_prev_level_pressed() -> void:
	if _level_paths.size() == 0:
		return
	_selected_level_index -= 1
	if _selected_level_index < 0:
		_selected_level_index = _level_paths.size() - 1
	GameSettings.set_selected_level_index(_selected_level_index)
	_update_preview_displays()
	_update_level_navigation_buttons()

func _on_next_level_pressed() -> void:
	if _level_paths.size() == 0:
		return
	_selected_level_index += 1
	if _selected_level_index >= _level_paths.size():
		_selected_level_index = 0
	GameSettings.set_selected_level_index(_selected_level_index)
	_update_preview_displays()
	_update_level_navigation_buttons()

func _on_decrease_kills_pressed() -> void:
	GameSettings.decrease_kills_to_win()
	_update_kills_display()

func _on_increase_kills_pressed() -> void:
	GameSettings.increase_kills_to_win()
	_update_kills_display()

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
	_character_select_popup.hide()

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
	var dir_path := ResourcePaths.LEVELS_DIR
	var thumbs_path := ResourcePaths.LEVEL_THUMBS_DIR
	
	# Check which levels have thumbnails (more reliable for web builds)
	_log("Checking for level thumbnails...")
	for n in range(1, 100):  # Check up to level99
		var thumb_path := "%s/level%02d.png" % [thumbs_path, n]
		if ResourceLoader.exists(thumb_path):
			var level_path := "%s/level%02d.tscn" % [dir_path, n]
			# Verify the level scene also exists
			if ResourceLoader.exists(level_path):
				_level_paths.append(level_path)
				_log("Found level with thumbnail: level%02d" % n)
		else:
			# Stop checking once we hit a missing thumbnail
			# (assumes sequential numbering)
			if n > 5:  # Only break after checking at least level05
				break
	
	_log("Found %d level(s) with thumbnails" % _level_paths.size())
	
	if _level_paths.size() > 0:
		# Restore previously selected level index from GameSettings
		_selected_level_index = GameSettings.get_selected_level_index()
		# Clamp to valid range
		if _selected_level_index >= _level_paths.size():
			_selected_level_index = 0
			GameSettings.set_selected_level_index(_selected_level_index)
	
	_update_level_navigation_buttons()

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
		ResourcePaths.get_character_spritesheet_path(character_name) + ResourcePaths.CHARACTER_IDLE_SPRITE,
		ResourcePaths.get_character_spritesheet_alt_path(character_name) + ResourcePaths.CHARACTER_IDLE_SPRITE
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

func _update_kills_display() -> void:
	var kills := GameSettings.get_kills_to_win()
	_kills_display.text = str(kills)
	_decrease_kills_button.disabled = (kills <= GameSettings.MIN_KILLS_TO_WIN)
	_increase_kills_button.disabled = (kills >= GameSettings.MAX_KILLS_TO_WIN)
