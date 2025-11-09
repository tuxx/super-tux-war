# Character System

The character system implements player and NPC behavior using a component-based architecture. This guide covers how characters work, their components, and how to add new characters.

## Overview

Characters in Super Tux War are built using a modular component system:

- **CharacterController** - Main controller that coordinates components
- **CharacterPhysics** - Movement, jumping, and physics
- **CharacterVisuals** - Animations, sprites, and visual effects
- **CharacterLifecycle** - Death, respawn, scoring
- **CPUController** - AI for NPC characters (optional)

## Architecture

### Component-Based Design

Each character is a `CharacterBody2D` with the following structure:

```
PlayerCharacter (CharacterBody2D)
├── CharacterController (Node) [character_controller.gd]
│   ├── Physics (Node) [character_physics.gd]
│   ├── Visuals (Node) [character_visuals.gd]
│   └── Lifecycle (Node) [character_lifecycle.gd]
├── AnimatedSprite2D
├── CollisionShape2D
└── (other child nodes)
```

**For NPCs**, add an additional component:

```
NPCCharacter (CharacterBody2D)
├── CharacterController (Node)
│   ├── Physics (Node)
│   ├── Visuals (Node)
│   ├── Lifecycle (Node)
│   └── CPUController (Node) [cpu_controller.gd]  ← AI component
├── AnimatedSprite2D
├── CollisionShape2D
└── (other child nodes)
```

### Why Components?

**Benefits**:
- **Separation of concerns**: Each component handles one responsibility
- **Reusability**: Same components for players and NPCs
- **Maintainability**: Easy to modify one aspect without affecting others
- **Testability**: Components can be tested independently
- **Flexibility**: Easy to add new behaviors or variations

## Character Scenes

### Player Character

**Scene**: `res://scenes/characters/player_character.tscn`  
**Script**: `res://scripts/characters/character_controller.gd`

```gdscript
extends CharacterBody2D
class_name CharacterController

@export var is_player: bool = true
```

### NPC Character

**Scene**: `res://scenes/characters/npc_character.tscn`  
**Script**: Uses same `character_controller.gd` with `is_player = false`

**Key Difference**: NPCs have a `CPUController` child node for AI.

## Component Details

### 1. CharacterController (Main)

**Purpose**: Coordinates all components and manages the character as a whole

**Responsibilities**:
- Routes input (player or AI) to components
- Manages component references
- Handles character color/identity
- Loads character animations
- Processes physics and visual updates

**Key Properties**:
```gdscript
@export var is_player: bool = true
var character_color: Color = Color.WHITE
var is_despawned: bool = false
```

**Key Functions**:
```gdscript
func set_ai_inputs(move_dir: float, jump: bool, jump_release: bool, drop: bool)
func load_character_animations(character_name: String)
func get_foot_position() -> Vector2
```

See [character-controller.md](character-controller.md) for full details.

### 2. CharacterPhysics Component

**Purpose**: Handles movement, jumping, and physics interactions

**Responsibilities**:
- Horizontal movement (walk/run)
- Jumping with variable height
- Gravity and falling
- Ice physics (planned, not yet implemented)
- Coyote time and jump buffering

**Physics Values**: Defined in `GameConstants`
- Walk Speed: 240 px/s
- Run Speed: 330 px/s
- Jump Velocity: -540 px/s
- Gravity: 1440 px/s²

See [physics-component.md](physics-component.md) for full details.

### 3. CharacterVisuals Component

**Purpose**: Manages animations, sprite flipping, and visual presentation

**Responsibilities**:
- Animation state machine (idle, run, jump, fall)
- Sprite direction (facing left/right)
- Animation loading and caching
- Visual feedback

**Animations**:
- `idle` - Standing still
- `run` - Moving horizontally
- `jump` - Ascending
- `fall` - Descending

See [visuals-component.md](visuals-component.md) for full details.

### 4. CharacterLifecycle Component

**Purpose**: Handles death, respawn, and scoring

**Responsibilities**:
- Stomp detection (head-to-head collisions)
- Death handling and gravestone spawning
- Respawn after delay (2 seconds)
- Score tracking (kills)
- Event emission (character_died, character_killed, etc.)

**Stomp Mechanics**:
- Character above stomps character below
- Relative velocity check (must be moving down relative to target)
- Instant death for stomped character
- +1 kill for stomper

See [lifecycle-component.md](lifecycle-component.md) for full details.

### 5. CPUController Component (NPCs only)

**Purpose**: AI pathfinding and decision-making for NPC characters

**Responsibilities**:
- Target selection (closest character)
- Pathfinding using navigation graph
- Tactical behaviors (stomp attempts, danger avoidance)
- Edge execution (walk, jump, drop)
- Blocked state detection and recovery

**AI Behaviors**:
- **Direct Stomp**: Attempts to stomp nearby targets
- **Pathfinding**: Uses navigation graph to reach target platform
- **Danger Avoidance**: Dodge incoming stompers
- **Direct Chase**: Falls back to simple chase if no path found

See [cpu-ai.md](cpu-ai.md) for full details.

## Character Properties

### Common Properties

All characters have these properties:

```gdscript
# Identity
var is_player: bool           # Player-controlled or NPC
var character_color: Color    # Tint color (NPCs use unique colors)

# State
var is_despawned: bool        # Currently despawned (dead)
velocity: Vector2             # Current velocity (from CharacterBody2D)

# Physics (from CharacterPhysics)
var is_on_floor: bool         # Grounded state
var coyote_timer: float       # Grace period after leaving ground
var jump_buffer_timer: float  # Jump input buffering

# Lifecycle (from CharacterLifecycle)
var kills: int                # Number of stomps performed
```

### Character-Specific Properties

```gdscript
# Set via load_character_animations()
var character_name: String    # "tux", "beasty", "gopher"
```

## Available Characters

Currently implemented characters:

| Character | Name | Description | Status |
|-----------|------|-------------|--------|
| **Tux** | `"tux"` | Linux penguin mascot | ✅ Complete |
| **Beasty** | `"beasty"` | FreeBSD daemon | ✅ Complete (sprites need improvement) |
| **Gopher** | `"gopher"` | Go language mascot | ✅ Complete |

**Planned Characters** (see [CONTRIBUTING.md](../CONTRIBUTING.md)):
- OpenBSD Fish (Puffy)
- GIMP (Wilber)
- GNU
- Rust (Ferris)
- Python
- More open-source mascots

## Character Selection

### At Runtime

Characters are selected via `GameSettings` autoload:

```gdscript
# In game code
var player_char := GameSettings.get_player_character()  # Default: "tux"
var cpu_char := GameSettings.get_cpu_character()        # Default: "beasty"

# Load animations
character.load_character_animations(player_char)
```

### In UI

Players can select characters in the start menu:
- Click player character portrait to cycle through options
- Click CPU character portrait to cycle and adjust CPU count

## Adding a New Character

See **[adding-characters.md](adding-characters.md)** for a complete step-by-step guide.

**Quick Overview**:
1. Create sprite sheets (idle, run, jump)
2. Add to `assets/characters/[name]/spritesheets/`
3. Configure AnimatedSprite2D frames
4. Update `ResourcePaths.gd` with animation paths
5. Add to character selection UI
6. Test in-game

## Input System

### Player Input

Player input is handled by `InputManager` and routed through `CharacterController`:

```gdscript
func _physics_process(delta: float) -> void:
	if is_player:
		_handle_player_input()
	# Physics component processes the input
```

**Input Actions** (configured in `project.godot`):
- `move_left` / `move_right` - Horizontal movement
- `jump` - Jump / variable jump
- `drop` - Drop through semisolid platforms

### AI Input

AI input is generated by `CPUController` and set via:

```gdscript
character.set_ai_inputs(move_dir, jump_pressed, jump_released, drop_pressed)
```

The controller then routes this to the physics component identically to player input.

## Physics & Movement

### Movement Constants

Defined in `GameConstants`:

```gdscript
const PLAYER_ACCEL: float = 30.0
const PLAYER_MAX_WALK_SPEED: float = 240.0
const PLAYER_MAX_RUN_SPEED: float = 330.0
const FRICTION_GROUND: float = 12.0
const FRICTION_AIR: float = 3.6

const JUMP_VELOCITY: float = -540.0
const GRAVITY: float = 1440.0
const MAX_FALL_SPEED: float = 1200.0
const COYOTE_TIME: float = 0.10
const JUMP_BUFFER_TIME: float = 0.10
```

### Ice Physics (Not Yet Implemented)

Ice constants are defined but not currently in use:

```gdscript
const PLAYER_ACCEL_ICE: float = 7.5     # 25% of normal
const FRICTION_ICE: float = 3.6         # 30% of normal
```

**Status**: Ice blocks exist visually, but physics behavior is not yet implemented. When implemented, standing on ice tiles will reduce acceleration and friction for slippery movement.

### Collision

Characters use:
- **Collision Layer**: Layer 1 (characters)
- **Collision Mask**: Layer 0 (world) + Layer 1 (characters)
- **Collision Shape**: Capsule or rectangle (~30×30 px)

Characters collide with:
- World tiles (GroundTileMap, SemisolidTileMap)
- Other characters (for stomp detection)

Characters do NOT collide with:
- Gravestones (pass through)
- Despawned characters

## Events

Characters emit events via `EventBus`:

```gdscript
# Lifecycle events
EventBus.character_died.emit(character)
EventBus.character_killed.emit(killer, victim)
EventBus.character_respawned.emit(character)

# Listen to events
EventBus.character_died.connect(_on_character_died)
```

**Available Events**:
- `character_died(character)` - Character was stomped
- `character_killed(killer, victim)` - Character stomped another
- `character_respawned(character)` - Character respawned after death

See [event_bus.gd](../../scripts/core/event_bus.gd) for all events.

## Performance Considerations

### NPC Count

The game is tested with **1 player + 7 NPCs** (8 characters total).

**Performance Factors**:
- Physics calculations (8 characters × 60fps)
- AI pathfinding (~6.7 Hz per NPC)
- Collision detection (8 bodies)
- Animation updates

**Optimizations**:
- Character list caching (refreshed every 1 second)
- Pathfinding runs at reduced rate (6.7 Hz, not 60 Hz)
- Efficient navigation graph
- Minimal allocations in hot paths

### Recommendations

For good performance:
- Keep character count ≤ 10
- Use character caching for AI queries
- Avoid expensive operations in `_physics_process`
- Cache node references with `@onready`

## Debugging

### Dev Menu

Press **F11** to toggle navigation graph visualization.  
Press **F12** to toggle jump arc visualization.

### Useful Debug Info

```gdscript
# Character state
print("Position: ", character.global_position)
print("Velocity: ", character.velocity)
print("On Floor: ", character.is_on_floor())
print("Despawned: ", character.is_despawned)

# AI state (for NPCs)
print("Target: ", cpu_controller.target)
print("Plan: ", cpu_controller.current_plan)
print("Active Edge: ", cpu_controller.active_edge)
```

### Common Issues

**Character doesn't move**:
- Check that CharacterPhysics component exists
- Verify input is being received
- Check collision shape is present

**Animations don't play**:
- Verify AnimatedSprite2D node exists
- Check that animations are loaded
- Ensure CharacterVisuals component exists

**NPC doesn't navigate**:
- Check that CPUController exists (NPCs only)
- Verify LevelNavigation exists in scene
- Enable debug view to see navigation graph

## Next Steps

- **[Adding a Character](adding-characters.md)** - Create your own character
- **[Character Controller](character-controller.md)** - Main controller details
- **[Physics Component](physics-component.md)** - Movement system
- **[Visuals Component](visuals-component.md)** - Animation system
- **[Lifecycle Component](lifecycle-component.md)** - Death and respawn
- **[CPU AI](cpu-ai.md)** - NPC artificial intelligence

---

**Related Documentation**:
- [Game Constants](../../scripts/core/game_constants.gd) - Physics values
- [Event Bus](../../scripts/core/event_bus.gd) - Event system
- [Level Design](../level-design/README.md) - Creating levels for characters

