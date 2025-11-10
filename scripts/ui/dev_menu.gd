extends Control

var desired_draw_graph := false
var desired_draw_jump := false
var npcs_removed := false

# Performance tracking
var frame_times: Array[float] = []
const MAX_FRAME_SAMPLES := 100
var perf_graph_control: Control = null
var perf_graph_container: PanelContainer = null
var perf_graph_visible := false
var highest_frame_time_ever: float = 0.0

# Player stats
var player_stats_container: PanelContainer = null
var player_stats_visible := false
var player_stats_labels: Dictionary = {}

const FONT_SIZE := 11  # Smaller font for dev menu

# Drag state
var dragging := false
var drag_offset := Vector2.ZERO
var dev_menu_container: VBoxContainer = null

# Position persistence
const DEV_MENU_CONFIG_PATH := "user://dev_menu_settings.cfg"
const DEV_MENU_CONFIG_SECTION := "dev_menu"
const DEV_MENU_CONFIG_KEY := "position"

func _ready() -> void:
	# Only show in debug builds (disabled in release exports)
	if not OS.is_debug_build():
		queue_free()
		return
	# Ensure the dev menu still processes input/UI when the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Ensure dev menu appears above everything (including game over screen)
	z_index = 1000
	
	# Listen to centralized input toggles
	InputManager.dev_menu_toggled.connect(func(): visible = not visible)
	InputManager.nav_graph_toggled.connect(func():
		desired_draw_graph = not desired_draw_graph
		_apply_toggle_states()
	)
	InputManager.jump_arcs_toggled.connect(func():
		desired_draw_jump = not desired_draw_jump
		_apply_toggle_states()
	)
	InputManager.debug_pause_toggled.connect(_toggle_debug_pause)
	InputManager.perf_graph_toggled.connect(_toggle_perf_graph)
	InputManager.player_stats_toggled.connect(_toggle_player_stats)
	InputManager.npc_clear_toggled.connect(_clear_npcs)
	
	# Listen to game state changes
	EventBus.game_state_changed.connect(_on_game_state_changed)
	
	# Update visibility based on current state
	_update_visibility_for_state()

	# Full-rect root to capture input
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS  # Pass through to children but still receive events
	
	# Main layout - VBox for stacking dev menu, perf graph, and player stats
	dev_menu_container = VBoxContainer.new()
	dev_menu_container.mouse_filter = Control.MOUSE_FILTER_STOP  # Capture mouse for dragging
	dev_menu_container.mouse_default_cursor_shape = Control.CURSOR_MOVE  # Show move cursor
	add_child(dev_menu_container)
	
	# Load saved position or use default (top-right with padding)
	var saved_pos: Vector2 = _load_menu_position()
	if saved_pos == Vector2.ZERO:
		# Default position: top-right with padding
		var tile_padding := int(GameConstants.TILE_SIZE * 2.5)
		await get_tree().process_frame  # Wait for viewport size
		var viewport_size := get_viewport_rect().size
		dev_menu_container.position = Vector2(viewport_size.x - 220 - tile_padding, tile_padding)
	else:
		dev_menu_container.position = saved_pos
	
	var main_vbox := dev_menu_container
	
	# Developer Menu Panel
	var dev_panel := _create_dev_menu_panel()
	main_vbox.add_child(dev_panel)
	
	# Spacing
	main_vbox.add_child(_make_spacer(8))
	
	# Performance Graph Panel (separate, toggleable)
	perf_graph_container = _create_perf_graph_panel()
	perf_graph_container.visible = perf_graph_visible
	main_vbox.add_child(perf_graph_container)
	
	# Spacing
	main_vbox.add_child(_make_spacer(8))
	
	# Player Stats Panel (separate, toggleable)
	player_stats_container = _create_player_stats_panel()
	player_stats_container.visible = player_stats_visible
	main_vbox.add_child(player_stats_container)

	var nav := _get_navigation()
	if nav:
		desired_draw_graph = nav.debug_draw_graph
		desired_draw_jump = nav.debug_draw_jump_arcs
	else:
		desired_draw_graph = bool(ProjectSettings.get_setting(LevelNavigation.SETTINGS_DRAW_GRAPH, desired_draw_graph))
		desired_draw_jump = bool(ProjectSettings.get_setting(LevelNavigation.SETTINGS_DRAW_JUMP, desired_draw_jump))

	_apply_toggle_states()

func _input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not dev_menu_container or not visible:
		return
	
	# Handle dragging
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				# Check if click is within the container bounds
				var mouse_pos := get_viewport().get_mouse_position()
				var container_rect := Rect2(dev_menu_container.position, dev_menu_container.size)
				if container_rect.has_point(mouse_pos):
					dragging = true
					drag_offset = mouse_pos - dev_menu_container.position
					dev_menu_container.modulate.a = 0.7  # Slight transparency while dragging
					get_viewport().set_input_as_handled()
			else:
				if dragging:
					dragging = false
					dev_menu_container.modulate.a = 1.0  # Restore full opacity
					# Save position to settings
					_save_menu_position()
					get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseMotion and dragging:
		var mm := event as InputEventMouseMotion
		var mouse_pos := get_viewport().get_mouse_position()
		dev_menu_container.position = mouse_pos - drag_offset
		
		# Clamp to viewport bounds
		var viewport_size := get_viewport_rect().size
		var menu_size := dev_menu_container.size
		dev_menu_container.position.x = clampf(dev_menu_container.position.x, 0, viewport_size.x - menu_size.x)
		dev_menu_container.position.y = clampf(dev_menu_container.position.y, 0, viewport_size.y - menu_size.y)
		get_viewport().set_input_as_handled()

func _create_dev_menu_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.modulate.a = 0.8
	panel.custom_minimum_size.x = 200  # Match performance graph width
	
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	
	var title := _make_label("Developer Menu [Drag to Move]")
	title.add_theme_font_size_override("font_size", 9)  # Slightly smaller hint
	vbox.add_child(title)
	
	var hint_pause := _make_label("P: Pause Game")
	vbox.add_child(hint_pause)
	var hint_npc := _make_label("N: Remove NPCs")
	vbox.add_child(hint_npc)
	
	vbox.add_child(_make_separator())
	
	var hint_stats := _make_label("F1: Toggle Player Stats")
	vbox.add_child(hint_stats)
	var hint_perf := _make_label("F2: Toggle Performance")
	vbox.add_child(hint_perf)
	var hint_menu := _make_label("F12: Toggle Dev Menu")
	vbox.add_child(hint_menu)
	var hint_graph := _make_label("PgUp: Toggle Nav Graph")
	vbox.add_child(hint_graph)
	var hint_jump := _make_label("PgDn: Toggle Jump Arcs")
	vbox.add_child(hint_jump)
	
	return panel

func _create_perf_graph_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.modulate.a = 0.8
	
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	
	var title := _make_label("Performance (F2)")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Performance graph with stats overlaid
	perf_graph_control = Control.new()
	perf_graph_control.custom_minimum_size = Vector2(200, 60)
	perf_graph_control.draw.connect(_draw_performance_graph)
	vbox.add_child(perf_graph_control)
	
	return panel

func _create_player_stats_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.modulate.a = 0.8
	panel.custom_minimum_size.x = 200  # Match performance graph width
	
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	
	var title := _make_label("Player Stats (F1)")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	vbox.add_child(_make_separator())
	
	# Create labels for player stats
	player_stats_labels["position"] = _make_label("Position: 0, 0")
	vbox.add_child(player_stats_labels["position"])
	
	player_stats_labels["velocity"] = _make_label("Velocity: 0, 0")
	vbox.add_child(player_stats_labels["velocity"])
	
	player_stats_labels["speed"] = _make_label("Speed: 0")
	vbox.add_child(player_stats_labels["speed"])
	
	player_stats_labels["accel"] = _make_label("Accel: 0")
	vbox.add_child(player_stats_labels["accel"])
	
	player_stats_labels["friction"] = _make_label("Friction: 0")
	vbox.add_child(player_stats_labels["friction"])
	
	player_stats_labels["on_floor"] = _make_label("On Floor: false")
	vbox.add_child(player_stats_labels["on_floor"])
	
	player_stats_labels["on_ice"] = _make_label("On Ice: false")
	vbox.add_child(player_stats_labels["on_ice"])
	
	return panel

func _make_separator() -> Control:
	var sep := HSeparator.new()
	sep.custom_minimum_size.x = 150
	return sep

func _make_spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	return spacer

func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	return label


func _get_navigation() -> LevelNavigation:
	var scene := get_tree().current_scene
	if scene is LevelNavigation:
		return scene
	return null


func _process(delta: float) -> void:
	if not OS.is_debug_build():
		return
	_apply_toggle_states()
	
	# Only track frame times when performance graph is visible
	if perf_graph_visible:
		var frame_ms := delta * 1000.0
		frame_times.append(frame_ms)
		if frame_times.size() > MAX_FRAME_SAMPLES:
			frame_times.pop_front()
		
		# Update performance graph
		if perf_graph_control:
			perf_graph_control.queue_redraw()
			_update_perf_stats()
	
	# Only update player stats when visible
	if player_stats_visible:
		_update_player_stats()


func _apply_toggle_states() -> void:
	ProjectSettings.set_setting(LevelNavigation.SETTINGS_DRAW_GRAPH, desired_draw_graph)
	ProjectSettings.set_setting(LevelNavigation.SETTINGS_DRAW_JUMP, desired_draw_jump)

	var nav := _get_navigation()
	if nav == null:
		return
	if nav.debug_draw_graph != desired_draw_graph:
		nav.set_debug_draw_graph(desired_draw_graph)
	if nav.debug_draw_jump_arcs != desired_draw_jump:
		nav.set_debug_draw_jump_arcs(desired_draw_jump)


func _toggle_debug_pause() -> void:
	# Toggle game pause without showing any menu (for debugging)
	get_tree().paused = not get_tree().paused
	print("[Dev] Debug pause: ", "PAUSED" if get_tree().paused else "UNPAUSED")

func _toggle_perf_graph() -> void:
	perf_graph_visible = not perf_graph_visible
	if perf_graph_container:
		perf_graph_container.visible = perf_graph_visible
	
	# Clear frame times when toggling off to save memory
	if not perf_graph_visible:
		frame_times.clear()
		highest_frame_time_ever = 0.0
	
	print("[Dev] Performance graph: ", "SHOWN" if perf_graph_visible else "HIDDEN")

func _toggle_player_stats() -> void:
	player_stats_visible = not player_stats_visible
	if player_stats_container:
		player_stats_container.visible = player_stats_visible
	print("[Dev] Player stats: ", "SHOWN" if player_stats_visible else "HIDDEN")

func _clear_npcs() -> void:
	if npcs_removed:
		print("[Dev] NPCs already cleared.")
		return
	
	var removed := 0
	var npcs := get_tree().get_nodes_in_group("characters")
	for character in npcs:
		if character is CharacterController and not character.is_player:
			character.queue_free()
			removed += 1
	
	npcs_removed = true
	print("[Dev] NPCs cleared: ", removed)

func _save_menu_position() -> void:
	if dev_menu_container:
		var config := ConfigFile.new()
		var err := config.load(DEV_MENU_CONFIG_PATH)
		if err != OK and err != ERR_DOES_NOT_EXIST:
			push_warning("Failed to load dev menu config: %s" % err)
		config.set_value(DEV_MENU_CONFIG_SECTION, DEV_MENU_CONFIG_KEY, dev_menu_container.position)
		err = config.save(DEV_MENU_CONFIG_PATH)
		if err != OK:
			push_warning("Failed to save dev menu config: %s" % err)
		print("[Dev] Menu position saved: ", dev_menu_container.position)

func _load_menu_position() -> Vector2:
	var config := ConfigFile.new()
	var err := config.load(DEV_MENU_CONFIG_PATH)
	if err != OK:
		return Vector2.ZERO
	return config.get_value(DEV_MENU_CONFIG_SECTION, DEV_MENU_CONFIG_KEY, Vector2.ZERO)

func _on_game_state_changed(_from_state: String, _to_state: String) -> void:
	_update_visibility_for_state()

func _update_visibility_for_state() -> void:
	# Hide dev menu in menu state, show in gameplay
	if GameStateManager.can_show_dev_menu():
		visible = true
	else:
		visible = false


func _update_perf_stats() -> void:
	if frame_times.is_empty():
		return
	
	# Track all-time highest frame time
	var current_ms: float = frame_times[frame_times.size() - 1]
	if current_ms > highest_frame_time_ever:
		highest_frame_time_ever = current_ms

func _update_player_stats() -> void:
	# Find the first player character
	var player: CharacterController = null
	var players := get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		player = players[0] as CharacterController
	
	if not player or not player.physics:
		# No player found - show N/A
		for key in player_stats_labels:
			player_stats_labels[key].text = "No Player"
		return
	
	# Update all stats
	player_stats_labels["position"].text = "Pos: %.0f, %.0f" % [player.global_position.x, player.global_position.y]
	player_stats_labels["velocity"].text = "Vel: %.0f, %.0f" % [player.velocity.x, player.velocity.y]
	player_stats_labels["speed"].text = "Speed: %.0f px/s" % absf(player.velocity.x)
	
	# Show actual acceleration being used (only when moving)
	var input_dir := InputManager.get_move_axis_x()
	var current_accel := 0.0
	if absf(input_dir) > 0.1:  # Has input
		current_accel = GameConstants.PLAYER_ACCEL
		if player.physics.is_on_ice:
			current_accel = GameConstants.PLAYER_ACCEL_ICE
	player_stats_labels["accel"].text = "Accel: %.0f px/s²" % current_accel
	
	# Show active friction (only when decelerating)
	var active_friction := 0.0
	if absf(input_dir) < 0.1 and absf(player.velocity.x) > 1.0:  # No input and still moving
		active_friction = player.physics._get_current_friction()
	
	# Show max speed
	var current_max_speed := GameConstants.PLAYER_MAX_WALK_SPEED
	if player.physics.is_turbo_active:
		current_max_speed = GameConstants.PLAYER_MAX_RUN_SPEED
	elif player.physics.is_slowdown_active:
		current_max_speed = GameConstants.PLAYER_MAX_SLOW_SPEED
	player_stats_labels["friction"].text = "Friction: %.0f | Max: %.0f" % [active_friction, current_max_speed]
	
	player_stats_labels["on_floor"].text = "On Floor: %s" % ("Yes" if player.is_on_floor() else "No")
	player_stats_labels["on_ice"].text = "On Ice: %s" % ("Yes" if player.physics.is_on_ice else "No")


func _draw_performance_graph() -> void:
	if not perf_graph_control or frame_times.is_empty():
		return
	
	var graph_size := perf_graph_control.get_size()
	var width := graph_size.x
	var height := graph_size.y
	
	# Draw background
	perf_graph_control.draw_rect(Rect2(Vector2.ZERO, graph_size), Color(0, 0, 0, 0.5))
	
	# Calculate scaling
	var max_ms := 33.33  # Target 30fps as max (spikes beyond this still visible)
	for ms in frame_times:
		if ms > max_ms:
			max_ms = ms
	
	# Draw reference lines
	# 60fps = 16.67ms
	var fps60_y := height - (16.67 / max_ms) * height
	perf_graph_control.draw_line(Vector2(0, fps60_y), Vector2(width, fps60_y), Color(0, 1, 0, 0.3), 1.0)
	
	# 30fps = 33.33ms
	var fps30_y := height - (33.33 / max_ms) * height
	perf_graph_control.draw_line(Vector2(0, fps30_y), Vector2(width, fps30_y), Color(1, 1, 0, 0.3), 1.0)
	
	# Draw the graph line
	if frame_times.size() < 2:
		return
	
	var samples := frame_times.size()
	var x_step := width / float(samples - 1)
	
	for i in range(samples - 1):
		var x1 := i * x_step
		var x2 := (i + 1) * x_step
		
		var y1 := height - (frame_times[i] / max_ms) * height
		var y2 := height - (frame_times[i + 1] / max_ms) * height
		
		# Clamp to visible area
		y1 = clampf(y1, 0, height)
		y2 = clampf(y2, 0, height)
		
		# Color based on performance
		var color := Color.GREEN
		if frame_times[i + 1] > 33.33:
			color = Color.RED
		elif frame_times[i + 1] > 16.67:
			color = Color.YELLOW
		
		perf_graph_control.draw_line(Vector2(x1, y1), Vector2(x2, y2), color, 2.0)
	
	# Draw stats overlay on top of graph
	var current_ms: float = frame_times[frame_times.size() - 1]
	var current_fps: float = 1000.0 / current_ms if current_ms > 0.0 else 0.0
	
	# Calculate median frame time
	var sorted_times := frame_times.duplicate()
	sorted_times.sort()
	var median_ms: float = 0.0
	var mid := int(sorted_times.size() / 2.0)
	if sorted_times.size() % 2 == 0:
		median_ms = (sorted_times[mid - 1] + sorted_times[mid]) / 2.0
	else:
		median_ms = sorted_times[mid]
	
	# Draw text with shadow for readability
	var font := ThemeDB.fallback_font
	var font_size := 10
	
	# Line 1: FPS and current frame time
	var line1 := "%.1f fps (%.1f ms)" % [current_fps, current_ms]
	perf_graph_control.draw_string(font, Vector2(6, 11), line1, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.BLACK)
	perf_graph_control.draw_string(font, Vector2(5, 10), line1, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	
	# Line 2: Median and Highest
	var line2 := "M: %.1f  H: %.1f" % [median_ms, highest_frame_time_ever]
	perf_graph_control.draw_string(font, Vector2(6, 23), line2, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.BLACK)
	perf_graph_control.draw_string(font, Vector2(5, 22), line2, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
