extends Node2D

const _AutoBuyerScript := preload("res://scripts/managers/auto_buyer.gd")

@onready var aquarium: Node2D = $Aquarium
@onready var bg_rect: ColorRect = $Aquarium/Background
@onready var fish_container: Node2D = $Aquarium/FishContainer
@onready var food_container: Node2D = $Aquarium/FoodContainer
@onready var decoration_container: Node2D = $Aquarium/DecorationContainer

var _bg_layer: CanvasLayer = null
var _bg_rect: ColorRect = null

var _ui_container: Node2D

var shop_panel_open: bool = false
var _selected_fish: Fish = null
var _prev_minus: bool = false
var _prev_equal: bool = false

var aquarium_bounds: Rect2:
	get:
		var view_size := get_viewport_rect().size
		if view_size == Vector2.ZERO:
			return Rect2(0, 0, Global.DESIGN_WIDTH, Global.DESIGN_HEIGHT)
		var s: float = view_size.x / Global.DESIGN_WIDTH
		# 根据窗口实际可见区域计算设计坐标中的鱼缸边界（底部对齐）
		var visible_height: float = view_size.y / s
		var visible_top := maxf(0.0, Global.DESIGN_HEIGHT - visible_height)
		return Rect2(0, visible_top, Global.DESIGN_WIDTH, Global.DESIGN_HEIGHT - visible_top)

var _fish_shop_list: GridContainer
var _deco_shop_list: GridContainer
var _equip_shop_list: VBoxContainer
var _deco_type_filters: Dictionary = {}  # DecorationData.TypeGroup -> CheckBox
var _fish_info_panel: Panel = null
var _fish_info_name: Label = null
var _fish_info_name_en: Label = null
var _fish_info_level: Label = null
var _fish_info_hunger: Label = null
var _fish_info_desc: Label = null
var _fish_info_sell: Label = null
var _fish_info_index: Label = null
var _fish_info_prev_btn: Button = null
var _fish_info_next_btn: Button = null
var _fish_info_sell_btn: Button = null
var _timescale_label: Label = null
var _game_menu_panel: Panel = null
var _game_menu_bg: ColorRect = null
var _fish_scale_label: Label = null
var _menu_open: bool = false

var _side_menu: SideMenu = null

var _coin_label: Label
var _earned_label: Label
var _fish_count_label: Label

var _window_manager: WindowManager = null
var _feed_manager: FeedManager = null
var _decoration_placer: DecorationPlacer = null


func _ready() -> void:
	Global.fish_added.connect(_on_fish_added)
	Global.fish_sold.connect(_on_fish_sold)
	Global.fish_info_requested.connect(_on_fish_info_requested)
	Global.game_loaded.connect(_on_game_loaded)

	get_window().size_changed.connect(_on_window_resized)

	_setup_background_layer()
	
	# 初始化 WindowManager
	var wm := WindowManager.new()
	wm.name = "WindowManager"
	add_child(wm)
	_window_manager = wm
	_window_manager.aquarium_scale_needed.connect(_update_aquarium_scale)
	_window_manager.redraw_requested.connect(queue_redraw)
	_window_manager.after_ui_shown.connect(_on_window_mode_ui_shown)
	
	# 初始化 FeedManager (必须在 _setup_ui 之前，因为侧边栏按钮会引用它)
	var fm := FeedManager.new()
	fm.name = "FeedManager"
	add_child(fm)
	_feed_manager = fm
	_feed_manager.fish_container = fish_container
	_feed_manager.food_container = food_container
	_feed_manager.aquarium = aquarium
	_feed_manager.aquarium_bounds_getter = func() -> Rect2: return aquarium_bounds
	
	# 初始化 DecorationPlacer (必须在 _setup_ui 之前)
	var dp := DecorationPlacer.new()
	dp.name = "DecorationPlacer"
	add_child(dp)
	_decoration_placer = dp
	_decoration_placer.aquarium = aquarium
	_decoration_placer.decoration_container = decoration_container
	_decoration_placer.aquarium_ref = $Aquarium as Aquarium
	_decoration_placer.aquarium_bounds_getter = func() -> Rect2: return aquarium_bounds

	_setup_ui()
	
	# 现在 _ui_container 已创建，设置引用
	_window_manager.ui_container = _ui_container
	_window_manager.ui_layer = $UI
	_feed_manager.ui_container = _ui_container
	
	# 连接侧边栏信号
	_side_menu.shop_pressed.connect(toggle_shop)
	_side_menu.feed_pressed.connect(_on_side_menu_feed)
	_side_menu.sell_toggled.connect(_on_side_menu_sell)
	_side_menu.move_toggled.connect(_on_side_menu_move)
	_side_menu.upgrade_pressed.connect(do_upgrade)
	_side_menu.autobuy_pressed.connect(_open_auto_buy_settings)
	_side_menu.wallpaper_toggled.connect(_on_side_menu_wallpaper)
	_side_menu.tiny_toggled.connect(_on_side_menu_tiny)

	# 初始缩放
	call_deferred(&"_update_aquarium_scale")

	SaveManager.load_game()
	_restore_fish_from_save()
	call_deferred(&"_apply_startup_mode")


func _on_window_resized() -> void:
	_update_aquarium_scale()
	_update_background_size()
	_update_ui_positions()
	_update_fish_info_panel_position()


func _setup_background_layer() -> void:
	_bg_layer = CanvasLayer.new()
	_bg_layer.name = "BackgroundLayer"
	add_child(_bg_layer)
	# layer = -1 确保背景渲染在所有内容（layer=0）的后面
	_bg_layer.layer = -1
	
	_bg_rect = ColorRect.new()
	_bg_rect.name = "BackgroundRect"
	_bg_rect.color = Color(0.35, 0.7, 0.9)
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_layer.add_child(_bg_rect)
	
	_update_background_size()


func _update_background_size() -> void:
	if _bg_rect == null:
		return
	var view_size := get_viewport_rect().size
	_bg_rect.position = Vector2.ZERO
	_bg_rect.size = view_size


func _update_aquarium_scale() -> void:
	"""根据窗口宽度缩放 Aquarium，并底部对齐"""
	var view_size := get_viewport_rect().size
	var s: float = view_size.x / Global.DESIGN_WIDTH
	Global.scale_factor = s
	
	aquarium.scale = Vector2(s, s)
	# 底部对齐：Aquarium 底部边缘 = 视口底部
	aquarium.position = Vector2(0, view_size.y - Global.DESIGN_HEIGHT * s)
	
	# 更新所有鱼的边界
	for fish in fish_container.get_children():
		if fish.has_method("set_aquarium_bounds"):
			fish.set_aquarium_bounds(aquarium_bounds)


func add_fish_if_empty() -> void:
	if fish_container.get_child_count() == 0:
		_spawn_fish(FishData.Species.GUPPY)


func _restore_fish_from_save() -> void:
	var fish_data: Array = Global.pending_fish_data
	Global.pending_fish_data = []
	if fish_data.is_empty():
		add_fish_if_empty()
		return
	
	for fd in fish_data:
		var dict: Dictionary = fd
		var species: int = dict.get("species", FishData.Species.GUPPY)
		var fish := _spawn_fish(species)
		fish.level = dict.get("level", 0.0)
		fish.hunger = dict.get("hunger", 1.0)
		fish.position = Vector2(dict.get("x", 0.0), dict.get("y", 0.0))


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


func _on_game_loaded() -> void:
	_decoration_placer.restore_from_save()
	_restore_auto_feeder()
	_restore_auto_buyer()


func _restore_auto_feeder() -> void:
	if Global.has_auto_feeder:
		_spawn_auto_feeder()


func _restore_auto_buyer() -> void:
	# 自动买鱼默认启用，始终生成
	_spawn_auto_buyer()


func _process(_delta: float) -> void:
	_handle_input()
	if _fish_info_panel and _fish_info_panel.visible:
		_refresh_fish_info_panel()
	
	if _decoration_placer.is_active():
		_decoration_placer.update_preview()
	
	_window_manager.handle_process(_delta)
	_feed_manager.process_feed(_delta)


func _handle_input() -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if _window_manager.handle_cancel():
			return
		if _auto_buy_settings_panel and is_instance_valid(_auto_buy_settings_panel):
			_close_auto_buy_settings()
			return
		if _menu_open:
			_toggle_game_menu()
		elif shop_panel_open:
			toggle_shop()
		elif _selected_fish != null:
			_hide_fish_info()
		elif Global.sell_mode:
			Global.sell_mode = false
		elif Global.move_mode:
			Global.move_mode = false
			var aqua := $Aquarium as Aquarium
			if aqua and aqua.has_method("clear_move_selection"):
				aqua.clear_move_selection()
		elif _decoration_placer.is_active():
			_decoration_placer.cancel_placement()
		elif _feed_manager.is_active():
			_feed_manager.exit_feed_mode()

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

	# Fish info panel keyboard navigation
	if _fish_info_panel and _fish_info_panel.visible and _selected_fish:
		if Input.is_action_just_pressed("ui_left"):
			_navigate_fish(-1)
		if Input.is_action_just_pressed("ui_right"):
			_navigate_fish(1)


func _input(event: InputEvent) -> void:
	# 窗口模式输入由 WindowManager 处理
	if _window_manager.handle_input(event):
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if Global.sell_mode:
			Global.sell_mode = false
			get_viewport().set_input_as_handled()
			return
		if Global.move_mode:
			Global.move_mode = false
			var aqua := $Aquarium as Aquarium
			if aqua and aqua.has_method("clear_move_selection"):
				aqua.clear_move_selection()
			get_viewport().set_input_as_handled()
			return
		if _decoration_placer.is_active() and not shop_panel_open:
			_decoration_placer.cancel_placement()
			get_viewport().set_input_as_handled()
			return
		if _feed_manager.is_active():
			_feed_manager.exit_feed_mode()
			get_viewport().set_input_as_handled()
			return
		if _selected_fish != null:
			_hide_fish_info()
			get_viewport().set_input_as_handled()
			return

	if _decoration_placer.is_active() and not shop_panel_open and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_decoration_placer.confirm_placement()
			return
	
	if _feed_manager.handle_input(event):
		return


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _selected_fish != null:
			_hide_fish_info()
			get_viewport().set_input_as_handled()
			return


func _setup_ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)

	var container := Node2D.new()
	container.name = "UIContainer"
	ui.add_child(container)
	_ui_container = container

	var view_size := get_viewport_rect().size

	_build_hud(container, view_size)
	_build_shop_panel(container, view_size)
	_build_side_menu_scene(container, view_size)
	_build_fish_info_panel(container, view_size)
	_build_game_menu(container, view_size)
	_build_timescale_label(container, view_size)


func _update_fish_count_display(_fish: Node2D = null, _price: int = 0) -> void:
	if is_instance_valid(_fish_count_label) and is_instance_valid(fish_container):
		_fish_count_label.text = "鱼: %d/%d" % [fish_container.get_child_count(), Global.max_fish]


func _update_ui_positions() -> void:
	if not is_instance_valid(_ui_container):
		return

	var view_size := get_viewport_rect().size

	# HUD
	var hud_bg := _ui_container.get_node_or_null("HUDBg") as ColorRect
	if hud_bg:
		hud_bg.size = Vector2(view_size.x, 50)

	var fish_count_label := _ui_container.get_node_or_null("FishCountLabel") as Label
	if fish_count_label:
		fish_count_label.position = Vector2(view_size.x - 150, 15)

	# Side menu
	if is_instance_valid(_side_menu):
		_side_menu.update_position(view_size)

	# Shop panel
	var shop_panel := _ui_container.get_node_or_null("ShopPanel") as Panel
	if shop_panel:
		shop_panel.position = Vector2(view_size.x / 2 - 500, view_size.y / 2 - 420)

	_update_fish_info_panel_position()

	# Menu button
	var menu_btn := _ui_container.get_node_or_null("MenuBtn") as Button
	if menu_btn:
		menu_btn.position = Vector2(view_size.x - 60, 12)

	# Game menu
	if _game_menu_bg:
		_game_menu_bg.size = view_size
		_game_menu_bg.position = Vector2.ZERO
	if _game_menu_panel:
		_game_menu_panel.position = Vector2(view_size.x / 2 - 110, view_size.y / 2 - 120)

	# Timescale label
	if _timescale_label:
		_timescale_label.position = Vector2(view_size.x - 280, 15)


func _build_hud(parent: Node, view_size: Vector2) -> void:
	var bg := ColorRect.new()
	bg.name = "HUDBg"
	bg.color = Color(0, 0, 0, 0.3)
	bg.size = Vector2(view_size.x, 50)
	bg.position = Vector2.ZERO
	parent.add_child(bg)

	var coin_icon := Sprite2D.new()
	coin_icon.texture = load("res://assets/ui/ui_coin.svg")
	coin_icon.scale = Vector2(0.5, 0.5)
	coin_icon.position = Vector2(30, 25)
	parent.add_child(coin_icon)

	_coin_label = Label.new()
	_coin_label.name = "CoinLabel"
	_coin_label.text = "金币: %d" % Global.coins
	_coin_label.position = Vector2(50, 12)
	_coin_label.add_theme_font_size_override("font_size", 18)
	_coin_label.modulate = Color(1, 1, 1, 0.9)
	parent.add_child(_coin_label)
	Global.coins_changed.connect(func(amount: int):
		if is_instance_valid(_coin_label):
			_coin_label.text = "金币: %d" % amount
	)

	_earned_label = Label.new()
	_earned_label.name = "TotalEarnedLabel"
	_earned_label.text = "累计: %d" % Global.total_earned
	_earned_label.position = Vector2(50, 34)
	_earned_label.add_theme_font_size_override("font_size", 11)
	_earned_label.modulate = Color(1, 1, 1, 0.6)
	parent.add_child(_earned_label)
	Global.total_earned_changed.connect(func(amount: int):
		if is_instance_valid(_earned_label):
			_earned_label.text = "累计: %d" % amount
	)

	_fish_count_label = Label.new()
	_fish_count_label.name = "FishCountLabel"
	_fish_count_label.text = "鱼: %d/%d" % [Global.fish_count, Global.max_fish]
	_fish_count_label.position = Vector2(view_size.x - 150, 15)
	_fish_count_label.add_theme_font_size_override("font_size", 16)
	_fish_count_label.modulate = Color(1, 1, 1, 0.9)
	parent.add_child(_fish_count_label)

	Global.fish_added.connect(_update_fish_count_display)
	Global.fish_sold.connect(_update_fish_count_display)
	Global.game_loaded.connect(_update_fish_count_display)

	# Menu button
	var menu_btn := Button.new()
	menu_btn.name = "MenuBtn"
	menu_btn.text = "菜单"
	menu_btn.position = Vector2(view_size.x - 60, 12)
	menu_btn.size = Vector2(50, 26)
	menu_btn.add_theme_font_size_override("font_size", 12)
	parent.add_child(menu_btn)
	menu_btn.pressed.connect(_toggle_game_menu)


func _build_shop_panel(parent: Node, view_size: Vector2) -> void:
	var shop_panel := Panel.new()
	shop_panel.name = "ShopPanel"
	shop_panel.size = Vector2(1000, 840)
	shop_panel.position = Vector2(view_size.x / 2 - 500, view_size.y / 2 - 420)
	shop_panel.visible = false
	parent.add_child(shop_panel)

	var shop_title := Label.new()
	shop_title.text = "商店"
	shop_title.position = Vector2(15, 12)
	shop_title.add_theme_font_size_override("font_size", 20)
	shop_title.modulate = Color(1, 1, 1, 0.9)
	shop_panel.add_child(shop_title)

	var close_btn := Button.new()
	close_btn.name = "CloseShopBtn"
	close_btn.text = "关闭"
	close_btn.position = Vector2(930, 10)
	close_btn.pressed.connect(toggle_shop)
	shop_panel.add_child(close_btn)

	var tab_container := TabContainer.new()
	tab_container.name = "TabContainer"
	tab_container.size = Vector2(980, 770)
	tab_container.position = Vector2(10, 45)
	shop_panel.add_child(tab_container)

	var fish_tab := VBoxContainer.new()
	fish_tab.name = "鱼类"
	var fish_scroll := ScrollContainer.new()
	fish_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fish_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fish_shop_list = GridContainer.new()
	_fish_shop_list.name = "FishList"
	_fish_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fish_scroll.add_child(_fish_shop_list)
	fish_tab.add_child(fish_scroll)
	tab_container.add_child(fish_tab)

	var deco_tab := VBoxContainer.new()
	deco_tab.name = "装饰"

	# 类型过滤勾选框
	var deco_filter_hbox := HBoxContainer.new()
	deco_filter_hbox.name = "DecoFilter"
	deco_filter_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deco_filter_hbox.custom_minimum_size = Vector2(0, 28)

	# 创建一个字典来存储所有过滤勾选框
	_deco_type_filters = {}
	for group in DecorationData.TypeGroup.values() as Array[int]:
		var cb := CheckBox.new()
		var name_cn := DecorationData.get_type_group_name(group)
		var name_en := DecorationData.get_type_group_name_en(group)
		cb.text = "%s (%s)" % [name_cn, name_en]
		cb.button_pressed = true  # 默认全勾
		cb.toggled.connect(_on_deco_filter_toggled)
		deco_filter_hbox.add_child(cb)
		_deco_type_filters[group] = cb

	deco_tab.add_child(deco_filter_hbox)

	var deco_scroll := ScrollContainer.new()
	deco_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deco_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_deco_shop_list = GridContainer.new()
	_deco_shop_list.name = "DecorationList"
	_deco_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deco_scroll.add_child(_deco_shop_list)
	deco_tab.add_child(deco_scroll)
	tab_container.add_child(deco_tab)

	var equip_tab := VBoxContainer.new()
	equip_tab.name = "设备"
	var equip_scroll := ScrollContainer.new()
	equip_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_equip_shop_list = VBoxContainer.new()
	_equip_shop_list.name = "EquipmentList"
	_equip_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip_scroll.add_child(_equip_shop_list)
	equip_tab.add_child(equip_scroll)
	tab_container.add_child(equip_tab)


func _build_side_menu_scene(parent: Node, view_size: Vector2) -> void:
	var scene := preload("res://scenes/ui/side_menu.tscn")
	_side_menu = scene.instantiate()
	_side_menu.name = "SideMenu"
	parent.add_child(_side_menu)
	_side_menu.update_position(view_size)


func _on_side_menu_feed(btn: Button) -> void:
	_feed_manager.toggle(btn)


func _on_side_menu_sell(btn: Button) -> void:
	Global.sell_mode = not Global.sell_mode
	if Global.sell_mode:
		btn.modulate = Color(1, 0.5, 0.5)
	else:
		btn.modulate = Color(1, 1, 1, 1)
	Global.sell_mode_changed.connect(func(active: bool):
		if is_instance_valid(btn):
			btn.modulate = Color(1, 0.5, 0.5) if active else Color(1, 1, 1, 1)
	, CONNECT_ONE_SHOT)


func _on_side_menu_move(btn: Button) -> void:
	Global.move_mode = not Global.move_mode
	if Global.move_mode:
		btn.modulate = Color(0.6, 1.0, 0.6)
	else:
		btn.modulate = Color(1, 1, 1, 1)
	Global.move_mode_changed.connect(func(active: bool):
		if is_instance_valid(btn):
			btn.modulate = Color(0.6, 1.0, 0.6) if active else Color(1, 1, 1, 1)
	, CONNECT_ONE_SHOT)


func _on_side_menu_tiny(btn: Button) -> void:
	_window_manager.toggle_tiny(btn)


func _on_side_menu_wallpaper(btn: Button) -> void:
	_window_manager.toggle_wallpaper(btn)


func _draw() -> void:
	for data in _window_manager.get_edge_highlights():
		draw_rect(data.rect, data.color)


func toggle_shop() -> void:
	if _decoration_placer.is_active():
		return
	shop_panel_open = not shop_panel_open
	if is_instance_valid(_ui_container):
		_ui_container.get_node("ShopPanel").visible = shop_panel_open

	if shop_panel_open:
		_refresh_shop_ui()


func _update_fish_columns() -> void:
	if _fish_shop_list == null:
		return
	var available := _fish_shop_list.size.x
	if available <= 0:
		available = 960.0
	_fish_shop_list.columns = maxi(1, int(available / 160))


func _update_decoration_columns() -> void:
	if _deco_shop_list == null:
		return
	# 根据 GridContainer 实际可用宽度计算列数
	var available := _deco_shop_list.size.x
	if available <= 0:
		# 后备：用 TabContainer 宽度估算（980 - 滚动条 ≈ 960）
		available = 960.0
	# 卡片宽度 150 + 间距 ≈ 160
	_deco_shop_list.columns = maxi(1, int(available / 160))


func _refresh_shop_ui() -> void:
	if _fish_shop_list == null or _deco_shop_list == null or _equip_shop_list == null:
		return

	for c in _fish_shop_list.get_children():
		c.queue_free()
	for c in _deco_shop_list.get_children():
		c.queue_free()
	for c in _equip_shop_list.get_children():
		c.queue_free()

	for species in FishData.Species.values() as Array[int]:
		if species == FishData.Species.COUNT:
			continue
		_add_fish_shop_entry(_fish_shop_list, species)

	_update_fish_columns()
	_update_decoration_columns()

	for deco_type in DecorationData.DecorationType.values() as Array[int]:
		if deco_type == DecorationData.DecorationType.COUNT:
			continue
		# 类型过滤：检查该装饰的类型分组是否被勾选
		var group := DecorationData.get_type_group(deco_type)
		var cb: CheckBox = _deco_type_filters.get(group)
		if cb != null and not cb.button_pressed:
			continue
		_add_deco_shop_entry(_deco_shop_list, deco_type)

	for eq_type in EquipmentData.EquipmentType.values() as Array[int]:
		if eq_type == EquipmentData.EquipmentType.AUTO_BUY:
			continue  # 自动买鱼已默认启用，无需购买
		_add_equip_shop_entry(_equip_shop_list, eq_type)


func _add_fish_shop_entry(parent: GridContainer, species: int) -> void:
	var card_scene := preload("res://scenes/ui/fish_card/fish_card.tscn")
	var card := card_scene.instantiate() as FishCard
	parent.add_child(card)
	card.setup(species)
	var s: int = species
	card.buy_pressed.connect(func(_type: int): _buy_fish(s))


func _add_deco_shop_entry(parent: GridContainer, deco_type: int) -> void:
	var card_scene := preload("res://scenes/ui/decoration_card/decoration_card.tscn")
	var card := card_scene.instantiate() as DecorationCard
	parent.add_child(card)
	card.setup(deco_type)
	var dt := deco_type
	card.buy_pressed.connect(func(_type: int): _buy_decoration(dt))


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
	if not Global.can_afford(cost):
		return
	if Global.spend(cost):
		toggle_shop()
		_decoration_placer.start_placement(deco_type)
		Global.save_dirty = true
		_refresh_shop_ui()





func _on_deco_filter_toggled(_toggled: bool) -> void:
	_refresh_shop_ui()


func _add_equip_shop_entry(parent: VBoxContainer, eq_type: int) -> void:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 75 if eq_type == EquipmentData.EquipmentType.AUTO_FEEDER else 45)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = EquipmentData.get_display_name(eq_type)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 判断是否已拥有
	var already_owned := false
	var is_toggle := false
	var is_auto_buy := false
	match eq_type:
		EquipmentData.EquipmentType.AUTO_FEEDER:
			already_owned = Global.has_auto_feeder
			is_toggle = true
		EquipmentData.EquipmentType.AUTO_SELL:
			already_owned = Global.has_auto_sell
			is_toggle = true
		EquipmentData.EquipmentType.AUTO_BUY:
			already_owned = Global.has_auto_buy
			is_auto_buy = true

	var cost: int = EquipmentData.get_cost(eq_type)
	var cost_label := Label.new()
	cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var buy_btn := Button.new()
	if already_owned:
		cost_label.text = "已拥有"
		if is_toggle:
			if eq_type == EquipmentData.EquipmentType.AUTO_FEEDER:
				buy_btn.text = "开启" if Global.auto_feeder_enabled else "关闭"
				buy_btn.disabled = false
				buy_btn.pressed.connect(_toggle_auto_feeder)
			else:
				buy_btn.text = "开启" if Global.auto_sell_enabled else "关闭"
				buy_btn.disabled = false
				buy_btn.pressed.connect(_toggle_auto_sell)
		elif is_auto_buy:
			buy_btn.text = "设置"
			buy_btn.disabled = false
			buy_btn.pressed.connect(_open_auto_buy_settings)
		else:
			buy_btn.text = "已装备"
			buy_btn.disabled = true
	else:
		cost_label.text = "¥%d" % cost
		buy_btn.text = "购买"
		buy_btn.disabled = Global.coins < cost
		var et := eq_type
		buy_btn.pressed.connect(func(): _buy_equipment(et))

	hbox.add_child(name_label)
	hbox.add_child(cost_label)
	hbox.add_child(buy_btn)
	vbox.add_child(hbox)
	panel.add_child(vbox)
	parent.add_child(panel)

	# 如果已拥有自动买鱼，在下方显示目标数量设置
	if already_owned and is_auto_buy:
		var settings_panel := _build_auto_buy_settings_panel()
		vbox.add_child(settings_panel)

	# 如果已拥有自动投喂器，在下方显示投喂数量设置
	if already_owned and eq_type == EquipmentData.EquipmentType.AUTO_FEEDER:
		var feed_settings := _build_auto_feeder_settings_panel()
		vbox.add_child(feed_settings)


func _buy_equipment(eq_type: int) -> void:
	var cost: int = EquipmentData.get_cost(eq_type)
	if Global.spend(cost):
		match eq_type:
			EquipmentData.EquipmentType.AUTO_FEEDER:
				Global.has_auto_feeder = true
				_spawn_auto_feeder()
			EquipmentData.EquipmentType.AUTO_SELL:
				Global.has_auto_sell = true
				Global.auto_sell_enabled = true
			EquipmentData.EquipmentType.AUTO_BUY:
				# 自动买鱼已默认启用，此分支不再使用
				pass
		Global.equipment_added.emit(eq_type)
		Global.save_dirty = true
		_refresh_shop_ui()


func _spawn_auto_feeder() -> void:
	var equipment_container := $Aquarium.get_node_or_null("EquipmentContainer") as Node2D
	if not equipment_container:
		return
	
	# 如果已有自动投喂机，移除旧的
	for child in equipment_container.get_children():
		if child is AutoFeeder:
			child.queue_free()
	
	var feeder := AutoFeeder.new()
	feeder.name = "AutoFeeder"
	equipment_container.add_child(feeder)


func _spawn_auto_buyer() -> void:
	var equipment_container := $Aquarium.get_node_or_null("EquipmentContainer") as Node2D
	if not equipment_container:
		return
	
	# 如果已有自动买鱼，移除旧的
	for child in equipment_container.get_children():
		if child.get_script() == _AutoBuyerScript:
			child.queue_free()
	
	var buyer := _AutoBuyerScript.new()
	buyer.name = "AutoBuyer"
	equipment_container.add_child(buyer)


func do_upgrade() -> void:
	var cost := 500
	if Global.spend(cost):
		Global.max_fish += 2
		Global.save_dirty = true
		_update_fish_count_display()


# ── Fish Info Panel ──────────────────────────────────────────────────────

func _build_fish_info_panel(parent: Node, _view_size: Vector2) -> void:
	_fish_info_panel = Panel.new()
	_fish_info_panel.name = "FishInfoPanel"
	_fish_info_panel.size = Vector2(280, 180)
	_fish_info_panel.visible = false
	parent.add_child(_fish_info_panel)

	var margin := 8
	var line_h := 20

	# Top row: fish name + index + prev/next arrows
	var top_hbox := HBoxContainer.new()
	top_hbox.position = Vector2(margin, margin)
	top_hbox.size = Vector2(264, 24)
	top_hbox.add_theme_constant_override("separation", 4)
	_fish_info_panel.add_child(top_hbox)

	_fish_info_name = Label.new()
	_fish_info_name.name = "FishInfoName"
	_fish_info_name.add_theme_font_size_override("font_size", 16)
	_fish_info_name.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	top_hbox.add_child(_fish_info_name)

	_fish_info_index = Label.new()
	_fish_info_index.name = "FishInfoIndex"
	_fish_info_index.add_theme_font_size_override("font_size", 13)
	_fish_info_index.modulate = Color(1, 1, 1, 0.6)
	_fish_info_index.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_hbox.add_child(_fish_info_index)

	# Spacer to push arrows to the right
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer)

	_fish_info_prev_btn = Button.new()
	_fish_info_prev_btn.name = "FishInfoPrevBtn"
	_fish_info_prev_btn.text = "◀"
	_fish_info_prev_btn.size = Vector2(28, 24)
	_fish_info_prev_btn.add_theme_font_size_override("font_size", 12)
	_fish_info_prev_btn.pressed.connect(_on_fish_info_prev)
	top_hbox.add_child(_fish_info_prev_btn)

	_fish_info_next_btn = Button.new()
	_fish_info_next_btn.name = "FishInfoNextBtn"
	_fish_info_next_btn.text = "▶"
	_fish_info_next_btn.size = Vector2(28, 24)
	_fish_info_next_btn.add_theme_font_size_override("font_size", 12)
	_fish_info_next_btn.pressed.connect(_on_fish_info_next)
	top_hbox.add_child(_fish_info_next_btn)

	# Close button (X) on the far right
	var close_btn := Button.new()
	close_btn.name = "FishInfoCloseBtn"
	close_btn.text = "✕"
	close_btn.size = Vector2(24, 24)
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.pressed.connect(_hide_fish_info)
	top_hbox.add_child(close_btn)

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
	_fish_info_desc.size = Vector2(264, 30)
	_fish_info_panel.add_child(_fish_info_desc)

	# Bottom row: sell price label + sell button
	var sell_hbox := HBoxContainer.new()
	sell_hbox.position = Vector2(margin, margin + line_h * 6 + 4)
	sell_hbox.size = Vector2(264, 24)
	sell_hbox.add_theme_constant_override("separation", 4)
	_fish_info_panel.add_child(sell_hbox)

	_fish_info_sell = Label.new()
	_fish_info_sell.name = "FishInfoSell"
	_fish_info_sell.add_theme_font_size_override("font_size", 11)
	_fish_info_sell.modulate = Color(1, 0.8, 0.4, 0.9)
	_fish_info_sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_hbox.add_child(_fish_info_sell)

	_fish_info_sell_btn = Button.new()
	_fish_info_sell_btn.name = "FishInfoSellBtn"
	_fish_info_sell_btn.text = "出售"
	_fish_info_sell_btn.size = Vector2(50, 24)
	_fish_info_sell_btn.add_theme_font_size_override("font_size", 12)
	_fish_info_sell_btn.pressed.connect(_sell_selected_fish)
	sell_hbox.add_child(_fish_info_sell_btn)

	_update_fish_info_panel_position()


func _update_fish_info_panel_position() -> void:
	if _fish_info_panel == null:
		return
	var view_size := get_viewport_rect().size
	_fish_info_panel.position = Vector2(10, view_size.y - 70 - _fish_info_panel.size.y - 8)


func _on_fish_info_requested(fish: Node2D) -> void:
	if not is_instance_valid(fish) or not fish is Fish:
		return
	# 清除之前选中鱼的选中状态
	if _selected_fish != null and is_instance_valid(_selected_fish):
		_selected_fish.selected = false
	_selected_fish = fish as Fish
	_selected_fish.selected = true
	_refresh_fish_info_panel()
	_fish_info_panel.visible = true


func _refresh_fish_info_panel() -> void:
	if _selected_fish == null or not is_instance_valid(_selected_fish):
		return
	var f := _selected_fish
	var species: int = f.species
	var lv: int = f.get_level()
	var max_h := FishData.get_max_hunger(species)
	var hunger_pct: int = int(f.hunger / max_h * 100)

	# Find index of selected fish in container
	var fish_list := fish_container.get_children()
	var idx := fish_list.find(f)
	var total := fish_list.size()

	_fish_info_name.text = FishData.get_species_name(species)
	_fish_info_index.text = "#%d/%d" % [idx + 1, total]
	_fish_info_name_en.text = FishData.get_species_name_en(species)
	_fish_info_level.text = "等级: %d / %d" % [lv, FishData.get_max_level(species)]
	_fish_info_hunger.text = "饱食度: %d%%" % hunger_pct
	_fish_info_desc.text = FishData.get_description(species)

	# Update sell info
	if f.get_sellable():
		_fish_info_sell.text = "售价: ¥%d" % f.get_sell_price()
		_fish_info_sell_btn.visible = true
	else:
		_fish_info_sell.text = "状态: 死亡"
		_fish_info_sell_btn.visible = false


func _navigate_fish(direction: int) -> void:
	if _selected_fish == null or not is_instance_valid(_selected_fish):
		return
	var fish_list := fish_container.get_children()
	if fish_list.size() <= 1:
		return
	var idx := fish_list.find(_selected_fish)
	var new_idx := (idx + direction + fish_list.size()) % fish_list.size()
	_selected_fish.selected = false
	_selected_fish = fish_list[new_idx] as Fish
	if _selected_fish:
		_selected_fish.selected = true
		_refresh_fish_info_panel()


func _on_fish_info_prev() -> void:
	_navigate_fish(-1)


func _on_fish_info_next() -> void:
	_navigate_fish(1)


func _sell_selected_fish() -> void:
	if _selected_fish == null or not is_instance_valid(_selected_fish):
		return
	var f := _selected_fish
	if not f.get_sellable():
		return

	# Find current index before selling
	var fish_list := fish_container.get_children()
	var idx := fish_list.find(f)
	var total := fish_list.size()

	# Sell the fish (queues free, not immediate)
	f.sell()

	# After selling, pick the next fish
	# Note: queue_free doesn't remove immediately, so the sold fish is still in the list
	if total <= 1:
		_selected_fish.selected = false
		_hide_fish_info()
	else:
		var new_idx := (idx - 1) if (idx >= total - 1) else (idx + 1)
		_selected_fish.selected = false
		_selected_fish = fish_container.get_child(new_idx) as Fish
		if _selected_fish:
			_selected_fish.selected = true
			_refresh_fish_info_panel()


func _hide_fish_info() -> void:
	if _selected_fish != null and is_instance_valid(_selected_fish):
		_selected_fish.selected = false
	_selected_fish = null
	if _fish_info_panel:
		_fish_info_panel.visible = false


func _toggle_auto_sell() -> void:
	Global.auto_sell_enabled = not Global.auto_sell_enabled
	Global.save_dirty = true
	_refresh_shop_ui()


# ── Auto-Buy Settings ───────────────────────────────────────────────────

var _auto_buy_settings_panel: Panel = null

func _open_auto_buy_settings() -> void:
	# 弹出自动买鱼设置界面
	if not is_instance_valid(_ui_container):
		return
	
	# 如果已打开则关闭
	if _auto_buy_settings_panel and is_instance_valid(_auto_buy_settings_panel):
		_close_auto_buy_settings()
		return
	
	var panel := Panel.new()
	panel.name = "AutoBuySettings"
	panel.size = Vector2(800, 660)
	panel.position = Vector2(get_viewport_rect().size.x / 2 - 400, get_viewport_rect().size.y / 2 - 330)
	_ui_container.add_child(panel)
	_auto_buy_settings_panel = panel
	
	var title := Label.new()
	title.text = "自动买鱼 - 目标数量设置"
	title.position = Vector2(15, 12)
	title.add_theme_font_size_override("font_size", 16)
	panel.add_child(title)
	
	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(730, 10)
	close_btn.size = Vector2(60, 24)
	close_btn.pressed.connect(_close_auto_buy_settings)
	panel.add_child(close_btn)
	
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 45)
	scroll.size = Vector2(780, 560)
	panel.add_child(scroll)
	
	var grid := GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.columns = 5
	scroll.add_child(grid)
	
	var card_scene := preload("res://scenes/ui/autobuy_card/autobuy_card.tscn")
	for species in FishData.Species.values() as Array[int]:
		if species == FishData.Species.COUNT:
			continue
		
		var card := card_scene.instantiate() as AutoBuyCard
		grid.add_child(card)
		card.setup(species)
		card.target_changed.connect(func(_s: int, _t: int):
			Global.save_dirty = true
		)
	
	# 底部提示
	var hint := Label.new()
	hint.text = "提示：设置每种鱼期望的数量，鱼缸中不足时将自动购买"
	hint.position = Vector2(15, 620)
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.size = Vector2(370, 25)
	panel.add_child(hint)


func _close_auto_buy_settings() -> void:
	if is_instance_valid(_ui_container):
		var panel := _ui_container.get_node_or_null("AutoBuySettings")
		if panel:
			panel.queue_free()
	_auto_buy_settings_panel = null


func _build_auto_buy_settings_panel() -> VBoxContainer:
	# 构建设备列表中的预览设置面板
	var settings_container := VBoxContainer.new()
	settings_container.name = "AutoBuySettingsPreview"
	settings_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_container.add_theme_constant_override("separation", 2)
	
	var targets: Dictionary = Global.auto_buy_targets
	if targets.is_empty():
		return settings_container
	
	for species in FishData.Species.values() as Array[int]:
		if species == FishData.Species.COUNT:
			continue
		if not Global.unlocked_species[species]:
			continue
		
		var target: int = targets.get(species, 0)
		if target <= 0:
			continue
		
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var name_label := Label.new()
		name_label.text = FishData.get_species_name(species)
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		
		var count_label := Label.new()
		count_label.text = "目标: %d" % target
		count_label.add_theme_font_size_override("font_size", 11)
		count_label.modulate = Color(1, 1, 0.6, 0.9)
		row.add_child(count_label)
		
		settings_container.add_child(row)
	
	return settings_container


# ── Auto Feeder Settings ────────────────────────────────────────────────

func _toggle_auto_feeder() -> void:
	Global.auto_feeder_enabled = not Global.auto_feeder_enabled
	Global.save_dirty = true
	_refresh_shop_ui()


func _build_auto_feeder_settings_panel() -> VBoxContainer:
	var container := VBoxContainer.new()
	container.name = "AutoFeederSettingsPreview"
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 2)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label := Label.new()
	label.text = "每次投喂数量"
	label.add_theme_font_size_override("font_size", 11)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var dec_btn := Button.new()
	dec_btn.text = "−"
	dec_btn.size = Vector2(26, 24)
	dec_btn.add_theme_font_size_override("font_size", 12)
	row.add_child(dec_btn)

	var val_label := Label.new()
	val_label.text = "%d" % Global.auto_feeder_feed_count
	val_label.add_theme_font_size_override("font_size", 12)
	val_label.modulate = Color(1, 1, 0.6, 0.9)
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_label.custom_minimum_size = Vector2(30, 0)
	row.add_child(val_label)

	var inc_btn := Button.new()
	inc_btn.text = "+"
	inc_btn.size = Vector2(26, 24)
	inc_btn.add_theme_font_size_override("font_size", 12)
	row.add_child(inc_btn)

	dec_btn.pressed.connect(func():
		var v := Global.auto_feeder_feed_count
		if v > 1:
			Global.auto_feeder_feed_count = v - 1
			val_label.text = "%d" % Global.auto_feeder_feed_count
			Global.save_dirty = true
	)

	inc_btn.pressed.connect(func():
		var v := Global.auto_feeder_feed_count
		Global.auto_feeder_feed_count = v + 1
		val_label.text = "%d" % Global.auto_feeder_feed_count
		Global.save_dirty = true
	)

	container.add_child(row)
	return container


# ── Game Menu ───────────────────────────────────────────────────────────

func _build_game_menu(parent: Node, view_size: Vector2) -> void:
	_game_menu_bg = ColorRect.new()
	_game_menu_bg.name = "GameMenuBg"
	_game_menu_bg.color = Color(0, 0, 0, 0.4)
	_game_menu_bg.size = view_size
	_game_menu_bg.position = Vector2.ZERO
	_game_menu_bg.visible = false
	_game_menu_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(_game_menu_bg)
	# Clicking bg closes menu
	_game_menu_bg.gui_input.connect(_on_menu_bg_input)

	_game_menu_panel = Panel.new()
	_game_menu_panel.name = "GameMenuPanel"
	_game_menu_panel.size = Vector2(220, 240)
	_game_menu_panel.position = Vector2(view_size.x / 2 - 110, view_size.y / 2 - 140)
	_game_menu_panel.visible = false
	parent.add_child(_game_menu_panel)

	var title := Label.new()
	title.text = "游戏菜单"
	title.position = Vector2(12, 12)
	title.add_theme_font_size_override("font_size", 18)
	_game_menu_panel.add_child(title)

	var save_btn := Button.new()
	save_btn.text = "保存游戏"
	save_btn.position = Vector2(20, 45)
	save_btn.size = Vector2(180, 30)
	_game_menu_panel.add_child(save_btn)
	save_btn.pressed.connect(_on_save_pressed)

	var restart_btn := Button.new()
	restart_btn.text = "重新开始游戏"
	restart_btn.position = Vector2(20, 82)
	restart_btn.size = Vector2(180, 30)
	_game_menu_panel.add_child(restart_btn)
	restart_btn.pressed.connect(_on_restart_pressed)

	# ── 启动模式选择 ──
	var mode_label := Label.new()
	mode_label.text = "启动模式"
	mode_label.position = Vector2(20, 122)
	mode_label.add_theme_font_size_override("font_size", 12)
	_game_menu_panel.add_child(mode_label)

	var mode_option := OptionButton.new()
	mode_option.name = "StartupModeOption"
	mode_option.position = Vector2(20, 142)
	mode_option.size = Vector2(180, 28)
	mode_option.add_item("普通模式", Global.STARTUP_NORMAL)
	mode_option.add_item("壁纸模式", Global.STARTUP_WALLPAPER)
	mode_option.add_item("Tiny 模式", Global.STARTUP_TINY)
	mode_option.selected = Global.startup_mode
	_game_menu_panel.add_child(mode_option)
	mode_option.item_selected.connect(func(index: int):
		Global.startup_mode = mode_option.get_item_id(index)
	)

	# ── 鱼缩放比例 ──
	_fish_scale_label = Label.new()
	_fish_scale_label.text = "鱼缩放: %.1fx" % Global.fish_scale
	_fish_scale_label.name = "FishScaleLabel"
	_fish_scale_label.position = Vector2(20, 178)
	_fish_scale_label.add_theme_font_size_override("font_size", 12)
	_game_menu_panel.add_child(_fish_scale_label)

	var dec_btn := Button.new()
	dec_btn.text = "<"
	dec_btn.position = Vector2(20, 196)
	dec_btn.size = Vector2(30, 28)
	_game_menu_panel.add_child(dec_btn)
	dec_btn.pressed.connect(func():
		var v: float = snapped(Global.fish_scale - 0.1, 0.1)
		Global.fish_scale = v
		_fish_scale_label.text = "鱼缩放: %.1fx" % v
	)

	var scale_slider := HSlider.new()
	scale_slider.name = "FishScaleSlider"
	scale_slider.position = Vector2(55, 196)
	scale_slider.size = Vector2(110, 28)
	scale_slider.min_value = 0.5
	scale_slider.max_value = 5.0
	scale_slider.step = 0.1
	scale_slider.value = Global.fish_scale
	_game_menu_panel.add_child(scale_slider)
	scale_slider.value_changed.connect(func(value: float):
		var v: float = snapped(value, 0.1)
		Global.fish_scale = v
		_fish_scale_label.text = "鱼缩放: %.1fx" % v
	)

	var inc_btn := Button.new()
	inc_btn.text = ">"
	inc_btn.position = Vector2(170, 196)
	inc_btn.size = Vector2(30, 28)
	_game_menu_panel.add_child(inc_btn)
	inc_btn.pressed.connect(func():
		var v: float = snapped(Global.fish_scale + 0.1, 0.1)
		Global.fish_scale = v
		_fish_scale_label.text = "鱼缩放: %.1fx" % v
	)


func _toggle_game_menu() -> void:
	_menu_open = not _menu_open
	_game_menu_bg.visible = _menu_open
	_game_menu_panel.visible = _menu_open
	if _menu_open and _fish_scale_label:
		_fish_scale_label.text = "鱼缩放: %.1fx" % Global.fish_scale


func _on_menu_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle_game_menu()


func _on_save_pressed() -> void:
	SaveManager.save_game()
	_toggle_game_menu()


func _on_restart_pressed() -> void:
	_toggle_game_menu()
	SaveManager.reset_save()


func _on_window_mode_ui_shown() -> void:
	"""退出窗口模式后恢复面板可见性"""
	if not is_instance_valid(_ui_container):
		return
	var shop_panel_node := _ui_container.get_node_or_null("ShopPanel") as Panel
	if shop_panel_node:
		shop_panel_node.visible = shop_panel_open
	if _fish_info_panel:
		_fish_info_panel.visible = _selected_fish != null and is_instance_valid(_selected_fish)
	if _game_menu_panel:
		_game_menu_panel.visible = _menu_open
	if _game_menu_bg:
		_game_menu_bg.visible = _menu_open


func _apply_startup_mode() -> void:
	match Global.startup_mode:
		Global.STARTUP_WALLPAPER:
			if not _window_manager.wallpaper_mode:
				_window_manager.enter_wallpaper()
				if is_instance_valid(_ui_container):
					var btn := _ui_container.get_node_or_null("Btn_wallpaper") as Button
					if btn:
						btn.modulate = Color(0.6, 1.0, 0.8)
		Global.STARTUP_TINY:
			if not _window_manager.tiny_mode:
				_window_manager.enter_tiny()
				if is_instance_valid(_ui_container):
					var btn := _ui_container.get_node_or_null("Btn_tiny") as Button
					if btn:
						btn.modulate = Color(0.8, 0.6, 1.0)


# ── Timescale ────────────────────────────────────────────────────────────

func _build_timescale_label(parent: Node, view_size: Vector2) -> void:
	_timescale_label = Label.new()
	_timescale_label.name = "TimescaleLabel"
	_timescale_label.text = "x%.1f" % Engine.time_scale
	_timescale_label.position = Vector2(view_size.x - 280, 15)
	_timescale_label.add_theme_font_size_override("font_size", 16)
	_timescale_label.modulate = Color(1, 1, 1, 0.9)
	parent.add_child(_timescale_label)

	Global.game_loaded.connect(func():
		if is_instance_valid(_timescale_label):
			_timescale_label.text = "x%.1f" % Engine.time_scale
	)


func _timescale_changed() -> void:
	if _timescale_label:
		_timescale_label.text = "x%.1f" % Engine.time_scale
		# Brief flash effect
		_timescale_label.modulate = Color(1, 1, 1, 1.0)
		var tween := create_tween()
		tween.tween_property(_timescale_label, "modulate", Color(1, 1, 1, 0.9), 1.0)
