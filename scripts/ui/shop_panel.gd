extends Control

class_name ShopPanel

@onready var fish_list: GridContainer = %FishList
@onready var decoration_list: GridContainer = %DecorationList
@onready var tab_container: TabContainer = %TabContainer


func _ready() -> void:
	Global.coins_changed.connect(_on_coins_changed)
	_populate_fish_shop()
	_populate_decoration_shop()


func _on_coins_changed(_amount: int) -> void:
	_refresh_buttons()


func _populate_fish_shop() -> void:
	for c in fish_list.get_children():
		c.queue_free()
	
	_update_fish_columns()
	
	for species in FishData.Species.values() as Array[int]:
		if species == FishData.Species.COUNT:
			continue
		
		_add_fish_entry(species)


func _update_fish_columns() -> void:
	var available := fish_list.size.x
	if available <= 0:
		available = 960.0
	fish_list.columns = maxi(1, int(available / 160))


func _add_fish_entry(species: int) -> void:
	var card_scene := preload("res://scenes/ui/fish_card/fish_card.tscn")
	var card := card_scene.instantiate() as FishCard
	fish_list.add_child(card)
	card.setup(species)
	card.buy_pressed.connect(_on_buy_fish)


func _populate_decoration_shop() -> void:
	for c in decoration_list.get_children():
		c.queue_free()
	
	for deco_type in DecorationData.DecorationType.values() as Array[int]:
		if deco_type == DecorationData.DecorationType.COUNT:
			continue
		_add_decoration_entry(deco_type)


func _add_decoration_entry(deco_type: int) -> void:
	var card_scene := preload("res://scenes/ui/decoration_card/decoration_card.tscn")
	var card := card_scene.instantiate() as DecorationCard
	decoration_list.add_child(card)
	card.setup(deco_type)
	card.buy_pressed.connect(_on_buy_decoration)


func _on_buy_fish(species: int) -> void:
	var cost: int = FishData.get_buy_cost(species)
	if not Global.can_add_fish():
		return
	if Global.spend(cost):
		var fish_scene := preload("res://scenes/fish/fish.tscn")
		var fish := fish_scene.instantiate()
		fish.species = species
		Global.fish_count += 1
		Global.fish_added.emit(fish)
		Global.save_dirty = true
		_refresh_buttons()


func _on_buy_decoration(deco_type: int) -> void:
	var cost: int = DecorationData.get_cost(deco_type)
	if Global.spend(cost):
		Global.owned_decorations.append({"type": deco_type, "x": 0, "y": 0, "scale_x": 0.5, "scale_y": 0.5})
		Global.decoration_added.emit(deco_type)
		Global.save_dirty = true
		_refresh_buttons()


func _refresh_buttons() -> void:
	_populate_fish_shop()
	_populate_decoration_shop()
