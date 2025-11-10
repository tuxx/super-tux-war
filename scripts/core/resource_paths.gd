class_name ResourcePaths

## Centralized resource paths to avoid hardcoded strings throughout the codebase.
##
## Provides constants and helper functions for all asset and scene paths.
## Makes it easy to refactor file locations without hunting through code.

# Scene paths
const SCENE_START_MENU := "res://scenes/ui/start_menu.tscn"
const SCENE_LEVEL_01 := "res://scenes/levels/level01.tscn"

# Character asset paths
const CHARACTER_SPRITESHEETS := "res://assets/characters/%s/spritesheets/"
const CHARACTER_SPRITESHEET_ALT := "res://assets/characters/%s/spritesheet/"
const CHARACTER_IDLE_SPRITE := "idle.png"
const CHARACTER_JUMP_SPRITE := "jump.png"
const CHARACTER_RUN_SPRITE := "run.png"
const CHARACTER_SKID_SPRITE := "skid.png"
const CHARACTER_PORTRAIT := "res://assets/characters/%s/base-16x16.png"

# Level asset paths
const LEVEL_THUMBS_DIR := "res://assets/level_thumbs"
const LEVEL_THUMB_FORMAT := "res://assets/level_thumbs/%s.png"
const LEVELS_DIR := "res://scenes/levels"
const LEVEL_FORMAT := "res://scenes/levels/%s.tscn"

## Helper functions

static func get_character_spritesheet_path(character_name: String) -> String:
	return CHARACTER_SPRITESHEETS % character_name

static func get_character_spritesheet_alt_path(character_name: String) -> String:
	return CHARACTER_SPRITESHEET_ALT % character_name

static func get_character_portrait_path(character_name: String) -> String:
	return CHARACTER_PORTRAIT % character_name

static func get_level_thumbnail_path(level_name: String) -> String:
	return LEVEL_THUMB_FORMAT % level_name

static func get_level_scene_path(level_name: String) -> String:
	return LEVEL_FORMAT % level_name
