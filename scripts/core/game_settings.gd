extends Node

# Simple game settings singleton
# Stores settings that persist between menu and gameplay

var cpu_count: int = 1  # Number of CPU opponents (1-7)
var player_character: String = "tux"  # Player's selected character
var cpu_character: String = "beasty"  # CPU's selected character

const MIN_CPU_COUNT: int = 1
const MAX_CPU_COUNT: int = 7

# Available characters
const AVAILABLE_CHARACTERS: Array[String] = ["tux", "beasty", "gopher"]

func set_cpu_count(count: int) -> void:
	cpu_count = clampi(count, MIN_CPU_COUNT, MAX_CPU_COUNT)

func get_cpu_count() -> int:
	return cpu_count

func increase_cpu_count() -> void:
	set_cpu_count(cpu_count + 1)

func decrease_cpu_count() -> void:
	set_cpu_count(cpu_count - 1)

func set_player_character(character_name: String) -> void:
	if character_name in AVAILABLE_CHARACTERS:
		player_character = character_name

func get_player_character() -> String:
	return player_character

func set_cpu_character(character_name: String) -> void:
	if character_name in AVAILABLE_CHARACTERS:
		cpu_character = character_name

func get_cpu_character() -> String:
	return cpu_character

func get_character_display_name(character_name: String) -> String:
	match character_name:
		"tux":
			return "Tux"
		"beasty":
			return "Beasty"
		"gopher":
			return "Gopher"
		_:
			return character_name.capitalize()

