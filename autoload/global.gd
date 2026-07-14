extends Node

signal coins_changed(amount: int)
signal total_earned_changed(amount: int)
@warning_ignore("unused_signal")
signal fish_added(fish: Node2D)
@warning_ignore("unused_signal")
signal fish_sold(fish: Node2D, price: int)
signal fish_unlocked(species: int)
@warning_ignore("unused_signal")
signal decoration_added(deco_type: int)
@warning_ignore("unused_signal")
signal decoration_placed(deco_type: int, position: Vector2)
@warning_ignore("unused_signal")
signal equipment_added(eq_type: int)
signal move_mode_changed(active: bool)

const DESIGN_WIDTH := 1920.0
const DESIGN_HEIGHT := 1080.0
var scale_factor: float = 1.0


# 创建一个可点击的装饰物精灵（带点击区域和元数据）
static func make_decoration_sprite(deco_type: int, initial_scale: Vector2 = Vector2(0.5, 0.5)) -> Sprite2D:
	var tex_path := DecorationData.get_texture_path(deco_type)
	if not ResourceLoader.exists(tex_path):
		return null
	var deco := Sprite2D.new()
	deco.texture = load(tex_path)
	deco.scale = initial_scale
	deco.set_meta(&"deco_type", deco_type)
	
	# 添加点击区域
	var area := Area2D.new()
	area.name = "ClickArea"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var tex_size := deco.texture.get_size() if deco.texture else Vector2(64, 64)
	rect.size = tex_size * deco.scale
	shape.shape = rect
	area.add_child(shape)
	deco.add_child(area)
	
	return deco


# 查找 owned_decorations 中与装饰物精灵匹配的数据索引
func _find_decoration_index(sprite: Sprite2D) -> int:
	var deco_type = sprite.get_meta(&"deco_type", -1)
	if deco_type < 0:
		return -1
	var spos := sprite.position
	var best_idx := -1
	var best_dist := INF
	for i in owned_decorations.size():
		var d = owned_decorations[i]
		if typeof(d) == TYPE_DICTIONARY and d.get("type", -1) == deco_type:
			var dist = Vector2(d.get("x", 0), d.get("y", 0)).distance_squared_to(spos)
			if dist < best_dist:
				best_dist = dist
				best_idx = i
		elif typeof(d) == TYPE_INT and d == deco_type:
			# 旧格式（仅类型），取第一个匹配
			return i
	return best_idx


# 更新指定装饰物的位置/缩放数据（拖拽/拉伸结束后调用）
func update_decoration_instance(deco_type: int, pos: Vector2, scale: Vector2) -> void:
	# 尝试按位置查找已有数据并更新
	for i in owned_decorations.size():
		var d = owned_decorations[i]
		if typeof(d) == TYPE_DICTIONARY and d.get("type", -1) == deco_type:
			if Vector2(d.get("x", 0), d.get("y", 0)).distance_squared_to(pos) < 1.0:
				d["x"] = pos.x
				d["y"] = pos.y
				d["scale_x"] = scale.x
				d["scale_y"] = scale.y
				return
	# 没找到精确匹配 → 更新最后放置的同类型装饰
	for i in range(owned_decorations.size() - 1, -1, -1):
		var d = owned_decorations[i]
		if typeof(d) == TYPE_DICTIONARY and d.get("type", -1) == deco_type:
			d["x"] = pos.x
			d["y"] = pos.y
			d["scale_x"] = scale.x
			d["scale_y"] = scale.y
			return


# 出售装饰物：由点击回调调用
func sell_decoration_sprite(deco_sprite: Sprite2D) -> void:
	var deco_type = deco_sprite.get_meta(&"deco_type", -1)
	if deco_type < 0:
		return
	
	var price := DecorationData.get_sell_price(deco_type)
	coins += price
	total_earned += price
	save_dirty = true
	
	# 从 owned_decorations 中移除匹配的数据
	var idx := _find_decoration_index(deco_sprite)
	if idx >= 0:
		owned_decorations.remove_at(idx)
	
	# 显示卖出飘字
	_show_decoration_sell_label(deco_sprite.global_position, price)
	
	deco_sprite.queue_free()


func _show_decoration_sell_label(pos: Vector2, price: int) -> void:
	var label := Label.new()
	label.text = "+%d$" % price
	label.add_theme_color_override("font_color", Color(1, 0.85, 0, 1))
	label.add_theme_font_size_override("font_size", 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = pos - Vector2(0, 20)
	label.z_index = 100
	
	# 添加到当前场景
	var scene: Node = Engine.get_main_loop().current_scene
	if scene:
		scene.add_child(label)
	
	var tween := label.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position", label.position + Vector2(0, -80), 3.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(2.5)
	tween.tween_callback(label.queue_free)

var decoration_placement_active: bool = false
var pending_decoration_type: int = -1
signal feed_mode_changed(active: bool)
signal sell_mode_changed(active: bool)
@warning_ignore("unused_signal")
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
var owned_decorations: Array = []  # Array[int]（旧格式）或 Array[Dictionary]（新格式）
var has_auto_feeder: bool = false:
	set(value):
		has_auto_feeder = value
		save_dirty = true
var auto_feeder_enabled: bool = true:
	set(value):
		auto_feeder_enabled = value
		save_dirty = true
var auto_feeder_feed_count: int = 3:
	set(value):
		auto_feeder_feed_count = max(value, 1)
		save_dirty = true
var has_auto_sell: bool = false:
	set(value):
		has_auto_sell = value
		save_dirty = true
var auto_sell_enabled: bool = false:
	set(value):
		auto_sell_enabled = value
		save_dirty = true
var has_auto_buy: bool = false:
	set(value):
		has_auto_buy = value
		save_dirty = true
var auto_buy_targets: Dictionary = {}:
	set(value):
		auto_buy_targets = value
		save_dirty = true
var save_dirty: bool = false
var fish_count: int = 0
var max_fish: int = 6

# 加载存档时临时存储鱼的数据，由 main.gd 读取后恢复鱼
var pending_fish_data: Array = []

var feed_mode: bool = false:
	set(value):
		feed_mode = value
		if value:
			sell_mode = false
			move_mode = false
		feed_mode_changed.emit(value)

var sell_mode: bool = false:
	set(value):
		sell_mode = value
		if value:
			feed_mode = false
			move_mode = false
		sell_mode_changed.emit(value)
		_update_sell_cursor()

var move_mode: bool = false:
	set(value):
		move_mode = value
		if value:
			feed_mode = false
			sell_mode = false
		move_mode_changed.emit(value)
		_update_move_cursor()


func _update_sell_cursor() -> void:
	if sell_mode:
		var tex := load("res://assets/ui/cursor_dollar.png") as Texture2D
		if tex:
			var img := tex.get_image()
			img.resize(32, 32, Image.INTERPOLATE_LANCZOS)
			var cursor_tex := ImageTexture.create_from_image(img)
			Input.set_custom_mouse_cursor(cursor_tex, Input.CURSOR_ARROW, Vector2(16, 16))
	else:
		Input.set_custom_mouse_cursor(null)


func _update_move_cursor() -> void:
	if move_mode:
		var tex := load("res://assets/ui/ui_move.svg") as Texture2D
		if tex:
			var img := tex.get_image()
			img.resize(32, 32, Image.INTERPOLATE_LANCZOS)
			var cursor_tex := ImageTexture.create_from_image(img)
			Input.set_custom_mouse_cursor(cursor_tex, Input.CURSOR_ARROW, Vector2(16, 16))
	else:
		Input.set_custom_mouse_cursor(null)


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
	# 统一保存为完整数据格式
	var deco_save: Array = []
	for d in owned_decorations:
		if typeof(d) == TYPE_DICTIONARY:
			deco_save.append(d.duplicate())
		elif typeof(d) == TYPE_INT:
			deco_save.append({"type": d, "x": 0, "y": 0, "scale_x": 0.5, "scale_y": 0.5})
	return {
		"coins": coins,
		"total_earned": total_earned,
		"unlocked_species": unlocked_species.duplicate(),
		"owned_decorations": deco_save,
		"has_auto_feeder": has_auto_feeder,
		"auto_feeder_enabled": auto_feeder_enabled,
		"auto_feeder_feed_count": auto_feeder_feed_count,
		"has_auto_sell": has_auto_sell,
		"auto_sell_enabled": auto_sell_enabled,
		"has_auto_buy": has_auto_buy,
		"auto_buy_targets": auto_buy_targets.duplicate(),
		"max_fish": max_fish,
		"time_scale": Engine.time_scale,
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
		if typeof(d) == TYPE_DICTIONARY:
			owned_decorations.append(d.duplicate())
		else:
			# 旧格式：只有类型 int，补默认位置/缩放
			owned_decorations.append({"type": d, "x": 0, "y": 0, "scale_x": 0.5, "scale_y": 0.5})
	has_auto_feeder = data.get("has_auto_feeder", false)
	auto_feeder_enabled = data.get("auto_feeder_enabled", true)
	auto_feeder_feed_count = data.get("auto_feeder_feed_count", 3)
	has_auto_sell = data.get("has_auto_sell", false)
	auto_sell_enabled = data.get("auto_sell_enabled", false)
	has_auto_buy = data.get("has_auto_buy", false)
	var raw_targets = data.get("auto_buy_targets", {})
	var converted_targets := {}
	for key in raw_targets:
		converted_targets[int(key)] = raw_targets[key]
	auto_buy_targets = converted_targets
	max_fish = data.get("max_fish", 6)
	Engine.time_scale = data.get("time_scale", 1.0)
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
	move_mode = false
	decoration_placement_active = false
	pending_decoration_type = -1
	unlocked_species = []
	unlocked_species.resize(FishData.Species.COUNT)
	unlocked_species[FishData.Species.GUPPY] = true
	owned_decorations.clear()
	has_auto_feeder = false
	auto_feeder_enabled = true
	auto_feeder_feed_count = 3
	has_auto_sell = false
	auto_sell_enabled = false
	has_auto_buy = false
	auto_buy_targets = {}
	Engine.time_scale = 1.0
