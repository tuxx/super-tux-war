extends Node
class_name CharacterVisuals

## Handles character animations and visual effects (spawn, respawn).

var character: CharacterBody2D
var animated_sprite: AnimatedSprite2D

# Spawn animation properties
const SPAWN_FADE_DURATION: float = 0.8
const SPAWN_INITIAL_ALPHA: float = 0.0
const SPAWN_SCALE_START: float = 0.3
const SPAWN_SCALE_BOUNCE: float = 1.2
const SPAWN_FLASH_BRIGHTNESS: float = 5.0
const SPAWN_FLASH_SPEED_MULT: float = 4.0
const SPAWN_BOUNCE_THRESHOLD: float = 0.6

var spawn_animation_timer: float = 0.0
const SKID_MIN_SPEED_RATIO := 0.95
const SKID_INPUT_THRESHOLD := 0.4
var _skid_active := false
var _skid_target_direction := 0

func _init(character_body: CharacterBody2D) -> void:
	character = character_body

func initialize() -> void:
	animated_sprite = character.get_node_or_null("AnimatedSprite2D")
	
	# Ensure normal appearance at start
	character.modulate = Color(1, 1, 1, 1)
	character.scale = Vector2.ONE

## Loads and applies cached sprite frames for the specified character.
func load_animations(character_name: String) -> void:
	if not animated_sprite:
		return
	
	var frames := AnimationCache.get_sprite_frames(character_name)
	if not frames:
		push_warning("Could not load animations for character: %s" % character_name)
		return
	
	animated_sprite.sprite_frames = frames
	
	if frames.has_animation("idle"):
		animated_sprite.play("idle")

## Updates current animation based on character state.
func update_animation(
	is_on_floor: bool,
	velocity: Vector2,
	input_direction: float = 0.0,
	effective_max_speed: float = GameConstants.PLAYER_MAX_WALK_SPEED,
	previous_velocity_x: float = 0.0
) -> void:
	if not animated_sprite:
		return
	
	if _update_skid_state(is_on_floor, velocity.x, input_direction, effective_max_speed, previous_velocity_x):
		return
	
	if not is_on_floor:
		# In the air
		if animated_sprite.sprite_frames.has_animation("jump"):
			if animated_sprite.animation != "jump":
				animated_sprite.animation = "jump"
			animated_sprite.stop()
			animated_sprite.frame = 1
		elif abs(velocity.x) > 10:
			if animated_sprite.animation != "run":
				animated_sprite.play("run")
		else:
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")
		
		# Flip based on direction
		if velocity.x < 0:
			animated_sprite.flip_h = true
		elif velocity.x > 0:
			animated_sprite.flip_h = false
	elif abs(velocity.x) > 10:
		# Moving horizontally
		if animated_sprite.animation != "run":
			animated_sprite.play("run")
		
		if velocity.x < 0:
			animated_sprite.flip_h = true
		else:
			animated_sprite.flip_h = false
	else:
		# Idle
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")

func _update_skid_state(
	is_on_floor: bool,
	velocity_x: float,
	input_direction: float,
	effective_max_speed: float,
	previous_velocity_x: float
) -> bool:
	if _skid_active:
		var velocity_dir: float = sign(velocity_x)
		var has_input := absf(input_direction) >= SKID_INPUT_THRESHOLD
		if not is_on_floor or not has_input or velocity_dir == _skid_target_direction or velocity_dir == 0:
			_skid_active = false
		else:
			_play_skid_animation(_skid_target_direction)
			return true
	
	if _should_start_skid(is_on_floor, velocity_x, input_direction, effective_max_speed, previous_velocity_x):
		_skid_active = true
		_skid_target_direction = sign(input_direction)
		_play_skid_animation(_skid_target_direction)
		return true
	
	return false


func _should_start_skid(
	is_on_floor: bool,
	velocity_x: float,
	input_direction: float,
	effective_max_speed: float,
	previous_velocity_x: float
) -> bool:
	if not is_on_floor:
		return false
	if effective_max_speed <= 0.0:
		return false
	var input_mag := absf(input_direction)
	if input_mag < SKID_INPUT_THRESHOLD:
		return false
	var velocity_dir: float = sign(velocity_x)
	var input_dir: float = sign(input_direction)
	if velocity_dir == 0 or input_dir == 0 or velocity_dir == input_dir:
		return false
	var speed: float = max(absf(previous_velocity_x), absf(velocity_x))
	return speed >= effective_max_speed * SKID_MIN_SPEED_RATIO


func _play_skid_animation(target_direction: int) -> void:
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("skid"):
		if animated_sprite.animation != "skid":
			animated_sprite.animation = "skid"
		animated_sprite.frame = 0
		animated_sprite.stop()
	else:
		if animated_sprite.animation != "run":
			animated_sprite.play("run")
	
	if target_direction != 0:
		animated_sprite.flip_h = target_direction < 0

## Starts spawn animation effects.
func start_spawn_animation() -> void:
	spawn_animation_timer = SPAWN_FADE_DURATION
	character.modulate = Color(SPAWN_FLASH_BRIGHTNESS, SPAWN_FLASH_BRIGHTNESS, SPAWN_FLASH_BRIGHTNESS, SPAWN_INITIAL_ALPHA)
	character.scale = Vector2(SPAWN_SCALE_START, SPAWN_SCALE_START)

## Updates spawn animation (call every frame during spawn).
func update_spawn_animation(delta: float) -> void:
	if spawn_animation_timer <= 0.0:
		# Ensure fully visible after animation
		if character.modulate.a < 1.0 or character.scale != Vector2.ONE:
			character.modulate = Color(1, 1, 1, 1)
			character.scale = Vector2.ONE
		return
	
	spawn_animation_timer = max(0.0, spawn_animation_timer - delta)
	
	var progress: float = 1.0 - (spawn_animation_timer / SPAWN_FADE_DURATION)
	
	# Fade in alpha
	var target_alpha: float = lerp(SPAWN_INITIAL_ALPHA, 1.0, progress)
	
	# Bright white flash fades quickly
	var flash_progress: float = min(progress * SPAWN_FLASH_SPEED_MULT, 1.0)
	var color_value: float = lerp(SPAWN_FLASH_BRIGHTNESS, 1.0, flash_progress)
	
	# Scale with bounce effect
	var scale_value: float
	if progress < SPAWN_BOUNCE_THRESHOLD:
		var grow_progress := progress / SPAWN_BOUNCE_THRESHOLD
		scale_value = lerp(SPAWN_SCALE_START, SPAWN_SCALE_BOUNCE, _ease_out_back(grow_progress))
	else:
		var settle_progress := (progress - SPAWN_BOUNCE_THRESHOLD) / (1.0 - SPAWN_BOUNCE_THRESHOLD)
		scale_value = lerp(SPAWN_SCALE_BOUNCE, 1.0, _ease_out_quad(settle_progress))
	
	character.modulate = Color(color_value, color_value, color_value, target_alpha)
	character.scale = Vector2(scale_value, scale_value)

## Faces character toward screen center.
func face_towards_screen_center() -> void:
	if not animated_sprite:
		return
	
	var center_x: float = character.get_viewport().get_visible_rect().size.x * 0.5
	if character.global_position.x < center_x:
		animated_sprite.flip_h = false
	else:
		animated_sprite.flip_h = true

func _ease_out_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)

func _ease_out_quad(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)
