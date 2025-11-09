extends Control

#const LEVEL_NAVIGATION := preload("res://scripts/level_navigation.gd")

var desired_draw_graph := false
var desired_draw_jump := false

func _ready() -> void:
	# Only show in debug builds (disabled in release exports)
	if not OS.is_debug_build():
		queue_free()
		return
	# Ensure the dev menu still processes input/UI when the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
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

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
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


func _process(_delta: float) -> void:
	if not OS.is_debug_build():
		return
	_apply_toggle_states()


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
