extends Marker2D
class_name SpawnPoint

enum AllowedRole { ANY, PLAYER, NPC }

@export var allowed: AllowedRole = AllowedRole.ANY
@export var radius: float = 16.0
@export var weight: int = 1

func _ready() -> void:
	add_to_group("spawn_points")


