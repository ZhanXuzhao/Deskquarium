extends Node

signal coins_changed(amount: int)
signal total_earned_changed(amount: int)
signal fish_added(fish: Node2D)
signal fish_removed(fish: Node2D)
signal fish_sold(fish: Node2D, price: int)
signal fish_unlocked(species: int)
signal decoration_added(deco_type: int)
signal feed_mode_changed(active: bool)
signal sell_mode_changed(active: bool)
signal shop_panel_toggled(visible: bool)
signal decoration_shop_toggled(visible: bool)
signal fish_info_requested(fish: Node2D)
signal game_loaded()

var coins: int = 5000:
	set(value):
		coins = max(value, 0)
		coins_changed.emit(coins)
		save_dirty = true

var total_earned: int = 0:
	set(value):
		total_earned = value
		total_earned_changed.emit(total_earned)
		save_dirty = true

var unlocked_species: Array[bool] = []
var owned_decorations: Array[int] = []
var save_dirty: bool = false
var fish_count: int = 0
var max_fish: int = 6

var feed_mode: bool = false:
	set(value):
		feed_mode = value
		if value:
			sell_mode = false
		feed_mode_changed.emit(value)

var sell_mode: bool = false:
	set(value):
		sell_mode = value
		if value:
			feed_mode = false
		sell_mode_changed.emit(value)


func _ready() -> void:
	unlocked_species.resize(FishData.Species.COUNT)
	unlocked_species[FishData.Species.GUPPY] = true


func can_afford(cost: int) -> bool:
	return coins >= cost


func spend(amount: int) -> bool:
	if coins >= amount:
		coins -= amount
		return true
	return false


func earn(amount: int) -> void:
	coins += amount
	total_earned += amount
	check_unlocks()


func check_unlocks() -> void:
	var changed := false
	for species in FishData.Species.values() as Array[int]:
		if species == FishData.Species.COUNT:
			continue
		if unlocked_species[species]:
			continue
		var req = FishData.get_unlock_requirement(species)
		if req.type == "none":
			unlocked_species[species] = true
			changed = true
			fish_unlocked.emit(species)
		elif req.type == "total_earned" and total_earned >= req.value:
			unlocked_species[species] = true
			changed = true
			fish_unlocked.emit(species)
	if changed:
		save_dirty = true


func can_add_fish() -> bool:
	return fish_count < max_fish


func get_save_data() -> Dictionary:
	return {
		"coins": coins,
		"total_earned": total_earned,
		"unlocked_species": unlocked_species.duplicate(),
		"owned_decorations": owned_decorations.duplicate(),
		"max_fish": max_fish,
	}


func load_save_data(data: Dictionary) -> void:
	coins = data.get("coins", 5000)
	total_earned = data.get("total_earned", 0)
	var saved_unlocked = data.get("unlocked_species", [])
	for i in saved_unlocked.size():
		if i < unlocked_species.size():
			unlocked_species[i] = saved_unlocked[i]
	var deco_data = data.get("owned_decorations", [])
	owned_decorations.clear()
	for d in deco_data:
		owned_decorations.append(d)
	max_fish = data.get("max_fish", 6)
	check_unlocks()
	game_loaded.emit()


func reset_state() -> void:
	coins = 5000
	total_earned = 0
	fish_count = 0
	max_fish = 6
	save_dirty = false
	feed_mode = false
	sell_mode = false
	unlocked_species = []
	unlocked_species.resize(FishData.Species.COUNT)
	unlocked_species[FishData.Species.GUPPY] = true
	owned_decorations.clear()
