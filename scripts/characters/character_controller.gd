extends CharacterBody2D
class_name CharacterController

## Orchestrates character components for physics, visuals, and lifecycle.
##
## Uses component-based architecture with CharacterPhysics, CharacterVisuals,
## and CharacterLifecycle for better separation of concerns and maintainability.

# Components
var physics: CharacterPhysics
var visuals: CharacterVisuals
var lifecycle: CharacterLifecycle

# Public properties
@export var is_player: bool = false
@export var character_color: Color = Color.WHITE
@export var character_asset_name: String = ""
@export var foot_offset: float = 14.0

# Exposed for backwards compatibility
var is_despawned: bool = false:
	get: return lifecycle.is_despawned if lifecycle else false

func _ready():
	# Initialize components
	physics = CharacterPhysics.new(self)
	visuals = CharacterVisuals.new(self)
	lifecycle = CharacterLifecycle.new(self)
	
	lifecycle.initialize()
	visuals.initialize()
	
	# Setup groups
	add_to_group("characters")
	if is_player:
		add_to_group("players")
	
	# Register with GameStateManager
	GameStateManager.register_character(self)
	
	# Rendering
	z_index = 10
	
	# Apply character color
	var color_rect := get_node_or_null("ColorRect")
	if color_rect:
		color_rect.color = character_color
	
	# Set initial facing
	visuals.face_towards_screen_center()

## Loads and applies cached sprite frames for the specified character.
func load_character_animations(character_name: String) -> void:
	character_asset_name = character_name
	visuals.load_animations(character_name)

func _physics_process(delta: float) -> void:
	# Update lifecycle (respawn, spawn protection)
	if not lifecycle.update_lifecycle(delta):
		return  # Don't process physics while despawned
	
	# Update spawn animation
	visuals.update_spawn_animation(delta)
	
	# Update physics (movement, gravity, collisions)
	var previous_velocity_y := physics.update_physics(delta, is_player)
	
	# Update animations
	visuals.update_animation(
		is_on_floor(),
		velocity,
		physics.get_current_input_direction(),
		physics.get_effective_max_speed(),
		physics.get_previous_horizontal_velocity()
	)
	
	# Check for character collisions (stomps and deaths)
	_check_character_collisions(previous_velocity_y)

## Sets AI input for next physics frame.
func set_ai_inputs(move_direction: float, jump_pressed: bool, jump_released: bool, drop_pressed: bool) -> void:
	physics.set_ai_inputs(move_direction, jump_pressed, jump_released, drop_pressed)

func _check_character_collisions(previous_velocity_y: float) -> void:
	# Check all character collisions for stomps and deaths
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		
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
				velocity.y = physics.jump_velocity * 0.5
			elif hit_their_bottom:
				# Hit their bottom from below - we die and credit them
				despawn(other_character)
			# Side collisions (normal.x dominant) are harmless - do nothing

## Despawns character, spawns gravestone, and emits kill event.
func despawn(killer: CharacterController = null) -> void:
	lifecycle.despawn(killer)

## Respawns character at spawn point with protection and visual effects.
func respawn() -> void:
	lifecycle.respawn()
	visuals.start_spawn_animation()
	visuals.face_towards_screen_center()

## Returns character's foot position for spawn point calculations.
func get_foot_position() -> Vector2:
	return lifecycle.get_foot_position()
