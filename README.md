# Super Tux War
A fan-inspired arena platformer built with Godot 4, following Super Mario War conventions. Battle in fast-paced multiplayer arenas where the goal is simple: stomp your opponents by landing on their heads while avoiding getting stomped yourself. Navigate 32×32 tile-based levels with precise platforming controls, one-way platforms, and hazards.

<div align="center">

### 🎮 [**PLAY NOW IN YOUR BROWSER**](https://tuxx.github.io/super-tux-war/) 🎮

</div>


---

<img width="1278" height="704" alt="2025-11-06_19-06-51" src="https://github.com/user-attachments/assets/45079bcc-71f6-4845-b81c-84a29612eb62" />

*Current tile map test level*

- *Tux*: Player character
- *FreeBSD Beastie*: NPC

*Controls*
- Move: A/D or Left/Right
- Jump: Space or W
- Drop through platforms: S+Space (Down+Jump)

---

## Game Design

### Movement & Physics (Super Mario War Style)
The game follows Super Mario War conventions for tight, responsive platformer controls:

**Player Movement**
- Walk speed: 240 px/s (4 px/frame at 60fps)
- Run speed: 330 px/s (5.5 px/frame)
- Jump velocity: -540 px/s (9 px/frame)
- Gravity: 1440 px/s² (0.40 px/frame²)
- Variable jump height: Release jump early for short hops
- Coyote time: 0.1s grace period after leaving platforms
- Jump buffering: 0.1s window to buffer jump input before landing

**Combat**
- Stomp enemies by landing on their head from above
- Respawn after 2 seconds

### Level Design (32×32 Tile Grid)

All levels use a strict **32×32 pixel tile grid** following Super Mario War design principles:

**Design Rules**
- Keep open arenas; avoid narrow corridors and 1-tile-high tunnels
- Ensure ≥2 tiles of headroom above landing platforms
- Horizontal gaps should be ≤3 tiles for running jumps
- Characters and objects occupy single-tile footprints (collision ~30×30 px)
- Jumps can clear ~2-3 tiles vertically

**Tile Layers (front to back)**
1. **Players/NPCs** (z-index 10) - Always render on top
2. **GroundTileMap** (z-index 0) - Solid collision tiles (walls, floors, ice)
3. **SemisolidTileMap** (z-index 0) - One-way platforms (jump through from below, drop through with Down+Jump)
4. **DecorationTileMap** (z-index -10) - Visual-only background tiles
5. **Death Layer** (future) - Hazard tiles (spikes, lava)
6. **Parallax Background** (future) - Scrolling backgrounds

**Tile Types**
- **Solid**: Full collision blocks (walls, ground, ice)
- **Semisolid**: One-way platforms (can jump up through, stand on top, drop through)
- **Ice**: Solid blocks with reduced friction
- **Death (floor)**: Hazard tiles that kill on contact from above
- **Death (ceiling)**: Hazard tiles that kill on contact from below

### AI Behavior (SMW-Style Reactive Logic)

NPCs use reactive heuristics instead of pathfinding, running at ~15 Hz (every 4 frames):

**Target Selection**
- Choose nearest player/goal/threat using distance
- Respect world wrap if enabled

**Movement Heuristics**
- Move toward target by default
- Run away if target is invincible or a threat
- Jump when blocked by walls (velocity ≈ 0 while moving)

**Vertical Decisions**
- Jump if target is above and horizontally aligned (±45 px window)
- Drop through semisolid platforms if target is below
- Avoid jumping into ceiling hazards (death_bottom tiles)

**Hazard Avoidance**
- Scan downward under feet for death_top tiles
- If pit/spike detected before solid ground, move away and jump

### Goals (may change)
- **Multiplayer**: Local first; P2P networking later; dedicated servers maybe after that
- **Worlds & levels**: Multiple worlds with levels you can play solo vs NPCs or versus other players
- **Characters**: Open-source–inspired, non-infringing mascots (e.g., tux, beastie, fish, gnu, etc.)
- **Items**:
  - Breakable stompboxes that spawn items
  - Fish (power-up), floppies (collectible), sudo (invincibility)
  - Throwable hazards; level-wide stun item
- **Game modes (later focus)**: deathmatch, team deathmatch, capture the flag, last one standing, collect the floppies

We will first focus on core gameplay foundations: characters, items, levels, and multiplayer. Game modes come later.

### Current Status
- ✅ SMW-style player movement with variable jump
- ✅ 32×32 tile-based level system with TileMap layers
- ✅ Solid and semisolid platform collision
- ✅ Drop-through platform mechanic
- ✅ Head stomp combat system
- ✅ Character respawn system
- 🚧 NPC AI (planned)
- 🚧 Items and powerups (planned)
- 🚧 Multiplayer (planned)

### Running the game
- Godot version: 4.5.1-stable
- Open in editor:
  ```bash
  godot4 --editor --path .
  ```
- Run:
  ```bash
  godot4 --path .
  ```
- Main scene: `scenes/levels/tile_map.tscn`

### Creating Assets

**Sprites**
- Character sprites should be designed at any resolution but scaled to fit within a 32×32 tile footprint
- Collision shapes are ~30×30 px (slightly smaller than tile size for clean movement)
- Use pixel art style with no filtering for crisp visuals
- Export as PNG with transparency
- Organize in `assets/characters/[character_name]/spritesheets/`

**Tiles**
- All tiles must be exactly 32×32 pixels
- Design with clear visual distinction between tile types (solid, semisolid, hazards)
- Use consistent pixel art style
- Export as PNG
- Organize in `assets/blocks/[type]/`

**Animations**
- Use sprite sheets with consistent frame sizes
- Recommended animations: idle, run, jump, death
- Frame rate: typically 4-8 fps for idle, 8 fps for run

**TileSet Configuration**
- Each tile needs physics collision shapes (32×32 for solid, thin top edge for semisolid)
- Set custom data flags: `solid`, `semisolid`, `ice`, `death_top`, `death_bottom`
- Configure physics layers: layer 0 for solid, layer 1 for semisolid


### Contributing
- Workflow: fork → feature branch → PR; discuss larger changes in issues first.
- Language/style: GDScript; keep changes focused and PRs small where possible.
- Assets: submit original or properly licensed assets; include required attributions; follow the sizes and naming above.
- License: MIT (code and assets). By contributing, you agree to license your contributions under MIT.
- Local testing: run with Godot 4.5.1 (see above).


### Acknowledgements
- Inspired by community-made arena platformers like Super Mario War.
- Thanks to all open-source contributors and tool authors (Godot, LibreSprite, etc.).

### Legal
- We do not use actual third‑party logos. Characters and items are original, non‑confusing stylizations to avoid trademark infringement and usage restrictions.
- No Nintendo IP.
- Attributions are included in-source and/or in-game where required (e.g., if any artwork derives from assets that require attribution). If you contribute assets needing attribution, include the attribution text in your PR.
- By contributing, you agree your code and assets are licensed under MIT for this project.
