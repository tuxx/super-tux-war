class_name GameConstants

# Global constants for tile size, movement, and physics baselines (Phase 0)

# Tile and units
const TILE_SIZE: int = 32

# Player movement (horizontal) — px/s and px/s^2 at 60 fps
# Note: Accel/friction are px/frame² → multiply by 60² = 3600 to get px/s²
const PLAYER_ACCEL: float = 1800.0               # px/s^2 (0.5 px/frame² × 3600)
const PLAYER_ACCEL_ICE: float = 450.0            # px/s^2 (0.125 px/frame² × 3600)

const PLAYER_MAX_WALK_SPEED: float = 240.0       # px/s
const PLAYER_MAX_RUN_SPEED: float = 330.0        # px/s
const PLAYER_MAX_SLOW_SPEED: float = 132.0       # px/s
const PLAYER_TAGGED_BOOST: float = 60.0          # px/s added when tagged/boosted

# Friction/decay (also px/frame² → multiply by 60² = 3600)
const FRICTION_GROUND: float = 720.0             # px/s^2 (0.2 px/frame² × 3600)
const FRICTION_ICE: float = 216.0                # px/s^2 (0.06 px/frame² × 3600)
const FRICTION_AIR: float = 216.0                # px/s^2 (0.06 px/frame² × 3600)

# Player vertical (derived from classic per-frame values at 60 fps)
# 9.0 px/frame jump and 0.40 px/frame^2 gravity -> ~2–3 tile full jump
const JUMP_VELOCITY: float = -540.0              # px/s (normal)
const JUMP_VELOCITY_TURBO: float = -612.0        # px/s (deferred; turbo variant)
const JUMP_VELOCITY_SLOW: float = -420.0         # px/s (deferred; slowdown variant)

# Correct per-second gravity from 0.40 px/frame^2: 0.40 * 60^2 = 1440 px/s^2
const GRAVITY: float = 1440.0                    # px/s^2
const MAX_FALL_SPEED: float = 1200.0             # px/s (20 px/frame)

# Early release clamp for variable jump (optional usage)
const JUMP_EARLY_CLAMP: float = -300.0           # px/s (equivalent to 5 px/frame)

# Input/feel auxiliaries
const COYOTE_TIME: float = 0.10                  # seconds
const JUMP_BUFFER_TIME: float = 0.10             # seconds

# Item speed multipliers (stubs for later phases)
const MULT_SLOWDOWN: float = 0.60
const MULT_TAGGED_BONUS: float = 60.0            # px/s
const ICE_ACCEL_MULT: float = 0.25
const ICE_FRICTION_MULT: float = 0.3

# Block/Tile ids and flags (placeholders; to align with TileMap later)
const BLOCK_SOLID: int = 1
const BLOCK_SEMISOLID: int = 2
const BLOCK_ICE: int = 3
const BLOCK_DEATH_TOP: int = 4
const BLOCK_DEATH_BOTTOM: int = 5


