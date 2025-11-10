extends Node
class_name CharacterPhysics

## Handles character physics: gravity, movement, collision, and boundary wrapping.
## Implements SMW-style acceleration/friction for realistic momentum-based movement.

var character: CharacterBody2D

# Physics properties
var jump_velocity: float = GameConstants.JUMP_VELOCITY
var gravity: float = GameConstants.GRAVITY
var max_fall_speed: float = GameConstants.MAX_FALL_SPEED

# Acceleration-based movement (SMW-style)
var acceleration: float = GameConstants.PLAYER_ACCEL
var max_speed: float = GameConstants.PLAYER_MAX_WALK_SPEED
var friction_ground: float = GameConstants.FRICTION_GROUND
var friction_ice: float = GameConstants.FRICTION_ICE
var friction_air: float = GameConstants.FRICTION_AIR
var current_input_direction: float = 0.0
var current_effective_max_speed: float = GameConstants.PLAYER_MAX_WALK_SPEED
var previous_horizontal_velocity: float = 0.0

# Speed modifiers (can be set externally for powerups/effects)
var speed_modifier: float = 1.0  # 1.0 = normal, 1.375 = turbo, 0.55 = slowdown
var is_turbo_active: bool = false  # Set true when turbo key held
var is_slowdown_active: bool = false  # Set true when slowdown effect active

# Surface detection
var is_on_ice: bool = false

# Boundary wrap
var wrap_enabled: bool = true
var wrap_offset: float = 10.0

# Jump assist timers
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var drop_through_timer: float = 0.0
const DROP_THROUGH_DURATION: float = 0.2

# AI input state
var ai_move_direction: float = 0.0
var ai_jump_pressed: bool = false
var ai_jump_released: bool = false
var ai_drop_pressed: bool = false

func _init(character_body: CharacterBody2D) -> void:
	character = character_body

## Updates physics timers and applies movement. Returns previous velocity Y for collision detection.
func update_physics(delta: float, is_player: bool) -> float:
	var was_on_floor := character.is_on_floor()
	
	# Update coyote time
	if was_on_floor:
		coyote_timer = GameConstants.COYOTE_TIME
	else:
		coyote_timer = max(0.0, coyote_timer - delta)
	
	# Update jump buffer
	if jump_buffer_timer > 0.0:
		jump_buffer_timer = max(0.0, jump_buffer_timer - delta)
	
	# Update drop-through timer
	if drop_through_timer > 0.0:
		drop_through_timer = max(0.0, drop_through_timer - delta)
	
	# Detect surface type (ice vs normal)
	_detect_surface_type()
	
	# Handle input
	if is_player:
		_handle_player_input(delta)
	else:
		_handle_ai_input(delta)
	
	# Apply gravity
	_apply_gravity(delta)
	
	# Cap velocity
	character.velocity.y = clamp(character.velocity.y, -max_fall_speed, max_fall_speed)
	character.velocity.x = clamp(character.velocity.x, -GameConstants.PLAYER_MAX_RUN_SPEED, GameConstants.PLAYER_MAX_RUN_SPEED)
	
	# Store previous velocity for collision detection
	var previous_velocity_y := character.velocity.y
	
	# Temporarily disable platform_on_leave for drop-through
	var old_platform_on_leave := character.platform_on_leave
	if drop_through_timer > 0.0:
		character.platform_on_leave = CharacterBody2D.PLATFORM_ON_LEAVE_DO_NOTHING
	
	character.move_and_slide()
	
	# Restore platform behavior
	if drop_through_timer > 0.0:
		character.platform_on_leave = old_platform_on_leave
	
	# Handle buffered jump after landing
	if character.is_on_floor() and not was_on_floor and jump_buffer_timer > 0.0:
		_perform_jump()
		jump_buffer_timer = 0.0
	
	# Boundary wrap after all motion
	_wrap_after_motion()
	
	return previous_velocity_y

func _handle_player_input(delta: float) -> void:
	is_turbo_active = Input.is_action_pressed("run")
	var input_direction := InputManager.get_move_axis_x()
	
	# Apply acceleration-based movement
	_apply_horizontal_movement(input_direction, delta)
	
	# Drop-through semisolid platforms
	if InputManager.is_move_down_pressed() and InputManager.is_jump_just_pressed() and character.is_on_floor():
		drop_through_timer = DROP_THROUGH_DURATION
		character.position.y += 1
		return
	
	# Jump with coyote time and buffering
	if InputManager.is_jump_just_pressed() and not InputManager.is_move_down_pressed():
		if coyote_timer > 0.0:
			_perform_jump()
			coyote_timer = 0.0
		else:
			jump_buffer_timer = GameConstants.JUMP_BUFFER_TIME
	
	# Variable jump: early release clamp
	if InputManager.is_jump_just_released() and character.velocity.y < 0:
		if character.velocity.y < GameConstants.JUMP_EARLY_CLAMP:
			character.velocity.y = GameConstants.JUMP_EARLY_CLAMP

func _handle_ai_input(delta: float) -> void:
	# Apply acceleration-based movement (same as player)
	_apply_horizontal_movement(ai_move_direction, delta)
	
	if ai_drop_pressed and character.is_on_floor():
		drop_through_timer = DROP_THROUGH_DURATION
		character.position.y += 1
		ai_drop_pressed = false
		return
	
	if ai_jump_pressed:
		if coyote_timer > 0.0:
			_perform_jump()
			coyote_timer = 0.0
		else:
			jump_buffer_timer = GameConstants.JUMP_BUFFER_TIME
	
	if ai_jump_released and character.velocity.y < 0:
		if character.velocity.y < GameConstants.JUMP_EARLY_CLAMP:
			character.velocity.y = GameConstants.JUMP_EARLY_CLAMP
	
	ai_jump_pressed = false
	ai_jump_released = false
	ai_drop_pressed = false

func set_ai_inputs(move_direction: float, jump_pressed: bool, jump_released: bool, drop_pressed: bool) -> void:
	ai_move_direction = clamp(move_direction, -1.0, 1.0)
	ai_jump_pressed = jump_pressed
	ai_jump_released = jump_released
	ai_drop_pressed = drop_pressed

func _apply_gravity(delta: float) -> void:
	if not character.is_on_floor():
		character.velocity.y += gravity * delta

func _perform_jump(jump_modifier: float = 1.0) -> void:
	var jump_speed := jump_velocity
	var has_directional_input := absf(current_input_direction) > 0.1
	var is_at_turbo_speed := absf(character.velocity.x) >= GameConstants.PLAYER_MAX_WALK_SPEED
	if is_turbo_active and has_directional_input and is_at_turbo_speed:
		jump_speed = GameConstants.JUMP_VELOCITY_TURBO
	character.velocity.y = jump_speed * jump_modifier

func _wrap_after_motion() -> void:
	if not wrap_enabled:
		return
	
	var rect: Rect2 = character.get_viewport().get_visible_rect()
	var left: float = rect.position.x
	var right: float = rect.position.x + rect.size.x
	var top: float = rect.position.y
	var bottom: float = rect.position.y + rect.size.y
	
	var pos: Vector2 = character.global_position
	
	# Horizontal wrap
	if pos.x > right:
		pos.x = left + wrap_offset
	elif pos.x < left:
		pos.x = right - wrap_offset
	
	# Vertical wrap
	if pos.y > bottom:
		pos.y = top + wrap_offset
	elif pos.y < top:
		pos.y = bottom - wrap_offset
	
	character.global_position = pos

## Applies SMW-style acceleration and friction to horizontal movement
func _apply_horizontal_movement(input_direction: float, delta: float) -> void:
	current_input_direction = input_direction
	previous_horizontal_velocity = character.velocity.x
	# Calculate effective max speed based on modifiers
	var effective_max_speed := max_speed
	if is_turbo_active:
		effective_max_speed = GameConstants.PLAYER_MAX_RUN_SPEED
	elif is_slowdown_active:
		effective_max_speed = GameConstants.PLAYER_MAX_SLOW_SPEED
	current_effective_max_speed = effective_max_speed
	
	# Determine acceleration rate based on surface
	var current_accel := acceleration
	if is_on_ice:
		current_accel = GameConstants.PLAYER_ACCEL_ICE
	
	if input_direction != 0.0:
		# Apply acceleration
		var accel_amount := current_accel * delta
		character.velocity.x += input_direction * accel_amount
		
		# Clamp to max speed
		character.velocity.x = clamp(character.velocity.x, -effective_max_speed, effective_max_speed)
	else:
		# Apply friction when no input
		var friction := _get_current_friction()
		var friction_amount := friction * delta
		
		if absf(character.velocity.x) <= friction_amount:
			# Stop completely if velocity is very small
			character.velocity.x = 0.0
		else:
			# Apply friction in opposite direction of movement
			var friction_dir: float = -sign(character.velocity.x)
			character.velocity.x += friction_dir * friction_amount

## Returns appropriate friction based on current state (ground, ice, air)
func _get_current_friction() -> float:
	if not character.is_on_floor():
		return friction_air
	elif is_on_ice:
		return friction_ice
	else:
		return friction_ground

## Detects if character is standing on ice tiles
func _detect_surface_type() -> void:
	is_on_ice = false
	
	if not character.is_on_floor():
		return
	
	# Get the TileMap from the current scene
	var tilemap := _find_tilemap()
	if tilemap == null:
		return
	
	# Check tile at foot position
	var foot_pos: Vector2 = character.get_foot_position()
	var tile_coords := tilemap.local_to_map(tilemap.to_local(foot_pos))
	
	# Get custom data for ice detection (assumes tile has "is_ice" custom data)
	var tile_data := tilemap.get_cell_tile_data(0, tile_coords)
	if tile_data != null and tile_data.get_custom_data("is_ice"):
		is_on_ice = true

## Finds the TileMap node in the current scene
func _find_tilemap() -> TileMap:
	var scene_root := character.get_tree().current_scene
	if scene_root == null:
		return null
	
	# Search for TileMap node (assumes it's directly in scene or in a child)
	var tilemaps := scene_root.find_children("*", "TileMap")
	if tilemaps.size() > 0:
		return tilemaps[0] as TileMap
	
	return null

## Calculates distance needed to stop from current velocity (useful for AI)
func get_stopping_distance() -> float:
	var friction := _get_current_friction()
	if friction <= 0.0:
		return INF
	
	var current_speed := absf(character.velocity.x)
	# Using kinematic equation: v² = u² + 2as
	# Solving for s (distance): s = v² / (2 * a)
	return (current_speed * current_speed) / (2.0 * friction)

## Calculates time needed to stop from current velocity (useful for AI)
func get_stopping_time() -> float:
	var friction := _get_current_friction()
	if friction <= 0.0:
		return INF
	
	var current_speed := absf(character.velocity.x)
	# Using equation: v = u - at
	# Solving for t: t = v / a
	return current_speed / friction

func get_current_input_direction() -> float:
	return current_input_direction

func get_effective_max_speed() -> float:
	return current_effective_max_speed

func get_previous_horizontal_velocity() -> float:
	return previous_horizontal_velocity
