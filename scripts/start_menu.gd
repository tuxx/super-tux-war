extends Control

@onready var _new_game_button: Button = $PanelContainer/VBox/Buttons/NewGameButton
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

func _ready() -> void:
	# Full-rect root
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_new_game_button.grab_focus()
	# Collect card node arrays and wire their click handlers once
	_card_containers = [_card1_container, _card2_container]
	_card_borders = [_card1_border, _card2_border]
	_card_buttons = [_card1_button, _card2_button]
	_card_thumbs = [_card1_thumb, _card2_thumb]
	_card_labels = [_card1_label, _card2_label]
	for i in range(_card_buttons.size()):
		var btn := _card_buttons[i]
		var container := _card_containers[i]
		container.visible = false
		if not btn.pressed.is_connected(_on_card_pressed.bind(btn)):
			btn.pressed.connect(_on_card_pressed.bind(btn))
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

func _populate_levels() -> void:
	# Clear old entries if any
	_level_paths.clear()
	for i in range(_card_containers.size()):
		_card_containers[i].visible = false
		_card_thumbs[i].texture = null
		_card_labels[i].text = ""
	var dir_path := "res://scenes/levels"
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	files.sort()
	for file_name in files:
		var lower := String(file_name).to_lower()
		if not lower.ends_with(".tscn"):
			continue
		if not lower.begins_with("level"):
			continue
		var level_path := dir_path + "/" + file_name
		if not ResourceLoader.exists(level_path):
			continue
		_level_paths.append(level_path)
	# Fill available cards
	var to_show: int = min(_level_paths.size(), _card_buttons.size())
	for i in range(to_show):
		await _fill_card(i, _level_paths[i])

func _fill_card(index: int, level_path: String) -> void:
	var packed: PackedScene = load(level_path)
	if packed == null:
		return
	var level_instance: Node = packed.instantiate()
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
	await get_tree().process_frame
	var texture: Texture2D = await _generate_thumbnail_for_instance(level_instance)
	if is_instance_valid(thumb) and texture != null:
		thumb.texture = texture
	
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

func _generate_thumbnail_for_instance(level_instance: Node) -> Texture2D:
	var subvp := SubViewport.new()
	subvp.size = Vector2i(256, 144)
	subvp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	subvp.disable_3d = true
	subvp.transparent_bg = false
	add_child(subvp)
	# Place level under a container so we can scale/position to fit the whole map
	var container := Node2D.new()
	subvp.add_child(container)
	container.add_child(level_instance)
	# Compute bounds across all TileMapLayer nodes
	var bounds: Rect2 = _compute_level_bounds(level_instance)
	# Move top-left to origin and scale to fit
	var available: Vector2 = Vector2(subvp.size)
	var scale_factor: float = min(
		available.x / max(1.0, bounds.size.x),
		available.y / max(1.0, bounds.size.y)
	)
	container.scale = Vector2(scale_factor, scale_factor)
	var scaled_size: Vector2 = bounds.size * scale_factor
	var padding: Vector2 = (available - scaled_size) * 0.5
	container.position = -Vector2(bounds.position) * scale_factor + padding
	# Wait for the viewport to fully render the tiles
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var vp_tex: ViewportTexture = subvp.get_texture()
	# Try to convert to ImageTexture to detach from the SubViewport
	var out_tex: Texture2D = null
	var img: Image = vp_tex.get_image()
	if img != null:
		img.resize(256, 144)
		out_tex = ImageTexture.create_from_image(img)
	subvp.queue_free()
	# If conversion failed, fall back to viewport texture (rare drivers)
	return out_tex if out_tex != null else vp_tex

func _compute_level_bounds(root: Node) -> Rect2:
	var combined := Rect2()
	var any := false
	for child in root.get_children():
		if child is TileMapLayer:
			var layer := child as TileMapLayer
			var used := layer.get_used_rect()
			if used.size == Vector2i.ZERO:
				continue
			var ts := Vector2(32, 32)
			if layer.tile_set != null:
				ts = Vector2(layer.tile_set.tile_size)
			var rect_world := Rect2(Vector2(used.position) * ts, Vector2(used.size) * ts)
			if not any:
				combined = rect_world
				any = true
			else:
				combined = combined.merge(rect_world)
	# Fallback in case there were no tiles
	if not any:
		return Rect2(Vector2.ZERO, Vector2(256, 144))
	return combined
