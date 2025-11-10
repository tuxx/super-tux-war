# Debug Launch Configuration (Local Only)

To speed up iteration you can create a local configuration file that
automatically overrides the launch scene and applies developer options
whenever the game boots. 

## 1. Create the Config File

Create `dev_launch.cfg` in the project root (next to `project.godot`) and add the sections you need. 
All sections are optional.

```ini
[launch]
scene="res://scenes/dev/dev_test_level.tscn"

[project]
nav_graph=true          # Always show navigation graph
jump_arcs=true          # Always show jump arcs

[dev_menu]
show_menu=true          # Keep developer menu visible
perf_graph=true         # Show performance graph (F2 toggle)
player_stats=true       # Show player stats (F1 toggle)
clear_npcs=true         # Remove NPCs after the level loads
position=Vector2(1040, 40) # Optional override for menu position
```

Restart the running build (or reload the scene) after saving the file.
If the file is missing, the game boots normally.

## 2. What Happens on Boot

`DebugBootstrap` (autoload) performs these steps:

1. Loads `dev_launch.cfg` if it exists.
2. Optionally changes the starting scene (`[launch]` section).
3. Applies project level debug settings such as navigation graph.
4. Waits for the developer menu to spawn and applies toggles/commands.
5. If `[match].auto_start` is enabled, waits for the Start Menu to finish loading, applies match settings, and calls `GameStateManager.start_match()`.

The config never writes back to versioned files. All state (including
dev menu position) is written to `user://dev_menu_settings.cfg`.

## 3. Available Keys

### `[launch]`
- `scene` — Full path to a `.tscn` file to load instead of the normal menu.

### `[project]`
- `nav_graph` — `true`/`false` to enable navigation debug draw.
- `jump_arcs` — `true`/`false` to enable jump arc debug draw.

### `[dev_menu]`
- `show_menu` — Force the developer menu visible.
- `perf_graph` — Open or hide the performance graph.
- `player_stats` — Open or hide the player stats panel.
- `clear_npcs` — Remove all NPCs once the scene is ready.
- `position` — Optional `Vector2(x, y)` to put the menu at a custom location.

Keys you omit simply use the default behaviour.

### `[match]`
- `auto_start` — `true` to immediately kick off a match once the Start Menu is ready.
- `level` — Level scene path to load (defaults to `res://scenes/levels/level01.tscn`).
- `player_character` — Player character id (`tux`, `beasty`, `gopher`).
- `cpu_character` — CPU character id.
- `cpu_count` — Number of CPU opponents (clamped to the in-game min/max).
- `kills_to_win` — Kill target for the match.

### `[player_stats]`
- `log_events` — `true` to print movement milestone logs (start, top speed, input release, stop).

## 4. Quick Example

```ini
[launch]
scene="res://scenes/levels/spacearena.tscn"

[project]
nav_graph=true

[dev_menu]
show_menu=true
perf_graph=true
clear_npcs=true

[player_stats]
log_events=true

[match]
auto_start=true
level="res://scenes/levels/level01.tscn"
player_character="tux"
cpu_character="beasty"
cpu_count=2
kills_to_win=10
```

This configuration starts the game directly in the space arena, shows the
nav graph, pops open the dev menu + perf graph, and removes every NPC so
you can focus on player movement. It also queues a match immediately with
the specified level + character settings, so you land in gameplay without
clicking through the menu. Setting `[player_stats].log_events=true` enables
the player movement console logs for debugging acceleration runs.
