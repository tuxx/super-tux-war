extends Node
class_name CharacterLifecycle

## Handles character spawn, death, and respawn logic.

const GRAVESTONE_SCENE = preload("res://scenes/objects/gravestone.tscn")

var character: CharacterBody2D
var shape_alive: CollisionShape2D

# Lifecycle state
var is_despawned: bool = false
var spawn_position: Vector2
var respawn_timer: float = 0.0
var spawn_protection_timer: float = 0.0

const RESPAWN_TIME: float = 2.0
const SPAWN_PROTECTION_DURATION: float = 1.0

func _init(character_body: CharacterBody2D) -> void:
	character = character_body

func initialize() -> void:
	spawn_position = character.global_position
	shape_alive = character.get_node_or_null("CollisionShape2D")
	
	if shape_alive:
		shape_alive.disabled = false

## Updates respawn timer and spawn protection.
func update_lifecycle(delta: float) -> bool:
	# Handle respawn timer
	if is_despawned:
		respawn_timer += delta
		if respawn_timer >= RESPAWN_TIME:
			respawn()
		return false  # Don't process physics while despawned
	
	# Update spawn protection
	if spawn_protection_timer > 0.0:
		spawn_protection_timer = max(0.0, spawn_protection_timer - delta)
		# Disable character collision during protection
		character.set_collision_layer_value(2, false)
		character.set_collision_mask_value(2, false)
	else:
		# Restore normal collision
		character.set_collision_layer_value(2, true)
		character.set_collision_mask_value(2, true)
	
	return true  # Continue processing

## Despawns character, spawns gravestone, and emits kill event.
func despawn(killer: CharacterController = null) -> void:
	if is_despawned:
		return
	
	is_despawned = true
	respawn_timer = 0.0
	character.velocity = Vector2.ZERO
	
	if killer and killer != character:
		EventBus.character_killed.emit(killer, character)
	
	_spawn_gravestone()
	
	# Hide and disable collisions
	character.visible = false
	character.set_collision_layer_value(2, false)
	character.set_collision_mask_value(1, false)
	character.set_collision_mask_value(2, false)
	
	if shape_alive:
		shape_alive.disabled = true

## Respawns character at spawn point with protection and visual effects.
func respawn() -> void:
	is_despawned = false
	respawn_timer = 0.0
	spawn_protection_timer = SPAWN_PROTECTION_DURATION
	
	# Get spawn position from manager
	var spawn_manager := character.get_tree().get_first_node_in_group("spawn_manager")
	if spawn_manager and spawn_manager.has_method("get_spawn_position_for"):
		spawn_position = spawn_manager.get_spawn_position_for(character)
	
	character.global_position = spawn_position
	character.velocity = Vector2.ZERO
	
	# Restore collision shape
	if shape_alive:
		shape_alive.disabled = false
	
	# Show character
	character.visible = true
	
	# Enable world collision (character collision handled by protection timer)
	character.set_collision_mask_value(1, true)
	character.set_collision_layer_value(2, false)
	character.set_collision_mask_value(2, false)

func _spawn_gravestone() -> void:
	var gravestone := GRAVESTONE_SCENE.instantiate()
	gravestone.global_position = character.global_position
	
	var level := character.get_tree().current_scene
	if level:
		level.add_child(gravestone)

## Returns character's foot position for spawn point calculations.
func get_foot_position() -> Vector2:
	var foot_offset: float = character.get("foot_offset")
	if foot_offset == null:
		foot_offset = 14.0
	return character.global_position + Vector2(0, foot_offset)
