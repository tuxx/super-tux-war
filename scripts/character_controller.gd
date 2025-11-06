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

# Respawn properties
var is_despawned: bool = false
var spawn_position: Vector2
var respawn_timer: float = 0.0
const RESPAWN_TIME: float = 2.0

# Animation
var animated_sprite: AnimatedSprite2D

# Timers/state for jump assist
var time_since_left_floor: float = 0.0
var jump_buffer_timer: float = 0.0
var was_on_floor: bool = false
var anchor_x: float = NAN

func _ready():
	# Store initial spawn position
	spawn_position = global_position
	
	# Get animated sprite reference
	animated_sprite = get_node_or_null("AnimatedSprite2D")
	
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

func _handle_input() -> void:
	# Horizontal movement input
	var input_direction = Input.get_axis("move_left", "move_right")
	velocity.x = input_direction * move_speed
	
	# Jump input buffering
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time

func _apply_gravity(delta: float) -> void:
	# Apply gravity with fall/low-jump multipliers for better feel
	if is_on_floor():
		return
	
	var g := gravity
	if velocity.y > 0.0:
		# Falling: make it faster/snappier
		g *= fall_multiplier
	elif velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		# Rising but jump released early: cut the jump by increasing gravity
		g *= low_jump_multiplier
	
	velocity.y += g * delta

func _should_jump() -> bool:
	# Can jump if on floor or within coyote time window, and we have a buffered press
	var can_coyote_jump := (is_on_floor() or time_since_left_floor <= coyote_time)
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
		
		# Check if collider is a CharacterBody2D with the character_controller script
		if collider is CharacterBody2D and collider.has_method("despawn"):
			# Check if we're above the other character (stomping on head)
			if global_position.y < collider.global_position.y:
				collider.despawn()
				# Bounce the stomper
				velocity.y = jump_velocity * 0.5

func despawn() -> void:
	if is_despawned:
		return
	
	is_despawned = true
	respawn_timer = 0.0
	
	# Hide the character
	visible = false
	
	# Disable collision
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

func _respawn() -> void:
	is_despawned = false
	respawn_timer = 0.0
	
	# Reset position
	global_position = spawn_position
	velocity = Vector2.ZERO
	was_on_floor = true
	jump_buffer_timer = 0.0
	time_since_left_floor = 0.0
	_face_towards_screen_center()
	
	# Show the character
	visible = true
	
	# Enable collision
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)

func _face_towards_screen_center() -> void:
	if not animated_sprite:
		return
	var center_x := get_viewport().get_visible_rect().size.x * 0.5
	# If positioned left of center, face right (no flip). If right of center, face left (flip).
	if global_position.x < center_x:
		animated_sprite.flip_h = false
	else:
		animated_sprite.flip_h = true
