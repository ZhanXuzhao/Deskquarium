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
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()
var _auto_sell_triggered: bool = false
var hunger: float = 100.0:
	set(value):
		var max_h := FishData.get_max_hunger(species)
		hunger = clampf(value, 0.0, max_h)
var state: FishState = FishState.SWIMMING
var swim_speed: float = 60.0
var target_position: Vector2
var direction: float = 1.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var area: Area2D = $Area2D
@onready var hunger_timer: Timer = $HungerTimer
@onready var state_timer: Timer = $StateTimer
@onready var depth_timer: Timer = $DepthTimer
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D

var aquarium_rect: Rect2 = Rect2(50, 50, 700, 450)
var target_food: Node2D = null
var _eating_food: bool = false


func _ready() -> void:
	if collision_shape and collision_shape.shape == null:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(80, 50)
		collision_shape.shape = shape
	
	_update_appearance()
	pick_new_target()
	hunger = FishData.get_max_hunger(species)
	hunger_timer.start(20.0)
	state_timer.start(2.0)
	area.input_event.connect(_on_input_event)
	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)
	
	# 深度层级定时器：每隔 1-3 分钟随机刷新一次 z_index
	_restart_depth_timer()
	_update_depth_layer()
	
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)


func _draw() -> void:
	if not selected:
		return
	if sprite == null or sprite.texture == null:
		return
	var tex_size := sprite.texture.get_size()
	var size := tex_size * sprite.scale
	var rect := Rect2(-size / 2, size)
	draw_rect(rect, Color(1, 1, 0, 0.8), false, 2.0)


func _on_hunger_timeout() -> void:
	hunger -= 1.0


func _update_appearance() -> void:
	var tex_path := FishData.get_texture_path(species)
	if ResourceLoader.exists(tex_path):
		var tex := load(tex_path) as Texture2D
		if tex:
			sprite.texture = tex
	
	var base_size := FishData.get_base_size(species)
	var size := base_size * (0.5 + level * 0.5) * Global.fish_scale
	sprite.scale = Vector2(size, size)
	sprite.flip_h = direction < 0
	
	if selected:
		queue_redraw()
	



func _process(delta: float) -> void:
	match state:
		FishState.SWIMMING:
			_swim(delta)
		FishState.EATING:
			_eat(delta)
	
	_update_appearance()
	
	# Auto-sell check: triggers when fish reaches max level with auto_sell enabled
	if Global.auto_sell_enabled and get_level() >= FishData.get_max_level(species):
		_auto_sell()


func _swim(delta: float) -> void:
	if target_food and is_instance_valid(target_food):
		state = FishState.EATING
		return
	
	# Look for food on the bottom when hungry
	if hunger < 90.0:
		var food_container := get_parent().get_parent().get_node_or_null("FoodContainer") as Node2D
		if food_container and food_container.get_child_count() > 0:
			var nearest: Node2D = null
			var nearest_dist: float = INF
			for pellet in food_container.get_children():
				if not is_instance_valid(pellet):
					continue
				if pellet is FoodPellet and pellet.consumed:
					continue
				var pellet_dist := position.distance_to(pellet.position)
				if pellet_dist < nearest_dist:
					nearest_dist = pellet_dist
					nearest = pellet
			if nearest:
				target_food = nearest
				state = FishState.EATING
				return
	
	var dist := position.distance_to(target_position)
	if dist < 10.0:
		pick_new_target()
		return
	
	var dir_vec := (target_position - position).normalized()
	var speed := swim_speed * (0.8 + level * 0.4)
	
	position += dir_vec * speed * delta
	# 限制鱼在边界内
	var margin := 10.0
	position.x = clampf(position.x, aquarium_rect.position.x + margin, aquarium_rect.position.x + aquarium_rect.size.x - margin)
	position.y = clampf(position.y, aquarium_rect.position.y + margin, aquarium_rect.position.y + aquarium_rect.size.y - margin)
	
	direction = sign(dir_vec.x)
	sprite.flip_h = direction < 0


func _eat(delta: float) -> void:
	if not target_food or not is_instance_valid(target_food):
		target_food = null
		state = FishState.SWIMMING
		return
	
	# 计算鱼头偏移：使鱼头（而非鱼身中心）靠近食物
	var head_offset := 20.0
	if sprite and sprite.texture:
		head_offset = sprite.texture.get_width() * sprite.scale.x * 0.45
	
	# 根据靠近方向调整目标位置，让鱼头抵达食物位置
	var approach_dir: float = sign(target_food.position.x - position.x)
	var target_pos := target_food.position
	target_pos.x -= approach_dir * head_offset
	
	var dir_vec := (target_pos - position).normalized()
	# Lower hunger = faster swimming when competing for food
	var max_h := FishData.get_max_hunger(species)
	var speed_factor := 1.0 + (1.0 - hunger / max_h) * 2.0
	var speed := swim_speed * speed_factor
	position += dir_vec * speed * delta
	# 限制鱼在边界内
	var margin := 10.0
	position.x = clampf(position.x, aquarium_rect.position.x + margin, aquarium_rect.position.x + aquarium_rect.size.x - margin)
	position.y = clampf(position.y, aquarium_rect.position.y + margin, aquarium_rect.position.y + aquarium_rect.size.y - margin)
	
	# 吃食期间固定朝向食物方向，避免反复转向
	direction = approach_dir
	sprite.flip_h = direction < 0
	
	# 正在吃食中则等待动画结束
	if _eating_food:
		return
	
	var dist := position.distance_to(target_pos)
	if dist < 20.0 and not (target_food is FoodPellet and target_food.consumed):
		_eat_food(target_food)


func _eat_food(food: Node2D) -> void:
	_eating_food = true
	hunger += 10.0
	# Growth only happens when satiety >= 50%
	if hunger >= FishData.get_max_hunger(species) * 0.5:
		level = min(1.0, level + FishData.get_growth_rate(species))
		_check_auto_sell()
	
	if food.has_method("consume"):
		food.consume()
	
	# 等待1秒吃食动画（食物震动）
	await get_tree().create_timer(1.0).timeout
	
	target_food = null
	state = FishState.SWIMMING
	pick_new_target()
	
	_eating_food = false
	
	Global.earn(0)


func pick_new_target() -> void:
	var margin := 50.0
	var x := randf_range(aquarium_rect.position.x + margin, aquarium_rect.position.x + aquarium_rect.size.x - margin)
	var y := randf_range(aquarium_rect.position.y + margin, aquarium_rect.position.y + aquarium_rect.size.y - margin)
	target_position = Vector2(x, y)


func set_aquarium_bounds(rect: Rect2) -> void:
	aquarium_rect = rect


# ── 动态深度层级 ──────────────────────────────────────────────────────────
# 根据鱼的 Y 坐标动态更新 z_index，范围 [0, max(装饰 z_index) + 1]，
# 使鱼游动时自然地在装饰物前后穿插。

func _update_depth_layer() -> void:
	var fish_container := get_parent() as Node2D
	if fish_container == null:
		return
	var aquarium := fish_container.get_parent() as Node2D
	if aquarium == null:
		return
	var deco_container := aquarium.get_node_or_null("DecorationContainer") as Node2D
	if deco_container == null:
		return
	
	# 查找所有装饰物的最大 z_index
	var max_deco_z := 0
	for deco in deco_container.get_children():
		if deco is Sprite2D:
			max_deco_z = max(max_deco_z, deco.z_index)
	
	# 将鱼在鱼缸中的 Y 坐标映射到 z_index 范围
	# Y 越大（越靠下）→ z_index 越高（显示在前面）
	var t := inverse_lerp(0.0, Global.DESIGN_HEIGHT, position.y)
	t = clampf(t, 0.0, 1.0)
	z_index = int(lerp(0.0, float(max_deco_z + 1), t))


# ── 定时刷新深度层级 ──────────────────────────────────────────────────────
# 每隔 1-3 分钟重新随机设置鱼的 z_index，在装饰物前后自然穿插

func _on_depth_timeout() -> void:
	_update_depth_layer()
	_restart_depth_timer()


func _restart_depth_timer() -> void:
	var interval := randf_range(60.0, 180.0)  # 1~3 分钟
	depth_timer.wait_time = interval
	depth_timer.start()


func get_level() -> int:
	var max_lv := FishData.get_max_level(species)
	return clamp(1 + int(level * max_lv), 1, max_lv)


func get_sell_price() -> int:
	return FishData.get_sell_price(species, get_level())


func get_sellable() -> bool:
	return true


func feed() -> void:
	hunger += 10.0
	# Growth only happens when satiety >= 50%
	if hunger >= FishData.get_max_hunger(species) * 0.5:
		level = min(1.0, level + FishData.get_growth_rate(species) * 0.5)
		_check_auto_sell()


func set_food_target(food: Node2D) -> void:
	if hunger >= 90.0:
		return
	
	if food is FoodPellet and food.consumed:
		return
	
	# 仅在新的食物距离更近时才切换目标，确保鱼优先选择最近的鱼食
	if target_food != null and is_instance_valid(target_food):
		var current_dist := position.distance_squared_to(target_food.position)
		var new_dist := position.distance_squared_to(food.position)
		if new_dist >= current_dist:
			return
	
	target_food = food
	if state == FishState.SWIMMING:
		state = FishState.EATING


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			if Global.decoration_placement_active:
				return
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
	
	_show_sell_label(price)
	
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


func _show_sell_label(price: int) -> void:
	var label := Label.new()
	label.text = "+%d$" % price
	label.add_theme_color_override("font_color", Color(1, 0.85, 0, 1))
	label.add_theme_font_size_override("font_size", 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = global_position - Vector2(0, 20)
	label.z_index = 100
	
	get_parent().add_child(label)
	
	var tween := label.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position", label.position + Vector2(0, -80), 3.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(2.5)
	tween.tween_callback(label.queue_free)


func _check_auto_sell() -> void:
	if Global.auto_sell_enabled and get_level() >= FishData.get_max_level(species):
		_auto_sell()


func _auto_sell() -> void:
	if _auto_sell_triggered or not is_inside_tree():
		return
	_auto_sell_triggered = true
	# Brief flash effect before selling
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 0, 1), 0.2)
	tween.tween_callback(sell)


func _sell_fish() -> void:
	sell()


func _on_state_timeout() -> void:
	if state == FishState.SWIMMING and randf() < 0.3:
		pick_new_target()
