extends Node

## Singleton that caches character animation SpriteFrames to avoid duplicates.
##
## Creates and caches SpriteFrames for each character type, so all instances
## of the same character share the same animation resources.
## This significantly reduces memory usage when spawning multiple NPCs.

var _cache: Dictionary = {}  # character_name -> SpriteFrames

## Returns cached SpriteFrames for a character, creating if not yet cached.
func get_sprite_frames(character_name: String) -> SpriteFrames:
	if _cache.has(character_name):
		return _cache[character_name]
	
	var frames := _create_sprite_frames(character_name)
	if frames:
		_cache[character_name] = frames
	return frames

func _create_sprite_frames(character_name: String) -> SpriteFrames:
	# Build paths to character spritesheets (try both plural and singular)
	var base_path := ResourcePaths.get_character_spritesheet_path(character_name)
	var base_path_alt := ResourcePaths.get_character_spritesheet_alt_path(character_name)
	
	# Check which path exists
	if not ResourceLoader.exists(base_path + ResourcePaths.CHARACTER_IDLE_SPRITE) and ResourceLoader.exists(base_path_alt + ResourcePaths.CHARACTER_IDLE_SPRITE):
		base_path = base_path_alt
	
	var idle_path := base_path + ResourcePaths.CHARACTER_IDLE_SPRITE
	var jump_path := base_path + ResourcePaths.CHARACTER_JUMP_SPRITE
	var run_path := base_path + ResourcePaths.CHARACTER_RUN_SPRITE
	var skid_path := base_path + ResourcePaths.CHARACTER_SKID_SPRITE
	
	# Try to load textures
	var idle_texture := _load_texture_safe(idle_path)
	var jump_texture := _load_texture_safe(jump_path)
	var run_texture := _load_texture_safe(run_path)
	var skid_texture := _load_texture_safe(skid_path)
	
	# If no textures could be loaded, return null
	if not idle_texture and not jump_texture and not run_texture and not skid_texture:
		push_warning("Could not load animations for character: %s" % character_name)
		return null
	
	# Create new SpriteFrames
	var new_frames := SpriteFrames.new()
	
	# Add idle animation (2 frames, 32x32 each)
	if idle_texture:
		new_frames.add_animation("idle")
		new_frames.set_animation_speed("idle", 4.0)
		new_frames.set_animation_loop("idle", true)
		var idle_frame_1 := AtlasTexture.new()
		idle_frame_1.atlas = idle_texture
		idle_frame_1.region = Rect2(0, 0, 32, 32)
		new_frames.add_frame("idle", idle_frame_1, 1.0, 0)
		var idle_frame_2 := AtlasTexture.new()
		idle_frame_2.atlas = idle_texture
		idle_frame_2.region = Rect2(32, 0, 32, 32)
		new_frames.add_frame("idle", idle_frame_2, 1.0, 1)
	
	# Add jump animation (2 frames, 32x32 each)
	if jump_texture:
		new_frames.add_animation("jump")
		new_frames.set_animation_speed("jump", 5.0)
		new_frames.set_animation_loop("jump", true)
		var jump_frame_1 := AtlasTexture.new()
		jump_frame_1.atlas = jump_texture
		jump_frame_1.region = Rect2(0, 0, 32, 32)
		new_frames.add_frame("jump", jump_frame_1, 1.0, 0)
		var jump_frame_2 := AtlasTexture.new()
		jump_frame_2.atlas = jump_texture
		jump_frame_2.region = Rect2(32, 0, 32, 32)
		new_frames.add_frame("jump", jump_frame_2, 1.0, 1)
	
	# Add run animation (4 frames, 32x32 each)
	if run_texture:
		new_frames.add_animation("run")
		new_frames.set_animation_speed("run", 8.0)
		new_frames.set_animation_loop("run", true)
		for i in range(4):
			var run_frame := AtlasTexture.new()
			run_frame.atlas = run_texture
			run_frame.region = Rect2(i * 32, 0, 32, 32)
			new_frames.add_frame("run", run_frame, 1.0, i)
	
	if skid_texture:
		new_frames.add_animation("skid")
		new_frames.set_animation_speed("skid", 1.0)
		new_frames.set_animation_loop("skid", false)
		var skid_frame := AtlasTexture.new()
		skid_frame.atlas = skid_texture
		skid_frame.region = Rect2(0, 0, 32, 32)
		new_frames.add_frame("skid", skid_frame, 1.0, 0)
	
	return new_frames

func _load_texture_safe(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var texture := load(path)
	if texture is Texture2D:
		return texture
	return null

func clear_cache() -> void:
	_cache.clear()
