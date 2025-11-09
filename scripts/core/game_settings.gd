extends Node

# Simple game settings singleton
# Stores settings that persist between menu and gameplay

var cpu_count: int = 1  # Number of CPU opponents (1-7)

const MIN_CPU_COUNT: int = 1
const MAX_CPU_COUNT: int = 7

func set_cpu_count(count: int) -> void:
	cpu_count = clampi(count, MIN_CPU_COUNT, MAX_CPU_COUNT)

func get_cpu_count() -> int:
	return cpu_count

func increase_cpu_count() -> void:
	set_cpu_count(cpu_count + 1)

func decrease_cpu_count() -> void:
	set_cpu_count(cpu_count - 1)

