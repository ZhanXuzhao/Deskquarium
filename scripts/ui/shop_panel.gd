extends Control

class_name ShopPanel

@onready var fish_list: VBoxContainer = %FishList
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
	
	for species in FishData.Species.values() as Array[int]:
		if species == FishData.Species.COUNT:
			continue
		
		_add_fish_entry(species)


func _add_fish_entry(species: int) -> void:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 60)
	
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var name_label := Label.new()
	name_label.text = FishData.get_species_name(species)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var info_label := Label.new()
	var is_unlocked := Global.unlocked_species[species]
	if is_unlocked:
		var cost: int = FishData.get_buy_cost(species)
		info_label.text = "¥%d" % cost
	else:
		var req: Dictionary = FishData.get_unlock_requirement(species)
		info_label.text = "累计¥%d解锁" % req.value
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var buy_btn := Button.new()
	if is_unlocked:
		buy_btn.text = "购买"
		buy_btn.pressed.connect(_on_buy_fish.bind(species))
		if Global.coins < FishData.get_buy_cost(species) or not Global.can_add_fish():
			buy_btn.disabled = true
	else:
		buy_btn.text = "锁定"
		buy_btn.disabled = true
	
	hbox.add_child(name_label)
	hbox.add_child(info_label)
	hbox.add_child(buy_btn)
	panel.add_child(hbox)
	fish_list.add_child(panel)


func _populate_decoration_shop() -> void:
	for c in decoration_list.get_children():
		c.queue_free()
	
	for deco_type in DecorationData.DecorationType.values() as Array[int]:
		if deco_type == DecorationData.DecorationType.COUNT:
			continue
		_add_decoration_entry(deco_type)


func _add_decoration_entry(deco_type: int) -> void:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(180, 150)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)

	# 装饰图片预览（固定 64×64，用 CenterContainer 约束）
	var tex_path := DecorationData.get_texture_path(deco_type)
	var tex := load(tex_path) as Texture2D if ResourceLoader.exists(tex_path) else null

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.custom_minimum_size = Vector2(0, 64)

	var preview := TextureRect.new()
	if tex:
		preview.texture = tex
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else:
		preview.modulate = Color(0.3, 0.3, 0.3, 1)
	preview.custom_minimum_size = Vector2(64, 64)
	center.add_child(preview)
	vbox.add_child(center)

	# 名称
	var name_label := Label.new()
	name_label.text = DecorationData.get_display_name(deco_type)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(name_label)

	# 价格
	var cost: int = DecorationData.get_cost(deco_type)
	var cost_label := Label.new()
	cost_label.text = "¥%d" % cost
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_label.add_theme_font_size_override("font_size", 12)
	cost_label.modulate = Color(1, 0.85, 0, 1)
	vbox.add_child(cost_label)

	# 购买按钮
	var buy_btn := Button.new()
	buy_btn.text = "购买"
	buy_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buy_btn.disabled = Global.coins < cost
	buy_btn.pressed.connect(_on_buy_decoration.bind(deco_type))
	vbox.add_child(buy_btn)

	card.add_child(vbox)
	decoration_list.add_child(card)


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
