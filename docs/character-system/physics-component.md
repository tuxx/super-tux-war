# Character Physics Component

The `CharacterPhysics` component handles all character movement, jumping, gravity, and physics interactions. It implements Super Mario War-style platformer physics with variable jump height.

**Script**: `res://scripts/characters/components/character_physics.gd`  
**Class Name**: `CharacterPhysics`

## Overview

This component is responsible for:
- Horizontal movement (acceleration, deceleration, friction)
- Jumping with variable height
- Gravity and falling
- Coyote time (grace period after leaving ground)
- Jump buffering (early jump input)
- One-way platform (semisolid) drop-through
- Ice physics (planned, not yet implemented)

## Architecture

The physics component is owned by `CharacterController` and operates on the controller's `velocity` and collision state.

```
CharacterController (CharacterBody2D)
│
└── CharacterPhysics
    ├── Processes input (player or AI)
    ├── Updates velocity
    ├── Applies gravity
    └── Calls move_and_slide()
```

## Properties

### Core References

```gdscript
var character: CharacterBody2D  # Reference to owning character
```

### Physics Constants

All constants are defined in `GameConstants`:

```gdscript
# Horizontal Movement
const PLAYER_ACCEL: float = 30.0
const PLAYER_MAX_WALK_SPEED: float = 240.0
const PLAYER_MAX_RUN_SPEED: float = 330.0
const FRICTION_GROUND: float = 12.0
const FRICTION_AIR: float = 3.6

# Vertical Movement
const JUMP_VELOCITY: float = -540.0     # px/s (upward is negative)
const GRAVITY: float = 1440.0           # px/s²
const MAX_FALL_SPEED: float = 1200.0    # px/s (terminal velocity)
const JUMP_EARLY_CLAMP: float = -300.0  # px/s (variable jump minimum)

# Feel/Polish
const COYOTE_TIME: float = 0.10         # seconds
const JUMP_BUFFER_TIME: float = 0.10    # seconds
```

### Ice Physics (Not Yet Implemented)

Constants defined but not currently used:

```gdscript
const PLAYER_ACCEL_ICE: float = 7.5     # 25% of normal acceleration
const FRICTION_ICE: float = 3.6         # 30% of normal friction
```

**Status**: Ice blocks exist visually, but the physics behavior is not implemented. Detecting ice tiles and applying these constants is planned for a future update.

### State Variables

```gdscript
# Jump mechanics
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var can_variable_jump: bool = false
var jump_velocity: float = JUMP_VELOCITY

# One-way platform drop
var is_dropping_through: bool = false
var drop_through_timer: float = 0.0
const DROP_THROUGH_DURATION: float = 0.2

# AI input (when not player)
var ai_move_direction: float = 0.0
var ai_jump_pressed: bool = false
var ai_jump_released: bool = false
var ai_drop_pressed: bool = false
```

## Movement System

### Horizontal Movement

#### Acceleration

When moving left/right:

```gdscript
velocity.x += move_direction * PLAYER_ACCEL * delta
```

- `move_direction`: -1.0 (left), 0.0 (none), 1.0 (right)
- Acceleration is constant (not velocity-dependent)
- Same acceleration whether starting from rest or changing direction

#### Speed Limits

```gdscript
velocity.x = clampf(velocity.x, -PLAYER_MAX_RUN_SPEED, PLAYER_MAX_RUN_SPEED)
```

- Walk speed: 240 px/s (7.5 tiles/sec)
- Run speed: 330 px/s (10.3 tiles/sec)
- Currently no distinction between walk/run (always uses run speed)

#### Friction

When no input or on ground:

```gdscript
var friction := FRICTION_GROUND if is_on_floor() else FRICTION_AIR
velocity.x = move_toward(velocity.x, 0, friction * delta)
```

- **Ground friction**: 12.0 px/s² (quick stop)
- **Air friction**: 3.6 px/s² (30% of ground, allows air control)

**Behavior**:
- Player stops quickly when releasing movement
- Some air control maintained while jumping

### Vertical Movement

#### Gravity

Applied every frame when not on ground:

```gdscript
if not character.is_on_floor():
	velocity.y += GameConstants.GRAVITY * delta
	velocity.y = min(velocity.y, GameConstants.MAX_FALL_SPEED)
```

- Gravity: 1440 px/s² (constant downward acceleration)
- Terminal velocity: 1200 px/s (max fall speed)

#### Jump

Jump is initiated when:
1. Jump input pressed
2. Character is on floor OR coyote time active

```gdscript
if jump_pressed and (_can_jump() or coyote_timer > 0.0):
	velocity.y = jump_velocity
	can_variable_jump = true
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
```

- Initial velocity: -540 px/s (upward)
- Jump height: ~2-3 tiles
- Can jump slightly after leaving ledge (coyote time)

#### Variable Jump Height

**Short Hop** - Release jump early:

```gdscript
if jump_released and can_variable_jump and velocity.y < JUMP_EARLY_CLAMP:
	velocity.y = JUMP_EARLY_CLAMP
	can_variable_jump = false
```

- Releasing jump button cuts upward velocity
- Minimum: -300 px/s (prevents instant drop)
- Allows short hops vs full jumps

**Behavior**:
- Hold jump: Full height (~2-3 tiles)
- Tap jump: Short hop (~1-1.5 tiles)

### Coyote Time

Grace period after walking off a ledge:

```gdscript
if character.is_on_floor():
	coyote_timer = GameConstants.COYOTE_TIME
else:
	coyote_timer = max(0.0, coyote_timer - delta)
```

- Duration: 0.1 seconds (6 frames at 60fps)
- Allows jump shortly after leaving platform
- Feels more forgiving and responsive

### Jump Buffering

Allows jump input before landing:

```gdscript
if jump_pressed:
	jump_buffer_timer = GameConstants.JUMP_BUFFER_TIME

if character.is_on_floor() and jump_buffer_timer > 0.0:
	# Execute buffered jump
	velocity.y = jump_velocity
	jump_buffer_timer = 0.0
```

- Duration: 0.1 seconds
- Jump input remembered for brief window
- Automatically executes on landing
- Prevents missed jumps due to timing

## One-Way Platforms (Semisolids)

### Drop Through

When pressing Down+Jump on a semisolid platform:

```gdscript
if is_on_floor() and drop_pressed:
	is_dropping_through = true
	drop_through_timer = DROP_THROUGH_DURATION
```

**Effect**:
- Disables collision with semisolid layer (layer 2)
- Duration: 0.2 seconds
- Allows character to fall through platform

**Implementation**:
```gdscript
character.set_collision_mask_value(2, not is_dropping_through)
```

### Jump Through

Automatically handled by Godot's one-way collision:
- Semisolid tiles have one-way collision enabled
- Characters pass through from below/sides
- Land on top surface automatically

## Input Processing

### Player Input

Reads from Godot `Input`:

```gdscript
var move_direction: float = 0.0
if Input.is_action_pressed("move_left"):
	move_direction -= 1.0
if Input.is_action_pressed("move_right"):
	move_direction += 1.0

var jump_pressed := Input.is_action_just_pressed("jump")
var jump_released := Input.is_action_just_released("jump")
var drop_pressed := Input.is_action_just_pressed("drop")
```

**Input Actions** (from `project.godot`):
- `move_left`: A, Left Arrow
- `move_right`: D, Right Arrow
- `jump`: Space, W, Up Arrow
- `drop`: S, Down Arrow (only works with jump)

### AI Input

Set by CPUController via `set_ai_inputs()`:

```gdscript
func set_ai_inputs(move_dir: float, jump: bool, jump_release: bool, drop: bool) -> void:
	ai_move_direction = move_dir
	ai_jump_pressed = jump
	ai_jump_released = jump_release
	ai_drop_pressed = drop
```

AI inputs are processed identically to player inputs.

## Physics Update Loop

Called by CharacterController in `_physics_process()`:

```gdscript
func update_physics(delta: float, is_player: bool) -> float:
	# 1. Save velocity before movement
	var previous_velocity_y := character.velocity.y
	
	# 2. Get input (player or AI)
	var input := _get_input(is_player)
	
	# 3. Apply horizontal movement
	_apply_horizontal_movement(input["move_direction"], delta)
	
	# 4. Apply vertical movement (gravity, jump)
	_apply_vertical_movement(input["jump_pressed"], input["jump_released"], delta)
	
	# 5. Handle drop-through platforms
	_handle_drop_through(input["drop_pressed"], delta)
	
	# 6. Update timers
	_update_timers(delta)
	
	# 7. Move character with collision
	character.move_and_slide()
	
	# 8. Return previous velocity for stomp detection
	return previous_velocity_y
```

**Returns**: Previous Y velocity (for stomp detection in controller)

## Ice Physics (Planned)

When implemented, ice tiles will modify physics:

### Detection (Planned)

```gdscript
func _is_on_ice() -> bool:
	# Raycast or tile check
	# Check if standing tile has ice flag
	return false  # Not yet implemented
```

### Modified Physics (Planned)

```gdscript
var accel := PLAYER_ACCEL_ICE if on_ice else PLAYER_ACCEL
var friction := FRICTION_ICE if on_ice else FRICTION_GROUND
```

**Expected Behavior**:
- **Reduced acceleration**: 7.5 px/s² (25% of normal) - slower speed changes
- **Reduced friction**: 3.6 px/s² (30% of normal) - slides when stopping
- **Maintained speed**: Momentum preserved longer
- **Fun challenge**: Requires careful movement control

**Implementation TODO**:
1. Detect ice tiles (raycast or tile data query)
2. Apply ice constants when on ice
3. Add visual feedback (sparkle particles, slide sounds)

## Usage Examples

### Basic Movement

```gdscript
# Handled automatically by CharacterController
# Player: Input from keyboard/gamepad
# NPC: Input from CPUController
```

### Force a Jump (Bounce)

```gdscript
# After stomping enemy
character.velocity.y = physics.jump_velocity * 0.5  # Half-height bounce
```

### Stop Character

```gdscript
character.velocity = Vector2.ZERO
```

### Teleport Character

```gdscript
character.global_position = target_position
character.velocity = Vector2.ZERO  # Reset velocity to avoid weird physics
```

## Tuning Physics

All constants can be modified in `GameConstants.gd`:

### Making Jumps Higher

```gdscript
const JUMP_VELOCITY: float = -600.0  # More negative = higher
```

### Making Movement Faster

```gdscript
const PLAYER_MAX_RUN_SPEED: float = 400.0  # Higher = faster
const PLAYER_ACCEL: float = 40.0           # Higher = faster acceleration
```

### Making Movement More Floaty

```gdscript
const GRAVITY: float = 1200.0  # Lower = more floaty
```

### Making Movement More Responsive

```gdscript
const FRICTION_GROUND: float = 20.0  # Higher = quicker stops
const PLAYER_ACCEL: float = 50.0     # Higher = faster response
```

## Performance Considerations

- **No allocations**: Physics code doesn't allocate memory in hot path
- **Cached references**: Character reference cached at construction
- **Simple math**: All operations are basic arithmetic (no trig, sqrt, etc.)
- **Efficient**: Runs 60 times per second for up to 8 characters without issues

## Debugging

### Common Issues

**Character doesn't move**:
- Check input is being received (`print(move_direction)`)
- Verify `update_physics()` is being called
- Check collision mask allows world collision

**Jumps feel wrong**:
- Adjust `JUMP_VELOCITY` (more negative = higher)
- Adjust `GRAVITY` (higher = falls faster)
- Tune `COYOTE_TIME` and `JUMP_BUFFER_TIME` for feel

**Can't drop through platforms**:
- Verify platform is on collision layer 2
- Check platform has one-way collision enabled
- Ensure `drop` input is being pressed with `jump`

### Debug Information

```gdscript
print("Physics State:")
print("  Velocity: ", character.velocity)
print("  On Floor: ", character.is_on_floor())
print("  Coyote Timer: ", coyote_timer)
print("  Jump Buffer: ", jump_buffer_timer)
print("  Can Variable Jump: ", can_variable_jump)
print("  Dropping Through: ", is_dropping_through)
```

## Related Documentation

- **[Character Controller](character-controller.md)** - Main controller
- **[Game Constants](../../scripts/core/game_constants.gd)** - Physics values
- **[Level Design](../level-design/README.md)** - Level design for physics
- **[Character System Overview](README.md)** - Overall architecture

---

**See Also**:
- [character_physics.gd](../../scripts/characters/components/character_physics.gd) - Full source code
- [Super Mario War Physics](http://supermariowar.supersanctuary.net/) - Inspiration

