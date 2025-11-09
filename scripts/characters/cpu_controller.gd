extends Node

#const GAME_CONSTANTS = preload("res://scripts/game_constants.gd")

const THINK_INTERVAL := 0.067
const TARGET_LOCK_TIME := 1.0
const WALK_REACH_EPS := 6.0
const ALIGNMENT_WINDOW := 8.0
const LANDING_TOLERANCE := 12.0
const DANGER_VERTICAL := 96.0
const DANGER_HORIZONTAL := 40.0
const DIRECTION_COOLDOWN := 0.15
const BLOCKED_DISTANCE := 6.0
const BLOCKED_TIME := 0.45
const BLOCKED_SPEED_THRESHOLD := 20.0
const STOMP_HORIZONTAL_RANGE := 80.0
const STOMP_VERTICAL_RANGE := GameConstants.TILE_SIZE * 3.0
const STOMP_JUMP_THRESHOLD := GameConstants.TILE_SIZE * 0.75
const STOMP_FULL_JUMP_CLEARANCE := GameConstants.TILE_SIZE * 3.25
const STOMP_MIN_STOMP_CLEARANCE := GameConstants.TILE_SIZE * 1.0
const STOMP_CLEARANCE_BUFFER := GameConstants.TILE_SIZE * 0.5
const SAFE_LANDING_HORIZONTAL_BUFFER := GameConstants.TILE_SIZE * 0.75

var navigation: LevelNavigation
var character: CharacterController
var target: CharacterController

var think_timer: float = 0.0
var target_lock_timer: float = 0.0

var current_plan: Array = []
var active_edge: Dictionary = {}
var active_edge_target_id: int = -1
var current_start_node_id: int = -1
var current_target_platform_id: int = -1
var last_move_dir: float = 0.0
var direction_cooldown: float = 0.0
var blocked_timer: float = 0.0
var last_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	character = get_parent() as CharacterController
	if character == null:
		push_warning("CPU controller requires parent CharacterController.")
	navigation = get_tree().current_scene as LevelNavigation
	think_timer = THINK_INTERVAL
	target_lock_timer = 0.0
	if character:
		last_position = character.global_position


func _physics_process(delta: float) -> void:
	if character == null or navigation == null or character.is_despawned:
		return

	think_timer -= delta
	if think_timer <= 0.0:
		think_timer = THINK_INTERVAL
		if active_edge.is_empty():
			_update_strategy()
		else:
			_refresh_target()

	var danger := _check_danger()
	if danger["active"]:
		character.set_ai_inputs(danger["move_dir"], false, false, false)
		return

	direction_cooldown = max(0.0, direction_cooldown - delta)
	var action := _run_tactics()
	action = _stabilize_move_direction(action, delta)
	action = _handle_blocked_state(action, delta)
	character.set_ai_inputs(
		action["move_dir"],
		action["jump_pressed"],
		action.get("jump_released", false),
		action["drop_pressed"]
	)
	last_position = character.global_position


func _update_strategy() -> void:
	_refresh_target()
	if target == null:
		current_plan.clear()
		_clear_active_edge()
		return

	var start_node := _resolve_node_for_body(character)
	var target_node := _resolve_node_for_body(target)
	if start_node == null or target_node == null:
		current_plan.clear()
		return

	if start_node.id != current_start_node_id or target_node.platform_id != current_target_platform_id:
		current_plan = _build_path(start_node.id, target_node.platform_id)
		current_start_node_id = start_node.id
		current_target_platform_id = target_node.platform_id
		_clear_active_edge()


func _refresh_target() -> void:
	if target != null and (not is_instance_valid(target) or target.is_despawned):
		target = null

	if target == null or target_lock_timer <= 0.0:
		target = _pick_target()
		target_lock_timer = TARGET_LOCK_TIME
	else:
		target_lock_timer = max(0.0, target_lock_timer - THINK_INTERVAL)


func _pick_target() -> CharacterController:
	# Target any character (players and other NPCs), not just players
	var candidates = get_tree().get_nodes_in_group("characters")
	var best: CharacterController = null
	var best_dist := INF
	for node in candidates:
		if not node is CharacterController:
			continue
		var other := node as CharacterController
		# Skip self
		if other == character:
			continue
		# Skip despawned characters
		if other.is_despawned:
			continue
		var dist := character.global_position.distance_to(other.global_position)
		if dist < best_dist:
			best_dist = dist
			best = other
	return best


func _resolve_node_for_body(body: CharacterController) -> LevelNavigation.NodeEntry:
	if body == null:
		return null
	return navigation.find_closest_node(body.get_foot_position())


func _build_path(start_node_id: int, target_platform_id: int) -> Array:
	var start_node := navigation.get_node_by_id(start_node_id)
	if start_node == null:
		return []
	if start_node.platform_id == target_platform_id:
		return []

	var adjacency := navigation.get_adjacency_list()
	var queue: Array = [start_node_id]
	var visited: Dictionary = {}
	visited[start_node_id] = true
	var came_from: Dictionary = {}
	var goal_id := -1

	while not queue.is_empty() and goal_id == -1:
		var node_id: int = queue[0]
		queue.remove_at(0)
		var node := navigation.get_node_by_id(node_id)
		if node == null:
			continue
		if node.platform_id == target_platform_id:
			goal_id = node_id
			break

		for edge in adjacency.get(node_id, []):
			var next_id: int = edge["to"]
			if visited.has(next_id):
				continue
			visited[next_id] = true
			came_from[next_id] = {"node": node_id, "edge": edge}
			queue.append(next_id)

	if goal_id == -1:
		return []

	var path: Array = []
	var walker := goal_id
	while walker != start_node_id:
		if not came_from.has(walker):
			return []
		var record: Dictionary = came_from[walker]
		var edge: Dictionary = record["edge"]
		path.append(edge.duplicate(true))
		walker = record["node"]
	path.reverse()
	return path


func _run_tactics() -> Dictionary:
	var stomp: Dictionary = _attempt_direct_stomp()
	if not stomp.is_empty():
		current_plan.clear()
		_clear_active_edge()
		return stomp

	if not active_edge.is_empty():
		return _continue_active_edge()

	if current_plan.is_empty():
		return _chase_target_directly()

	var edge: Dictionary = current_plan[0]
	match edge["type"]:
		LevelNavigation.EDGE_WALK:
			return _execute_walk_edge(edge)
		LevelNavigation.EDGE_DROP:
			return _prepare_drop_edge(edge)
		LevelNavigation.EDGE_JUMP:
			return _prepare_jump_edge(edge)
		_:
			current_plan.remove_at(0)
			return _chase_target_directly()


func _execute_walk_edge(edge: Dictionary) -> Dictionary:
	var node := navigation.get_node_by_id(edge["to"])
	if node == null:
		current_plan.remove_at(0)
		return _chase_target_directly()

	var dx := node.position.x - character.global_position.x
	var move_dir := _signed_direction(dx)
	if absf(dx) <= WALK_REACH_EPS:
		current_plan.remove_at(0)
		move_dir = 0.0
	return _action(move_dir, false, false)


func _prepare_jump_edge(edge: Dictionary) -> Dictionary:
	var start_node := navigation.get_node_by_id(edge["from"])
	var target_node := navigation.get_node_by_id(edge["to"])
	if start_node == null or target_node == null:
		current_plan.remove_at(0)
		return _chase_target_directly()

	var dx := start_node.position.x - character.global_position.x
	var move_dir := _signed_direction(dx)

	if absf(dx) <= ALIGNMENT_WINDOW:
		move_dir = _signed_direction(target_node.position.x - character.global_position.x)
		if character.is_on_floor():
			var jump_edge := edge
			var landing_node := target_node
			if _is_jump_blocked_by_player(landing_node):
				var redirected := _find_safe_jump_edge(start_node, landing_node)
				if redirected.is_empty():
					return _sidestep_below_player()
				jump_edge = redirected
				current_plan[0] = jump_edge
				landing_node = navigation.get_node_by_id(jump_edge["to"])
				if landing_node == null or _is_jump_blocked_by_player(landing_node):
					return _sidestep_below_player()
				move_dir = _signed_direction(landing_node.position.x - character.global_position.x)
			if landing_node == null:
				return _sidestep_below_player()
			active_edge = jump_edge.duplicate(true)
			active_edge_target_id = landing_node.id
			current_plan.remove_at(0)
			return _action(move_dir, true, false)

	return _action(move_dir, false, false)


func _prepare_drop_edge(edge: Dictionary) -> Dictionary:
	var start_node := navigation.get_node_by_id(edge["from"])
	var target_node := navigation.get_node_by_id(edge["to"])
	if start_node == null or target_node == null:
		current_plan.remove_at(0)
		return _chase_target_directly()

	var dx := start_node.position.x - character.global_position.x
	var move_dir := _signed_direction(dx)

	if absf(dx) <= ALIGNMENT_WINDOW and character.is_on_floor():
		active_edge = edge.duplicate(true)
		active_edge_target_id = target_node.id
		current_plan.remove_at(0)
		return _action(move_dir, false, true)

	return _action(move_dir, false, false)


func _continue_active_edge() -> Dictionary:
	var target_node := navigation.get_node_by_id(active_edge_target_id)
	if target_node == null:
		_clear_active_edge()
		return _chase_target_directly()

	var move_dir := _signed_direction(target_node.position.x - character.global_position.x)
	if character.is_on_floor() and _foot_close_to_node(target_node):
		_clear_active_edge()
	return _action(move_dir, false, false)


func _chase_target_directly() -> Dictionary:
	if target == null:
		return _action(0.0, false, false)

	var dx := target.global_position.x - character.global_position.x
	var move_dir := _signed_direction(dx)
	return _action(move_dir, false, false)


func _foot_close_to_node(node: LevelNavigation.NodeEntry) -> bool:
	var foot := character.get_foot_position()
	return absf(foot.x - node.position.x) <= LANDING_TOLERANCE and absf(foot.y - node.position.y) <= LANDING_TOLERANCE


func _check_danger() -> Dictionary:
	# Check for danger from any character (players and other NPCs) falling on us
	var bodies = get_tree().get_nodes_in_group("characters")
	for node in bodies:
		if not node is CharacterController:
			continue
		var other := node as CharacterController
		# Skip self
		if other == character:
			continue
		if other.is_despawned:
			continue
		var rel := other.global_position - character.global_position
		if rel.y < -DANGER_VERTICAL and absf(rel.x) <= DANGER_HORIZONTAL and other.velocity.y > 0.0:
			return {"active": true, "move_dir": -_signed_direction(rel.x)}
	return {"active": false, "move_dir": 0.0}


func _is_jump_blocked_by_player(target_node: LevelNavigation.NodeEntry) -> bool:
	if target == null or character == null or target_node == null:
		return false
	if target_node.type != LevelNavigation.NODE_SEMISOLID:
		return false
	if target.global_position.y >= character.global_position.y:
		return false
	if absf(target.global_position.x - character.global_position.x) > GameConstants.TILE_SIZE:
		return false
	var player_node := _resolve_node_for_body(target)
	if player_node == null:
		return false
	if player_node.platform_id != target_node.platform_id:
		return false
		
	var vertical_gap := target.global_position.y - character.global_position.y
	return vertical_gap <= STOMP_VERTICAL_RANGE


func _evaluate_stomp_jump_profile(relative_target: Vector2) -> Dictionary:
	if character == null:
		return {"allowed": false, "use_short_jump": false}

	var max_distance: float = STOMP_FULL_JUMP_CLEARANCE
	var clearance: float = _get_ceiling_clearance(max_distance)
	var required: float = STOMP_MIN_STOMP_CLEARANCE + max(0.0, -relative_target.y)
	if clearance < required:
		return {"allowed": false, "use_short_jump": false}

	var short_jump_threshold: float = max(STOMP_MIN_STOMP_CLEARANCE, max_distance - STOMP_CLEARANCE_BUFFER)
	var use_short_jump: bool = clearance < short_jump_threshold
	return {
		"allowed": true,
		"use_short_jump": use_short_jump
	}


func _find_safe_jump_edge(start_node: LevelNavigation.NodeEntry, blocked_node: LevelNavigation.NodeEntry) -> Dictionary:
	if navigation == null or start_node == null or blocked_node == null:
		return {}

	var adjacency_list := navigation.get_adjacency_list()
	var edges: Array = adjacency_list.get(start_node.id, [])
	if edges.is_empty():
		return {}

	var desired_x := blocked_node.position.x
	if target != null:
		desired_x = target.global_position.x

	var best_edge: Dictionary = {}
	var best_score := INF

	for candidate in edges:
		if candidate.get("type", "") != LevelNavigation.EDGE_JUMP:
			continue
		var landing_node := navigation.get_node_by_id(candidate["to"])
		if landing_node == null:
			continue
		if landing_node.platform_id != blocked_node.platform_id:
			continue
		if landing_node.id == blocked_node.id:
			continue
		var separation := absf(landing_node.position.x - desired_x)
		if separation < SAFE_LANDING_HORIZONTAL_BUFFER:
			continue
		if separation < best_score:
			best_score = separation
			best_edge = candidate.duplicate(true)

	return best_edge


func _sidestep_below_player() -> Dictionary:
	var dir := 0.0
	if target != null:
		dir = -_signed_direction(target.global_position.x - character.global_position.x)
	if dir == 0.0:
		dir = 1.0 if randf() > 0.5 else -1.0
	return _action(dir, false, false)


func _is_ceiling_player_blocked() -> bool:
	if character == null:
		return false

	var start := character.global_position
	var end := start - Vector2(0, GameConstants.TILE_SIZE * 1.5)
	var space := character.get_world_2d().direct_space_state

	var query := PhysicsRayQueryParameters2D.new()
	query.from = start
	query.to = end
	query.exclude = [character.get_rid()]
	query.collision_mask = character.collision_mask

	var result := space.intersect_ray(query)
	if result.is_empty():
		return false

	var collider: Object = result.get("collider")
	if collider is CharacterController:
		var other := collider as CharacterController
		return other != character and not other.is_despawned
	return false


func _get_ceiling_clearance(max_distance: float) -> float:
	if character == null:
		return max_distance

	var start := character.global_position
	var end := start - Vector2(0, max_distance)
	var space := character.get_world_2d().direct_space_state
	if space == null:
		return max_distance

	var exclude: Array = [character.get_rid()]
	if target != null and is_instance_valid(target):
		exclude.append(target.get_rid())

	var query := PhysicsRayQueryParameters2D.new()
	query.from = start
	query.to = end
	query.exclude = exclude
	query.collision_mask = character.collision_mask

	var result := space.intersect_ray(query)
	if result.is_empty():
		return max_distance

	var hit_position: Vector2 = result.get("position", end)
	return start.distance_to(hit_position)


func _action(move_dir: float, jump_pressed: bool, drop_pressed: bool, jump_released: bool = false) -> Dictionary:
	return {
		"move_dir": clamp(move_dir, -1.0, 1.0),
		"jump_pressed": jump_pressed,
		"drop_pressed": drop_pressed,
		"jump_released": jump_released
	}


func _signed_direction(value: float) -> float:
	if value > WALK_REACH_EPS * 0.5:
		return 1.0
	if value < -WALK_REACH_EPS * 0.5:
		return -1.0
	return 0.0


func _clear_active_edge() -> void:
	active_edge.clear()
	active_edge_target_id = -1


func _stabilize_move_direction(action: Dictionary, _delta: float) -> Dictionary:
	var dir: float = action["move_dir"]
	if dir == 0.0:
		last_move_dir = 0.0
		direction_cooldown = 0.0
	else:
		dir = 1.0 if dir > 0.0 else -1.0
		if last_move_dir != 0.0 and dir != last_move_dir:
			if direction_cooldown > 0.0:
				dir = last_move_dir
			else:
				last_move_dir = dir
				direction_cooldown = DIRECTION_COOLDOWN
		else:
			if dir != last_move_dir:
				last_move_dir = dir
				direction_cooldown = DIRECTION_COOLDOWN
	action["move_dir"] = dir
	return action


func _handle_blocked_state(action: Dictionary, delta: float) -> Dictionary:
	if character == null:
		return action

	var horizontal_delta := absf(character.global_position.x - last_position.x)
	var horizontal_speed := absf(character.velocity.x)
	var grounded := character.is_on_floor()

	if horizontal_delta > BLOCKED_DISTANCE or horizontal_speed > BLOCKED_SPEED_THRESHOLD or not grounded:
		blocked_timer = 0.0
	else:
		blocked_timer += delta

	if blocked_timer >= BLOCKED_TIME:
		blocked_timer = 0.0
		current_plan.clear()
		_clear_active_edge()
		if grounded:
			action["jump_pressed"] = true
		if last_move_dir == 0.0:
			action["move_dir"] = 1.0 if randf() > 0.5 else -1.0
		else:
			action["move_dir"] = -last_move_dir
	return action


func _attempt_direct_stomp() -> Dictionary:
	if target == null or character == null:
		return {}

	var rel := target.global_position - character.global_position
	if rel.y < 0.0:
		return {}
	if absf(rel.x) > STOMP_HORIZONTAL_RANGE:
		return {}
	if absf(rel.y) > STOMP_VERTICAL_RANGE:
		return {}
	if rel.y > STOMP_JUMP_THRESHOLD:
		return {}

	var move_dir := _signed_direction(rel.x)
	if move_dir == 0.0:
		move_dir = 1.0 if rel.x >= 0.0 else -1.0

	var jump := false
	var short_jump := false
	if character.is_on_floor() and rel.y < STOMP_JUMP_THRESHOLD and not _is_ceiling_player_blocked():
		var jump_profile := _evaluate_stomp_jump_profile(rel)
		if jump_profile.get("allowed", false):
			jump = true
			short_jump = jump_profile.get("use_short_jump", false)

	return _action(move_dir, jump, false, short_jump)
