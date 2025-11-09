# Character Lifecycle Component

The `CharacterLifecycle` component handles character death, respawn, spawn protection, and gravestone spawning.

**Script**: `res://scripts/characters/components/character_lifecycle.gd`  
**Class Name**: `CharacterLifecycle`

## Overview

This component manages the character's life cycle:
- **Death** - When stomped, spawn gravestone and hide character
- **Respawn Timer** - 2-second delay before respawn
- **Respawn** - Get new spawn point and respawn with protection
- **Spawn Protection** - 1-second invulnerability after respawn

## Properties

### Core References

```gdscript
var character: CharacterBody2D
var shape_alive: CollisionShape2D
```

### State Variables

```gdscript
var is_despawned: bool = false
var spawn_position: Vector2
var respawn_timer: float = 0.0
var spawn_protection_timer: float = 0.0
```

### Constants

```gdscript
const RESPAWN_TIME: float = 2.0
const SPAWN_PROTECTION_DURATION: float = 1.0
const GRAVESTONE_SCENE = preload("res://scenes/objects/gravestone.tscn")
```

## Life Cycle States

### Alive

**State**: `is_despawned = false`

**Properties**:
- Visible and active
- Collision enabled
- Processes physics normally
- Can be stomped

**May have spawn protection** (first 1 second after respawn):
- No character-to-character collision (can't be stomped)
- Still collides with world
- Visual feedback (handled by visuals component)

### Despawned (Dead)

**State**: `is_despawned = true`

**Properties**:
- Hidden (`visible = false`)
- Collision disabled
- Physics not processed
- Respawn timer counting down (2 seconds)
- Gravestone spawned at death location

## Functions

### initialize()

Called once during character setup:

```gdscript
func initialize() -> void:
	spawn_position = character.global_position
	shape_alive = character.get_node_or_null("CollisionShape2D")
	
	if shape_alive:
		shape_alive.disabled = false
```

**Purpose**: Cache references and set initial spawn position.

### update_lifecycle()

Called every frame by CharacterController:

```gdscript
func update_lifecycle(delta: float) -> bool
```

**Returns**: `true` if should continue processing physics, `false` if despawned

**Responsibilities**:

1. **If despawned**: Update respawn timer
   ```gdscript
   respawn_timer += delta
   if respawn_timer >= RESPAWN_TIME:
	   respawn()
   return false  # Don't process physics
   ```

2. **If spawn protected**: Update protection timer and disable character collision
   ```gdscript
   spawn_protection_timer -= delta
   if spawn_protection_timer > 0.0:
	   # Disable character-to-character collision (layer 2)
	   character.set_collision_layer_value(2, false)
	   character.set_collision_mask_value(2, false)
   else:
	   # Restore normal collision
	   character.set_collision_layer_value(2, true)
	   character.set_collision_mask_value(2, true)
   ```

3. **Return**: `true` to continue physics processing

### despawn()

Kills the character:

```gdscript
func despawn(killer: CharacterController = null) -> void
```

**Parameters**:
- `killer`: Character who caused the death (optional)

**Process**:

1. **Check already despawned**:
   ```gdscript
   if is_despawned:
	   return  # Don't despawn twice
   ```

2. **Set state**:
   ```gdscript
   is_despawned = true
   respawn_timer = 0.0
   character.velocity = Vector2.ZERO
   ```

3. **Emit kill event** (if killer provided):
   ```gdscript
   if killer and killer != character:
	   EventBus.character_killed.emit(killer, character)
   ```

4. **Spawn gravestone**:
   ```gdscript
   _spawn_gravestone()
   ```

5. **Hide and disable collision**:
   ```gdscript
   character.visible = false
   character.set_collision_layer_value(2, false)  # Character layer
   character.set_collision_mask_value(1, false)   # World layer
   character.set_collision_mask_value(2, false)   # Character layer
   shape_alive.disabled = true
   ```

**Effects**:
- Character becomes invisible
- Stops colliding with everything
- Gravestone spawns and falls
- 2-second respawn timer starts

### respawn()

Brings character back to life:

```gdscript
func respawn() -> void
```

**Process**:

1. **Reset state**:
   ```gdscript
   is_despawned = false
   respawn_timer = 0.0
   spawn_protection_timer = SPAWN_PROTECTION_DURATION
   ```

2. **Get new spawn position**:
   ```gdscript
   var spawn_manager := character.get_tree().get_first_node_in_group("spawn_manager")
   if spawn_manager and spawn_manager.has_method("get_spawn_position_for"):
	   spawn_position = spawn_manager.get_spawn_position_for(character)
   ```

3. **Teleport to spawn**:
   ```gdscript
   character.global_position = spawn_position
   character.velocity = Vector2.ZERO
   ```

4. **Re-enable collision**:
   ```gdscript
   shape_alive.disabled = false
   character.visible = true
   character.set_collision_mask_value(1, true)  # World collision
   # Character collision disabled temporarily (spawn protection)
   character.set_collision_layer_value(2, false)
   character.set_collision_mask_value(2, false)
   ```

**Effects**:
- Character teleports to spawn point
- Becomes visible again
- Collides with world but not characters (protection)
- Spawn animation begins (handled by visuals component)

### get_foot_position()

Returns character's foot position:

```gdscript
func get_foot_position() -> Vector2:
	var foot_offset: float = character.get("foot_offset") or 14.0
	return character.global_position + Vector2(0, foot_offset)
```

**Used by**:
- SpawnManager for spawn point selection
- CPUController for navigation node matching

## Gravestone System

### _spawn_gravestone()

Spawns a gravestone at death location:

```gdscript
func _spawn_gravestone() -> void:
	var gravestone := GRAVESTONE_SCENE.instantiate()
	gravestone.global_position = character.global_position
	
	var level := character.get_tree().current_scene
	if level:
		level.add_child(gravestone)
```

**Gravestone Behavior**:
- Spawns at exact death position
- Falls due to gravity (RigidBody2D)
- Collides with world only (not characters)
- Despawns automatically after 10 seconds
- Visual marker of death location

See [gravestone.gd](../../scripts/objects/gravestone.gd) for implementation.

## Spawn Protection

### Purpose

Prevents spawn camping - characters can't be stomped immediately after respawning.

### Duration

1 second (60 frames at 60fps)

### Implementation

**Collision Layers**:
- **Layer 1**: World tiles (walls, floors)
- **Layer 2**: Characters

**During Protection**:
```gdscript
character.set_collision_layer_value(2, false)  # Don't appear to other characters
character.set_collision_mask_value(2, false)   # Don't collide with other characters
```

**After Protection**:
```gdscript
character.set_collision_layer_value(2, true)   # Appear to other characters
character.set_collision_mask_value(2, true)    # Collide with other characters
```

### Visual Feedback

Spawn protection is indicated by spawn animation (fade-in, scale, flash) handled by `CharacterVisuals`.

## Respawn Flow

Complete sequence from death to respawn:

1. **Character is stomped** → `despawn(killer)` called
2. **Gravestone spawns** at death location
3. **Character hides** and disables collision
4. **2-second timer** counts down
5. **New spawn point selected** by SpawnManager
6. **Character teleports** to spawn point
7. **Spawn animation starts** (visuals component)
8. **1-second protection** prevents stomps
9. **Protection ends** → normal gameplay resumes

**Total Downtime**: 3 seconds (2s dead + 1s protected)

## Events

### Emitted

**character_killed**:
```gdscript
EventBus.character_killed.emit(killer, victim)
```

**When**: Character is stomped by another character

**Parameters**:
- `killer`: CharacterController who stomped
- `victim`: CharacterController who died

### Listened

None directly (CharacterController listens and calls lifecycle methods)

## Integration with Other Components

### CharacterController

**Uses lifecycle for**:
- Checking if despawned (`character.is_despawned`)
- Calling `despawn()` when stomped
- Calling `respawn()` after timer
- Updating lifecycle every frame

### CharacterVisuals

**Uses lifecycle for**:
- Starting spawn animation on respawn
- Showing/hiding character

### CPUController

**Uses lifecycle for**:
- Checking if character is valid target (`not target.is_despawned`)
- Pausing AI when despawned

## Collision Configuration

### Alive (No Protection)

```
Collision Layer: [1: world, 2: characters]
Collision Mask:  [1: world, 2: characters]
```
- Collides with world and characters
- Can be stomped

### Alive (With Protection)

```
Collision Layer: [1: world]
Collision Mask:  [1: world]
```
- Collides with world only
- Cannot be stomped (invisible to other characters)

### Despawned

```
Collision Layer: []
Collision Mask:  []
Shape: disabled
```
- No collision at all
- Invisible

## Usage Examples

### Manual Despawn

```gdscript
# Kill character without killer credit
character.despawn()

# Kill character with killer credit
character.despawn(killer_character)
```

### Check if Alive

```gdscript
if not character.is_despawned:
	# Character is alive, can interact
	pass
```

### Force Immediate Respawn

```gdscript
character.lifecycle.respawn_timer = RESPAWN_TIME  # Set timer to max
# On next frame, character will respawn
```

### Get Spawn Protection Status

```gdscript
var is_protected := character.lifecycle.spawn_protection_timer > 0.0
```

## Debugging

### Common Issues

**Character doesn't respawn**:
- Check SpawnManager exists in scene
- Verify spawn points are configured
- Check respawn timer is counting up

**Character respawns in wrong place**:
- Check SpawnManager logic
- Verify spawn points are spread out
- Check `get_spawn_position_for()` implementation

**Spawn protection doesn't work**:
- Verify collision layers/masks are being set
- Check spawn_protection_timer is > 0
- Ensure update_lifecycle() is being called

### Debug Information

```gdscript
print("Lifecycle State:")
print("  Despawned: ", is_despawned)
print("  Respawn Timer: ", respawn_timer)
print("  Spawn Protection: ", spawn_protection_timer)
print("  Spawn Position: ", spawn_position)
```

## Performance Considerations

- **Gravestone pooling**: Not implemented, but could improve performance if many deaths occur
- **Respawn timer**: Simple float increment, very efficient
- **Collision updates**: Only happens at state changes, not every frame

## Related Documentation

- **[Character Controller](character-controller.md)** - Main controller
- **[Spawn Points](../level-design/spawn-points.md)** - Spawn system details
- **[Visuals Component](visuals-component.md)** - Spawn animation
- **[Event Bus](../core-systems/event-bus.md)** - Event system

---

**See Also**:
- [character_lifecycle.gd](../../scripts/characters/components/character_lifecycle.gd) - Full source code
- [gravestone.gd](../../scripts/objects/gravestone.gd) - Gravestone implementation
- [spawn_manager.gd](../../scripts/levels/spawn_manager.gd) - Spawn point selection

