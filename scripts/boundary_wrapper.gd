extends Node2D

# Offset to prevent oscillation when wrapping
@export var wrap_offset: float = 10.0

# Called every frame to check for boundary wrapping
func _physics_process(_delta: float) -> void:
	# Determine bounds from the current viewport each frame
	var visible_rect: Rect2 = get_viewport().get_visible_rect()
	# Check all CharacterBody2D children in the parent node
	for child in get_parent().get_children():
		if child is CharacterBody2D:
			_check_wrap(child, visible_rect)

# Test if character position exceeds boundaries and wrap if needed
func _check_wrap(character: CharacterBody2D, rect: Rect2) -> void:
	_wrap_horizontal(character, rect)
	_wrap_vertical(character, rect)

# Handle left/right edge wrapping
func _wrap_horizontal(character: CharacterBody2D, rect: Rect2) -> void:
	var left: float = rect.position.x
	var right: float = rect.position.x + rect.size.x
	if character.position.x > right:
		character.position.x = left + wrap_offset
	elif character.position.x < left:
		character.position.x = right - wrap_offset

# Handle top/bottom edge wrapping
func _wrap_vertical(character: CharacterBody2D, rect: Rect2) -> void:
	var top: float = rect.position.y
	var bottom: float = rect.position.y + rect.size.y
	if character.position.y > bottom:
		character.position.y = top + wrap_offset
	elif character.position.y < top:
		character.position.y = bottom - wrap_offset
