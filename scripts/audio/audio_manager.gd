extends Node

## Central audio manager for all game sounds and music.
##
## Manages procedural sound generation, audio playback with polyphony,
## and spatial audio positioning. Provides consistent API for playing
## game sounds with automatic variation.

var sound_generator: SoundGenerator
var sfx_players: Array[AudioStreamPlayer2D] = []
const SFX_PLAYER_COUNT := 16  # Pool size for simultaneous sounds

# Pre-generated sound cache (multiple variations per type)
var _jump_sounds: Array[AudioStreamWAV] = []
var _death_sounds: Array[AudioStreamWAV] = []
var _stomp_sounds: Array[AudioStreamWAV] = []
var _spawn_sounds: Array[AudioStreamWAV] = []
var _footstep_sounds: Array[AudioStreamWAV] = []

const VARIATIONS_PER_SOUND := 4  # Pre-generate 4 variations of each sound

func _ready() -> void:
	sound_generator = SoundGenerator.new()
	add_child(sound_generator)
	
	# Pre-generate sound variations
	_pregenerate_sounds()
	
	# Create pool of 2D audio players for spatial sound
	for i in range(SFX_PLAYER_COUNT):
		var player := AudioStreamPlayer2D.new()
		player.bus = "SFX"
		player.max_distance = 2000.0
		player.attenuation = 2.0
		add_child(player)
		sfx_players.append(player)

## Pre-generates sound variations to avoid runtime generation lag.
func _pregenerate_sounds() -> void:
	for i in range(VARIATIONS_PER_SOUND):
		_jump_sounds.append(sound_generator.generate_jump())
		_death_sounds.append(sound_generator.generate_death())
		_stomp_sounds.append(sound_generator.generate_stomp())
		_spawn_sounds.append(sound_generator.generate_spawn())
		_footstep_sounds.append(sound_generator.generate_footstep())

## Plays a jump sound at the given position.
func play_jump(global_position: Vector2 = Vector2.ZERO) -> void:
	var stream := _get_random_sound(_jump_sounds)
	_play_at_position(stream, global_position, 0.4, randf_range(0.95, 1.05))

## Plays a death sound at the given position.
func play_death(global_position: Vector2 = Vector2.ZERO) -> void:
	var stream := _get_random_sound(_death_sounds)
	_play_at_position(stream, global_position, 0.5, randf_range(0.9, 1.1))

## Plays a stomp/landing sound at the given position.
func play_stomp(global_position: Vector2 = Vector2.ZERO) -> void:
	var stream := _get_random_sound(_stomp_sounds)
	_play_at_position(stream, global_position, 0.6, randf_range(0.9, 1.1))

## Plays a footstep sound at the given position.
func play_footstep(global_position: Vector2 = Vector2.ZERO) -> void:
	var stream := _get_random_sound(_footstep_sounds)
	_play_at_position(stream, global_position, 0.25, randf_range(0.95, 1.05))

## Plays a spawn/respawn shimmer sound at the given position.
func play_spawn(global_position: Vector2 = Vector2.ZERO) -> void:
	var stream := _get_random_sound(_spawn_sounds)
	_play_at_position(stream, global_position, 0.35, randf_range(0.95, 1.05))

## Returns a random sound from a pre-generated array.
func _get_random_sound(sounds: Array[AudioStreamWAV]) -> AudioStreamWAV:
	if sounds.is_empty():
		push_error("Sound array is empty!")
		return null
	return sounds[randi() % sounds.size()]

## Internal: Plays a stream at a position with given volume and pitch variation.
func _play_at_position(stream: AudioStream, global_position: Vector2, volume_linear: float, pitch_scale: float = 1.0) -> void:
	if stream == null:
		return
	
	# Find available player from pool
	var player: AudioStreamPlayer2D = null
	for p in sfx_players:
		if not p.playing:
			player = p
			break
	
	# If all players busy, steal the oldest one (first in array)
	if player == null:
		player = sfx_players[0]
	
	# Configure and play
	player.stream = stream
	player.global_position = global_position
	player.volume_db = linear_to_db(volume_linear)
	player.pitch_scale = pitch_scale
	player.play()

## Sets master volume (0.0 to 1.0).
func set_master_volume(volume: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(volume) if volume > 0 else -80.0)

## Sets SFX volume (0.0 to 1.0).
func set_sfx_volume(volume: float) -> void:
	var bus_idx := AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(volume) if volume > 0 else -80.0)

## Sets music volume (0.0 to 1.0).
func set_music_volume(volume: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(volume) if volume > 0 else -80.0)

