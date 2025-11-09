extends RigidBody2D

@export var lifetime_seconds: float = 10.0

func _ready() -> void:
	var timer := get_tree().create_timer(lifetime_seconds)
	timer.timeout.connect(_on_lifetime_timeout)

func _on_lifetime_timeout() -> void:
	queue_free()


