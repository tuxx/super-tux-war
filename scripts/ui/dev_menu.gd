extends Control

#const LEVEL_NAVIGATION := preload("res://scripts/level_navigation.gd")

var desired_draw_graph := false
var desired_draw_jump := false

# Performance tracking
var frame_times: Array[float] = []
const MAX_FRAME_SAMPLES := 100
var perf_graph: Control = null
var mft_label: Label = null
var hft_label: Label = null
var highest_frame_time_ever: float = 0.0  # All-time peak, never decreases

func _ready() -> void:
	# Only show in debug builds (disabled in release exports)
	if not OS.is_debug_build():
		queue_free()
		return
	# Ensure the dev menu still processes input/UI when the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Ensure dev menu appears above everything (including game over screen)
	z_index = 1000
	
	# Reset stats when scene changes
	reset_performance_stats()
	
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

	# Full-rect root to let containers position panel at top-right with margins
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Use tile-based padding: 1.5 tiles
	var tile_padding := int(GameConstants.TILE_SIZE * 1.5)
	
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", tile_padding)
	margin.add_theme_constant_override("margin_right", tile_padding)
	add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(hbox)
	# Push content to the right
	hbox.alignment = BoxContainer.ALIGNMENT_END

	var panel: PanelContainer = PanelContainer.new()
	panel.modulate.a = 0.7  # slightly transparent
	hbox.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	panel.add_child(vbox)

	var title: Label = Label.new()
	title.text = "Developer Menu"
	vbox.add_child(title)

	var hint_pause: Label = Label.new()
	hint_pause.text = "P: Pause Game"
	vbox.add_child(hint_pause)

	vbox.add_child(_make_separator())

	var hint_menu: Label = Label.new()
	hint_menu.text = "F10: Toggle Dev Menu"
	vbox.add_child(hint_menu)
	var hint_graph: Label = Label.new()
	hint_graph.text = "F11: Toggle Nav Graph"
	vbox.add_child(hint_graph)
	var hint_jump: Label = Label.new()
	hint_jump.text = "F12: Toggle Jump Arcs"
	vbox.add_child(hint_jump)
	
	vbox.add_child(_make_separator())
	
	# Performance graph
	perf_graph = Control.new()
	perf_graph.custom_minimum_size = Vector2(200, 60)
	perf_graph.draw.connect(_draw_performance_graph)
	vbox.add_child(perf_graph)
	
	var perf_label: Label = Label.new()
	perf_label.text = "Frame Time (ms)"
	perf_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(perf_label)
	
	# Median frame time label
	mft_label = Label.new()
	mft_label.text = "MFT: 0.0 ms"
	mft_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(mft_label)
	
	# Highest frame time label
	hft_label = Label.new()
	hft_label.text = "HFT: 0.0 ms"
	hft_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hft_label)

	var nav := _get_navigation()
	if nav:
		desired_draw_graph = nav.debug_draw_graph
		desired_draw_jump = nav.debug_draw_jump_arcs
	else:
		desired_draw_graph = bool(ProjectSettings.get_setting(LevelNavigation.SETTINGS_DRAW_GRAPH, desired_draw_graph))
		desired_draw_jump = bool(ProjectSettings.get_setting(LevelNavigation.SETTINGS_DRAW_JUMP, desired_draw_jump))

	_apply_toggle_states()

func _unhandled_input(_event: InputEvent) -> void:
	# Handled via InputManager signals
	if not OS.is_debug_build():
		return


func _make_separator() -> Control:
	var sep := HSeparator.new()
	sep.custom_minimum_size.x = 150
	return sep


func _get_navigation() -> LevelNavigation:
	var scene := get_tree().current_scene
	if scene is LevelNavigation:
		return scene
	return null


func _process(delta: float) -> void:
	if not OS.is_debug_build():
		return
	_apply_toggle_states()
	
	# Track frame time in milliseconds
	var frame_ms := delta * 1000.0
	frame_times.append(frame_ms)
	if frame_times.size() > MAX_FRAME_SAMPLES:
		frame_times.pop_front()
	
	# Update performance graph and stats
	if perf_graph and visible:
		perf_graph.queue_redraw()
		_update_frame_stats()


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


func reset_performance_stats() -> void:
	# Reset frame time statistics (called when level loads/restarts)
	frame_times.clear()
	highest_frame_time_ever = 0.0
	if mft_label:
		mft_label.text = "MFT: 0.0 ms"
	if hft_label:
		hft_label.text = "HFT: 0.0 ms"


func _update_frame_stats() -> void:
	if frame_times.is_empty():
		return
	
	# Calculate median frame time
	var sorted_times := frame_times.duplicate()
	sorted_times.sort()
	var median_ms: float = 0.0
	var mid := sorted_times.size() / 2
	if sorted_times.size() % 2 == 0:
		median_ms = (sorted_times[mid - 1] + sorted_times[mid]) / 2.0
	else:
		median_ms = sorted_times[mid]
	
	# Track all-time highest frame time (never decreases)
	var current_frame_ms: float = frame_times[frame_times.size() - 1]
	if current_frame_ms > highest_frame_time_ever:
		highest_frame_time_ever = current_frame_ms
	
	# Update labels
	if mft_label:
		mft_label.text = "MFT: %.1f ms" % median_ms
	if hft_label:
		hft_label.text = "HFT: %.1f ms" % highest_frame_time_ever


func _draw_performance_graph() -> void:
	if not perf_graph or frame_times.is_empty():
		return
	
	var graph_size := perf_graph.get_size()
	var width := graph_size.x
	var height := graph_size.y
	
	# Draw background
	perf_graph.draw_rect(Rect2(Vector2.ZERO, graph_size), Color(0, 0, 0, 0.5))
	
	# Calculate scaling
	var max_ms := 33.33  # Target 30fps as max (spikes beyond this still visible)
	for ms in frame_times:
		if ms > max_ms:
			max_ms = ms
	
	# Draw reference lines
	# 60fps = 16.67ms
	var fps60_y := height - (16.67 / max_ms) * height
	perf_graph.draw_line(Vector2(0, fps60_y), Vector2(width, fps60_y), Color(0, 1, 0, 0.3), 1.0)
	
	# 30fps = 33.33ms
	var fps30_y := height - (33.33 / max_ms) * height
	perf_graph.draw_line(Vector2(0, fps30_y), Vector2(width, fps30_y), Color(1, 1, 0, 0.3), 1.0)
	
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
		
		perf_graph.draw_line(Vector2(x1, y1), Vector2(x2, y2), color, 2.0)
	
	# Draw current FPS text
	var current_ms: float = frame_times[frame_times.size() - 1]
	var current_fps: float = 1000.0 / current_ms if current_ms > 0.0 else 0.0
	var fps_text := "%.1f fps (%.1f ms)" % [current_fps, current_ms]
	perf_graph.draw_string(ThemeDB.fallback_font, Vector2(5, 12), fps_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
