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
var _menu_open: bool = false

var _coin_label: Label
var _earned_label: Label
var _fish_count_label: Label

var _wallpaper_mode: bool = false
var _tiny_mode: bool = false
var _prev_window_mode: int = DisplayServer.WINDOW_MODE_WINDOWED
var _prev_borderless: bool = false
var _prev_window_pos: Vector2i = Vector2i.ZERO
var _prev_window_size: Vector2i = Vector2i.ZERO
var _prev_always_on_top: bool = false

var _tiny_exit_popup: Panel = null

# Tiny 模式窗口拖拽/缩放
var _drag_active: bool = false
var _drag_start_mouse: Vector2i = Vector2i.ZERO
var _drag_start_window: Vector2i = Vector2i.ZERO
var _resize_active: bool = false
var _resize_start_mouse: Vector2i = Vector2i.ZERO
var _resize_start_size: Vector2i = Vector2i.ZERO
var _resize_start_pos: Vector2i = Vector2i.ZERO
var _resize_edges: int = 0

const EDGE_LEFT := 1
const EDGE_RIGHT := 2
const EDGE_TOP := 4
const EDGE_BOTTOM := 8
const RESIZE_HANDLE_SIZE := 20
const MIN_WINDOW_WIDTH := 100
const MIN_WINDOW_HEIGHT := 50

# Tiny 模式边缘高亮
var _tiny_near_left: bool = false
var _tiny_near_right: bool = false
var _tiny_near_top: bool = false
var _tiny_near_bottom: bool = false

const EDGE_HIGHLIGHT_COLOR := Color(1.0, 1.0, 0.3, 0.5)
const EDGE_HIGHLIGHT_THICKNESS := 20.0

# 装饰物放置模式
var _placement_preview: Sprite2D = null
var _placement_deco_type: int = -1

# 投喂模式
var _feed_mode: bool = false
var _feed_holding: bool = false
var _feed_hold_time: float = 0.0
const FEED_INTERVAL: float = 1.0 / 3.0


func _ready() -> void:
	Global.fish_added.connect(_on_fish_added)
	Global.fish_sold.connect(_on_fish_sold)
	Global.fish_info_requested.connect(_on_fish_info_requested)
	Global.game_loaded.connect(_on_game_loaded)
	Global.decoration_placed.connect(_on_decoration_placed)

	get_window().size_changed.connect(_on_window_resized)

	_setup_background_layer()
	_setup_ui()

	# 初始缩放（在 UI 构建之后，确保 viewport 已有效）
	call_deferred(&"_update_aquarium_scale")

	SaveManager.load_game()
	_restore_fish_from_save()
	# 装饰物和设备的恢复由 _on_game_loaded 信号处理
	# 等待一帧确保 UI 和 viewport 就绪后，按启动模式设置
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
	_restore_decorations_from_save()
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
	
	if Global.decoration_placement_active:
		_update_placement_preview()
	
	if _tiny_mode:
		_update_tiny_window()
		_update_resize_cursor()
	
	if _feed_mode and _feed_holding:
		_feed_hold_time += _delta
		while _feed_hold_time >= FEED_INTERVAL:
			_feed_hold_time -= FEED_INTERVAL
			_place_food_at_mouse()


func _handle_input() -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if (_tiny_mode or _wallpaper_mode) and _tiny_exit_popup and _tiny_exit_popup.visible:
			_close_tiny_exit_popup()
			return
		if _tiny_mode or _wallpaper_mode:
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
		elif Global.decoration_placement_active:
			_cancel_placement()
		elif _feed_mode:
			_exit_feed_mode()

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
	if (_tiny_mode or _wallpaper_mode) and event is InputEventMouseButton:
		var view_size := get_viewport_rect().size
		var mouse_pos := get_viewport().get_mouse_position()
		
		# 壁纸模式：仅拦截点击 + 右键弹窗（无拖拽缩放）
		if _wallpaper_mode:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if _tiny_exit_popup and is_instance_valid(_tiny_exit_popup) and _tiny_exit_popup.visible:
					var popup_rect := Rect2(_tiny_exit_popup.position, _tiny_exit_popup.size)
					if popup_rect.has_point(mouse_pos):
						return
					else:
						_close_tiny_exit_popup()
				get_viewport().set_input_as_handled()
				return
			if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				_show_tiny_exit_popup()
				get_viewport().set_input_as_handled()
				return
		
		# Tiny 模式：拖拽/缩放 + 右键弹窗
		
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _tiny_mode and event.double_click:
			# 双击直接退出 Tiny 模式
			_exit_tiny_mode()
			if is_instance_valid(_ui_container):
				var tiny_btn := _ui_container.get_node_or_null("Btn_tiny") as Button
				if tiny_btn:
					tiny_btn.modulate = Color(1, 1, 1, 1)
			get_viewport().set_input_as_handled()
			return
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			# 如果弹出菜单可见
			if _tiny_exit_popup and is_instance_valid(_tiny_exit_popup) and _tiny_exit_popup.visible:
				var popup_rect := Rect2(_tiny_exit_popup.position, _tiny_exit_popup.size)
				if popup_rect.has_point(mouse_pos):
					return  # 点击在菜单内，放行让按钮处理
				else:
					_close_tiny_exit_popup()  # 点击菜单外，关闭菜单
					# 不返回，继续走拖拽/缩放逻辑
			
			if event.pressed:
				# 检测鼠标靠近哪个窗口边缘
				_resize_edges = 0
				if mouse_pos.x <= RESIZE_HANDLE_SIZE:
					_resize_edges |= EDGE_LEFT
				if mouse_pos.x >= view_size.x - RESIZE_HANDLE_SIZE:
					_resize_edges |= EDGE_RIGHT
				if mouse_pos.y <= RESIZE_HANDLE_SIZE:
					_resize_edges |= EDGE_TOP
				if mouse_pos.y >= view_size.y - RESIZE_HANDLE_SIZE:
					_resize_edges |= EDGE_BOTTOM
				
				if _resize_edges != 0:
					# 边缘缩放
					_resize_active = true
					_resize_start_mouse = DisplayServer.mouse_get_position()
					_resize_start_size = DisplayServer.window_get_size()
					_resize_start_pos = DisplayServer.window_get_position()
				else:
					# 整个窗口拖拽移动
					_drag_active = true
					_drag_start_mouse = DisplayServer.mouse_get_position()
					_drag_start_window = DisplayServer.window_get_position()
				
				get_viewport().set_input_as_handled()
				return
			else:
				# 释放鼠标
				_drag_active = false
				_resize_active = false
				_resize_edges = 0
				Input.set_custom_mouse_cursor(null)
		
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_show_tiny_exit_popup()
			get_viewport().set_input_as_handled()
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
		if Global.decoration_placement_active and not shop_panel_open:
			_cancel_placement()
			return
		if _feed_mode:
			_exit_feed_mode()
			return
		if _selected_fish != null:
			_hide_fish_info()
			get_viewport().set_input_as_handled()
			return

	if Global.decoration_placement_active and not shop_panel_open and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_confirm_placement()
	
	if _feed_mode and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_feed_holding = true
				_feed_hold_time = 0.0
				_place_food_at_mouse()
			else:
				_feed_holding = false
			get_viewport().set_input_as_handled()
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
	_build_side_menu(container, view_size)
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
	for child in _ui_container.get_children():
		if child is Button and child.name.begins_with("Btn_"):
			var action := child.name.trim_prefix("Btn_")
			var buttons := [
				{"action": "shop"},
				{"action": "feed"},
				{"action": "sell"},
				{"action": "move"},
				{"action": "upgrade"},
				{"action": "autobuy"},
				{"action": "wallpaper"},
				{"action": "tiny"},
			]
			var btn_count := buttons.size()
			var btn_width := 70
			var btn_height := 65
			var spacing := 12
			var total_height := btn_count * btn_height + (btn_count - 1) * spacing
			var start_y := (view_size.y - total_height) / 2
			for i in btn_count:
				if buttons[i].action == action:
					child.position = Vector2(view_size.x - 85 + (85 - btn_width) / 2.0, start_y + i * (btn_height + spacing))
					break

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


func _build_side_menu(parent: Node, view_size: Vector2) -> void:
	var buttons := [
		{"text": "商店", "icon": "res://assets/ui/ui_shop.svg", "action": "shop"},
		{"text": "喂食", "icon": "res://assets/ui/ui_food.svg", "action": "feed"},
		{"text": "出售", "icon": "res://assets/ui/ui_sell.svg", "action": "sell"},
		{"text": "移动", "icon": "res://assets/ui/ui_move.svg", "action": "move"},
		{"text": "升级", "icon": "res://assets/ui/ui_star.svg", "action": "upgrade"},
		{"text": "自动", "icon": "res://assets/ui/ui_autobuy_gen.png", "action": "autobuy"},
		{"text": "壁纸", "icon": "", "action": "wallpaper"},
		{"text": "Tiny", "icon": "", "action": "tiny"},
	]

	var btn_count := buttons.size()
	var btn_width := 70
	var btn_height := 65
	var spacing := 12
	var total_height := btn_count * btn_height + (btn_count - 1) * spacing
	var start_y := (view_size.y - total_height) / 2

	for i in btn_count:
		var data: Dictionary = buttons[i]
		var btn_x := view_size.x - 85 + (85 - btn_width) / 2.0
		var btn_y := start_y + i * (btn_height + spacing)

		var btn := Button.new()
		btn.name = "Btn_%s" % data.action
		btn.text = data.text
		btn.position = Vector2(btn_x, btn_y)
		btn.size = Vector2(btn_width, btn_height)
		btn.add_theme_font_size_override("font_size", 10)
		parent.add_child(btn)

		if data.icon.is_empty():
			# 壁纸按钮无图标，仅文字
			btn.add_theme_font_size_override("font_size", 11)
		else:
			var tex := load(data.icon) as Texture2D
			if tex:
				btn.icon = tex
				btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER

		match data.action:
			"shop":
				btn.pressed.connect(toggle_shop)
			"feed":
				btn.pressed.connect(_toggle_feed_mode.bind(btn))
			"sell":
				btn.pressed.connect(_toggle_sell_mode.bind(btn))
			"move":
				btn.pressed.connect(_toggle_move_mode.bind(btn))
			"upgrade":
				btn.pressed.connect(do_upgrade)
			"autobuy":
				btn.pressed.connect(_open_auto_buy_settings)
			"wallpaper":
				btn.pressed.connect(_toggle_wallpaper_mode.bind(btn))
			"tiny":
				btn.pressed.connect(_toggle_tiny_mode.bind(btn))


func _toggle_sell_mode(btn: Button) -> void:
	Global.sell_mode = not Global.sell_mode
	if Global.sell_mode:
		btn.modulate = Color(1, 0.5, 0.5)
	else:
		btn.modulate = Color(1, 1, 1, 1)
	Global.sell_mode_changed.connect(func(active: bool):
		if is_instance_valid(btn):
			btn.modulate = Color(1, 0.5, 0.5) if active else Color(1, 1, 1, 1)
	, CONNECT_ONE_SHOT)


func _toggle_move_mode(btn: Button) -> void:
	Global.move_mode = not Global.move_mode
	if Global.move_mode:
		btn.modulate = Color(0.6, 1.0, 0.6)
	else:
		btn.modulate = Color(1, 1, 1, 1)
	Global.move_mode_changed.connect(func(active: bool):
		if is_instance_valid(btn):
			btn.modulate = Color(0.6, 1.0, 0.6) if active else Color(1, 1, 1, 1)
	, CONNECT_ONE_SHOT)


func _toggle_tiny_mode(btn: Button) -> void:
	if not _tiny_mode:
		_enter_tiny_mode()
		btn.modulate = Color(0.8, 0.6, 1.0)
	else:
		_exit_tiny_mode()
		btn.modulate = Color(1, 1, 1, 1)


const TINY_WIDTH := 400
const TINY_HEIGHT := 200


func _enter_tiny_mode() -> void:
	_prev_window_mode = DisplayServer.window_get_mode()
	_prev_borderless = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
	_prev_window_pos = DisplayServer.window_get_position()
	_prev_window_size = DisplayServer.window_get_size()
	_prev_always_on_top = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP)
	
	# 退出壁纸模式（如果已激活）
	if _wallpaper_mode:
		_exit_wallpaper_mode()
		# 找到 tiny 按钮重置颜色
		if is_instance_valid(_ui_container):
			var wallpaper_btn := _ui_container.get_node_or_null("Btn_wallpaper") as Button
			if wallpaper_btn:
				wallpaper_btn.modulate = Color(1, 1, 1, 1)
	
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	# 优先使用存档中或上次退出 Tiny 模式时的尺寸和位置
	if Global.tiny_window_size != Vector2i.ZERO:
		DisplayServer.window_set_size(Global.tiny_window_size)
		DisplayServer.window_set_position(Global.tiny_window_pos)
	else:
		DisplayServer.window_set_size(Vector2i(TINY_WIDTH, TINY_HEIGHT))
		# 居中
		var screen_center := DisplayServer.screen_get_size() / 2.0
		DisplayServer.window_set_position(Vector2i(int(screen_center.x - TINY_WIDTH / 2.0), int(screen_center.y - TINY_HEIGHT / 2.0)))
	
	_hide_all_ui()
	
	# 显式更新 Aquarium 缩放和鱼边界（确保 viewport 已更新）
	_update_aquarium_scale()
	
	_tiny_mode = true


func _exit_tiny_mode() -> void:
	# 记录当前 Tiny 窗口尺寸/位置，供下次进入时复用（也会通过 Global 存档）
	Global.tiny_window_size = DisplayServer.window_get_size()
	Global.tiny_window_pos = DisplayServer.window_get_position()

	_drag_active = false
	_resize_active = false
	Input.set_custom_mouse_cursor(null)
	_tiny_near_left = false
	_tiny_near_right = false
	_tiny_near_top = false
	_tiny_near_bottom = false
	queue_redraw()
	_close_tiny_exit_popup()
	_show_all_ui()
	
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, _prev_borderless)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, _prev_always_on_top)
	DisplayServer.window_set_mode(_prev_window_mode)
	if _prev_window_pos != Vector2i.ZERO:
		DisplayServer.window_set_position(_prev_window_pos)
	if _prev_window_size != Vector2i.ZERO:
		DisplayServer.window_set_size(_prev_window_size)
	
	_tiny_mode = false


func _hide_all_ui() -> void:
	if is_instance_valid(_ui_container):
		_ui_container.visible = false


func _show_all_ui() -> void:
	if not is_instance_valid(_ui_container):
		return
	_ui_container.visible = true
	# 按当前状态隐藏不应显示的面板
	var shop_panel_node := _ui_container.get_node_or_null("ShopPanel") as Panel
	if shop_panel_node:
		shop_panel_node.visible = shop_panel_open
	if _fish_info_panel:
		_fish_info_panel.visible = _selected_fish != null and is_instance_valid(_selected_fish)
	if _game_menu_panel:
		_game_menu_panel.visible = _menu_open
	if _game_menu_bg:
		_game_menu_bg.visible = _menu_open


func _show_tiny_exit_popup() -> void:
	if _tiny_exit_popup and _tiny_exit_popup.visible:
		return
	_close_tiny_exit_popup()
	
	var ui := get_node_or_null("UI") as CanvasLayer
	if ui == null:
		return
	
	var mode_name := "壁纸" if _wallpaper_mode else "Tiny"
	
	var popup := Panel.new()
	popup.name = "TinyExitPopup"
	popup.size = Vector2(200, 130)
	var view_size := get_viewport_rect().size
	popup.position = Vector2(view_size.x / 2 - 100, view_size.y / 2 - 65)
	ui.add_child(popup)
	_tiny_exit_popup = popup
	
	var label := Label.new()
	label.text = mode_name + " 模式"
	label.position = Vector2(12, 12)
	label.add_theme_font_size_override("font_size", 14)
	popup.add_child(label)
	
	var exit_btn := Button.new()
	exit_btn.text = "退出 " + mode_name + " 模式"
	exit_btn.position = Vector2(20, 45)
	exit_btn.size = Vector2(160, 30)
	popup.add_child(exit_btn)
	if _wallpaper_mode:
		exit_btn.pressed.connect(_on_wallpaper_exit_pressed)
	else:
		exit_btn.pressed.connect(_on_tiny_exit_pressed)
	
	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.position = Vector2(20, 85)
	cancel_btn.size = Vector2(160, 28)
	popup.add_child(cancel_btn)
	cancel_btn.pressed.connect(_close_tiny_exit_popup)


func _close_tiny_exit_popup() -> void:
	if _tiny_exit_popup and is_instance_valid(_tiny_exit_popup):
		_tiny_exit_popup.queue_free()
	_tiny_exit_popup = null


func _update_tiny_window() -> void:
	if _drag_active:
		var current_mouse := DisplayServer.mouse_get_position()
		var delta := current_mouse - _drag_start_mouse
		DisplayServer.window_set_position(_drag_start_window + delta)
	
	if _resize_active:
		var current_mouse := DisplayServer.mouse_get_position()
		var delta := current_mouse - _resize_start_mouse
		var new_size := _resize_start_size
		var new_pos := _resize_start_pos
		
		if _resize_edges & EDGE_RIGHT:
			new_size.x = maxi(_resize_start_size.x + delta.x, MIN_WINDOW_WIDTH)
		if _resize_edges & EDGE_LEFT:
			var nw := maxi(_resize_start_size.x - delta.x, MIN_WINDOW_WIDTH)
			new_pos.x = _resize_start_pos.x + (_resize_start_size.x - nw)
			new_size.x = nw
		if _resize_edges & EDGE_BOTTOM:
			new_size.y = maxi(_resize_start_size.y + delta.y, MIN_WINDOW_HEIGHT)
		if _resize_edges & EDGE_TOP:
			var nh := maxi(_resize_start_size.y - delta.y, MIN_WINDOW_HEIGHT)
			new_pos.y = _resize_start_pos.y + (_resize_start_size.y - nh)
			new_size.y = nh
		
		DisplayServer.window_set_position(new_pos)
		DisplayServer.window_set_size(new_size)


func _update_resize_cursor() -> void:
	if _resize_active:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var view_size := get_viewport_rect().size
	
	# 鼠标在窗口外时不显示高亮
	var mouse_inside := mouse_pos.x >= 0 and mouse_pos.x < view_size.x and mouse_pos.y >= 0 and mouse_pos.y < view_size.y
	
	var near_left := mouse_inside and mouse_pos.x <= RESIZE_HANDLE_SIZE
	var near_right := mouse_inside and mouse_pos.x >= view_size.x - RESIZE_HANDLE_SIZE
	var near_top := mouse_inside and mouse_pos.y <= RESIZE_HANDLE_SIZE
	var near_bottom := mouse_inside and mouse_pos.y >= view_size.y - RESIZE_HANDLE_SIZE
	
	# 更新边缘高亮状态并触发重绘
	if near_left != _tiny_near_left or near_right != _tiny_near_right or near_top != _tiny_near_top or near_bottom != _tiny_near_bottom:
		_tiny_near_left = near_left
		_tiny_near_right = near_right
		_tiny_near_top = near_top
		_tiny_near_bottom = near_bottom
		queue_redraw()
	
	if near_left and near_top:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	elif near_right and near_bottom:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	elif near_left and near_bottom:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	elif near_right and near_top:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	elif near_left or near_right:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_HSPLIT)
	elif near_top or near_bottom:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_VSPLIT)
	else:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_MOVE)


func _draw() -> void:
	if not _tiny_mode:
		return
	var view_size := get_viewport_rect().size
	if _tiny_near_left:
		draw_rect(Rect2(0, 0, EDGE_HIGHLIGHT_THICKNESS, view_size.y), EDGE_HIGHLIGHT_COLOR)
	if _tiny_near_right:
		draw_rect(Rect2(view_size.x - EDGE_HIGHLIGHT_THICKNESS, 0, EDGE_HIGHLIGHT_THICKNESS, view_size.y), EDGE_HIGHLIGHT_COLOR)
	if _tiny_near_top:
		draw_rect(Rect2(0, 0, view_size.x, EDGE_HIGHLIGHT_THICKNESS), EDGE_HIGHLIGHT_COLOR)
	if _tiny_near_bottom:
		draw_rect(Rect2(0, view_size.y - EDGE_HIGHLIGHT_THICKNESS, view_size.x, EDGE_HIGHLIGHT_THICKNESS), EDGE_HIGHLIGHT_COLOR)


func _on_tiny_exit_pressed() -> void:
	if is_instance_valid(_ui_container):
		var tiny_btn := _ui_container.get_node_or_null("Btn_tiny") as Button
		if tiny_btn:
			_exit_tiny_mode()
			tiny_btn.modulate = Color(1, 1, 1, 1)


func _on_wallpaper_exit_pressed() -> void:
	if is_instance_valid(_ui_container):
		var wp_btn := _ui_container.get_node_or_null("Btn_wallpaper") as Button
		if wp_btn:
			_exit_wallpaper_mode()
			wp_btn.modulate = Color(1, 1, 1, 1)


func _toggle_wallpaper_mode(btn: Button) -> void:
	if not _wallpaper_mode:
		_enter_wallpaper_mode()
		btn.modulate = Color(0.6, 1.0, 0.8)
	else:
		_exit_wallpaper_mode()
		btn.modulate = Color(1, 1, 1, 1)


func _enter_wallpaper_mode() -> void:
	_prev_window_mode = DisplayServer.window_get_mode()
	_prev_borderless = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
	_prev_window_pos = DisplayServer.window_get_position()
	_prev_window_size = DisplayServer.window_get_size()
	
	# 退出 tiny 模式（如果已激活）
	if _tiny_mode:
		if is_instance_valid(_ui_container):
			var tiny_btn := _ui_container.get_node_or_null("Btn_tiny") as Button
			if tiny_btn:
				_exit_tiny_mode()
				tiny_btn.modulate = Color(1, 1, 1, 1)
	
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	# 窗口最大化（不覆盖任务栏）
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	
	_hide_all_ui()
	
	# 在 Windows 上将窗口设为壁纸层（壁纸之上、图标之下）
	if DisplayServer.get_name() == "Windows":
		_set_window_as_wallpaper_windows()
	
	_wallpaper_mode = true


func _exit_wallpaper_mode() -> void:
	_close_tiny_exit_popup()
	_show_all_ui()
	
	if DisplayServer.get_name() == "Windows":
		_restore_window_parent_windows()
	
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, _prev_borderless)
	DisplayServer.window_set_mode(_prev_window_mode)
	if _prev_window_pos != Vector2i.ZERO:
		DisplayServer.window_set_position(_prev_window_pos)
	if _prev_window_size != Vector2i.ZERO:
		DisplayServer.window_set_size(_prev_window_size)
	
	_wallpaper_mode = false


func _set_window_as_wallpaper_windows() -> void:
	"""通过 PowerShell 调用 Win32 API，将游戏窗口设为桌面壁纸层子窗口（壁纸之上、图标之下）"""
	var hwnd := DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)
	if hwnd == 0:
		return
	
	var ps_code := (
		'Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W {
    [DllImport("user32.dll")] public static extern IntPtr FindWindow(string c, string w);
    [DllImport("user32.dll")] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr c, string cn, string wn);
    [DllImport("user32.dll")] public static extern IntPtr SetParent(IntPtr c, IntPtr p);
    [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int h, bool r);
    [DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, int m, IntPtr wp, IntPtr lp, uint f, uint t, out IntPtr r);
    [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h, int cmd);
}
"@
Add-Type -AssemblyName System.Windows.Forms
$hwnd=[IntPtr]' + str(hwnd) + '
$progman=[W]::FindWindow("Progman",$null)
# 发送 0x052C 让 Progman 将桌面图标分离到 WorkerW
[W]::SendMessageTimeout($progman,0x052C,[IntPtr]::Zero,[IntPtr]::Zero,2,1000,[ref][IntPtr]::Zero)
# 遍历 WorkerW，找到包含 SHELLDLL_DefView 的那个（桌面图标层）
$workerW=[IntPtr]::Zero
$wallpaperW=[IntPtr]::Zero
while($true){
    $workerW=[W]::FindWindowEx([IntPtr]::Zero,$workerW,"WorkerW",$null)
    if($workerW -eq [IntPtr]::Zero){break}
    $defView=[W]::FindWindowEx($workerW,[IntPtr]::Zero,"SHELLDLL_DefView",$null)
    if($defView -ne [IntPtr]::Zero){
        # 图标层的上一个 Z 序窗口就是壁纸层
        $wallpaperW=[W]::GetWindow($workerW,3)  # GW_HWNDPREV = 3
        if($wallpaperW -eq [IntPtr]::Zero){$wallpaperW=$progman}
        break
    }
}
if($wallpaperW -eq [IntPtr]::Zero){$wallpaperW=$progman}
[W]::SetParent($hwnd,[IntPtr]::Zero)
[W]::SetParent($hwnd,$wallpaperW)
$w=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
$h=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height
[W]::MoveWindow($hwnd,0,0,$w,$h,$true)
'
	)
	
	OS.execute("powershell", ["-NoProfile", "-NoLogo", "-Command", ps_code], [], true)


func _restore_window_parent_windows() -> void:
	"""将窗口父级设回桌面"""
	var hwnd := DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)
	if hwnd == 0:
		return
	
	var ps_code := (
		'Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W {
    [DllImport("user32.dll")] public static extern IntPtr SetParent(IntPtr c, IntPtr p);
}
"@
[W]::SetParent([IntPtr]' + str(hwnd) + ',[IntPtr]::Zero)
'
	)
	
	OS.execute("powershell", ["-NoProfile", "-NoLogo", "-Command", ps_code], [], true)


func toggle_shop() -> void:
	if Global.decoration_placement_active:
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
		# 先关闭商店，再进入放置模式（否则 toggle_shop 会被放置模式拦截）
		toggle_shop()
		_enter_placement_mode(deco_type)
		Global.save_dirty = true
		_refresh_shop_ui()


# ═══════════════════════════════════════════════════════════
#  装饰物放置模式
# ═══════════════════════════════════════════════════════════

func _enter_placement_mode(deco_type: int) -> void:
	"""进入放置模式：鼠标跟随预览，点击放置"""
	Global.decoration_placement_active = true
	_placement_deco_type = deco_type
	
	# 创建预览精灵
	_placement_preview = Sprite2D.new()
	_placement_preview.name = "PlacementPreview"
	var tex_path := DecorationData.get_texture_path(deco_type)
	if ResourceLoader.exists(tex_path):
		_placement_preview.texture = load(tex_path)
	_placement_preview.scale = Vector2(0.5, 0.5)
	_placement_preview.modulate = Color(1, 1, 1, 0.6)  # 半透明
	_placement_preview.z_index = 10
	decoration_container.add_child(_placement_preview)
	
	_update_placement_preview()


func _update_placement_preview() -> void:
	"""更新预览跟随鼠标位置（转换到 Aquarium 本地坐标 = 设计空间）"""
	if _placement_preview == null:
		return
	var mouse_pos := get_global_mouse_position()
	# 转换到 Aquarium 本地设计空间坐标
	var local_pos := aquarium.to_local(mouse_pos)
	# 限制在鱼缸范围内
	var margin := 20.0
	var clamped_x := clampf(local_pos.x, margin, aquarium_bounds.size.x - margin)
	var clamped_y := clampf(local_pos.y, aquarium_bounds.size.y * 0.3, aquarium_bounds.size.y - margin)
	_placement_preview.position = Vector2(clamped_x, clamped_y)


func _confirm_placement() -> void:
	"""确认放置装饰物"""
	if _placement_preview == null:
		return
	
	var pos := _placement_preview.position
	var preview_scale := _placement_preview.scale
	# 新装饰默认层级为 10
	var new_z := 10
	_place_decoration(_placement_deco_type, pos, preview_scale, new_z)
	Global.owned_decorations.append({"type": _placement_deco_type, "x": pos.x, "y": pos.y, "scale_x": preview_scale.x, "scale_y": preview_scale.y, "z_index": new_z})
	Global.decoration_placed.emit(_placement_deco_type, pos)
	Global.save_dirty = true
	_exit_placement_mode()


func _cancel_placement() -> void:
	"""取消放置，退还金币"""
	if _placement_deco_type >= 0:
		var cost := DecorationData.get_cost(_placement_deco_type)
		Global.coins += cost  # 退款
	_exit_placement_mode()


func _exit_placement_mode() -> void:
	"""退出放置模式，清理预览"""
	Global.decoration_placement_active = false
	_placement_deco_type = -1
	if _placement_preview:
		_placement_preview.queue_free()
		_placement_preview = null


func _place_decoration(deco_type: int, pos: Vector2, initial_scale: Vector2 = Vector2(0.5, 0.5), z_idx: int = 0) -> void:
	"""在指定位置生成装饰物精灵"""
	var deco: Sprite2D = Global.make_decoration_sprite(deco_type, initial_scale, z_idx)
	if deco == null:
		return
	deco.position = pos
	_connect_decoration_interaction(deco)
	decoration_container.add_child(deco)


func _connect_decoration_interaction(deco: Sprite2D) -> void:
	"""为装饰物连接出售模式的点击和悬停交互"""
	var area := deco.get_node_or_null("ClickArea") as Area2D
	if area == null:
		return
	
	var aqua_ref := $Aquarium as Aquarium
	
	area.input_event.connect(func(_viewport: Node, event: InputEvent, _shape_idx: int):
		if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			return
		
		# 移动模式 - 转发到 aquarium 处理
		if Global.move_mode and aqua_ref:
			aqua_ref._handle_decoration_input(deco, event)
			return
		
		if not Global.sell_mode:
			return
		Global.sell_decoration_sprite(deco)
	)
	
	area.mouse_entered.connect(func():
		if Global.move_mode and aqua_ref and aqua_ref._move_selected_deco != deco:
			deco.modulate = Color(0.8, 1.0, 0.8, 1)
		elif Global.sell_mode:
			deco.modulate = Color(1, 0.6, 0.6, 1)
	)
	
	area.mouse_exited.connect(func():
		if Global.move_mode:
			if aqua_ref and aqua_ref._move_selected_deco != deco:
				deco.modulate = Color(1, 1, 1, 1)
		elif not Global.sell_mode:
			deco.modulate = Color(1, 1, 1, 1)
	)
	
	# 模式切换时恢复装饰物颜色
	var sell_lambda := func(active: bool):
		if not is_instance_valid(deco):
			return
		if not active and not Global.move_mode:
			deco.modulate = Color(1, 1, 1, 1)
	
	var move_lambda := func(active: bool):
		if not is_instance_valid(deco):
			return
		if not active:
			deco.modulate = Color(1, 1, 1, 1)
	
	Global.sell_mode_changed.connect(sell_lambda)
	Global.move_mode_changed.connect(move_lambda)
	
	# 装饰物被销毁时自动断开全局信号，避免悬空捕获
	deco.tree_exited.connect(func():
		if Global.sell_mode_changed.is_connected(sell_lambda):
			Global.sell_mode_changed.disconnect(sell_lambda)
		if Global.move_mode_changed.is_connected(move_lambda):
			Global.move_mode_changed.disconnect(move_lambda)
	)


func _on_decoration_placed(_deco_type: int, _position: Vector2) -> void:
	"""由 Global.decoration_placed 信号触发"""
	pass


func _restore_decorations_from_save() -> void:
	"""从存档恢复已拥有的装饰物"""
	# 清除现有装饰物，避免重复
	for child in decoration_container.get_children():
		if child.name != "PlacementPreview":
			child.queue_free()
	
	for d in Global.owned_decorations:
		if typeof(d) == TYPE_DICTIONARY:
			var dict = d
			var deco_type: int = dict.get("type", 0)
			var pos := Vector2(dict.get("x", 0), dict.get("y", 0))
			var deco_scale := Vector2(dict.get("scale_x", 0.5), dict.get("scale_y", 0.5))
			var z_idx: int = dict.get("z_index", 0)
			# 如果位置为 (0,0) 且是旧格式迁移来的，随机放置
			if pos == Vector2.ZERO and dict.get("x", 0) == 0 and dict.get("y", 0) == 0:
				var margin := 100.0
				pos.x = randf_range(margin, aquarium_bounds.size.x - margin)
				pos.y = randf_range(aquarium_bounds.size.y * 0.4, aquarium_bounds.size.y - 20.0)
			_place_decoration(deco_type, pos, deco_scale, z_idx)
		else:
			# 旧格式：只有类型 int
			var deco_type: int = d
			var margin := 100.0
			var x := randf_range(margin, aquarium_bounds.size.x - margin)
			var y := randf_range(aquarium_bounds.size.y * 0.4, aquarium_bounds.size.y - 20.0)
			_place_decoration(deco_type, Vector2(x, y))
	
	# 恢复后按 z_index 排序
	var aqua := $Aquarium as Aquarium
	if aqua and aqua.has_method("_sort_decoration_children"):
		aqua._sort_decoration_children()


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


func do_feed() -> void:
	if fish_container.get_child_count() == 0:
		return

	if not Global.spend(10):
		return

	var pellet_scene := preload("res://scenes/food/food_pellet.tscn")
	var pellet_script := preload("res://scripts/food/food_pellet.gd")
	for i in 10:
		var pellet := pellet_scene.instantiate()
		pellet.set_script(pellet_script)

		var margin := 80
		var x := randf_range(aquarium_bounds.position.x + margin, aquarium_bounds.position.x + aquarium_bounds.size.x - margin)
		pellet.position = Vector2(x, aquarium_bounds.position.y + 10)
		pellet.bottom_y = aquarium_bounds.position.y + aquarium_bounds.size.y - 10
		food_container.add_child(pellet)

		for fish in fish_container.get_children():
			if fish.has_method("set_food_target"):
				fish.set_food_target(pellet)


# ── 投喂模式 ─────────────────────────────────────────────────────────────

func _toggle_feed_mode(btn: Button) -> void:
	if not _feed_mode:
		_enter_feed_mode()
		btn.modulate = Color(1.0, 0.8, 0.4)
	else:
		_exit_feed_mode()


func _enter_feed_mode() -> void:
	_feed_mode = true
	# 将光标设为鱼食图标（缩放到 32x32）
	var cursor_tex := load("res://assets/ui/ui_food.svg") as Texture2D
	if cursor_tex:
		var img := cursor_tex.get_image()
		if img:
			img.resize(32, 32, Image.INTERPOLATE_LANCZOS)
			var scaled_tex := ImageTexture.create_from_image(img)
			Input.set_custom_mouse_cursor(scaled_tex, Input.CURSOR_ARROW, Vector2(16, 16))


func _exit_feed_mode() -> void:
	_feed_mode = false
	_feed_holding = false
	_feed_hold_time = 0.0
	Input.set_custom_mouse_cursor(null)
	if is_instance_valid(_ui_container):
		var feed_btn := _ui_container.get_node_or_null("Btn_feed") as Button
		if feed_btn:
			feed_btn.modulate = Color(1, 1, 1, 1)


func _place_food_at_mouse() -> void:
	if fish_container.get_child_count() == 0:
		return
	if not Global.spend(10):
		return
	
	var mouse_pos := get_global_mouse_position()
	var local_pos := aquarium.to_local(mouse_pos)
	
	var margin := 20.0
	var clamped_x := clampf(local_pos.x, margin, aquarium_bounds.size.x - margin)
	var clamped_y := clampf(local_pos.y, margin, aquarium_bounds.size.y - margin)
	
	var pellet_scene := preload("res://scenes/food/food_pellet.tscn")
	var pellet_script := preload("res://scripts/food/food_pellet.gd")
	var pellet := pellet_scene.instantiate()
	pellet.set_script(pellet_script)
	pellet.position = Vector2(clamped_x, clamped_y)
	pellet.bottom_y = aquarium_bounds.position.y + aquarium_bounds.size.y - 10
	food_container.add_child(pellet)
	
	for fish in fish_container.get_children():
		if fish.has_method("set_food_target"):
			fish.set_food_target(pellet)


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
	var hunger_pct: int = int(f.hunger * 100)

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
	var scale_label := Label.new()
	scale_label.text = "鱼缩放: 1.0x"
	scale_label.name = "FishScaleLabel"
	scale_label.position = Vector2(20, 178)
	scale_label.add_theme_font_size_override("font_size", 12)
	_game_menu_panel.add_child(scale_label)

	var scale_slider := HSlider.new()
	scale_slider.name = "FishScaleSlider"
	scale_slider.position = Vector2(20, 196)
	scale_slider.size = Vector2(180, 28)
	scale_slider.min_value = 0.5
	scale_slider.max_value = 10.0
	scale_slider.step = 0.1
	scale_slider.value = Global.fish_scale
	_game_menu_panel.add_child(scale_slider)
	scale_slider.value_changed.connect(func(value: float):
		value = snapped(value, 0.1)
		Global.fish_scale = value
		scale_label.text = "鱼缩放: %.1fx" % value
	)


func _toggle_game_menu() -> void:
	_menu_open = not _menu_open
	_game_menu_bg.visible = _menu_open
	_game_menu_panel.visible = _menu_open


func _on_menu_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle_game_menu()


func _on_save_pressed() -> void:
	SaveManager.save_game()
	_toggle_game_menu()


func _on_restart_pressed() -> void:
	_toggle_game_menu()
	SaveManager.reset_save()


func _apply_startup_mode() -> void:
	match Global.startup_mode:
		Global.STARTUP_WALLPAPER:
			if not _wallpaper_mode:
				_enter_wallpaper_mode()
				if is_instance_valid(_ui_container):
					var btn := _ui_container.get_node_or_null("Btn_wallpaper") as Button
					if btn:
						btn.modulate = Color(0.6, 1.0, 0.8)
		Global.STARTUP_TINY:
			if not _tiny_mode:
				_enter_tiny_mode()
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
