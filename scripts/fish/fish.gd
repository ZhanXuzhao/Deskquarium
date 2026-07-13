extends Node2D

class_name Fish

enum FishState {
	SWIMMING,
	EATING,
	DEAD,
}

@export var species: int = FishData.Species.GUPPY:
	set(value):
		species = value
		if is_node_ready():
			_update_appearance()

var level: float = 0.0
var auto_sell: bool = false:
	set(value):
		auto_sell = value
		if auto_sell and get_level() >= FishData.get_max_level(species):
			_auto_sell()
var hunger: float = 1.0:
	set(value):
		hunger = clampf(value, 0.0, 1.0)
var state: FishState = FishState.SWIMMING
var swim_speed: float = 60.0
var target_position: Vector2
var direction: float = 1.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var area: Area2D = $Area2D
@onready var level_label: Label = $LevelLabel
@onready var hunger_timer: Timer = $HungerTimer
@onready var state_timer: Timer = $StateTimer
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D

var aquarium_rect: Rect2 = Rect2(50, 50, 700, 450)
var target_food: Node2D = null


func _ready() -> void:
	if collision_shape and collision_shape.shape == null:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(80, 50)
		collision_shape.shape = shape
	
	_update_appearance()
	pick_new_target()
	hunger_timer.start(3.0)
	state_timer.start(2.0)
	area.input_event.connect(_on_input_event)
	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)


func _update_appearance() -> void:
	var tex_path := FishData.get_texture_path(species)
	if ResourceLoader.exists(tex_path):
		var tex := load(tex_path) as Texture2D
		if tex:
			sprite.texture = tex
	
	var scale_factor := 0.5 + level * 0.8 + species * 0.15
	sprite.scale = Vector2(scale_factor, scale_factor) * 0.6
	sprite.flip_h = direction < 0
	
	level_label.text = "Lv.%d" % [get_level()]
	level_label.modulate = Color(1, 1, 1, 0.8)


func _process(delta: float) -> void:
	match state:
		FishState.SWIMMING:
			_swim(delta)
		FishState.EATING:
			_eat(delta)
	
	_update_appearance()


func _swim(delta: float) -> void:
	if target_food and is_instance_valid(target_food):
		state = FishState.EATING
		return
	
	# Look for food on the bottom when hungry
	if hunger < 0.8:
		var food_container := get_parent().get_parent().get_node_or_null("FoodContainer") as Node2D
		if food_container and food_container.get_child_count() > 0:
			var nearest: Node2D = null
			var nearest_dist: float = INF
			for pellet in food_container.get_children():
				if not is_instance_valid(pellet):
					continue
				var pellet_dist := global_position.distance_to(pellet.global_position)
				if pellet_dist < nearest_dist:
					nearest_dist = pellet_dist
					nearest = pellet
			if nearest:
				target_food = nearest
				state = FishState.EATING
				return
	
	var dist := global_position.distance_to(target_position)
	if dist < 10.0:
		pick_new_target()
		return
	
	var dir_vec := (target_position - global_position).normalized()
	var speed := swim_speed * (0.8 + level * 0.4)
	
	global_position += dir_vec * speed * delta
	
	direction = sign(dir_vec.x)
	sprite.flip_h = direction < 0


func _eat(delta: float) -> void:
	if not target_food or not is_instance_valid(target_food):
		target_food = null
		state = FishState.SWIMMING
		return
	
	var dir_vec := (target_food.global_position - global_position).normalized()
	# Lower hunger = faster swimming when competing for food
	var speed_factor := 1.0 + (1.0 - hunger) * 2.0
	var speed := swim_speed * speed_factor
	global_position += dir_vec * speed * delta
	
	direction = sign(dir_vec.x)
	sprite.flip_h = direction < 0
	
	var dist := global_position.distance_to(target_food.global_position)
	if dist < 20.0:
		_eat_food(target_food)


func _eat_food(food: Node2D) -> void:
	hunger = min(1.0, hunger + 0.3)
	# Growth only happens when satiety >= 50%
	if hunger >= 0.5:
		level = min(1.0, level + FishData.get_growth_rate(species))
		_check_auto_sell()
	
	if food.has_method("consume"):
		food.consume()
	
	target_food = null
	state = FishState.SWIMMING
	pick_new_target()
	
	Global.earn(0)


func pick_new_target() -> void:
	var margin := 50.0
	var x := randf_range(aquarium_rect.position.x + margin, aquarium_rect.position.x + aquarium_rect.size.x - margin)
	var y := randf_range(aquarium_rect.position.y + margin, aquarium_rect.position.y + aquarium_rect.size.y - margin)
	target_position = Vector2(x, y)


func set_aquarium_bounds(rect: Rect2) -> void:
	aquarium_rect = rect


func get_level() -> int:
	var max_lv := FishData.get_max_level(species)
	return clamp(1 + int(level * max_lv), 1, max_lv)


func get_sell_price() -> int:
	return FishData.get_sell_price(species, get_level())


func get_sellable() -> bool:
	return true


func feed() -> void:
	hunger = min(1.0, hunger + 0.15)
	# Growth only happens when satiety >= 50%
	if hunger >= 0.5:
		level = min(1.0, level + FishData.get_growth_rate(species) * 0.5)
		_check_auto_sell()


func set_food_target(food: Node2D) -> void:
	if hunger < 0.8:
		target_food = food
		if state == FishState.SWIMMING:
			state = FishState.EATING


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if Global.sell_mode and get_sellable():
				_sell_fish()
			else:
				Global.fish_info_requested.emit(self)


func _on_mouse_entered() -> void:
	if Global.sell_mode:
		modulate = Color(1, 0.6, 0.6, 1)


func _on_mouse_exited() -> void:
	modulate = Color(1, 1, 1, 1)


func sell() -> void:
	var price := get_sell_price()
	Global.earn(price)
	Global.fish_count -= 1
	Global.fish_sold.emit(self, price)
	Global.save_dirty = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)


func _check_auto_sell() -> void:
	if auto_sell and get_level() >= FishData.get_max_level(species):
		_auto_sell()


func _auto_sell() -> void:
	if not is_inside_tree():
		return
	# Brief flash effect before selling
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 0, 1), 0.2)
	tween.tween_callback(sell)


func _sell_fish() -> void:
	sell()


func _on_hunger_timeout() -> void:
	if state == FishState.DEAD:
		return
	hunger -= 0.02


func _on_state_timeout() -> void:
	if state == FishState.SWIMMING and randf() < 0.3:
		pick_new_target()
