extends CharacterBody2D

# Movement and physics properties
@export var move_speed: float = 300.0
@export var jump_velocity: float = -400.0
@export var gravity: float = 980.0
@export var is_player: bool = false
@export var character_color: Color = Color.WHITE
@export var max_fall_speed: float = 1000.0

# Jump feel tuning
@export var fall_multiplier: float = 2.0			# Faster falls feel snappier
@export var low_jump_multiplier: float = 3.0		# Cutting jump early increases gravity
@export var coyote_time: float = 0.1				# Grace time after leaving ground to still jump
@export var jump_buffer_time: float = 0.1			# Buffer jump input slightly before landing
@export var apex_gravity_scale: float = 0.6		# Reduce gravity near apex to add slight "hang"
@export var apex_threshold_speed: float = 40.0	# |vy| below this is considered near apex
@export var air_control_multiplier: float = 0.85	# Slightly reduce horizontal control while airborne
@export var apex_horizontal_bonus: float = 1.15	# Small horizontal speed bonus at apex
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

# Timers/state for jump assist
var time_since_left_floor: float = 0.0
var jump_buffer_timer: float = 0.0
var was_on_floor: bool = false
var anchor_x: float = NAN
var death_anim_active: bool = false
var hit_flash_timer: float = 0.0
var base_sprite_modulate: Color = Color(1, 1, 1, 1)

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
	
	# Handle input for player characters
	if is_player:
		_handle_input()
	else:
		# Ensure NPCs do not retain any horizontal drift
		velocity.x = 0.0

	# Update grounded state timers for coyote time
	if is_on_floor():
		time_since_left_floor = 0.0
	else:
		time_since_left_floor += delta

	# Decrease jump buffer timer
	if jump_buffer_timer > 0.0:
		jump_buffer_timer = max(0.0, jump_buffer_timer - delta)
	
	# Apply gravity
	_apply_gravity(delta)
	
	# Handle buffered/coyote jump resolution after gravity application
	if _should_jump():
		_perform_jump()

	# Cap velocity to prevent infinite acceleration
	velocity.y = clamp(velocity.y, -max_fall_speed, max_fall_speed)
	velocity.x = clamp(velocity.x, -move_speed * 2, move_speed * 2)
	
	# Move and handle collisions
	var previous_velocity_y = velocity.y
	move_and_slide()

	# Hard-lock NPC X so collision resolution and respawns cannot push it sideways
	if not is_player and anchor_x == anchor_x: # check for NaN
		global_position.x = anchor_x

	# Detect landing to consume buffered jump if still pending
	if is_on_floor() and not was_on_floor and jump_buffer_timer > 0.0:
		_perform_jump()

	was_on_floor = is_on_floor()
	
	# Update animations
	_update_animation()
	
	# Check for head stomps
	if previous_velocity_y > 0:  # Was falling
		_check_head_stomp()

	# Boundary wrap after all motion for determinism
	_wrap_after_motion()

func _handle_input() -> void:
	# Horizontal movement input
	var input_direction = Input.get_axis("move_left", "move_right")
	var horizontal_speed: float = move_speed
	if not is_on_floor():
		# Slight midair control dampening
		horizontal_speed *= air_control_multiplier
		# Small apex bonus to help clear gaps
		if _is_near_apex():
			horizontal_speed *= apex_horizontal_bonus
	velocity.x = input_direction * horizontal_speed
	
	# Jump input buffering
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time

func _apply_gravity(delta: float) -> void:
	# Apply gravity with fall/low-jump multipliers for better feel
	if is_on_floor():
		return
	
	var g: float = gravity
	if velocity.y > 0.0:
		# Falling: make it faster/snappier
		g *= fall_multiplier
	elif velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		# Rising but jump released early: cut the jump by increasing gravity
		g *= low_jump_multiplier
	
	# Add a slight hang near the jump apex to feel more controllable
	if _is_near_apex():
		g *= apex_gravity_scale
	
	velocity.y += g * delta

func _is_near_apex() -> bool:
	return (not is_on_floor()) and abs(velocity.y) <= apex_threshold_speed

func _should_jump() -> bool:
	# Can jump if on floor or within coyote time window, and we have a buffered press
	var can_coyote_jump: bool = (is_on_floor() or time_since_left_floor <= coyote_time)
	return can_coyote_jump and jump_buffer_timer > 0.0

func _perform_jump() -> void:
	velocity.y = jump_velocity
	jump_buffer_timer = 0.0
	# Reset coyote after consuming jump
	time_since_left_floor = coyote_time + 1.0

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

func _check_head_stomp() -> void:
	# Check if we landed on another character
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# Only stomp characters when contacting their top surface (avoid side/bottom kills)
		if collider is CharacterBody2D and collider != self and collider.has_method("despawn"):
			# Ignore already-despawned targets
			if collider.has_method("get") and collider.get("is_despawned") == true:
				continue
			var normal: Vector2 = collision.get_normal()
			# Upward normal means we hit their top. Threshold tolerates slopes/rounded shapes.
			var hit_top: bool = normal.y < -0.6
			if hit_top:
				collider.despawn()
				# Bounce the stomper back up for game feel
				velocity.y = jump_velocity * 0.5

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
	was_on_floor = true
	jump_buffer_timer = 0.0
	time_since_left_floor = 0.0
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
