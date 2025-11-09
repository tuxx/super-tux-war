extends Node

## Central event bus for decoupled communication across systems.
##
## All game events are emitted through this singleton to avoid tight coupling
## between systems. Systems can subscribe to events without knowing about each other.

## Game state events
@warning_ignore("unused_signal")
signal game_paused
@warning_ignore("unused_signal")
signal game_resumed
@warning_ignore("unused_signal")
signal game_state_changed(from_state: String, to_state: String)

## Match events
@warning_ignore("unused_signal")
signal match_started
@warning_ignore("unused_signal")
signal match_ended(winner: CharacterController)
@warning_ignore("unused_signal")
signal win_condition_met(winner: CharacterController)
@warning_ignore("unused_signal")
signal character_killed(killer: CharacterController, victim: CharacterController)

## Scene events
@warning_ignore("unused_signal")
signal scene_changing(from_path: String, to_path: String)
@warning_ignore("unused_signal")
signal scene_changed(scene_path: String)
@warning_ignore("unused_signal")
signal level_loaded(level_path: String)

## UI events
@warning_ignore("unused_signal")
signal ui_notification(message: String, type: String)
