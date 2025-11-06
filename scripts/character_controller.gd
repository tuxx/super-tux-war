extends CharacterBody2D

# Movement and physics properties
@export var move_speed: float = GameConstants.PLAYER_MAX_WALK_SPEED
@export var jump_velocity: float = GameConstants.JUMP_VELOCITY
@export var gravity: float = GameConstants.GRAVITY
@export var is_player: bool = false
@export var character_color: Color = Color.WHITE
@export var max_fall_speed: float = GameConstants.MAX_FALL_SPEED

# Note: Movement feel multipliers removed to match SMW baseline
# (no apex hang/bonus, no air-control dampening, no per-node speed multipliers)
@export var death_hold_before_respawn: float = 0.2	# Hold last death frame before respawn
@export var hit_flash_duration: float = 0.2		# Time to tint red on hit

# Boundary wrap settings
@export var wrap_enabled: bool = true
@export var wrap_offset: float = 10.0

# Respawn properties
var is_despawned: bool = false
var spawn_position: Vector2
var respawn_timer: float = 0.0
const RESPAWN_TIME: float = 2.0

# Animation
var animated_sprite: AnimatedSprite2D
var shape_alive: CollisionShape2D
var shape_dead: CollisionShape2D

# Timers/state for jump assist and drop-through
var anchor_x: float = NAN
var death_anim_active: bool = false
var hit_flash_timer: float = 0.0
var base_sprite_modulate: Color = Color(1, 1, 1, 1)
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var drop_through_timer: float = 0.0
const DROP_THROUGH_DURATION: float = 0.2

func _ready():
	# Store initial spawn position
	spawn_position = global_position
	
	# Get animated sprite reference
	animated_sprite = get_node_or_null("AnimatedSprite2D")
	if animated_sprite:
		base_sprite_modulate = animated_sprite.modulate
	shape_alive = get_node_or_null("CollisionShape2D") as CollisionShape2D
	shape_dead = get_node_or_null("CollisionShape2D_Dead") as CollisionShape2D
	# Ensure correct initial shape state
	if shape_alive:
		shape_alive.disabled = false
	if shape_dead:
		shape_dead.disabled = true

	# Register player in group for dev tools and gameplay systems
	if is_player:
		add_to_group("players")
	
	# Apply character color to visual representation if ColorRect exists
	var color_rect = get_node_or_null("ColorRect")
	if color_rect:
		color_rect.color = character_color

	# Set initial facing toward screen center
	_face_towards_screen_center()

	# For NPCs, lock horizontal position to prevent drift from collisions
	if not is_player:
		anchor_x = global_position.x

func _physics_process(delta: float) -> void:
	# Handle respawn timer
	if is_despawned:
		respawn_timer += delta
		# If we're playing a death animation, allow physics so the body falls to the floor
		if death_anim_active:
			# Simple gravity while dead (no jump modifiers)
			velocity.x = 0.0
			velocity.y = clamp(velocity.y + gravity * delta, -max_fall_speed, max_fall_speed)
			move_and_slide()
			# Manage hit flash tint
			if animated_sprite:
				if hit_flash_timer > 0.0:
					hit_flash_timer = max(0.0, hit_flash_timer - delta)
					animated_sprite.modulate = Color(1, 0.25, 0.25, 1)
				else:
					animated_sprite.modulate = base_sprite_modulate
			# Ensure last frame is shown shortly before respawn
			if animated_sprite and animated_sprite.sprite_frames and animated_sprite.animation == "death":
				if respawn_timer >= (RESPAWN_TIME - death_hold_before_respawn):
					var frames: SpriteFrames = animated_sprite.sprite_frames
					var last_idx: int = max(0, frames.get_frame_count("death") - 1)
					animated_sprite.stop()
					animated_sprite.animation = "death"
					animated_sprite.frame = last_idx
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
	
	# Handle input for player characters
	if is_player:
		_handle_input()
	else:
		# Ensure NPCs do not retain any horizontal drift
		velocity.x = 0.0

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

	# Hard-lock NPC X so collision resolution and respawns cannot push it sideways
	if not is_player and anchor_x == anchor_x: # check for NaN
		global_position.x = anchor_x

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
	var input_direction = Input.get_axis("move_left", "move_right")
	velocity.x = input_direction * move_speed
	
	# Drop-through semisolid platforms (Down + Jump)
	if Input.is_action_pressed("move_down") and Input.is_action_just_pressed("jump") and is_on_floor():
		# Initiate drop-through by temporarily disabling one-way collision detection
		drop_through_timer = DROP_THROUGH_DURATION
		position.y += 1  # Small nudge down to clear the platform
		return
	
	# Jump with coyote time and buffering
	if Input.is_action_just_pressed("jump") and not Input.is_action_pressed("move_down"):
		if coyote_timer > 0.0:
			_perform_jump()
			coyote_timer = 0.0
		else:
			# Buffer the jump
			jump_buffer_timer = GameConstants.JUMP_BUFFER_TIME
	
	# Variable jump: early release clamp
	if Input.is_action_just_released("jump") and velocity.y < 0:
		if velocity.y < GameConstants.JUMP_EARLY_CLAMP:
			velocity.y = GameConstants.JUMP_EARLY_CLAMP

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
	if abs(velocity.x) > 10:  # Moving horizontally
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
		if collider is CharacterBody2D and collider != self and collider.has_method("despawn"):
			# Ignore already-despawned targets
			if collider.has_method("get") and collider.get("is_despawned") == true:
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
				collider.despawn()
				velocity.y = jump_velocity * 0.5
			elif hit_their_bottom:
				# Hit their bottom from below - we die
				despawn()
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

func despawn() -> void:
	if is_despawned:
		return
	
	is_despawned = true
	respawn_timer = 0.0
	velocity = Vector2.ZERO
	
	var has_death_anim: bool = false
	if animated_sprite:
		var frames: SpriteFrames = animated_sprite.sprite_frames
		has_death_anim = frames != null and frames.has_animation("death")
	
	if has_death_anim:
		# Play death animation and allow body to fall under gravity
		animated_sprite.sprite_frames.set_animation_loop("death", false)
		animated_sprite.play("death")
		death_anim_active = true
		# Keep collisions enabled so we can land on the floor
		# Start hit flash tint
		hit_flash_timer = hit_flash_duration
		# Switch to smaller dead collision shape if available (player only)
		if is_player:
			if shape_alive:
				shape_alive.disabled = true
			if shape_dead:
				shape_dead.disabled = false
	else:
		# No death animation: hide immediately and disable collisions
		visible = false
		set_collision_layer_value(1, false)
		set_collision_mask_value(1, false)
		# Ensure no collision shapes remain active
		if shape_alive:
			shape_alive.disabled = true
		if shape_dead:
			shape_dead.disabled = true

func _respawn() -> void:
	is_despawned = false
	respawn_timer = 0.0
	death_anim_active = false
	hit_flash_timer = 0.0
	
	# Reset position
	global_position = spawn_position
	velocity = Vector2.ZERO
	_face_towards_screen_center()
	# Restore alive collision shape
	if shape_alive:
		shape_alive.disabled = false
	if shape_dead:
		shape_dead.disabled = true
	
	# Show the character
	visible = true
	if animated_sprite:
		animated_sprite.modulate = base_sprite_modulate
	
	# Enable collision
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)

func _face_towards_screen_center() -> void:
	if not animated_sprite:
		return
	var center_x: float = get_viewport().get_visible_rect().size.x * 0.5
	# If positioned left of center, face right (no flip). If right of center, face left (flip).
	if global_position.x < center_x:
		animated_sprite.flip_h = false
	else:
		animated_sprite.flip_h = true
