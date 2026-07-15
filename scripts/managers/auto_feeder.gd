extends Node2D

class_name AutoFeeder

## 自动投喂机检测间隔（秒）
var check_interval: float = 5.0
var _elapsed: float = 0.0

## 每次投喂花费
var feed_cost: int = 10


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= check_interval:
		_elapsed = 0.0
		_try_auto_feed()


func _try_auto_feed() -> void:
	if not is_inside_tree():
		return
	
	if not Global.auto_feeder_enabled:
		return
	
	# 查找鱼缸中的食物容器
	var aquarium := get_parent().get_parent()  # EquipmentContainer -> Aquarium -> Main
	if not aquarium:
		return
	
	var food_container := aquarium.get_node_or_null("FoodContainer") as Node2D
	if not food_container:
		return
	
	# 至少有一条鱼饱食度低于 50% 时才投喂
	var fish_container := aquarium.get_node_or_null("FishContainer") as Node2D
	if fish_container:
		var any_hungry := false
		for fish in fish_container.get_children():
			if fish.has_method("get_hunger") and fish.hunger < 0.5:
				any_hungry = true
				break
		if not any_hungry:
			return
	
	# 如果鱼缸中没有鱼食，则自动投喂
	if food_container.get_child_count() == 0:
		_do_auto_feed(food_container)


func _do_auto_feed(food_container: Node2D) -> void:
	var total_cost: int = Global.auto_feeder_feed_count * 1
	if not Global.can_afford(total_cost):
		return
	if not Global.spend(total_cost):
		return
	
	var aquarium_rect := _get_aquarium_rect()
	if aquarium_rect.size.x <= 0:
		return
	
	var pellet_scene := preload("res://scenes/food/food_pellet.tscn")
	var pellet_script := preload("res://scripts/food/food_pellet.gd")
	
	for i in Global.auto_feeder_feed_count:
		var pellet := pellet_scene.instantiate()
		pellet.set_script(pellet_script)
		var margin := 80.0
		var x := randf_range(aquarium_rect.position.x + margin, aquarium_rect.position.x + aquarium_rect.size.x - margin)
		pellet.position = Vector2(x, aquarium_rect.position.y + 20)
		pellet.bottom_y = aquarium_rect.position.y + aquarium_rect.size.y - 10
		food_container.add_child(pellet)
		
		# 通知鱼有新的食物
		var fish_container := food_container.get_parent().get_node_or_null("FishContainer")
		if fish_container:
			for fish in fish_container.get_children():
				if fish.has_method("set_food_target"):
					fish.set_food_target(pellet)


func _get_aquarium_rect() -> Rect2:
	# 使用设计空间坐标（Aquarium 的缩放由 main.gd 处理）
	var margin := 50.0
	var top_margin := 80.0
	var right_margin := 100.0
	var bottom_margin := 20.0
	return Rect2(margin, top_margin, Global.DESIGN_WIDTH - margin - right_margin, Global.DESIGN_HEIGHT - top_margin - bottom_margin)
