extends Control

@onready var _new_game_button: Button = $PanelContainer/VBox/Buttons/NewGameButton
@onready var _vbox: VBoxContainer = $PanelContainer/VBox

var _cpu_count_minus: Button = null
var _cpu_count_plus: Button = null
var _cpu_count_label: Label = null
@onready var _card1_container: PanelContainer = $PanelContainer/VBox/LevelScroll/CenterContainer/LevelGrid/LevelCard1
@onready var _card1_border: ReferenceRect = $PanelContainer/VBox/LevelScroll/CenterContainer/LevelGrid/LevelCard1/Border
@onready var _card1_button: Button = $PanelContainer/VBox/LevelScroll/CenterContainer/LevelGrid/LevelCard1/Button
@onready var _card1_thumb: TextureRect = $PanelContainer/VBox/LevelScroll/CenterContainer/LevelGrid/LevelCard1/VBox/Thumb
@onready var _card1_label: Label = $PanelContainer/VBox/LevelScroll/CenterContainer/LevelGrid/LevelCard1/VBox/Name
@onready var _card2_container: PanelContainer = $PanelContainer/VBox/LevelScroll/CenterContainer/LevelGrid/LevelCard2
@onready var _card2_border: ReferenceRect = $PanelContainer/VBox/LevelScroll/CenterContainer/LevelGrid/LevelCard2/Border
@onready var _card2_button: Button = $PanelContainer/VBox/LevelScroll/CenterContainer/LevelGrid/LevelCard2/Button
@onready var _card2_thumb: TextureRect = $PanelContainer/VBox/LevelScroll/CenterContainer/LevelGrid/LevelCard2/VBox/Thumb
@onready var _card2_label: Label = $PanelContainer/VBox/LevelScroll/CenterContainer/LevelGrid/LevelCard2/VBox/Name

var _level_paths: Array[String] = []
var _card_containers: Array[PanelContainer] = []
var _card_borders: Array[ReferenceRect] = []
var _card_buttons: Array[Button] = []
var _card_thumbs: Array[TextureRect] = []
var _card_labels: Array[Label] = []
var _selected_level_index: int = -1

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
	
	# Create CPU count selector UI
	_create_cpu_count_ui()
	
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_new_game_button.grab_focus()
	
	# Connect CPU count buttons
	if _cpu_count_minus:
		_cpu_count_minus.pressed.connect(_on_cpu_count_minus_pressed)
	if _cpu_count_plus:
		_cpu_count_plus.pressed.connect(_on_cpu_count_plus_pressed)
	if _cpu_count_label:
		_update_cpu_count_display()
	
	# Collect card node arrays and wire their click handlers once
	_card_containers = [_card1_container, _card2_container]
	_card_borders = [_card1_border, _card2_border]
	_card_buttons = [_card1_button, _card2_button]
	_card_thumbs = [_card1_thumb, _card2_thumb]
	_card_labels = [_card1_label, _card2_label]
	_log("Cards available: %d" % _card_buttons.size())
	for i in range(_card_buttons.size()):
		var btn := _card_buttons[i]
		var container := _card_containers[i]
		container.visible = false
		if not btn.pressed.is_connected(_on_card_pressed.bind(btn)):
			btn.pressed.connect(_on_card_pressed.bind(btn))
		if not btn.gui_input.is_connected(_on_card_gui_input.bind(i)):
			btn.gui_input.connect(_on_card_gui_input.bind(i))
	_log("Connected button signals.")
	call_deferred("_populate_levels")


func _on_new_game_pressed() -> void:
	# Load the selected level, or the first available level
	var level_to_load: String = ""
	if _selected_level_index >= 0 and _selected_level_index < _level_paths.size():
		level_to_load = _level_paths[_selected_level_index]
	elif _level_paths.size() > 0:
		level_to_load = _level_paths[0]
	else:
		# Fallback to level01 if list could not be built
		level_to_load = "res://scenes/levels/level01.tscn"
	
	if level_to_load != "":
		get_tree().change_scene_to_file(level_to_load)


func _on_cpu_count_minus_pressed() -> void:
	if has_node("/root/GameSettings"):
		GameSettings.decrease_cpu_count()
		_update_cpu_count_display()


func _on_cpu_count_plus_pressed() -> void:
	if has_node("/root/GameSettings"):
		GameSettings.increase_cpu_count()
		_update_cpu_count_display()


func _update_cpu_count_display() -> void:
	if not _cpu_count_label:
		return
	
	if not has_node("/root/GameSettings"):
		_cpu_count_label.text = "1"
		return
	
	var count := GameSettings.get_cpu_count()
	_cpu_count_label.text = str(count)
	
	# Disable buttons at limits
	if _cpu_count_minus:
		_cpu_count_minus.disabled = (count <= GameSettings.MIN_CPU_COUNT)
	if _cpu_count_plus:
		_cpu_count_plus.disabled = (count >= GameSettings.MAX_CPU_COUNT)

func _populate_levels() -> void:
	# Clear old entries if any
	_level_paths.clear()
	_log("Populate levels started.")
	for i in range(_card_containers.size()):
		_card_containers[i].visible = false
		_card_thumbs[i].texture = null
		_card_labels[i].text = ""
	var dir_path := "res://scenes/levels"
	# Primary: fast static helper (may return empty on some Web builds)
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	_log("DirAccess.get_files_at -> %d entries" % files.size())
	if files.is_empty():
		# Fallback: iterate using DirAccess instance (more broadly supported)
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
	# Final fallback: probe known levelXX.tscn names
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
			# Web fallback: try actually loading to test presence
			var test := load(level_path)
			if test != null:
				exists = true
		# Even if existence cannot be confirmed (Web), still add candidates;
		# we'll attempt to load during fill and keep placeholders visible.
		if exists:
			_level_paths.append(level_path)
		else:
			_level_paths.append(level_path)
	# If nothing passed the filters, try a conservative fallback list
	if _level_paths.size() == 0:
		_log("No filtered .tscn files. Falling back to probing level01..level20.")
		for n in range(1, 21):
			var candidate_path := "%s/level%02d.tscn" % [dir_path, n]
			_level_paths.append(candidate_path)
	_log("Filtered level paths -> %d" % _level_paths.size())
	# Fill available cards
	var to_show: int = min(_level_paths.size(), _card_buttons.size())
	_log("To show: %d (available buttons=%d)" % [to_show, _card_buttons.size()])
	for i in range(to_show):
		# Show placeholder immediately; thumbnail will be filled asynchronously
		_card_containers[i].visible = true
		_card_labels[i].text = _fallback_display_name_from_path(_level_paths[i])
		_card_buttons[i].tooltip_text = _card_labels[i].text
		_card_buttons[i].disabled = false
		_log("Showing placeholder for %s" % _level_paths[i])
		_fill_card(i, _level_paths[i])
	if to_show == 0:
		_log("No levels to show. Check export includes or directory listing on Web.")

func _fill_card(index: int, level_path: String) -> void:
	_log("Filling card %d with %s" % [index, level_path])
	var packed: PackedScene = load(level_path)
	if packed == null:
		_log("Failed to load scene: %s" % level_path)
		return
	var level_instance: Node = packed.instantiate()
	if level_instance == null:
		_log("Failed to instantiate: %s" % level_path)
	var display_name := _resolve_level_display_name(level_path, level_instance)
	var container := _card_containers[index]
	var btn := _card_buttons[index]
	var thumb := _card_thumbs[index]
	var label := _card_labels[index]
	container.visible = true
	btn.tooltip_text = display_name
	btn.text = ""
	btn.set_meta("level_path", level_path)
	label.text = display_name
	thumb.texture = null
	btn.disabled = false
	
	# Use preloaded thumbnail from registry
	var preloaded_tex := LevelThumbnails.get_thumbnail(level_path)
	if preloaded_tex != null:
		thumb.texture = preloaded_tex
		_log("Loaded thumbnail for %s" % display_name)
	else:
		_log("No thumbnail found for %s (run baker in editor)" % display_name)
	
	# Auto-select first level
	if index == 0:
		_selected_level_index = 0
		_update_card_selection()

func _resolve_level_display_name(level_path: String, level_instance: Node) -> String:
	var level_name := ""
	var info_node: Node = level_instance.get_node_or_null("LevelInfo")
	if info_node:
		var candidate := str(info_node.get("level_name"))
		if candidate.strip_edges() != "":
			level_name = candidate
	if level_name == "":
		var base := level_path.get_file().get_basename()
		if base.begins_with("level"):
			level_name = "Level " + base.substr(5, base.length() - 5)
		else:
			level_name = base.capitalize()
	return level_name

func _on_card_pressed(button: Button) -> void:
	# Find which card was clicked
	for i in range(_card_buttons.size()):
		if _card_buttons[i] == button:
			_selected_level_index = i
			_update_card_selection()
			break

func _on_card_gui_input(event: InputEvent, card_index: int) -> void:
	# Detect double-click to launch level directly
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.double_click:
			# Double-click detected - launch the level
			if card_index >= 0 and card_index < _level_paths.size():
				var level_to_load := _level_paths[card_index]
				_log("Double-click detected on card %d, launching %s" % [card_index, level_to_load])
				get_tree().change_scene_to_file(level_to_load)

func _update_card_selection() -> void:
	# Update visual feedback for selected card (show/hide border)
	for i in range(_card_borders.size()):
		if i == _selected_level_index:
			_card_borders[i].visible = true  # Show yellow border
			# Move focus to the selected card so theme focus border shows
			if is_instance_valid(_card_buttons[i]):
				_card_buttons[i].grab_focus()
		else:
			_card_borders[i].visible = false  # Hide border
			if is_instance_valid(_card_buttons[i]) and _card_buttons[i].has_focus():
				_card_buttons[i].release_focus()

func _fallback_display_name_from_path(level_path: String) -> String:
	var base := level_path.get_file().get_basename()
	if base.begins_with("level"):
		return "Level " + base.substr(5, base.length() - 5)
	return base.capitalize()


func _create_cpu_count_ui() -> void:
	# Create CPU count selector and add it to the VBox (before level scroll)
	var cpu_section := VBoxContainer.new()
	cpu_section.name = "CPUCountSection"
	
	# Title label
	var title_label := Label.new()
	title_label.text = "CPU Opponents"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	cpu_section.add_child(title_label)
	
	# Add some spacing
	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(0, 10)
	cpu_section.add_child(spacer1)
	
	# HBox for controls
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cpu_section.add_child(hbox)
	
	# Minus button
	_cpu_count_minus = Button.new()
	_cpu_count_minus.text = "−"
	_cpu_count_minus.custom_minimum_size = Vector2(50, 50)
	_cpu_count_minus.add_theme_font_size_override("font_size", 24)
	hbox.add_child(_cpu_count_minus)
	
	# Spacer
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(20, 0)
	hbox.add_child(spacer2)
	
	# Count label
	_cpu_count_label = Label.new()
	_cpu_count_label.text = "1"
	_cpu_count_label.custom_minimum_size = Vector2(60, 50)
	_cpu_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cpu_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cpu_count_label.add_theme_font_size_override("font_size", 28)
	hbox.add_child(_cpu_count_label)
	
	# Spacer
	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(20, 0)
	hbox.add_child(spacer3)
	
	# Plus button
	_cpu_count_plus = Button.new()
	_cpu_count_plus.text = "+"
	_cpu_count_plus.custom_minimum_size = Vector2(50, 50)
	_cpu_count_plus.add_theme_font_size_override("font_size", 24)
	hbox.add_child(_cpu_count_plus)
	
	# Add another spacer after the controls
	var spacer4 := Control.new()
	spacer4.custom_minimum_size = Vector2(0, 20)
	cpu_section.add_child(spacer4)
	
	# Find the LevelScroll node and insert CPU section before it
	var level_scroll := _vbox.get_node_or_null("LevelScroll")
	if level_scroll:
		var index := level_scroll.get_index()
		_vbox.add_child(cpu_section)
		_vbox.move_child(cpu_section, index)
	else:
		# Fallback: add at the beginning
		_vbox.add_child(cpu_section)
		_vbox.move_child(cpu_section, 0)
