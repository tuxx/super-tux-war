extends Node

# Simple game settings singleton
# Stores settings that persist between menu and gameplay

var cpu_count: int = 1  # Number of CPU opponents (1-7)
var player_character: String = "tux"  # Player's selected character
var cpu_character: String = "beasty"  # CPU's selected character
var kills_to_win: int = 10  # Number of kills needed to win
var selected_level_index: int = 0  # Currently selected level in main menu

const MIN_CPU_COUNT: int = 1
const MAX_CPU_COUNT: int = 7
const MIN_KILLS_TO_WIN: int = 3
const MAX_KILLS_TO_WIN: int = 50

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

func set_kills_to_win(kills: int) -> void:
	kills_to_win = clampi(kills, MIN_KILLS_TO_WIN, MAX_KILLS_TO_WIN)

func get_kills_to_win() -> int:
	return kills_to_win

func increase_kills_to_win() -> void:
	set_kills_to_win(kills_to_win + 1)

func decrease_kills_to_win() -> void:
	set_kills_to_win(kills_to_win - 1)

func set_selected_level_index(index: int) -> void:
	selected_level_index = max(0, index)

func get_selected_level_index() -> int:
	return selected_level_index

