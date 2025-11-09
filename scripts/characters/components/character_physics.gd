extends Node
class_name CharacterPhysics

## Handles character physics: gravity, movement, collision, and boundary wrapping.

var character: CharacterBody2D

# Physics properties
var move_speed: float = GameConstants.PLAYER_MAX_WALK_SPEED
var jump_velocity: float = GameConstants.JUMP_VELOCITY
var gravity: float = GameConstants.GRAVITY
var max_fall_speed: float = GameConstants.MAX_FALL_SPEED

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
	
	# Handle input
	if is_player:
		_handle_player_input()
	else:
		_handle_ai_input()
	
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

func _handle_player_input() -> void:
	var input_direction := InputManager.get_move_axis_x()
	character.velocity.x = input_direction * move_speed
	
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

func _handle_ai_input() -> void:
	character.velocity.x = ai_move_direction * move_speed
	
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

func _perform_jump() -> void:
	character.velocity.y = jump_velocity
	AudioManager.play_jump(character.global_position)

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
