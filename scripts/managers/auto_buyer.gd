extends Node2D

class_name AutoBuyer

## 自动买鱼检测间隔（秒）
var check_interval: float = 3.0
var _elapsed: float = 0.0

var sprite: Sprite2D


func _ready() -> void:
	# 创建精灵节点作为视觉外观
	sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	add_child(sprite)
	
	var tex := load("res://assets/ui/ui_coin.svg") as Texture2D
	if tex:
		sprite.texture = tex
	
	sprite.scale = Vector2(1.0, 1.0)
	sprite.modulate = Color(1.0, 0.9, 0.3, 0.9)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= check_interval:
		_elapsed = 0.0
		_try_auto_buy()


func _try_auto_buy() -> void:
	if not is_inside_tree():
		return
	
	if not Global.has_auto_buy:
		return
	
	var aquarium := get_parent().get_parent()  # EquipmentContainer -> Aquarium -> Main
	if not aquarium:
		return
	
	var fish_container := aquarium.get_node_or_null("FishContainer") as Node2D
	if not fish_container:
		return
	
	var targets: Dictionary = Global.auto_buy_targets
	if targets.is_empty():
		return
	
	# 遍历每种鱼的期望数量
	for species_key in targets.keys():
		var species: int = int(species_key)
		var target_count: int = targets[species_key]
		if target_count <= 0:
			continue
		
		# 计算当前鱼缸中该品种的数量
		var current_count: int = 0
		for fish in fish_container.get_children():
			if fish is Fish and fish.species == species:
				current_count += 1
		
		# 如果不足且还能加鱼且钱够，则买一条
		if current_count < target_count and Global.can_add_fish():
			var cost: int = FishData.get_buy_cost(species)
			if Global.can_afford(cost):
				_buy_fish(species, fish_container)
				return  # 一次只买一条，避免在同一帧花太多钱


func _buy_fish(species: int, _fish_container: Node2D) -> void:
	var cost: int = FishData.get_buy_cost(species)
	if not Global.spend(cost):
		return
	
	var fish_scene := preload("res://scenes/fish/fish.tscn")
	var fish_script := preload("res://scripts/fish/fish.gd")
	var fish := fish_scene.instantiate()
	fish.set_script(fish_script)
	fish.species = species
	Global.fish_count += 1
	Global.fish_added.emit(fish)
	Global.save_dirty = true
