# SMW-Style Acceleration Physics Implementation

This document describes the Super Mario War-style momentum-based movement system implemented in TuxWars.

## Overview

The movement system has been upgraded from instant velocity to acceleration-based physics with friction, matching Super Mario War's feel. Characters now build up speed over time and slide when stopping, creating more dynamic and skill-based gameplay.

## Physics Parameters

### Acceleration (SMW: 0.5 px/frame → 30 px/s²)
- **Normal Ground**: 30 px/s² (`GameConstants.PLAYER_ACCEL`)
- **Ice Surface**: 7.5 px/s² (`GameConstants.PLAYER_ACCEL_ICE`)
- Takes ~8 frames to reach max speed from standstill on normal ground
- Takes ~32 frames on ice

### Maximum Speeds
- **Normal Walk**: 240 px/s (4.0 px/frame)
- **Turbo/Run**: 330 px/s (5.5 px/frame) - 37.5% faster
- **Slowdown**: 132 px/s (2.2 px/frame) - 55% of normal

### Friction/Deceleration
When no movement input is held:
- **Ground**: 12 px/s² - stops in ~20 frames from max speed
- **Ice**: 3.6 px/s² - stops in ~67 frames (slides far!)
- **Air**: 3.6 px/s² - minimal air control

## Implementation Details

### Core Files Modified

1. **`scripts/characters/components/character_physics.gd`**
   - Replaced instant velocity with `_apply_horizontal_movement()`
   - Added friction system via `_get_current_friction()`
   - Ice detection via `_detect_surface_type()`
   - Helper functions: `get_stopping_distance()` and `get_stopping_time()`

2. **`scripts/characters/cpu_controller.gd`**
   - Increased movement tolerances 4x to account for momentum:
     - `WALK_REACH_EPS`: 6.0 → 24.0
     - `ALIGNMENT_WINDOW`: 8.0 → 32.0
     - `LANDING_TOLERANCE`: 12.0 → 40.0
   - Added predictive braking via `_should_brake_for_target()`
   - AI now stops pressing movement keys early to hit precise positions

### Physics Component API

#### New Properties
```gdscript
# Speed modifiers (set externally for powerups)
var is_turbo_active: bool = false
var is_slowdown_active: bool = false

# Surface detection
var is_on_ice: bool = false
```

#### New Methods
```gdscript
# Get distance character will travel before stopping (pixels)
func get_stopping_distance() -> float

# Get time character will take to stop (seconds)
func get_stopping_time() -> float
```

### AI Behavior

The AI now uses **predictive stopping** to handle momentum:

1. **Stopping Distance Calculation**: AI calculates how far it will slide based on current velocity and friction
2. **Early Braking**: Stops pressing movement keys when `distance_to_target <= stopping_distance * 1.5`
3. **Increased Tolerances**: More forgiving position checks to avoid jittery behavior

Example from `_should_brake_for_target()`:
```gdscript
var stopping_distance := character.physics.get_stopping_distance()
var required_distance := stopping_distance * BRAKING_DISTANCE_MULTIPLIER  # 1.5x
return moving_towards and distance_to_target <= required_distance
```

## Ice Tile Detection

The system detects ice tiles via TileMap custom data:

1. Finds TileMap node in current scene
2. Checks tile at character's foot position
3. Reads `"is_ice"` custom data property
4. Applies ice physics when `true`

### Setting Up Ice Tiles

To make tiles slippery in Godot:

1. Open your TileSet in the TileMap editor
2. Select the ice tile
3. Add custom data layer named `"is_ice"` (type: Boolean)
4. Set value to `true` for ice tiles

## Turbo/Run Feature

Infrastructure is ready but not bound to input yet:

```gdscript
# In character_physics.gd
character.physics.is_turbo_active = true  # Enable turbo speed
character.physics.is_slowdown_active = true  # Enable slowdown effect
```

### Adding Turbo Input (Future)

To add turbo button support:

1. Add action to `InputManager._ensure_default_actions()`:
   ```gdscript
   _ensure_action("run")
   _add_key_if_missing("run", KEY_SHIFT)
   ```

2. Check in physics input handling:
   ```gdscript
   func _handle_player_input(delta: float) -> void:
       is_turbo_active = Input.is_action_pressed("run")
       # ... rest of input handling
   ```

## Testing the System

### Visual Differences You'll Notice

1. **Startup**: Characters gradually accelerate instead of instant speed
2. **Stopping**: Characters slide to a stop when you release movement keys
3. **Ice**: Extremely long slides on ice tiles (3.33x longer than normal)
4. **AI Movement**: NPCs approach platforms more carefully, brake early

### Testing Checklist

- [ ] Player accelerates smoothly from standstill
- [ ] Player slides when releasing movement keys
- [ ] Ice tiles cause extended sliding
- [ ] AI successfully navigates platforms without falling off
- [ ] AI can perform jumps at correct positions
- [ ] No jittery AI behavior (excessive direction changes)

### Tuning Parameters

If AI is too sloppy or too precise, adjust these constants in `cpu_controller.gd`:

```gdscript
# Make AI more precise (smaller values) or more relaxed (larger values)
const WALK_REACH_EPS := 24.0  # How close AI gets to walk targets
const ALIGNMENT_WINDOW := 32.0  # Jump preparation window
const BRAKING_DISTANCE_MULTIPLIER := 1.5  # Safety margin (1.0 = perfect, 2.0 = very early)
```

If physics feels too fast/slow, adjust in `game_constants.gd`:

```gdscript
const PLAYER_ACCEL: float = 30.0  # Higher = faster acceleration
const FRICTION_GROUND: float = 12.0  # Higher = stops faster
```

## Performance Notes

- Ice detection runs once per physics frame only when on floor (minimal cost)
- AI predictive braking adds one `get_stopping_distance()` call per decision
- Stopping distance calculation is simple kinematic math (no iteration)
- No performance regression expected

## Known Limitations

1. **Ice Detection**: Requires TileMap with custom data layer `"is_ice"`
   - Falls back to normal friction if TileMap not found
   - Only checks tile at exact foot position (not wider area)

2. **Turbo Mode**: Infrastructure exists but no input binding yet

3. **Air Acceleration**: Currently uses same acceleration as ground
   - Could be reduced for more "floaty" air control if desired

## Future Enhancements

- [ ] Add turbo button input binding
- [ ] Different air acceleration value
- [ ] Ice particle effects when sliding on ice
- [ ] Speed lines visual effect at high speeds
- [ ] Multiple friction zones (mud, conveyor belts, etc.)
- [ ] AI difficulty levels (adjusting tolerances)

## Conversion Reference

SMW runs at 60 FPS. To convert SMW values:

| SMW Value | Unit | Godot Value | Formula |
|-----------|------|-------------|---------|
| 0.5 | px/frame | 30 | × 60 |
| 4.0 | px/frame | 240 | × 60 |
| 0.2 | px/frame | 12 | × 60 |

For px/frame² (acceleration): multiply by 60² = 3600

