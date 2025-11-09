extends CharacterBody2D
class_name CharacterController

signal enemy_killed(victim: CharacterBody2D)

# Preload gravestone scene
const GRAVESTONE_SCENE = preload("res://scenes/objects/gravestone.tscn")

# Movement and physics properties
@export var move_speed: float = GameConstants.PLAYER_MAX_WALK_SPEED
@export var jump_velocity: float = GameConstants.JUMP_VELOCITY
@export var gravity: float = GameConstants.GRAVITY
@export var is_player: bool = false
@export var character_color: Color = Color.WHITE
@export var character_asset_name: String = ""
@export var max_fall_speed: float = GameConstants.MAX_FALL_SPEED
@export var foot_offset: float = 14.0

# Boundary wrap settings
@export var wrap_enabled: bool = true
@export var wrap_offset: float = 10.0

# Respawn properties
var is_despawned: bool = false
var spawn_position: Vector2
var respawn_timer: float = 0.0
const RESPAWN_TIME: float = 2.0

# Spawn animation properties
const SPAWN_FADE_DURATION: float = 0.8
const SPAWN_INITIAL_ALPHA: float = 0.0
const SPAWN_SCALE_START: float = 0.3
const SPAWN_SCALE_BOUNCE: float = 1.2
var spawn_animation_timer: float = 0.0

# Animation
var animated_sprite: AnimatedSprite2D
var shape_alive: CollisionShape2D

# Timers/state for jump assist and drop-through
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var drop_through_timer: float = 0.0
const DROP_THROUGH_DURATION: float = 0.2

var ai_move_direction: float = 0.0
var ai_jump_pressed: bool = false
var ai_jump_released: bool = false
var ai_drop_pressed: bool = false
var spawn_protection_timer: float = 0.0
const SPAWN_PROTECTION_DURATION: float = 1.0

func _ready():
	# Store initial spawn position
	spawn_position = global_position
	
	# Get animated sprite reference
	animated_sprite = get_node_or_null("AnimatedSprite2D")
	shape_alive = get_node_or_null("CollisionShape2D") as CollisionShape2D
	# Ensure correct initial shape state
	if shape_alive:
		shape_alive.disabled = false

	add_to_group("characters")
	# Register player in group for dev tools and gameplay systems
	if is_player:
		add_to_group("players")
	
	# Ensure characters render above temporary objects like gravestones
	z_index = 10
	
	# Apply character color to visual representation if ColorRect exists
	var color_rect = get_node_or_null("ColorRect")
	if color_rect:
		color_rect.color = character_color
	
	# Ensure normal appearance at start (no spawn effects)
	modulate = Color(1, 1, 1, 1)
	scale = Vector2.ONE

	# Set initial facing toward screen center
	_face_towards_screen_center()

func _physics_process(delta: float) -> void:
	# Handle respawn timer
	if is_despawned:
		respawn_timer += delta
		if respawn_timer >= RESPAWN_TIME:
			_respawn()
		return
	
	# Update timers
	var was_on_floor = is_on_floor()
	if was_on_floor:
		coyote_timer = GameConstants.COYOTE_TIME
	else:
		coyote_timer = max(0.0, coyote_timer - delta)
	
	if jump_buffer_timer > 0.0:
		jump_buffer_timer = max(0.0, jump_buffer_timer - delta)
	
	if drop_through_timer > 0.0:
		drop_through_timer = max(0.0, drop_through_timer - delta)
	
	# Spawn protection: temporarily disable character-vs-character collisions
	if spawn_protection_timer > 0.0:
		spawn_protection_timer = max(0.0, spawn_protection_timer - delta)
		# Ensure we don't appear on the character layer and don't collide with it
		set_collision_layer_value(2, false)
		set_collision_mask_value(2, false)
	else:
		# Restore normal character collisions
		set_collision_layer_value(2, true)
		set_collision_mask_value(2, true)
	
	# Handle spawn animation effects
	if spawn_animation_timer > 0.0:
		_update_spawn_animation()
		spawn_animation_timer = max(0.0, spawn_animation_timer - delta)
	elif spawn_animation_timer <= 0.0 and (modulate.a < 1.0 or scale != Vector2.ONE):
		# Ensure we're fully visible and at normal scale after animation completes
		modulate = Color(1, 1, 1, 1)
		scale = Vector2.ONE
	
	# Handle input for player or AI
	if is_player:
		_handle_input()
	else:
		_handle_ai_input()

	# Apply gravity
	_apply_gravity(delta)
	
	# Cap velocity to prevent infinite acceleration
	velocity.y = clamp(velocity.y, -max_fall_speed, max_fall_speed)
	velocity.x = clamp(velocity.x, -GameConstants.PLAYER_MAX_RUN_SPEED, GameConstants.PLAYER_MAX_RUN_SPEED)
	
	# Move and handle collisions
	var previous_velocity_y = velocity.y
	
	# Temporarily disable platform_on_leave for drop-through
	var old_platform_on_leave = platform_on_leave
	if drop_through_timer > 0.0:
		platform_on_leave = CharacterBody2D.PLATFORM_ON_LEAVE_DO_NOTHING
	
	move_and_slide()
	
	# Restore platform behavior
	if drop_through_timer > 0.0:
		platform_on_leave = old_platform_on_leave

	# Handle buffered jump after landing
	if is_on_floor() and not was_on_floor and jump_buffer_timer > 0.0:
		_perform_jump()
		jump_buffer_timer = 0.0

	# Update animations
	_update_animation()
	
	# Check for character collisions (stomps and deaths)
	_check_character_collisions(previous_velocity_y)

	# Boundary wrap after all motion for determinism
	_wrap_after_motion()

func _handle_input() -> void:
	# Horizontal movement input
	var input_direction = InputManager.get_move_axis_x()
	velocity.x = input_direction * move_speed
	
	# Drop-through semisolid platforms (Down + Jump)
	if InputManager.is_move_down_pressed() and InputManager.is_jump_just_pressed() and is_on_floor():
		# Initiate drop-through by temporarily disabling one-way collision detection
		drop_through_timer = DROP_THROUGH_DURATION
		position.y += 1  # Small nudge down to clear the platform
		return
	
	# Jump with coyote time and buffering
	if InputManager.is_jump_just_pressed() and not InputManager.is_move_down_pressed():
		if coyote_timer > 0.0:
			_perform_jump()
			coyote_timer = 0.0
		else:
			# Buffer the jump
			jump_buffer_timer = GameConstants.JUMP_BUFFER_TIME
	
	# Variable jump: early release clamp
	if InputManager.is_jump_just_released() and velocity.y < 0:
		if velocity.y < GameConstants.JUMP_EARLY_CLAMP:
			velocity.y = GameConstants.JUMP_EARLY_CLAMP

func _handle_ai_input() -> void:
	velocity.x = ai_move_direction * move_speed

	if ai_drop_pressed and is_on_floor():
		drop_through_timer = DROP_THROUGH_DURATION
		position.y += 1
		ai_drop_pressed = false
		return

	if ai_jump_pressed:
		if coyote_timer > 0.0:
			_perform_jump()
			coyote_timer = 0.0
		else:
			jump_buffer_timer = GameConstants.JUMP_BUFFER_TIME

	if ai_jump_released and velocity.y < 0:
		if velocity.y < GameConstants.JUMP_EARLY_CLAMP:
			velocity.y = GameConstants.JUMP_EARLY_CLAMP

	ai_jump_pressed = false
	ai_jump_released = false
	ai_drop_pressed = false

func set_ai_inputs(move_direction: float, jump_pressed: bool, jump_released: bool, drop_pressed: bool) -> void:
	ai_move_direction = clamp(move_direction, -1.0, 1.0)
	ai_jump_pressed = jump_pressed
	ai_jump_released = jump_released
	ai_drop_pressed = drop_pressed

func _apply_gravity(delta: float) -> void:
	# Apply gravity (SMW baseline; no apex/fall multipliers)
	if not is_on_floor():
		velocity.y += gravity * delta


func _perform_jump() -> void:
	velocity.y = jump_velocity

func _update_animation() -> void:
	if not animated_sprite:
		return
	
	# Determine which animation to play
	if not is_on_floor():  # In the air (jumping or falling)
		# Play jump animation if it exists, otherwise fall back to idle/run
		if animated_sprite.sprite_frames.has_animation("jump"):
			if animated_sprite.animation != "jump":
				animated_sprite.animation = "jump"
			# Keep on frame 2 (index 1) while in the air
			animated_sprite.stop()
			animated_sprite.frame = 1
		elif abs(velocity.x) > 10:
			if animated_sprite.animation != "run":
				animated_sprite.play("run")
		else:
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")
		
		# Flip sprite based on direction
		if velocity.x < 0:
			animated_sprite.flip_h = true
		elif velocity.x > 0:
			animated_sprite.flip_h = false
	elif abs(velocity.x) > 10:  # Moving horizontally
		if animated_sprite.animation != "run":
			animated_sprite.play("run")
		
		# Flip sprite based on direction
		if velocity.x < 0:
			animated_sprite.flip_h = true
		else:
			animated_sprite.flip_h = false
	else:  # Idle
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")

func _check_character_collisions(previous_velocity_y: float) -> void:
	# Check all character collisions for stomps and deaths
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# Only process character-to-character collisions
		var other_character := collider as CharacterController
		if other_character and other_character != self:
			# Ignore already-despawned targets
			if other_character.is_despawned:
				continue
			
			var normal: Vector2 = collision.get_normal()
			
			# Check if we stomped them (we were falling and hit their top)
			# Upward normal means we hit their top from above
			var hit_their_top: bool = normal.y < -0.6 and previous_velocity_y > 0
			
			# Check if we hit their bottom (we were jumping up and hit their bottom)
			# Downward normal means we hit their bottom from below
			var hit_their_bottom: bool = normal.y > 0.6 and previous_velocity_y < 0
			
			if hit_their_top:
				# Successful stomp - they die, we bounce
				other_character.despawn(self)
				velocity.y = jump_velocity * 0.5
			elif hit_their_bottom:
				# Hit their bottom from below - we die and credit them
				despawn(other_character)
			# Side collisions (normal.x dominant) are harmless - do nothing

func _wrap_after_motion() -> void:
	if not wrap_enabled:
		return
	# Use viewport visible rect as world bounds (matches previous 0..1280x720 default)
	var rect: Rect2 = get_viewport().get_visible_rect()
	var left: float = rect.position.x
	var right: float = rect.position.x + rect.size.x
	var top: float = rect.position.y
	var bottom: float = rect.position.y + rect.size.y
	
	var pos: Vector2 = global_position
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
	global_position = pos

func despawn(killer: CharacterController = null) -> void:
	if is_despawned:
		return
	
	is_despawned = true
	respawn_timer = 0.0
	velocity = Vector2.ZERO
	
	if killer and killer != self:
		killer.enemy_killed.emit(self)
	
	# Spawn gravestone at character position
	_spawn_gravestone()
	
	# Hide character and disable collisions immediately
	visible = false
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, false)
	set_collision_mask_value(2, false)
	if shape_alive:
		shape_alive.disabled = true

func _respawn() -> void:
	is_despawned = false
	respawn_timer = 0.0
	spawn_protection_timer = SPAWN_PROTECTION_DURATION
	spawn_animation_timer = SPAWN_FADE_DURATION
	
	# Reset position
	var spawn_manager := get_tree().get_first_node_in_group("spawn_manager")
	if spawn_manager and spawn_manager.has_method("get_spawn_position_for"):
		spawn_position = spawn_manager.get_spawn_position_for(self)
	global_position = spawn_position
	velocity = Vector2.ZERO
	_face_towards_screen_center()
	# Restore alive collision shape
	if shape_alive:
		shape_alive.disabled = false
	
	# Show the character
	visible = true
	
	# Initialize spawn visual effects
	# Start with bright white flash, invisible, and small scale
	modulate = Color(5.0, 5.0, 5.0, SPAWN_INITIAL_ALPHA)  # Bright white flash
	scale = Vector2(SPAWN_SCALE_START, SPAWN_SCALE_START)
	
	# Enable collision
	set_collision_mask_value(1, true)
	# Start with character layer/mask disabled; will be restored after protection
	set_collision_layer_value(2, false)
	set_collision_mask_value(2, false)

func _update_spawn_animation() -> void:
	# Calculate progress (0.0 = just spawned, 1.0 = animation complete)
	var progress: float = 1.0 - (spawn_animation_timer / SPAWN_FADE_DURATION)
	
	# Fade in alpha from invisible to fully visible
	var target_alpha: float = lerp(SPAWN_INITIAL_ALPHA, 1.0, progress)
	
	# Bright white flash fades quickly (back to normal color)
	var flash_progress: float = min(progress * 4.0, 1.0)  # Flash fades 4x faster
	var color_value: float = lerp(5.0, 1.0, flash_progress)
	
	# Scale with bounce effect using custom easing
	var scale_value: float
	if progress < 0.6:
		# Grow from small to slightly larger than normal (bounce up)
		var grow_progress := progress / 0.6
		scale_value = lerp(SPAWN_SCALE_START, SPAWN_SCALE_BOUNCE, _ease_out_back(grow_progress))
	else:
		# Settle back to normal size (bounce down)
		var settle_progress := (progress - 0.6) / 0.4
		scale_value = lerp(SPAWN_SCALE_BOUNCE, 1.0, _ease_out_quad(settle_progress))
	
	# Apply the visual effects
	modulate = Color(color_value, color_value, color_value, target_alpha)
	scale = Vector2(scale_value, scale_value)

func _ease_out_back(t: float) -> float:
	# Back easing for overshoot effect
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)

func _ease_out_quad(t: float) -> float:
	# Quadratic ease out for smooth settling
	return 1.0 - (1.0 - t) * (1.0 - t)

func _face_towards_screen_center() -> void:
	if not animated_sprite:
		return
	var center_x: float = get_viewport().get_visible_rect().size.x * 0.5
	# If positioned left of center, face right (no flip). If right of center, face left (flip).
	if global_position.x < center_x:
		animated_sprite.flip_h = false
	else:
		animated_sprite.flip_h = true

func get_foot_position() -> Vector2:
	return global_position + Vector2(0, foot_offset)

func _spawn_gravestone() -> void:
	# Create gravestone instance
	var gravestone = GRAVESTONE_SCENE.instantiate()
	gravestone.global_position = global_position
	
	# Add to scene tree (add to the level/root)
	var level = get_tree().current_scene
	if level:
		level.add_child(gravestone)
