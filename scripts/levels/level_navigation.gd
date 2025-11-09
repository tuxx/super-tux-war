extends Node2D
class_name LevelNavigation

const GAME_CONSTANTS := preload("res://scripts/core/game_constants.gd")

class NodeEntry:
	var id: int
	var cell: Vector2i
	var position: Vector2
	var type: String
	var platform_id: int = -1
	var is_edge: bool = true

	func _init(node_id: int, cell_coord: Vector2i, world_pos: Vector2, node_type: String) -> void:
		id = node_id
		self.cell = cell_coord
		self.position = world_pos
		type = node_type


class PlatformEntry:
	var id: int
	var type: String
	var y: int
	var nodes: Array

	func _init(platform_id: int, platform_type: String, row_y: int, platform_nodes: Array) -> void:
		id = platform_id
		type = platform_type
		y = row_y
		nodes = platform_nodes


const SETTINGS_DRAW_GRAPH := "debug/navigation/show_graph"
const SETTINGS_DRAW_JUMP := "debug/navigation/show_jump_arcs"

const EDGE_WALK := "walk"
const EDGE_JUMP := "jump"
const EDGE_DROP := "drop"

const NODE_SOLID := "solid"
const NODE_SEMISOLID := "semisolid"

const LANDING_EPSILON := 4.0
const SIMULATION_STEP := 1.0 / 120.0
const CHARACTER_HALF_WIDTH := 12.0
const CHARACTER_HEIGHT := 29.0
const HORIZONTAL_SPEED_CUSHION := 20.0
const MIN_JUMP_DISTANCE := 6.0
const ARC_TIME_LIMIT := 1.25

const COLOR_SOLID_NODE := Color(1.0, 0.9, 0.2)
const COLOR_SEMISOLID_NODE := Color(0.95, 0.6, 0.95)
const COLOR_WALK := Color(0.3, 1.0, 0.3)
const COLOR_JUMP := Color(0.3, 0.85, 1.0)
const COLOR_DROP := Color(1.0, 0.65, 0.2)
const COLOR_PLATFORM_SOLID := Color(0.2, 0.4, 1.0, 0.35)
const COLOR_PLATFORM_SEMISOLID := Color(0.2, 1.0, 0.4, 0.35)

@export var debug_draw_graph := false
@export var debug_draw_jump_arcs := false 
@export var max_jump_up_tiles: int = 3
@export var max_jump_horizontal_tiles: int = 4

var nodes: Array[NodeEntry] = []
var walk_edges: Array = []
var jump_edges: Array = []
var drop_edges: Array = []
var adjacency: Dictionary = {}
var platforms: Dictionary = {}

var _node_by_cell: Dictionary = {}
var _solid_cells: Dictionary = {}
var _semisolid_cells: Dictionary = {}
var _border_cells: Dictionary = {}
var _has_solid_border := false

@onready var _ground_tile_map: TileMapLayer = $GroundTileMap
@onready var _semisolid_tile_map: TileMapLayer = $SemisolidTileMap


func _ready() -> void:
	_load_debug_settings()
	_build_navigation_graph()
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if debug_draw_graph or debug_draw_jump_arcs:
		queue_redraw()


func rebuild_graph() -> void:
	_build_navigation_graph()
	queue_redraw()


func _build_navigation_graph() -> void:
	nodes.clear()
	walk_edges.clear()
	jump_edges.clear()
	drop_edges.clear()
	adjacency.clear()
	platforms.clear()
	_node_by_cell.clear()

	_collect_tile_sets()
	_detect_solid_border()
	_build_nodes()
	_assign_platforms()
	_initialize_adjacency()
	_build_walk_edges()
	_build_drop_edges()
	_build_jump_edges()


func _collect_tile_sets() -> void:
	_solid_cells.clear()
	_semisolid_cells.clear()

	if _ground_tile_map:
		for cell_variant in _ground_tile_map.get_used_cells():
			var cell: Vector2i = cell_variant
			_solid_cells[cell] = true

	if _semisolid_tile_map:
		for cell_variant in _semisolid_tile_map.get_used_cells():
			var cell: Vector2i = cell_variant
			_semisolid_cells[cell] = true


func _detect_solid_border() -> void:
	_border_cells.clear()
	_has_solid_border = false

	if _ground_tile_map == null:
		return

	var used_rect: Rect2i = _ground_tile_map.get_used_rect()
	if used_rect.size == Vector2i.ZERO:
		return

	var left := used_rect.position.x
	var right := used_rect.position.x + used_rect.size.x - 1
	var top := used_rect.position.y
	var bottom := used_rect.position.y + used_rect.size.y - 1

	if used_rect.size.x <= 2 or used_rect.size.y <= 2:
		return

	_has_solid_border = true

	for x in range(left, right + 1):
		var top_cell := Vector2i(x, top)
		var bottom_cell := Vector2i(x, bottom)
		if not _solid_cells.has(top_cell) or not _solid_cells.has(bottom_cell):
			_has_solid_border = false
			break
		_border_cells[top_cell] = true
		_border_cells[bottom_cell] = true

	if not _has_solid_border:
		_border_cells.clear()
		return

	for y in range(top + 1, bottom):
		var left_cell := Vector2i(left, y)
		var right_cell := Vector2i(right, y)
		if not _solid_cells.has(left_cell) or not _solid_cells.has(right_cell):
			_has_solid_border = false
			break
		_border_cells[left_cell] = true
		_border_cells[right_cell] = true

	if not _has_solid_border:
		_border_cells.clear()


func _build_nodes() -> void:
	var tile_size := GAME_CONSTANTS.TILE_SIZE

	for cell_variant in _solid_cells.keys():
		var cell: Vector2i = cell_variant
		var above: Vector2i = cell + Vector2i(0, -1)
		if _solid_cells.has(above):
			continue
		var node := _create_node(cell, NODE_SOLID, tile_size)
		nodes.append(node)
		_node_by_cell[cell] = node

	for cell_variant in _semisolid_cells.keys():
		var cell: Vector2i = cell_variant
		if _node_by_cell.has(cell):
			continue
		var node := _create_node(cell, NODE_SEMISOLID, tile_size)
		nodes.append(node)
		_node_by_cell[cell] = node


func _create_node(cell: Vector2i, node_type: String, tile_size: int) -> NodeEntry:
	var node_id := nodes.size()
	var node_position := _cell_to_world_top_center(cell, tile_size)
	return NodeEntry.new(node_id, cell, node_position, node_type)


func _cell_to_world_top_center(cell: Vector2i, tile_size: int) -> Vector2:
	return Vector2(
		float(cell.x) * tile_size + tile_size * 0.5,
		float(cell.y) * tile_size
	)


func _assign_platforms() -> void:
	platforms.clear()
	var next_platform_id := 0
	var nodes_by_row: Dictionary = {}

	for node in nodes:
		var row: int = node.cell.y
		if nodes_by_row.has(row):
			(nodes_by_row[row] as Array).append(node)
		else:
			nodes_by_row[row] = [node]

	for row in nodes_by_row.keys():
		var row_nodes: Array = nodes_by_row[row]
		row_nodes.sort_custom(Callable(self, "_sort_nodes_by_x"))

		var current_group: Array = []
		var prev_cell_x := -9999
		var prev_type := ""

		for node in row_nodes:
			if current_group.is_empty():
				current_group.append(node)
			elif node.cell.x == prev_cell_x + 1 and node.type == prev_type:
				current_group.append(node)
			else:
				_finalize_platform_group(current_group, next_platform_id)
				next_platform_id += 1
				current_group = [node]

			prev_cell_x = node.cell.x
			prev_type = node.type

		if not current_group.is_empty():
			_finalize_platform_group(current_group, next_platform_id)
			next_platform_id += 1


func _finalize_platform_group(group: Array, platform_id: int) -> void:
	if group.is_empty():
		return

	var duplicated_group: Array = group.duplicate()
	var platform := PlatformEntry.new(
		platform_id,
		(group[0] as NodeEntry).type,
		(group[0] as NodeEntry).cell.y,
		duplicated_group
	)
	platforms[platform_id] = platform

	for index in range(group.size()):
		var node: NodeEntry = group[index]
		node.platform_id = platform_id
		node.is_edge = index == 0 or index == group.size() - 1


func _sort_nodes_by_x(a: NodeEntry, b: NodeEntry) -> bool:
	return a.cell.x < b.cell.x


func _initialize_adjacency() -> void:
	for node in nodes:
		adjacency[node.id] = []


func _build_walk_edges() -> void:
	for node in nodes:
		for direction in [-1, 1]:
			var neighbor_cell: Vector2i = node.cell + Vector2i(direction, 0)
			if not _node_by_cell.has(neighbor_cell):
				continue

			var neighbor: NodeEntry = _node_by_cell[neighbor_cell]
			if absf(neighbor.position.y - node.position.y) > 1.0:
				continue

			_add_edge(node.id, neighbor.id, EDGE_WALK, [node.position, neighbor.position])


func _build_drop_edges() -> void:
	for node in nodes:
		if node.type != NODE_SEMISOLID or not node.is_edge:
			continue

		var target_variant: Variant = _find_drop_target(node.cell)
		if target_variant == null:
			continue

		var target: NodeEntry = target_variant
		_add_edge(node.id, target.id, EDGE_DROP, [node.position, target.position])


func _find_drop_target(start_cell: Vector2i):
	var max_depth := 256
	var current := start_cell + Vector2i(0, 1)

	for _i in range(max_depth):
		if _node_by_cell.has(current):
			return _node_by_cell[current]

		if _solid_cells.has(current):
			return null

		current.y += 1

	return null


func _build_jump_edges() -> void:
	var max_vertical_pixels := GAME_CONSTANTS.TILE_SIZE * max_jump_up_tiles
	var max_horizontal_pixels := GAME_CONSTANTS.TILE_SIZE * max_jump_horizontal_tiles

	for node in nodes:
		for target in nodes:
			if target == node:
				continue
			if target.platform_id == node.platform_id:
				continue

			if not _is_jump_pair_allowed(node, target):
				continue

			var vertical_delta: float = node.position.y - target.position.y
			if vertical_delta < -LANDING_EPSILON:
				continue
			if vertical_delta > max_vertical_pixels + LANDING_EPSILON:
				continue

			var horizontal_delta: float = target.position.x - node.position.x
			if absf(horizontal_delta) < MIN_JUMP_DISTANCE:
				continue
			if absf(horizontal_delta) > max_horizontal_pixels:
				continue

			var time_to_target := _solve_jump_time(node.position.y, target.position.y)
			if time_to_target <= 0.0 or time_to_target > ARC_TIME_LIMIT:
				continue

			var vx: float = horizontal_delta / time_to_target
			if absf(vx) > GAME_CONSTANTS.PLAYER_MAX_RUN_SPEED + HORIZONTAL_SPEED_CUSHION:
				continue

			var sim_result := _simulate_jump_arc(node.position, target.position, vx, time_to_target)
			if not sim_result["valid"]:
				continue

			_add_edge(node.id, target.id, EDGE_JUMP, sim_result["points"], {
				"time": time_to_target,
				"vx": vx
			})


func _is_jump_pair_allowed(node: NodeEntry, target: NodeEntry) -> bool:
	var target_above := target.position.y + LANDING_EPSILON < node.position.y
	if target_above:
		return true

	return node.is_edge and target.is_edge


func _solve_jump_time(start_y: float, target_y: float) -> float:
	var a := 0.5 * GAME_CONSTANTS.GRAVITY
	var b := GAME_CONSTANTS.JUMP_VELOCITY
	var c := start_y - target_y
	var discriminant := b * b - 4.0 * a * c

	if discriminant < 0.0:
		return -1.0

	var sqrt_disc := sqrt(discriminant)
	var t1 := (-b - sqrt_disc) / (2.0 * a)
	var t2 := (-b + sqrt_disc) / (2.0 * a)
	var best := -1.0

	for t in [t1, t2]:
		if t > 0.0:
			if best < 0.0 or t > best:
				best = t

	return best


func _simulate_jump_arc(start_pos: Vector2, target_pos: Vector2, vx: float, total_time: float) -> Dictionary:
	var points: Array = []
	var time := 0.0
	points.append(start_pos)

	while time <= total_time + SIMULATION_STEP:
		time += SIMULATION_STEP
		var pos := Vector2(
			start_pos.x + vx * time,
			start_pos.y + GAME_CONSTANTS.JUMP_VELOCITY * time + 0.5 * GAME_CONSTANTS.GRAVITY * time * time
		)
		points.append(pos)

		if _collides_with_solid(pos):
			return {"valid": false}

		var vertical_velocity := GAME_CONSTANTS.JUMP_VELOCITY + GAME_CONSTANTS.GRAVITY * time
		if vertical_velocity > 0.0:
			if absf(pos.x - target_pos.x) <= GAME_CONSTANTS.TILE_SIZE * 0.5 and absf(pos.y - target_pos.y) <= LANDING_EPSILON:
				return {"valid": true, "points": points}

	return {"valid": false}


func _collides_with_solid(pos: Vector2) -> bool:
	var sample_points := [
		pos + Vector2(-CHARACTER_HALF_WIDTH, -2.0),
		pos + Vector2(CHARACTER_HALF_WIDTH, -2.0),
		pos + Vector2(-CHARACTER_HALF_WIDTH, -CHARACTER_HEIGHT),
		pos + Vector2(CHARACTER_HALF_WIDTH, -CHARACTER_HEIGHT),
		pos + Vector2(0.0, -CHARACTER_HEIGHT * 0.5)
	]

	for sample in sample_points:
		var cell := _world_to_cell(sample)
		if _is_blocking_cell(cell):
			return true

	return false


func _world_to_cell(world_pos: Vector2) -> Vector2i:
	var tile_size := GAME_CONSTANTS.TILE_SIZE
	return Vector2i(
		floor(world_pos.x / tile_size),
		floor(world_pos.y / tile_size)
	)


func _is_blocking_cell(cell: Vector2i) -> bool:
	if _has_solid_border and _border_cells.has(cell):
		return false

	return _solid_cells.has(cell)


func _add_edge(from_id: int, to_id: int, edge_type: String, points: Array, meta: Dictionary = {}) -> void:
	if not adjacency.has(from_id):
		adjacency[from_id] = []

	var edge := {
		"from": from_id,
		"to": to_id,
		"type": edge_type,
		"points": points.duplicate(),
		"cost": _polyline_length(points),
		"meta": meta
	}

	match edge_type:
		EDGE_WALK:
			walk_edges.append(edge)
		EDGE_DROP:
			drop_edges.append(edge)
		EDGE_JUMP:
			jump_edges.append(edge)

	adjacency[from_id].append(edge)


func _polyline_length(points: Array) -> float:
	var count := points.size()
	if count < 2:
		return 0.0

	var length := 0.0
	for i in range(count - 1):
		length += points[i].distance_to(points[i + 1])
	return length


func get_graph() -> Dictionary:
	return {
		"nodes": nodes,
		"walk_edges": walk_edges,
		"jump_edges": jump_edges,
		"drop_edges": drop_edges,
		"adjacency": adjacency,
		"platforms": platforms
	}


func get_node_by_id(node_id: int) -> NodeEntry:
	if node_id < 0 or node_id >= nodes.size():
		return null
	return nodes[node_id]


func get_adjacency_list() -> Dictionary:
	return adjacency


func get_nodes_for_platform(platform_id: int) -> Array:
	if not platforms.has(platform_id):
		return []
	return (platforms[platform_id] as PlatformEntry).nodes


func find_closest_node(world_pos: Vector2, vertical_tolerance: float = GAME_CONSTANTS.TILE_SIZE * 4.0) -> NodeEntry:
	var best: NodeEntry = null
	var best_score := INF
	for node in nodes:
		var dy := absf(world_pos.y - node.position.y)
		if dy > vertical_tolerance:
			continue
		var dx := absf(world_pos.x - node.position.x)
		var score := dx + dy * 0.5
		if score < best_score:
			best_score = score
			best = node
	return best


func get_tile_size() -> int:
	return GAME_CONSTANTS.TILE_SIZE


func _draw() -> void:
	if not debug_draw_graph and not debug_draw_jump_arcs:
		return

	if debug_draw_graph:
		_draw_platforms()
		_draw_graph_edges()
		_draw_nodes()

	if debug_draw_jump_arcs:
		_draw_jump_edges()


func _draw_platforms() -> void:
	for platform_id in platforms.keys():
		var platform: PlatformEntry = platforms[platform_id]
		var color := COLOR_PLATFORM_SEMISOLID if platform.type == NODE_SEMISOLID else COLOR_PLATFORM_SOLID
		var nodes_in_platform: Array = platform.nodes
		if nodes_in_platform.is_empty():
			continue

		var first_node: NodeEntry = nodes_in_platform[0]
		var last_node: NodeEntry = nodes_in_platform[nodes_in_platform.size() - 1]

		var rect := Rect2(
			Vector2(first_node.position.x - GAME_CONSTANTS.TILE_SIZE * 0.5, first_node.position.y),
			Vector2(
				(last_node.cell.x - first_node.cell.x + 1) * GAME_CONSTANTS.TILE_SIZE,
				3.0
			)
		)
		draw_rect(rect, color, true)


func _draw_graph_edges() -> void:
	for edge in walk_edges:
		draw_line(edge["points"][0], edge["points"][1], COLOR_WALK, 2.0)

	for edge in drop_edges:
		draw_line(edge["points"][0], edge["points"][1], COLOR_DROP, 2.0)


func _draw_nodes() -> void:
	for node in nodes:
		var color := COLOR_SEMISOLID_NODE if node.type == NODE_SEMISOLID else COLOR_SOLID_NODE
		var radius := 5.0 if node.is_edge else 3.0
		draw_circle(node.position + Vector2(0, -3), radius, color)


func _draw_jump_edges() -> void:
	for edge in jump_edges:
		var points: PackedVector2Array = PackedVector2Array(edge["points"])
		draw_polyline(points, COLOR_JUMP, 2.0)


func set_debug_draw_graph(enabled: bool) -> void:
	debug_draw_graph = enabled
	ProjectSettings.set_setting(SETTINGS_DRAW_GRAPH, enabled)
	queue_redraw()


func set_debug_draw_jump_arcs(enabled: bool) -> void:
	debug_draw_jump_arcs = enabled
	ProjectSettings.set_setting(SETTINGS_DRAW_JUMP, enabled)
	queue_redraw()


func _load_debug_settings() -> void:
	if ProjectSettings.has_setting(SETTINGS_DRAW_GRAPH):
		debug_draw_graph = bool(ProjectSettings.get_setting(SETTINGS_DRAW_GRAPH))
	else:
		ProjectSettings.set_setting(SETTINGS_DRAW_GRAPH, debug_draw_graph)

	if ProjectSettings.has_setting(SETTINGS_DRAW_JUMP):
		debug_draw_jump_arcs = bool(ProjectSettings.get_setting(SETTINGS_DRAW_JUMP))
	else:
		ProjectSettings.set_setting(SETTINGS_DRAW_JUMP, debug_draw_jump_arcs)
