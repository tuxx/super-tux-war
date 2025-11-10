extends Node

const CONFIG_PATH := "res://dev_launch.cfg"
const SECTION_LAUNCH := "launch"
const SECTION_PROJECT := "project"
const SECTION_DEV_MENU := "dev_menu"
const SECTION_MATCH := "match"
const SECTION_PLAYER_STATS := "player_stats"

@warning_ignore("shadowed_global_identifier")
const LevelNavigation := preload("res://scripts/levels/level_navigation.gd")

var _config: ConfigFile
var _apply_attempts: int = 0
const MAX_APPLY_ATTEMPTS := 20
var _match_attempts: int = 0
const MAX_MATCH_ATTEMPTS := 20
const MAX_NPC_CLEAR_ATTEMPTS := 10
var _match_start_triggered := false
var _waiting_for_start_menu_ready := false
var _pending_clear_npcs := false
var _pending_dev_menu_ref: WeakRef = null
var _player_stats_log_enabled := false

func _ready() -> void:
	if Engine.is_editor_hint() or not OS.is_debug_build():
		return
	
	var cfg := ConfigFile.new()
	var err := cfg.load(CONFIG_PATH)
	if err == ERR_DOES_NOT_EXIST:
		return
	if err != OK:
		push_warning("[DebugBootstrap] Failed to load %s (error %s)" % [CONFIG_PATH, err])
		return
	
	_config = cfg
	_apply_project_settings()
	_apply_player_stats_settings()
	
	get_tree().connect("scene_changed", Callable(self, "_on_scene_changed"), CONNECT_ONE_SHOT)
	
	if _config.has_section_key(SECTION_LAUNCH, "scene"):
		var scene_path: String = _config.get_value(SECTION_LAUNCH, "scene", "")
		if scene_path != "":
			call_deferred("_change_scene", scene_path)
			return
	
	# If no scene override, apply options once current scene is ready
	call_deferred("_on_scene_changed")


func _change_scene(scene_path: String) -> void:
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_warning("[DebugBootstrap] Failed to change scene to %s (error %s)" % [scene_path, err])


func _on_scene_changed() -> void:
	if _config == null:
		return
	_try_apply_dev_menu()
	_maybe_queue_auto_match()


func _apply_project_settings() -> void:
	if _config == null or not _config.has_section(SECTION_PROJECT):
		return
	
	if _config.has_section_key(SECTION_PROJECT, "nav_graph"):
		ProjectSettings.set_setting(
			LevelNavigation.SETTINGS_DRAW_GRAPH,
			bool(_config.get_value(SECTION_PROJECT, "nav_graph", false))
		)
	
	if _config.has_section_key(SECTION_PROJECT, "jump_arcs"):
		ProjectSettings.set_setting(
			LevelNavigation.SETTINGS_DRAW_JUMP,
			bool(_config.get_value(SECTION_PROJECT, "jump_arcs", false))
		)


func _try_apply_dev_menu() -> void:
	if _config == null or not _config.has_section(SECTION_DEV_MENU):
		return
	
	var dev_menu := _find_dev_menu()
	if dev_menu:
		_apply_dev_menu_options(dev_menu)
		return
	
	_apply_attempts += 1
	if _apply_attempts > MAX_APPLY_ATTEMPTS:
		push_warning("[DebugBootstrap] DevMenu not found; skipping debug options.")
		return
	
	get_tree().create_timer(0.2).timeout.connect(_try_apply_dev_menu, CONNECT_ONE_SHOT)


func _find_dev_menu() -> Node:
	return get_tree().root.find_child("DevMenu", true, false)


func _apply_dev_menu_options(dev_menu: Node) -> void:
	if dev_menu == null:
		return
	
	if _config.has_section_key(SECTION_DEV_MENU, "show_menu"):
		dev_menu.visible = bool(_config.get_value(SECTION_DEV_MENU, "show_menu", true))
	
	if _config.has_section_key(SECTION_DEV_MENU, "position"):
		var container: Variant = dev_menu.get("dev_menu_container")
		if container is Control:
			var pos: Vector2 = _config.get_value(SECTION_DEV_MENU, "position", (container as Control).position)
			if pos is Vector2:
				(container as Control).position = pos
	
	if _config.has_section_key(SECTION_DEV_MENU, "perf_graph"):
		var desired := bool(_config.get_value(SECTION_DEV_MENU, "perf_graph", false))
		var is_visible := bool(dev_menu.get("perf_graph_visible"))
		if desired != is_visible:
			dev_menu.call("_toggle_perf_graph")
	
	if _config.has_section_key(SECTION_DEV_MENU, "player_stats"):
		var desired_stats := bool(_config.get_value(SECTION_DEV_MENU, "player_stats", false))
		var is_stats_visible := bool(dev_menu.get("player_stats_visible"))
		if desired_stats != is_stats_visible:
			dev_menu.call("_toggle_player_stats")
	
	if _config.has_section_key(SECTION_DEV_MENU, "clear_npcs"):
		var should_clear := bool(_config.get_value(SECTION_DEV_MENU, "clear_npcs", false))
		if should_clear:
			_queue_clear_npcs(dev_menu)


func _maybe_queue_auto_match() -> void:
	if not _should_auto_start_match() or _match_start_triggered:
		return
	_try_start_match()


func _should_auto_start_match() -> bool:
	if _config == null or not _config.has_section(SECTION_MATCH):
		return false
	return bool(_config.get_value(SECTION_MATCH, "auto_start", false))


func _try_start_match() -> void:
	if _match_start_triggered:
		return
	if not _should_auto_start_match():
		return
	var start_menu := _get_start_menu_scene()
	if start_menu == null:
		_match_attempts += 1
		if _match_attempts > MAX_MATCH_ATTEMPTS:
			push_warning("[DebugBootstrap] StartMenu not ready; skipping auto match.")
			return
		get_tree().create_timer(0.2).timeout.connect(_try_start_match, CONNECT_ONE_SHOT)
		return
	if not start_menu.is_node_ready():
		if not _waiting_for_start_menu_ready:
			_waiting_for_start_menu_ready = true
			start_menu.ready.connect(Callable(self, "_on_start_menu_ready"), CONNECT_ONE_SHOT)
		return
	_queue_auto_match_start()


func _get_start_menu_scene() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null
	if current_scene.scene_file_path == ResourcePaths.SCENE_START_MENU:
		return current_scene
	if current_scene.name == "StartMenu":
		return current_scene
	return null


func _on_start_menu_ready() -> void:
	_queue_auto_match_start()


func _start_match_from_config() -> void:
	if not _match_start_triggered:
		return
	_apply_match_settings()
	await get_tree().process_frame
	var level_path := _get_match_level_path()
	if level_path == "":
		push_warning("[DebugBootstrap] No level configured for auto match; skipping.")
		return
	GameStateManager.start_match(level_path)


func _apply_match_settings() -> void:
	if _config == null or not _config.has_section(SECTION_MATCH):
		return
	if _config.has_section_key(SECTION_MATCH, "player_character"):
		var player_char := str(_config.get_value(SECTION_MATCH, "player_character", "")).strip_edges().to_lower()
		if player_char != "":
			GameSettings.set_player_character(player_char)
	if _config.has_section_key(SECTION_MATCH, "cpu_character"):
		var cpu_char := str(_config.get_value(SECTION_MATCH, "cpu_character", "")).strip_edges().to_lower()
		if cpu_char != "":
			GameSettings.set_cpu_character(cpu_char)
	if _config.has_section_key(SECTION_MATCH, "cpu_count"):
		var cpu_count := int(_config.get_value(SECTION_MATCH, "cpu_count", GameSettings.get_cpu_count()))
		GameSettings.set_cpu_count(cpu_count)
	if _config.has_section_key(SECTION_MATCH, "kills_to_win"):
		var kills := int(_config.get_value(SECTION_MATCH, "kills_to_win", GameSettings.get_kills_to_win()))
		GameSettings.set_kills_to_win(kills)


func _get_match_level_path() -> String:
	if _config != null and _config.has_section_key(SECTION_MATCH, "level"):
		var path := str(_config.get_value(SECTION_MATCH, "level", "")).strip_edges()
		if path != "":
			return path
	return ResourcePaths.SCENE_LEVEL_01


func _queue_auto_match_start() -> void:
	if _match_start_triggered:
		return
	_waiting_for_start_menu_ready = false
	_match_start_triggered = true
	call_deferred("_start_match_from_config")


func _queue_clear_npcs(dev_menu: Node) -> void:
	if dev_menu == null:
		return
	if GameStateManager.is_playing():
		_clear_npcs_with_delay(dev_menu)
		return
	if _pending_clear_npcs:
		return
	_pending_clear_npcs = true
	_pending_dev_menu_ref = weakref(dev_menu)
	EventBus.level_loaded.connect(Callable(self, "_on_level_loaded_clear_npcs"), CONNECT_ONE_SHOT)


func _on_level_loaded_clear_npcs(_level_path: String) -> void:
	_pending_clear_npcs = false
	var menu: WeakRef = _pending_dev_menu_ref
	_pending_dev_menu_ref = null
	if menu:
		var dev_menu := menu.get_ref() as Node
		if dev_menu:
			_clear_npcs_with_delay(dev_menu)


func _clear_npcs_with_delay(dev_menu: Node, attempt: int = 0, menu_ref: WeakRef = null) -> void:
	var ref: WeakRef = menu_ref if menu_ref != null else weakref(dev_menu)
	get_tree().create_timer(0.25).timeout.connect(
		Callable(self, "_dispatch_clear_npcs").bind(ref, attempt),
		CONNECT_ONE_SHOT
	)


func _dispatch_clear_npcs(menu_ref: WeakRef, attempt: int) -> void:
	if menu_ref == null:
		return
	var dev_menu := menu_ref.get_ref() as Node
	if dev_menu == null:
		return
	if _has_npc_characters() or attempt >= MAX_NPC_CLEAR_ATTEMPTS:
		dev_menu.call("_clear_npcs")
	else:
		_clear_npcs_with_delay(dev_menu, attempt + 1, menu_ref)


func _has_npc_characters() -> bool:
	var npcs := get_tree().get_nodes_in_group("characters")
	for node in npcs:
		if node is CharacterController and not node.is_player:
			return true
	return false
func _apply_player_stats_settings() -> void:
	if _config == null or not _config.has_section(SECTION_PLAYER_STATS):
		return
	if _config.has_section_key(SECTION_PLAYER_STATS, "log_events"):
		_player_stats_log_enabled = bool(_config.get_value(SECTION_PLAYER_STATS, "log_events", false))
	ProjectSettings.set_setting("debug/player_stats_log_events", _player_stats_log_enabled)
