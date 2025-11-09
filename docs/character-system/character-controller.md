# Character Controller

The `CharacterController` is the main orchestrator for all character behavior. It coordinates the physics, visuals, and lifecycle components and manages character identity.

**Script**: `res://scripts/characters/character_controller.gd`  
**Base Class**: `CharacterBody2D`  
**Class Name**: `CharacterController`

## Overview

The Character Controller acts as the "brain" of the character, coordinating:
- **CharacterPhysics** - Movement and physics
- **CharacterVisuals** - Animations and visual effects
- **CharacterLifecycle** - Death, respawn, and scoring

It doesn't implement movement or animation logic directly; instead, it delegates to specialized components.

## Architecture

```
CharacterController (CharacterBody2D)
│
├── physics: CharacterPhysics
│   └── Handles movement, jumping, gravity
│
├── visuals: CharacterVisuals
│   └── Handles animations, sprites, visual effects
│
└── lifecycle: CharacterLifecycle
    └── Handles death, respawn, scoring
```

## Properties

### Exported Properties

```gdscript
@export var is_player: bool = false
@export var character_color: Color = Color.WHITE
@export var character_asset_name: String = ""
@export var foot_offset: float = 14.0
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| **is_player** | bool | false | If true, uses player input; if false, expects AI input |
| **character_color** | Color | WHITE | Tint color (NPCs get unique colors) |
| **character_asset_name** | String | "" | Character name ("tux", "beasty", "gopher") |
| **foot_offset** | float | 14.0 | Vertical offset to foot position for spawn calculations |

### Component References

```gdscript
var physics: CharacterPhysics
var visuals: CharacterVisuals
var lifecycle: CharacterLifecycle
```

These are initialized in `_ready()` and provide access to component functionality.

### State Properties

```gdscript
var is_despawned: bool  # Property that proxies to lifecycle.is_despawned
```

## Initialization

### _ready() Flow

```gdscript
func _ready():
	# 1. Create components
	physics = CharacterPhysics.new(self)
	visuals = CharacterVisuals.new(self)
	lifecycle = CharacterLifecycle.new(self)
	
	# 2. Initialize components
	lifecycle.initialize()  # Sets up collision shapes, spawn position
	visuals.initialize()    # Sets up animated sprite reference
	
	# 3. Setup groups
	add_to_group("characters")
	if is_player:
		add_to_group("players")
	
	# 4. Register with game state
	GameStateManager.register_character(self)
	
	# 5. Set rendering
	z_index = 10  # Characters render on top
	
	# 6. Apply character color
	# (Color rect node if exists)
	
	# 7. Set initial facing direction
	visuals.face_towards_screen_center()
```

## Physics Process

The controller orchestrates all updates in `_physics_process()`:

```gdscript
func _physics_process(delta: float) -> void:
	# 1. Update lifecycle (respawn timer, spawn protection)
	if not lifecycle.update_lifecycle(delta):
		return  # Don't process physics while despawned
	
	# 2. Update spawn animation
	visuals.update_spawn_animation(delta)
	
	# 3. Update physics (movement, gravity, collisions)
	var previous_velocity_y := physics.update_physics(delta, is_player)
	
	# 4. Update animations
	visuals.update_animation(is_on_floor(), velocity)
	
	# 5. Check for character collisions (stomps)
	_check_character_collisions(previous_velocity_y)
```

**Flow**:
1. **Lifecycle** - Checks if character should respawn, manages spawn protection
2. **Spawn Animation** - Updates fade-in/scale effects after respawn
3. **Physics** - Processes input, applies movement, gravity, collision
4. **Visuals** - Updates animation state based on velocity/grounding
5. **Collision** - Checks for stomps after physics is resolved

## Key Functions

### load_character_animations()

Loads sprite frames for a specific character:

```gdscript
func load_character_animations(character_name: String) -> void
```

**Parameters**:
- `character_name`: Character ID ("tux", "beasty", "gopher")

**Usage**:
```gdscript
character.load_character_animations("tux")
```

This delegates to `visuals.load_animations()` which uses `AnimationCache` to load preloaded sprite frames.

### set_ai_inputs()

Sets AI-controlled input for the next physics frame:

```gdscript
func set_ai_inputs(move_direction: float, jump_pressed: bool, jump_released: bool, drop_pressed: bool) -> void
```

**Parameters**:
- `move_direction`: -1.0 (left), 0.0 (none), 1.0 (right)
- `jump_pressed`: Jump button pressed this frame
- `jump_released`: Jump button released this frame (for variable jump)
- `drop_pressed`: Drop-through platform button pressed

**Usage** (by CPUController):
```gdscript
character.set_ai_inputs(1.0, true, false, false)  # Move right and jump
```

This delegates to `physics.set_ai_inputs()`.

### despawn()

Despawns the character (death):

```gdscript
func despawn(killer: CharacterController = null) -> void
```

**Parameters**:
- `killer`: The character who stomped this character (optional)

**Effects**:
- Sets `is_despawned = true`
- Spawns gravestone at death position
- Hides character and disables collision
- Emits `character_killed` event (if killer provided)
- Starts 2-second respawn timer

**Usage**:
```gdscript
character.despawn(stomper)  # Killed by stomper
character.despawn()          # Generic death
```

### respawn()

Respawns the character at a spawn point:

```gdscript
func respawn() -> void
```

**Effects**:
- Gets new spawn position from SpawnManager
- Teleports character to spawn point
- Grants 1 second of spawn protection (no character collision)
- Starts spawn animation (fade-in, scale, flash)
- Resets velocity
- Re-enables collision shapes

**Called automatically** by lifecycle component after 2-second delay.

### get_foot_position()

Returns the character's foot position (used for spawn point selection):

```gdscript
func get_foot_position() -> Vector2
```

**Returns**: World position of character's feet

**Usage**:
```gdscript
var foot_pos := character.get_foot_position()
var closest_node := navigation.find_closest_node(foot_pos)
```

## Collision Detection

### _check_character_collisions()

Checks all character-to-character collisions for stomps:

```gdscript
func _check_character_collisions(previous_velocity_y: float) -> void
```

**Logic**:
1. Iterate through all slide collisions from `move_and_slide()`
2. Check if collider is another character
3. Determine collision type based on normal vector and velocity:

**Stomp** (we kill them):
- Normal points up (`normal.y < -0.6`)
- We were falling (`previous_velocity_y > 0`)
- **Effect**: Other character dies, we bounce up

**Head Bonk** (they kill us):
- Normal points down (`normal.y > 0.6`)
- We were jumping (`previous_velocity_y < 0`)
- **Effect**: We die, they get credit

**Side Collision**:
- Normal is horizontal (`abs(normal.x) dominant`)
- **Effect**: Nothing (characters bump off each other)

### Stomp Detection Details

**Why use previous_velocity_y?**

After `move_and_slide()`, the velocity may have already been modified by collision response. We need the velocity **before** collision to determine if we were actually falling/jumping.

**Example**:
```gdscript
var previous_velocity_y := velocity.y  # Save before move_and_slide()
move_and_slide()                       # Velocity may change here
_check_character_collisions(previous_velocity_y)  # Use saved value
```

## Character Groups

Characters are automatically added to groups:

```gdscript
add_to_group("characters")      # All characters
if is_player:
	add_to_group("players")      # Player characters only
```

**Usage**:
```gdscript
# Get all characters
var characters := get_tree().get_nodes_in_group("characters")

# Get all players
var players := get_tree().get_nodes_in_group("players")
```

## Character Identity

### Player vs NPC

The `is_player` property determines input source:

**Player** (`is_player = true`):
- Uses `InputManager` for input
- Controlled by human player
- No CPUController component

**NPC** (`is_player = false`):
- Uses AI input via `set_ai_inputs()`
- Controlled by CPUController
- Has CPUController child node

### Character Colors

NPCs are assigned unique colors for differentiation:

```gdscript
# In SpawnManager
var color_index := i % CPU_COLORS.size()
npc.character_color = CPU_COLORS[color_index]
sprite.modulate = CPU_COLORS[color_index]
```

**Color Palette** (8 colors):
- White, Dark Gray, Blue, Green, Yellow, Orange, Purple, Cyan

## Game State Integration

Characters register with `GameStateManager` on spawn:

```gdscript
GameStateManager.register_character(self)
```

This allows:
- Global character tracking
- Score management
- Game over detection (all players dead)

## Rendering

Characters render on **z-index 10** (above tiles):

```gdscript
z_index = 10  # Set in _ready()
```

**Layer Order**:
- **10**: Characters (always on top)
- **0**: Tiles (GroundTileMap, SemisolidTileMap)
- **-10**: Decorations (DecorationTileMap)

## Events

The controller emits events via components (primarily lifecycle):

**Emitted Events**:
```gdscript
EventBus.character_killed.emit(killer, victim)  # When stomped
```

**Listened Events**: None (components may listen)

See [Event Bus](../core-systems/event-bus.md) for all events.

## Usage Examples

### Creating a Player Character

```gdscript
var player := PLAYER_SCENE.instantiate()
player.global_position = spawn_point.global_position
player.load_character_animations("tux")
add_child(player)
```

### Creating an NPC Character

```gdscript
var npc := NPC_SCENE.instantiate()
npc.global_position = spawn_point.global_position
npc.load_character_animations("beasty")
npc.character_color = Color.BLUE
add_child(npc)

# NPC's CPUController will automatically start controlling it
```

### Manual Respawn

```gdscript
character.despawn()  # Kill character
# Wait 2 seconds...
# character.respawn() is called automatically by lifecycle
```

### Get All Living Characters

```gdscript
var living_chars: Array[CharacterController] = []
for node in get_tree().get_nodes_in_group("characters"):
	var char := node as CharacterController
	if char and not char.is_despawned:
		living_chars.append(char)
```

## Debugging

### Common Issues

**Character doesn't respond to input**:
- Check `is_player` is set correctly
- For NPCs, verify CPUController exists and is calling `set_ai_inputs()`
- Check that physics component is initialized

**Character falls through floor**:
- Verify collision shape exists and is enabled
- Check collision mask includes layer 1 (world tiles)
- Ensure `move_and_slide()` is being called

**Stomps don't work**:
- Check collision mask includes layer 2 (characters)
- Verify `_check_character_collisions()` is being called
- Check that `previous_velocity_y` is passed correctly

### Debug Information

```gdscript
print("Character State:")
print("  Position: ", character.global_position)
print("  Velocity: ", character.velocity)
print("  On Floor: ", character.is_on_floor())
print("  Despawned: ", character.is_despawned)
print("  Is Player: ", character.is_player)
```

## Performance Considerations

- **Component creation**: Components are created once in `_ready()`, not every frame
- **Group management**: Characters are added to groups once, not repeatedly
- **Collision checking**: Only checks collisions that actually happened (`get_slide_collision_count()`)
- **Spawn animation**: Minimal overhead, only runs during spawn fade-in

## Related Documentation

- **[Physics Component](physics-component.md)** - Movement and jumping
- **[Visuals Component](visuals-component.md)** - Animations
- **[Lifecycle Component](lifecycle-component.md)** - Death and respawn
- **[CPU AI](cpu-ai.md)** - NPC artificial intelligence
- **[Character System Overview](README.md)** - Overall architecture

---

**See Also**:
- [character_controller.gd](../../scripts/characters/character_controller.gd) - Full source code
- [Game Constants](../../scripts/core/game_constants.gd) - Physics values
- [Event Bus](../../scripts/core/event_bus.gd) - Event system

