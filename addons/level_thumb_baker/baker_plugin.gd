@tool
extends EditorPlugin

const LEVELS_DIR := "res://scenes/levels"
const OUT_DIR := "res://assets/level_thumbs"
const THUMB_SIZE := Vector2i(256, 144)
const REGISTRY_PATH := "res://scripts/level_thumbnails.gd"

var _menu_name := "Level Thumbs"
var _filesystem: EditorFileSystem = null

func _enter_tree() -> void:
	add_tool_menu_item("%s: Bake" % _menu_name, _on_bake_pressed)
	_filesystem = get_editor_interface().get_resource_filesystem()
	# Auto-bake when filesystem changes (new/modified levels)
	if _filesystem:
		_filesystem.resources_reimported.connect(_on_resources_reimported)

func _exit_tree() -> void:
	remove_tool_menu_item("%s: Bake" % _menu_name)
	if _filesystem and _filesystem.resources_reimported.is_connected(_on_resources_reimported):
		_filesystem.resources_reimported.disconnect(_on_resources_reimported)
	_filesystem = null

func _on_bake_pressed() -> void:
	_bake_thumbnails()

func _on_resources_reimported(resources: PackedStringArray) -> void:
	# Check if any level scenes were modified
	var levels_changed := false
	for res in resources:
		if res.begins_with(LEVELS_DIR) and res.ends_with(".tscn"):
			levels_changed = true
			break
	
	if levels_changed:
		# Bake only the changed levels
		call_deferred("_bake_thumbnails")

func _bake_thumbnails() -> void:
	var editor_if := get_editor_interface()
	var base := editor_if.get_base_control()
	# Ensure output directory
	var root_da := DirAccess.open("res://")
	if root_da:
		root_da.make_dir_recursive("assets/level_thumbs")
	# Enumerate levels
	var files := DirAccess.get_files_at(LEVELS_DIR)
	files.sort()
	var count := 0
	var skipped := 0
	var baked_levels: Array[String] = []
	for file_name in files:
		var lower := String(file_name).to_lower()
		if not lower.ends_with(".tscn"):
			continue
		if not lower.begins_with("level"):
			continue
		var level_path := "%s/%s" % [LEVELS_DIR, file_name]
		var out_path := "%s/%s.png" % [OUT_DIR, file_name.get_basename()]
		
		# Check if thumbnail is up to date
		if _is_thumbnail_up_to_date(level_path, out_path):
			skipped += 1
			baked_levels.append(file_name.get_basename())
			continue
		
		var ok := await _render_level_thumbnail(level_path, out_path, base)
		if ok:
			count += 1
			baked_levels.append(file_name.get_basename())
	_update_registry(baked_levels)
	if count > 0:
		print("Baked %d level thumbnails (skipped %d up-to-date)" % [count, skipped])
	_filesystem.scan()  # Refresh filesystem so Godot sees the new files

func _render_level_thumbnail(level_path: String, out_path: String, parent: Control) -> bool:
	var packed: PackedScene = load(level_path)
	if packed == null:
		return false
	var level_instance: Node = packed.instantiate()
	if level_instance == null:
		return false
	# Build a temporary viewport hierarchy inside the editor UI so it renders
	var subvp := SubViewport.new()
	subvp.size = THUMB_SIZE
	subvp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	subvp.disable_3d = true
	subvp.transparent_bg = true  # Transparent so we see the actual content
	subvp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	parent.add_child(subvp)
	
	# Create a Camera2D to properly view the 2D content
	var camera := Camera2D.new()
	camera.enabled = true
	subvp.add_child(camera)
	var container := Node2D.new()
	camera.add_child(container)
	container.add_child(level_instance)
	# Compute bounds across TileMapLayer nodes
	var bounds: Rect2 = _compute_level_bounds(level_instance)
	var available: Vector2 = Vector2(subvp.size)
	var scale_factor: float = min(
		available.x / max(1.0, bounds.size.x),
		available.y / max(1.0, bounds.size.y)
	)
	container.scale = Vector2(scale_factor, scale_factor)
	var scaled_size: Vector2 = bounds.size * scale_factor
	var padding: Vector2 = (available - scaled_size) * 0.5
	container.position = -Vector2(bounds.position) * scale_factor + padding
	
	# Position camera to view the entire level
	camera.offset = available * 0.5
	# Wait a few frames to ensure render
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var tex: ViewportTexture = subvp.get_texture()
	var img: Image = tex.get_image()
	var ok := false
	if img:
		img.resize(THUMB_SIZE.x, THUMB_SIZE.y)
		# Save as PNG
		var abspath := ProjectSettings.globalize_path(out_path)
		var err := img.save_png(abspath)
		ok = err == OK
	subvp.queue_free()
	return ok

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
	if not any:
		return Rect2(Vector2.ZERO, Vector2(THUMB_SIZE))
	return combined

func _is_thumbnail_up_to_date(level_path: String, thumb_path: String) -> bool:
	# Check if thumbnail exists and is newer than the level scene
	if not FileAccess.file_exists(thumb_path):
		return false
	
	var level_time := FileAccess.get_modified_time(level_path)
	var thumb_time := FileAccess.get_modified_time(thumb_path)
	
	return thumb_time >= level_time

func _update_registry(level_names: Array[String]) -> void:
	# Generate the LevelThumbnails resource with preloaded textures
	var content := ""
	content += "extends Resource\n"
	content += "class_name LevelThumbnails\n\n"
	content += "## Centralized registry of preloaded level thumbnails\n"
	content += "## This ensures thumbnails are always available in web builds\n"
	content += "## Auto-generated by level_thumb_baker plugin\n\n"
	content += "# Preloaded thumbnails (PNG files work fine with compression disabled)\n"
	content += "const THUMBNAILS := {\n"
	
	for level_name in level_names:
		content += "\t\"%s\": preload(\"res://assets/level_thumbs/%s.png\"),\n" % [level_name, level_name]
	
	content += "}\n\n"
	content += "## Get thumbnail for a level path\n"
	content += "static func get_thumbnail(level_path: String) -> Texture2D:\n"
	content += "\tvar basename := level_path.get_file().get_basename()\n"
	content += "\tif THUMBNAILS.has(basename):\n"
	content += "\t\treturn THUMBNAILS[basename]\n"
	content += "\treturn null\n\n"
	content += "## Get all available level names that have thumbnails\n"
	content += "static func get_available_levels() -> Array[String]:\n"
	content += "\tvar levels: Array[String] = []\n"
	content += "\tlevels.assign(THUMBNAILS.keys())\n"
	content += "\treturn levels\n"
	
	var file := FileAccess.open(REGISTRY_PATH, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		push_warning("Updated LevelThumbnails registry at %s" % REGISTRY_PATH)


