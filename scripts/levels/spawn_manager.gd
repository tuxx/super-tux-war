extends Node

const PLAYER_SCENE := preload("res://scenes/characters/player_character.tscn")
const NPC_SCENE := preload("res://scenes/characters/npc_character.tscn")

const SAFE_SPAWN_DISTANCE := GameConstants.TILE_SIZE * 4.0

# Color palette for CPU characters
const CPU_COLORS := [
	Color(1.0, 1.0, 1.0),      # 0: White (default/original color)
	Color(0.2, 0.2, 0.2),      # 1: Black/Dark Gray
	Color(0.3, 0.3, 1.0),      # 2: Blue
	Color(0.3, 1.0, 0.3),      # 3: Green
	Color(1.0, 1.0, 0.3),      # 4: Yellow
	Color(1.0, 0.5, 0.0),      # 5: Orange
	Color(0.8, 0.3, 1.0),      # 6: Purple
	Color(0.3, 1.0, 1.0),      # 7: Cyan
]

var _spawn_points: Array[SpawnPoint] = []
var _last_point_by_id: Dictionary = {}   # character RID (int) -> SpawnPoint

func _ready() -> void:
	add_to_group("spawn_manager")
	_collect_spawn_points()
	_initial_spawn()


func _collect_spawn_points() -> void:
	_spawn_points.clear()
	for node in get_tree().get_nodes_in_group("spawn_points"):
		var sp := node as SpawnPoint
		if sp != null:
			_spawn_points.append(sp)


func _initial_spawn() -> void:
	# Clear any already placed Player/NPC children (in case level still has them)
	for child in get_children():
		if child is CharacterBody2D:
			child.queue_free()
	await get_tree().process_frame

	# Spawn player
	var player_point := _pick_point_for_role("player", null)
	var last_point: SpawnPoint = player_point

	if player_point != null:
		var player := PLAYER_SCENE.instantiate()
		get_parent().add_child(player)
		player.global_position = player_point.global_position
		_last_point_by_id[player.get_instance_id()] = player_point
	
	# Spawn multiple NPCs based on GameSettings
	var cpu_count := 1
	if has_node("/root/GameSettings"):
		cpu_count = GameSettings.get_cpu_count()
	for i in range(cpu_count):
		var npc_point := _pick_point_for_role("npc", last_point)
		if npc_point != null:
			var npc := NPC_SCENE.instantiate()
			get_parent().add_child(npc)
			npc.global_position = npc_point.global_position
			
			# Assign unique color to each CPU (cycles through palette)
			var color_index := i % CPU_COLORS.size()
			npc.character_color = CPU_COLORS[color_index]
			
			# Apply modulate to tint the sprite
			var sprite := npc.get_node_or_null("AnimatedSprite2D")
			if sprite:
				sprite.modulate = CPU_COLORS[color_index]
			
			_last_point_by_id[npc.get_instance_id()] = npc_point
			last_point = npc_point


func get_spawn_position_for(character: CharacterController) -> Vector2:
	var role := "player" if character.is_player else "npc"
	var last_point: SpawnPoint = _last_point_by_id.get(character.get_instance_id(), null) as SpawnPoint
	var point: SpawnPoint = _pick_point_for_role(role, last_point)
	if point == null:
		# Fallback: center of viewport
		return get_viewport().get_visible_rect().size * 0.5
	_last_point_by_id[character.get_instance_id()] = point
	return point.global_position


func _pick_point_for_role(role: String, avoid_point: SpawnPoint) -> SpawnPoint:
	if _spawn_points.is_empty():
		return null
	# Filter by allowed role
	var candidates: Array[SpawnPoint] = []
	for p in _spawn_points:
		if not is_instance_valid(p):
			continue
		if role == "player" and p.allowed == SpawnPoint.AllowedRole.NPC:
			continue
		if role == "npc" and p.allowed == SpawnPoint.AllowedRole.PLAYER:
			continue
		candidates.append(p)

	if candidates.is_empty():
		# fallback to all points
		candidates = []
		for n in _spawn_points:
			if is_instance_valid(n):
				candidates.append(n)

	# Avoid same point for this character if provided
	if avoid_point != null:
		candidates = candidates.filter(func(x: SpawnPoint): return x != avoid_point)
		if candidates.is_empty():
			candidates = []
			for n in _spawn_points:
				if is_instance_valid(n):
					candidates.append(n)

	# Avoid being too close to any living character
	var safe_candidates: Array[SpawnPoint] = []
	var others: Array = get_tree().get_nodes_in_group("characters")
	for p in candidates:
		var is_safe := true
		for node in others:
			var c := node as CharacterController
			if c == null or c.is_despawned:
				continue
			if p.global_position.distance_to(c.global_position) < SAFE_SPAWN_DISTANCE:
				is_safe = false
				break
		if is_safe:
			safe_candidates.append(p)

	if not safe_candidates.is_empty():
		candidates = safe_candidates

	# Random pick
	candidates.shuffle()
	return candidates[0]


