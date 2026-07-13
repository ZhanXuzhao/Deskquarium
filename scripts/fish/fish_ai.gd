extends Node

class_name FishAI


static func get_random_position(bounds: Rect2, margin: float = 50.0) -> Vector2:
	var x := randf_range(bounds.position.x + margin, bounds.position.x + bounds.size.x - margin)
	var y := randf_range(bounds.position.y + margin, bounds.position.y + bounds.size.y - margin)
	return Vector2(x, y)


static func is_fish_in_bounds(pos: Vector2, bounds: Rect2) -> bool:
	return bounds.has_point(pos)
