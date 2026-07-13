extends Node2D

@onready var aquarium: Node2D = $Aquarium
@onready var bg_sprite: Sprite2D = $Aquarium/Background
@onready var fish_container: Node2D = $Aquarium/FishContainer
@onready var food_container: Node2D = $Aquarium/FoodContainer
@onready var decoration_container: Node2D = $Aquarium/DecorationContainer

var shop_panel_open: bool = false
var _selected_fish: Node2D = null
var _prev_minus: bool = false
var _prev_equal: bool = false

var aquarium_bounds: Rect2:
	get:
		var view_size := get_viewport_rect().size
		var margin := 50
		var top_margin := 80
		var bottom_margin := 100
		return Rect2(margin, top_margin, view_size.x - margin * 2, view_size.y - top_margin - bottom_margin)

var _fish_shop_list: VBoxContainer
var _deco_shop_list: VBoxContainer
var _fish_info_panel: Panel = null
var _fish_info_name: Label = null
var _fish_info_name_en: Label = null
var _fish_info_level: Label = null
var _fish_info_hunger: Label = null
var _fish_info_desc: Label = null
var _fish_info_sell: Label = null
var _timescale_label: Label = null
var _game_menu_panel: Panel = null
var _game_menu_bg: ColorRect = null
var _menu_open: bool = false


func _ready() -> void:
	Global.fish_added.connect(_on_fish_added)
	Global.fish_sold.connect(_on_fish_sold)
	Global.shop_panel_toggled.connect(_on_shop_toggled)
	Global.fish_info_requested.connect(_on_fish_info_requested)

	get_window().size_changed.connect(_on_window_resized)

	_setup_aquarium()
	_setup_ui()

	SaveManager.load_game()
	add_fish_if_empty()


func _on_window_resized() -> void:
	_setup_aquarium()
	_update_ui_positions()
	_update_fish_info_panel_position()
	for fish in fish_container.get_children():
		if fish.has_method("set_aquarium_bounds"):
			fish.set_aquarium_bounds(aquarium_bounds)


func _setup_aquarium() -> void:
	var bg_tex := load("res://assets/aquarium_bg.svg") as Texture2D
	if bg_tex:
		bg_sprite.texture = bg_tex
		var tex_size := bg_tex.get_size()
		var view_size := get_viewport_rect().size
		var scale_factor: float = min(
			view_size.x / tex_size.x,
			view_size.y / tex_size.y
		)
		bg_sprite.scale = Vector2(scale_factor, scale_factor)
		bg_sprite.position = view_size / 2


func add_fish_if_empty() -> void:
	if fish_container.get_child_count() == 0:
		_spawn_fish(FishData.Species.GUPPY)


func _spawn_fish(species: int) -> Node2D:
	var fish_scene := preload("res://scenes/fish/fish.tscn")
	var fish := fish_scene.instantiate()
	var fish_script := preload("res://scripts/fish/fish.gd")
	fish.set_script(fish_script)
	fish.species = species
	Global.fish_count += 1
	Global.fish_added.emit(fish)
	return fish


func _on_fish_added(fish: Node2D) -> void:
	if fish.script == null:
		var fish_script := preload("res://scripts/fish/fish.gd")
		fish.set_script(fish_script)
		fish.species = FishData.Species.GUPPY

	fish_container.add_child(fish)
	if fish.has_method("set_aquarium_bounds"):
		fish.set_aquarium_bounds(aquarium_bounds)

	Global.save_dirty = true


func _on_fish_sold(_fish: Node2D, _price: int) -> void:
	Global.save_dirty = true


func _process(_delta: float) -> void:
	_handle_input()


func _handle_input() -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if _menu_open:
			_toggle_game_menu()
		elif shop_panel_open:
			toggle_shop()
		elif _selected_fish != null:
			_hide_fish_info()
		elif Global.sell_mode:
			Global.sell_mode = false

	var minus_pressed := Input.is_key_pressed(KEY_MINUS)
	var equal_pressed := Input.is_key_pressed(KEY_EQUAL)
	if minus_pressed and not _prev_minus:
		Engine.time_scale = max(0.1, Engine.time_scale - 0.5)
		_timescale_changed()
	if equal_pressed and not _prev_equal:
		Engine.time_scale = min(5.0, Engine.time_scale + 0.5)
		_timescale_changed()
	_prev_minus = minus_pressed
	_prev_equal = equal_pressed


func _setup_ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)

	var view_size := get_viewport_rect().size

	_build_hud(ui, view_size)
	_build_shop_panel(ui, view_size)
	_build_bottom_bar(ui, view_size)
	_build_fish_info_panel(ui, view_size)
	_build_game_menu(ui, view_size)
	_build_timescale_label(ui, view_size)


func _update_ui_positions() -> void:
	var ui := get_node_or_null("UI") as CanvasLayer
	if ui == null:
		return

	var view_size := get_viewport_rect().size

	# HUD
	var hud_bg := ui.get_node_or_null("HUDBg") as ColorRect
	if hud_bg:
		hud_bg.size = Vector2(view_size.x, 50)

	var fish_count_label := ui.get_node_or_null("FishCountLabel") as Label
	if fish_count_label:
		fish_count_label.position = Vector2(view_size.x - 150, 15)

	# Bottom bar
	var bar_bg := ui.get_node_or_null("BottomBarBg") as ColorRect
	if bar_bg:
		bar_bg.size = Vector2(view_size.x, 70)
		bar_bg.position = Vector2(0, view_size.y - 70)

	for child in ui.get_children():
		if child is Button and child.name.begins_with("Btn_"):
			var action := child.name.trim_prefix("Btn_")
			var buttons := [
				{"action": "shop"},
				{"action": "feed"},
				{"action": "sell"},
				{"action": "upgrade"},
			]
			var btn_count := buttons.size()
			var btn_width := 80
			var spacing := 30
			var total_width := btn_count * btn_width + (btn_count - 1) * spacing
			var start_x := (view_size.x - total_width) / 2
			for i in btn_count:
				if buttons[i].action == action:
					child.position = Vector2(start_x + i * (btn_width + spacing), view_size.y - 65)
					break

	# Shop panel
	var shop_bg := ui.get_node_or_null("ShopBg") as ColorRect
	if shop_bg:
		shop_bg.size = view_size
		shop_bg.position = Vector2.ZERO

	var shop_panel := ui.get_node_or_null("ShopPanel") as Panel
	if shop_panel:
		shop_panel.position = Vector2(view_size.x / 2 - 250, view_size.y / 2 - 210)

	_update_fish_info_panel_position()

	# Menu button
	var menu_btn := ui.get_node_or_null("MenuBtn") as Button
	if menu_btn:
		menu_btn.position = Vector2(view_size.x - 60, 12)

	# Game menu
	if _game_menu_bg:
		_game_menu_bg.size = view_size
		_game_menu_bg.position = Vector2.ZERO
	if _game_menu_panel:
		_game_menu_panel.position = Vector2(view_size.x / 2 - 110, view_size.y / 2 - 60)

	# Timescale label
	if _timescale_label:
		_timescale_label.position = Vector2(view_size.x - 120, view_size.y - 35)


func _build_hud(ui: CanvasLayer, view_size: Vector2) -> void:
	var bg := ColorRect.new()
	bg.name = "HUDBg"
	bg.color = Color(0, 0, 0, 0.3)
	bg.size = Vector2(view_size.x, 50)
	bg.position = Vector2.ZERO
	ui.add_child(bg)

	var coin_icon := Sprite2D.new()
	coin_icon.texture = load("res://assets/ui/ui_coin.svg")
	coin_icon.scale = Vector2(0.5, 0.5)
	coin_icon.position = Vector2(30, 25)
	ui.add_child(coin_icon)

	var coin_label := Label.new()
	coin_label.name = "CoinLabel"
	coin_label.text = "金币: %d" % Global.coins
	coin_label.position = Vector2(50, 12)
	coin_label.add_theme_font_size_override("font_size", 18)
	coin_label.modulate = Color(1, 1, 1, 0.9)
	ui.add_child(coin_label)
	Global.coins_changed.connect(func(amount: int): coin_label.text = "金币: %d" % amount)

	var earned_label := Label.new()
	earned_label.name = "TotalEarnedLabel"
	earned_label.text = "累计: %d" % Global.total_earned
	earned_label.position = Vector2(50, 34)
	earned_label.add_theme_font_size_override("font_size", 11)
	earned_label.modulate = Color(1, 1, 1, 0.6)
	ui.add_child(earned_label)
	Global.total_earned_changed.connect(func(amount: int): earned_label.text = "累计: %d" % amount)

	var fish_count_label := Label.new()
	fish_count_label.name = "FishCountLabel"
	fish_count_label.text = "鱼: %d/%d" % [Global.fish_count, Global.max_fish]
	fish_count_label.position = Vector2(view_size.x - 150, 15)
	fish_count_label.add_theme_font_size_override("font_size", 16)
	fish_count_label.modulate = Color(1, 1, 1, 0.9)
	ui.add_child(fish_count_label)

	var update_fish_count := func():
		fish_count_label.text = "鱼: %d/%d" % [fish_container.get_child_count(), Global.max_fish]

	Global.fish_added.connect(update_fish_count)
	Global.fish_sold.connect(update_fish_count)
	Global.game_loaded.connect(update_fish_count)

	# Menu button
	var menu_btn := Button.new()
	menu_btn.name = "MenuBtn"
	menu_btn.text = "菜单"
	menu_btn.position = Vector2(view_size.x - 60, 12)
	menu_btn.size = Vector2(50, 26)
	menu_btn.add_theme_font_size_override("font_size", 12)
	ui.add_child(menu_btn)
	menu_btn.pressed.connect(_toggle_game_menu)


func _build_shop_panel(ui: CanvasLayer, view_size: Vector2) -> void:
	var shop_bg := ColorRect.new()
	shop_bg.name = "ShopBg"
	shop_bg.color = Color(0, 0, 0, 0.5)
	shop_bg.size = view_size
	shop_bg.position = Vector2.ZERO
	shop_bg.visible = false
	shop_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(shop_bg)

	var shop_panel := Panel.new()
	shop_panel.name = "ShopPanel"
	shop_panel.size = Vector2(500, 420)
	shop_panel.position = Vector2(view_size.x / 2 - 250, view_size.y / 2 - 210)
	shop_panel.visible = false
	ui.add_child(shop_panel)

	var shop_title := Label.new()
	shop_title.text = "商店"
	shop_title.position = Vector2(15, 12)
	shop_title.add_theme_font_size_override("font_size", 20)
	shop_title.modulate = Color(1, 1, 1, 0.9)
	shop_panel.add_child(shop_title)

	var close_btn := Button.new()
	close_btn.name = "CloseShopBtn"
	close_btn.text = "关闭"
	close_btn.position = Vector2(430, 10)
	close_btn.pressed.connect(toggle_shop)
	shop_panel.add_child(close_btn)

	var tab_container := TabContainer.new()
	tab_container.name = "TabContainer"
	tab_container.size = Vector2(480, 350)
	tab_container.position = Vector2(10, 45)
	shop_panel.add_child(tab_container)

	var fish_tab := VBoxContainer.new()
	fish_tab.name = "鱼类"
	var fish_scroll := ScrollContainer.new()
	fish_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fish_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fish_shop_list = VBoxContainer.new()
	_fish_shop_list.name = "FishList"
	_fish_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fish_scroll.add_child(_fish_shop_list)
	fish_tab.add_child(fish_scroll)
	tab_container.add_child(fish_tab)

	var deco_tab := VBoxContainer.new()
	deco_tab.name = "装饰"
	var deco_scroll := ScrollContainer.new()
	deco_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deco_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_deco_shop_list = VBoxContainer.new()
	_deco_shop_list.name = "DecorationList"
	_deco_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deco_scroll.add_child(_deco_shop_list)
	deco_tab.add_child(deco_scroll)
	tab_container.add_child(deco_tab)


func _build_bottom_bar(ui: CanvasLayer, view_size: Vector2) -> void:
	var bar_bg := ColorRect.new()
	bar_bg.name = "BottomBarBg"
	bar_bg.color = Color(0, 0, 0, 0.4)
	bar_bg.size = Vector2(view_size.x, 70)
	bar_bg.position = Vector2(0, view_size.y - 70)
	ui.add_child(bar_bg)

	var buttons := [
		{"text": "商店", "icon": "res://assets/ui/ui_shop.svg", "action": "shop"},
		{"text": "喂食", "icon": "res://assets/ui/ui_food.svg", "action": "feed"},
		{"text": "出售", "icon": "res://assets/ui/ui_sell.svg", "action": "sell"},
		{"text": "升级", "icon": "res://assets/ui/ui_star.svg", "action": "upgrade"},
	]

	var btn_count := buttons.size()
	var btn_width := 80
	var spacing := 30
	var total_width := btn_count * btn_width + (btn_count - 1) * spacing
	var start_x := (view_size.x - total_width) / 2

	for i in btn_count:
		var data: Dictionary = buttons[i]
		var btn_x := start_x + i * (btn_width + spacing)
		var btn_y := view_size.y - 65

		var btn := Button.new()
		btn.name = "Btn_%s" % data.action
		btn.text = data.text
		btn.position = Vector2(btn_x, btn_y)
		btn.size = Vector2(btn_width, 60)
		btn.add_theme_font_size_override("font_size", 11)
		ui.add_child(btn)

		var tex := load(data.icon) as Texture2D
		if tex:
			btn.icon = tex

		match data.action:
			"shop":
				btn.pressed.connect(toggle_shop)
			"feed":
				btn.pressed.connect(do_feed)
			"sell":
				btn.pressed.connect(_toggle_sell_mode.bind(btn))
			"upgrade":
				btn.pressed.connect(do_upgrade)


func _toggle_sell_mode(btn: Button) -> void:
	Global.sell_mode = not Global.sell_mode
	if Global.sell_mode:
		btn.modulate = Color(1, 0.5, 0.5)
	else:
		btn.modulate = Color(1, 1, 1, 1)
	Global.sell_mode_changed.connect(func(active: bool):
		btn.modulate = Color(1, 0.5, 0.5) if active else Color(1, 1, 1, 1)
	, CONNECT_ONE_SHOT)


func toggle_shop() -> void:
	shop_panel_open = not shop_panel_open
	var ui := get_node("UI")
	ui.get_node("ShopBg").visible = shop_panel_open
	ui.get_node("ShopPanel").visible = shop_panel_open

	if shop_panel_open:
		_refresh_shop_ui()


func _refresh_shop_ui() -> void:
	if _fish_shop_list == null or _deco_shop_list == null:
		return

	for c in _fish_shop_list.get_children():
		c.queue_free()
	for c in _deco_shop_list.get_children():
		c.queue_free()

	for species in FishData.Species.values() as Array[int]:
		if species == FishData.Species.COUNT:
			continue
		_add_fish_shop_entry(_fish_shop_list, species)

	for deco_type in DecorationData.DecorationType.values() as Array[int]:
		_add_deco_shop_entry(_deco_shop_list, deco_type)


func _add_fish_shop_entry(parent: VBoxContainer, species: int) -> void:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 55)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.text = FishData.get_species_name(species)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 14)

	var is_unlocked := Global.unlocked_species[species]
	var info_label := Label.new()
	var buy_btn := Button.new()

	if is_unlocked:
		var cost: int = FishData.get_buy_cost(species)
		info_label.text = "¥%d" % cost
		buy_btn.text = "购买"
		buy_btn.disabled = Global.coins < cost or not Global.can_add_fish()
		var s: int = species
		buy_btn.pressed.connect(func(): _buy_fish(s))
	else:
		var req: Dictionary = FishData.get_unlock_requirement(species)
		info_label.text = "累计¥%d解锁" % req.value
		buy_btn.text = "???"
		buy_btn.disabled = true

	hbox.add_child(name_label)
	hbox.add_child(info_label)
	hbox.add_child(buy_btn)
	panel.add_child(hbox)
	parent.add_child(panel)


func _add_deco_shop_entry(parent: VBoxContainer, deco_type: int) -> void:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 45)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = DecorationData.get_display_name(deco_type)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var cost: int = DecorationData.get_cost(deco_type)
	var cost_label := Label.new()
	cost_label.text = "¥%d" % cost
	cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var buy_btn := Button.new()
	buy_btn.text = "购买"
	buy_btn.disabled = Global.coins < cost
	var dt := deco_type
	buy_btn.pressed.connect(func(): _buy_decoration(dt))

	hbox.add_child(name_label)
	hbox.add_child(cost_label)
	hbox.add_child(buy_btn)
	panel.add_child(hbox)
	parent.add_child(panel)


func _buy_fish(species: int) -> void:
	var cost: int = FishData.get_buy_cost(species)
	if not Global.can_add_fish():
		return
	if Global.spend(cost):
		_spawn_fish(species)
		Global.save_dirty = true
		_refresh_shop_ui()


func _buy_decoration(deco_type: int) -> void:
	var cost: int = DecorationData.get_cost(deco_type)
	if Global.spend(cost):
		Global.owned_decorations.append(deco_type)
		Global.decoration_added.emit(deco_type)
		Global.save_dirty = true
		_refresh_shop_ui()


func do_feed() -> void:
	if fish_container.get_child_count() == 0:
		return

	var cost := 10 + 5 * fish_container.get_child_count()
	if not Global.spend(cost):
		return

	var pellet_scene := preload("res://scenes/food/food_pellet.tscn")
	var pellet_script := preload("res://scripts/food/food_pellet.gd")
	var count: int = min(3 + fish_container.get_child_count(), 8)
	for i in count:
		var pellet := pellet_scene.instantiate()
		pellet.set_script(pellet_script)

		var margin := 80
		var x := randf_range(aquarium_bounds.position.x + margin, aquarium_bounds.position.x + aquarium_bounds.size.x - margin)
		pellet.position = Vector2(x, aquarium_bounds.position.y + 10)
		food_container.add_child(pellet)

		for fish in fish_container.get_children():
			if fish.has_method("set_food_target"):
				fish.set_food_target(pellet)


func do_upgrade() -> void:
	var cost := 500 + Global.max_fish * 200
	if Global.spend(cost):
		Global.max_fish += 2
		Global.save_dirty = true


func _on_shop_toggled(visible: bool) -> void:
	if visible:
		toggle_shop()


# ── Fish Info Panel ──────────────────────────────────────────────────────

func _build_fish_info_panel(ui: CanvasLayer, view_size: Vector2) -> void:
	_fish_info_panel = Panel.new()
	_fish_info_panel.name = "FishInfoPanel"
	_fish_info_panel.size = Vector2(220, 140)
	_fish_info_panel.visible = false
	ui.add_child(_fish_info_panel)

	var margin := 8
	var line_h := 20

	_fish_info_name = Label.new()
	_fish_info_name.name = "FishInfoName"
	_fish_info_name.position = Vector2(margin, margin)
	_fish_info_name.add_theme_font_size_override("font_size", 16)
	_fish_info_panel.add_child(_fish_info_name)

	_fish_info_name_en = Label.new()
	_fish_info_name_en.name = "FishInfoNameEn"
	_fish_info_name_en.position = Vector2(margin + 2, margin + line_h)
	_fish_info_name_en.add_theme_font_size_override("font_size", 10)
	_fish_info_name_en.modulate = Color(1, 1, 1, 0.6)
	_fish_info_panel.add_child(_fish_info_name_en)

	_fish_info_level = Label.new()
	_fish_info_level.name = "FishInfoLevel"
	_fish_info_level.position = Vector2(margin, margin + line_h * 2 + 2)
	_fish_info_level.add_theme_font_size_override("font_size", 13)
	_fish_info_panel.add_child(_fish_info_level)

	_fish_info_hunger = Label.new()
	_fish_info_hunger.name = "FishInfoHunger"
	_fish_info_hunger.position = Vector2(margin, margin + line_h * 3 + 2)
	_fish_info_hunger.add_theme_font_size_override("font_size", 12)
	_fish_info_panel.add_child(_fish_info_hunger)

	_fish_info_desc = Label.new()
	_fish_info_desc.name = "FishInfoDesc"
	_fish_info_desc.position = Vector2(margin, margin + line_h * 4 + 2)
	_fish_info_desc.add_theme_font_size_override("font_size", 10)
	_fish_info_desc.modulate = Color(1, 1, 1, 0.7)
	_fish_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fish_info_desc.size = Vector2(204, 30)
	_fish_info_panel.add_child(_fish_info_desc)

	_fish_info_sell = Label.new()
	_fish_info_sell.name = "FishInfoSell"
	_fish_info_sell.position = Vector2(margin, margin + line_h * 6 + 2)
	_fish_info_sell.add_theme_font_size_override("font_size", 11)
	_fish_info_sell.modulate = Color(1, 0.8, 0.4, 0.9)
	_fish_info_panel.add_child(_fish_info_sell)

	_update_fish_info_panel_position()


func _update_fish_info_panel_position() -> void:
	if _fish_info_panel == null:
		return
	var view_size := get_viewport_rect().size
	_fish_info_panel.position = Vector2(10, view_size.y - 70 - _fish_info_panel.size.y - 8)


func _on_fish_info_requested(fish: Node2D) -> void:
	if not is_instance_valid(fish):
		return
	_selected_fish = fish
	_refresh_fish_info_panel()
	_fish_info_panel.visible = true


func _refresh_fish_info_panel() -> void:
	if _selected_fish == null or not is_instance_valid(_selected_fish):
		return
	var f := _selected_fish
	var species: int = f.species
	var lv: int = f.get_level()
	var hunger_pct: int = int(f.hunger * 100)
	_fish_info_name.text = FishData.get_species_name(species)
	_fish_info_name_en.text = FishData.get_species_name_en(species)
	_fish_info_level.text = "等级: %d / %d" % [lv, FishData.get_max_level(species)]
	_fish_info_hunger.text = "饱食度: %d%%" % hunger_pct
	_fish_info_desc.text = FishData.get_description(species)
	if f.get_sellable():
		_fish_info_sell.text = "售价: ¥%d" % f.get_sell_price()
	else:
		_fish_info_sell.text = "状态: 死亡"


func _hide_fish_info() -> void:
	_selected_fish = null
	if _fish_info_panel:
		_fish_info_panel.visible = false


# ── Game Menu ───────────────────────────────────────────────────────────

func _build_game_menu(ui: CanvasLayer, view_size: Vector2) -> void:
	_game_menu_bg = ColorRect.new()
	_game_menu_bg.name = "GameMenuBg"
	_game_menu_bg.color = Color(0, 0, 0, 0.4)
	_game_menu_bg.size = view_size
	_game_menu_bg.position = Vector2.ZERO
	_game_menu_bg.visible = false
	_game_menu_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(_game_menu_bg)
	# Clicking bg closes menu
	_game_menu_bg.gui_input.connect(_on_menu_bg_input)

	_game_menu_panel = Panel.new()
	_game_menu_panel.name = "GameMenuPanel"
	_game_menu_panel.size = Vector2(220, 120)
	_game_menu_panel.position = Vector2(view_size.x / 2 - 110, view_size.y / 2 - 60)
	_game_menu_panel.visible = false
	ui.add_child(_game_menu_panel)

	var title := Label.new()
	title.text = "游戏菜单"
	title.position = Vector2(12, 12)
	title.add_theme_font_size_override("font_size", 18)
	_game_menu_panel.add_child(title)

	var restart_btn := Button.new()
	restart_btn.text = "重新开始游戏"
	restart_btn.position = Vector2(20, 45)
	restart_btn.size = Vector2(180, 30)
	_game_menu_panel.add_child(restart_btn)
	restart_btn.pressed.connect(_on_restart_pressed)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.position = Vector2(20, 82)
	cancel_btn.size = Vector2(180, 30)
	_game_menu_panel.add_child(cancel_btn)
	cancel_btn.pressed.connect(_toggle_game_menu)


func _toggle_game_menu() -> void:
	_menu_open = not _menu_open
	_game_menu_bg.visible = _menu_open
	_game_menu_panel.visible = _menu_open


func _on_menu_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle_game_menu()


func _on_restart_pressed() -> void:
	_toggle_game_menu()
	SaveManager.reset_save()


# ── Timescale ────────────────────────────────────────────────────────────

func _build_timescale_label(ui: CanvasLayer, view_size: Vector2) -> void:
	_timescale_label = Label.new()
	_timescale_label.name = "TimescaleLabel"
	_timescale_label.text = "x%.1f" % Engine.time_scale
	_timescale_label.position = Vector2(view_size.x - 120, view_size.y - 35)
	_timescale_label.add_theme_font_size_override("font_size", 14)
	_timescale_label.modulate = Color(1, 1, 1, 0.5)
	ui.add_child(_timescale_label)


func _timescale_changed() -> void:
	if _timescale_label:
		_timescale_label.text = "x%.1f" % Engine.time_scale
		# Brief flash effect
		_timescale_label.modulate = Color(1, 1, 1, 1.0)
		var tween := create_tween()
		tween.tween_property(_timescale_label, "modulate", Color(1, 1, 1, 0.5), 1.0)
