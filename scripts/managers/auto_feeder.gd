extends Node2D

class_name AutoFeeder

## 自动投喂机检测间隔（秒）
var check_interval: float = 5.0
var _elapsed: float = 0.0

## 每次投喂的鱼食数量
var feed_count: int = 3
## 每次投喂花费
var feed_cost: int = 10

var sprite: Sprite2D


func _ready() -> void:
	# 创建精灵节点作为视觉外观
	sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	add_child(sprite)
	
	var tex := load("res://assets/food_pellet.svg") as Texture2D
	if tex:
		sprite.texture = tex
	
	sprite.scale = Vector2(2.0, 2.0)
	sprite.modulate = Color(0.6, 0.8, 1.0, 0.9)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= check_interval:
		_elapsed = 0.0
		_try_auto_feed()


func _try_auto_feed() -> void:
	if not is_inside_tree():
		return
	
	# 查找鱼缸中的食物容器
	var aquarium := get_parent().get_parent()  # EquipmentContainer -> Aquarium -> Main
	if not aquarium:
		return
	
	var food_container := aquarium.get_node_or_null("FoodContainer") as Node2D
	if not food_container:
		return
	
	# 如果鱼缸中没有鱼食，则自动投喂
	if food_container.get_child_count() == 0:
		_do_auto_feed(food_container)


func _do_auto_feed(food_container: Node2D) -> void:
	if not Global.can_afford(feed_cost):
		return
	if not Global.spend(feed_cost):
		return
	
	var aquarium_rect := _get_aquarium_rect()
	if aquarium_rect.size.x <= 0:
		return
	
	var pellet_scene := preload("res://scenes/food/food_pellet.tscn")
	var pellet_script := preload("res://scripts/food/food_pellet.gd")
	
	for i in feed_count:
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
	var view_size := get_viewport_rect().size
	var margin := 50.0
	var top_margin := 80.0
	var right_margin := 100.0
	var bottom_margin := 20.0
	return Rect2(margin, top_margin, view_size.x - margin - right_margin, view_size.y - top_margin - bottom_margin)
