extends Node

signal pause_toggled
signal dev_menu_toggled
signal nav_graph_toggled
signal jump_arcs_toggled
signal debug_pause_toggled

const DEADZONE := 0.5

func _ready() -> void:
	# Always run, even when paused and across scenes
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Ensure actions exist and have sensible keyboard + controller bindings
	_ensure_default_actions()


func _process(_delta: float) -> void:
	# Centralized toggle handling so other nodes don't care about device
	if Input.is_action_just_pressed("pause"):
		pause_toggled.emit()
	if Input.is_action_just_pressed("toggle_dev_menu"):
		dev_menu_toggled.emit()
	if Input.is_action_just_pressed("toggle_nav_graph"):
		nav_graph_toggled.emit()
	if Input.is_action_just_pressed("toggle_jump_arcs"):
		jump_arcs_toggled.emit()
	if Input.is_action_just_pressed("debug_pause"):
		debug_pause_toggled.emit()


# --- Public helpers for gameplay code (characters, etc.) ---
func get_move_axis_x() -> float:
	return Input.get_axis("move_left", "move_right")

func get_move_axis_y() -> float:
	return Input.get_axis("ui_up", "ui_down")

func is_move_down_pressed() -> bool:
	return Input.is_action_pressed("move_down") or Input.is_action_pressed("ui_down")

func is_jump_just_pressed() -> bool:
	return Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept")

func is_jump_just_released() -> bool:
	return Input.is_action_just_released("jump") or Input.is_action_just_released("ui_accept")


# --- Internal: InputMap setup ---
func _ensure_default_actions() -> void:
	# Basic movement/actions used by gameplay
	_ensure_action("move_left")
	_ensure_action("move_right")
	_ensure_action("move_down")
	_ensure_action("jump")
	_ensure_action("pause")
	# UI actions (menu navigation)
	_ensure_action("ui_left")
	_ensure_action("ui_right")
	_ensure_action("ui_up")
	_ensure_action("ui_down")
	_ensure_action("ui_accept")
	_ensure_action("ui_cancel")
	# Dev toggles (debug builds)
	_ensure_action("toggle_dev_menu")
	_ensure_action("toggle_nav_graph")
	_ensure_action("toggle_jump_arcs")
	_ensure_action("debug_pause")

	# Keyboard mappings (WASD + Arrows)
	_add_key_if_missing("move_left", KEY_A)
	_add_key_if_missing("move_left", KEY_LEFT)
	_add_key_if_missing("move_right", KEY_D)
	_add_key_if_missing("move_right", KEY_RIGHT)
	_add_key_if_missing("move_down", KEY_S)
	_add_key_if_missing("move_down", KEY_DOWN)
	_add_key_if_missing("jump", KEY_SPACE)
	_add_key_if_missing("jump", KEY_W)

	_add_key_if_missing("ui_left", KEY_LEFT)
	_add_key_if_missing("ui_left", KEY_A)
	_add_key_if_missing("ui_right", KEY_RIGHT)
	_add_key_if_missing("ui_right", KEY_D)
	_add_key_if_missing("ui_up", KEY_UP)
	_add_key_if_missing("ui_up", KEY_W)
	_add_key_if_missing("ui_down", KEY_DOWN)
	_add_key_if_missing("ui_down", KEY_S)
	_add_key_if_missing("ui_accept", KEY_ENTER)
	_add_key_if_missing("ui_accept", KEY_SPACE)
	_add_key_if_missing("ui_cancel", KEY_ESCAPE)
	_add_key_if_missing("pause", KEY_ESCAPE)

	# Dev keys (F keys and P for pause)
	_add_key_if_missing("toggle_dev_menu", KEY_F10)
	_add_key_if_missing("toggle_nav_graph", KEY_F11)
	_add_key_if_missing("toggle_jump_arcs", KEY_F12)
	_add_key_if_missing("debug_pause", KEY_P)

	# Controller - buttons
	_add_joy_button_if_missing("jump", JOY_BUTTON_A) # South (A on Xbox)
	_add_joy_button_if_missing("ui_accept", JOY_BUTTON_A)
	_add_joy_button_if_missing("ui_cancel", JOY_BUTTON_B) # East (B on Xbox)
	_add_joy_button_if_missing("pause", JOY_BUTTON_START)
	# D-Pad for menus and movement
	_add_joy_button_if_missing("ui_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button_if_missing("ui_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_button_if_missing("ui_up", JOY_BUTTON_DPAD_UP)
	_add_joy_button_if_missing("ui_down", JOY_BUTTON_DPAD_DOWN)
	_add_joy_button_if_missing("move_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button_if_missing("move_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_button_if_missing("move_down", JOY_BUTTON_DPAD_DOWN)

	# Controller - left stick axes
	_add_axis_if_missing("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis_if_missing("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis_if_missing("ui_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis_if_missing("ui_right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis_if_missing("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis_if_missing("ui_down", JOY_AXIS_LEFT_Y, 1.0)


func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, DEADZONE)


func _add_key_if_missing(action: String, keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	_add_event_if_missing(action, ev)


func _add_joy_button_if_missing(action: String, button_index: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button_index
	_add_event_if_missing(action, ev)


func _add_axis_if_missing(action: String, axis: JoyAxis, axis_value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = axis_value
	_add_event_if_missing(action, ev)


func _add_event_if_missing(action: String, new_event: InputEvent) -> void:
	for existing in InputMap.action_get_events(action):
		if _events_equivalent(existing, new_event):
			return
	InputMap.action_add_event(action, new_event)


func _events_equivalent(a: InputEvent, b: InputEvent) -> bool:
	if a.get_class() != b.get_class():
		return false
	if a is InputEventKey and b is InputEventKey:
		return (a as InputEventKey).physical_keycode == (b as InputEventKey).physical_keycode
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return (a as InputEventJoypadButton).button_index == (b as InputEventJoypadButton).button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		var am := a as InputEventJoypadMotion
		var bm := b as InputEventJoypadMotion
		return am.axis == bm.axis and signf(am.axis_value) == signf(bm.axis_value)
	return false
