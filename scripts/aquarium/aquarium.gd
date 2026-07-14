extends Node2D

class_name Aquarium

@onready var fish_container: Node2D = $FishContainer
@onready var food_container: Node2D = $FoodContainer
@onready var decoration_container: Node2D = $DecorationContainer
@onready var click_area: Area2D = $ClickArea

var food_pellets: Array[Node2D] = []

# 水面高度比例（占视口高度百分比，0.0~1.0）
var water_surface_height_ratio: float = 0.06:
	set(value):
		water_surface_height_ratio = clampf(value, 0.0, 0.5)
		_update_water_surface()

var _water_surface: ColorRect = null
var _water_surface_material: ShaderMaterial = null


# 鱼缸边界 = 设计分辨率空间
var aquarium_rect: Rect2:
	get:
		return Rect2(0, 0, Global.DESIGN_WIDTH, Global.DESIGN_HEIGHT)


func _ready() -> void:
	Global.fish_added.connect(_on_fish_added)
	Global.decoration_added.connect(_on_decoration_added)
	# 不再设置 Aquarium 节点的缩放，由 main.gd 直接控制背景
	_setup_water_surface()


func _setup_water_surface() -> void:
	var shader := preload("res://shaders/water_surface.gdshader") as Shader
	if shader == null:
		return
	
	_water_surface_material = ShaderMaterial.new()
	_water_surface_material.shader = shader
	
	_water_surface = ColorRect.new()
	_water_surface.name = "WaterSurface"
	_water_surface.material = _water_surface_material
	_water_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_water_surface)
	
	_update_water_surface()


func _update_water_surface() -> void:
	if _water_surface == null:
		return
	
	var surf_height := Global.DESIGN_HEIGHT * water_surface_height_ratio
	
	_water_surface.size = Vector2(Global.DESIGN_WIDTH, surf_height)
	_water_surface.position = Vector2.ZERO


func set_water_surface_height_ratio(value: float) -> void:
	water_surface_height_ratio = value


func _on_fish_added(fish: Node2D) -> void:
	fish_container.add_child(fish)
	if fish.has_method("set_aquarium_bounds"):
		fish.set_aquarium_bounds(aquarium_rect)


func _on_decoration_added(deco_type: int) -> void:
	var deco := Global.make_decoration_sprite(deco_type)
	if deco == null:
		return
	var margin := 100.0
	var x := randf_range(aquarium_rect.position.x + margin, aquarium_rect.position.x + aquarium_rect.size.x - margin)
	var y := randf_range(aquarium_rect.position.y + aquarium_rect.size.y * 0.5, aquarium_rect.position.y + aquarium_rect.size.y - 20)
	deco.position = Vector2(x, y)
	_connect_decoration_interaction(deco)
	decoration_container.add_child(deco)


func _connect_decoration_interaction(deco: Sprite2D) -> void:
	"""为装饰物连接出售模式的点击和悬停交互"""
	var area := deco.get_node_or_null("ClickArea") as Area2D
	if area == null:
		return
	
	area.input_event.connect(func(_viewport: Node, event: InputEvent, _shape_idx: int):
		if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			return
		if not Global.sell_mode:
			return
		Global.sell_decoration_sprite(deco)
	)
	
	area.mouse_entered.connect(func():
		if Global.sell_mode:
			deco.modulate = Color(1, 0.6, 0.6, 1)
	)
	
	area.mouse_exited.connect(func():
		deco.modulate = Color(1, 1, 1, 1)
	)
	
	# 出售模式关闭时恢复装饰物颜色
	Global.sell_mode_changed.connect(func(active: bool):
		if not is_instance_valid(deco):
			return
		if not active:
			deco.modulate = Color(1, 1, 1, 1)
	)


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
