extends Node2D

class_name Aquarium

@onready var fish_container: Node2D = $FishContainer
@onready var food_container: Node2D = $FoodContainer
@onready var decoration_container: Node2D = $DecorationContainer
@onready var bg_sprite: Sprite2D = $Background
@onready var click_area: Area2D = $ClickArea

var aquarium_rect: Rect2 = Rect2(40, 60, 750, 460)
var food_pellets: Array[Node2D] = []


func _ready() -> void:
	Global.fish_added.connect(_on_fish_added)
	Global.decoration_added.connect(_on_decoration_added)
	
	if bg_sprite and bg_sprite.texture:
		var tex_size := bg_sprite.texture.get_size() as Vector2
		scale_aquarium_size(tex_size)


func scale_aquarium_size(tex_size: Vector2) -> void:
	var screen_size := get_viewport_rect().size
	var scale_factor: float = min(
		screen_size.x / tex_size.x,
		screen_size.y / tex_size.y
	) * 0.9
	scale = Vector2(scale_factor, scale_factor)


func _on_fish_added(fish: Node2D) -> void:
	fish_container.add_child(fish)
	if fish.has_method("set_aquarium_bounds"):
		fish.set_aquarium_bounds(aquarium_rect)


func _on_decoration_added(deco_type: int) -> void:
	var svg_path := DecorationData.get_svg_path(deco_type)
	if ResourceLoader.exists(svg_path):
		var deco := Sprite2D.new()
		deco.texture = load(svg_path)
		var margin := 100.0
		var x := randf_range(aquarium_rect.position.x + margin, aquarium_rect.position.x + aquarium_rect.size.x - margin)
		var y := randf_range(aquarium_rect.position.y + aquarium_rect.size.y * 0.5, aquarium_rect.position.y + aquarium_rect.size.y - 20)
		deco.position = Vector2(x, y)
		deco.scale = Vector2(0.5, 0.5)
		decoration_container.add_child(deco)


func spawn_food() -> void:
	if not Global.can_afford(10):
		return
	if not Global.spend(10):
		return
	
	var pellet_scene := preload("res://scenes/food/food_pellet.tscn")
	var count := randi_range(2, 4)
	for i in count:
		var pellet := pellet_scene.instantiate()
		var margin := 80.0
		var x := randf_range(aquarium_rect.position.x + margin, aquarium_rect.position.x + aquarium_rect.size.x - margin)
		pellet.position = Vector2(x, aquarium_rect.position.y + 20)
		pellet.bottom_y = aquarium_rect.position.y + aquarium_rect.size.y - 10
		food_container.add_child(pellet)
		food_pellets.append(pellet)
		pellet.tree_exited.connect(_on_pellet_removed.bind(pellet))


func _on_pellet_removed(pellet: Node2D) -> void:
	food_pellets.erase(pellet)


func get_nearest_food(fish_pos: Vector2) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for pellet in food_pellets:
		if not is_instance_valid(pellet):
			continue
		var dist := fish_pos.distance_to(pellet.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = pellet
	return nearest
