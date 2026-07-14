extends Node2D

class_name Aquarium

@onready var fish_container: Node2D = $FishContainer
@onready var food_container: Node2D = $FoodContainer
@onready var decoration_container: Node2D = $DecorationContainer
var food_pellets: Array[Node2D] = []

# 水面高度比例（占视口高度百分比，0.0~1.0）
var water_surface_height_ratio: float = 0.06:
	set(value):
		water_surface_height_ratio = clampf(value, 0.0, 0.5)
		_update_water_surface()

var _water_surface: ColorRect = null
var _water_surface_material: ShaderMaterial = null

# ── Decorations move/resize mode ──────────────────────────────────────────
var _move_selected_deco: Sprite2D = null
var _selection_overlay: Node2D = null
var _is_dragging_deco: bool = false
var _deco_drag_type: String = ""  # "move" or handle name
var _deco_drag_start_mouse_global: Vector2 = Vector2.ZERO
var _deco_drag_start_pos: Vector2 = Vector2.ZERO
var _deco_drag_start_scale: Vector2 = Vector2.ZERO
var _deco_drag_start_tex_size: Vector2 = Vector2.ZERO
var _hovered_edge: String = ""  # 当前鼠标悬停的边缘/控制点名称
const HANDLE_SIZE: float = 8.0
const HANDLE_HIT: float = 14.0  # 点击检测范围


# 获取装饰物在父级坐标下的包围矩形（基于纹理和缩放）
static func _get_deco_rect(deco: Sprite2D) -> Rect2:
	if deco.texture == null:
		return Rect2(deco.position, Vector2(64, 64))
	var tex_size := deco.texture.get_size()
	var size := tex_size * deco.scale
	# Sprite2D 默认 centered=true，位置在中心
	return Rect2(deco.position - size / 2, size)


# 获取装饰物在本地坐标下的 8 个控制点位置
static func _get_handle_positions(deco: Sprite2D) -> Dictionary:
	var rect := _get_deco_rect(deco)
	var r := rect
	var hs := HANDLE_SIZE
	return {
		"top_left":     Vector2(r.position.x, r.position.y),
		"top_center":   Vector2(r.position.x + r.size.x / 2, r.position.y),
		"top_right":    Vector2(r.position.x + r.size.x, r.position.y),
		"middle_left":  Vector2(r.position.x, r.position.y + r.size.y / 2),
		"middle_right": Vector2(r.position.x + r.size.x, r.position.y + r.size.y / 2),
		"bottom_left":  Vector2(r.position.x, r.position.y + r.size.y),
		"bottom_center":Vector2(r.position.x + r.size.x / 2, r.position.y + r.size.y),
		"bottom_right": Vector2(r.position.x + r.size.x, r.position.y + r.size.y),
	}


# 判断鼠标点击位置是否在某个控制点上
static func _hit_test_handle(deco: Sprite2D, local_pos: Vector2) -> String:
	var handles := _get_handle_positions(deco)
	var threshold := HANDLE_HIT
	for name in handles:
		var hp: Vector2 = handles[name]
		if local_pos.distance_to(hp) <= threshold:
			return name
	return ""


# 判断鼠标点击位置是否在装饰物边缘上（排除角落控制点）
static func _hit_test_edge(deco: Sprite2D, local_pos: Vector2) -> String:
	var rect := _get_deco_rect(deco)
	var threshold := HANDLE_HIT
	var handles := _get_handle_positions(deco)
	
	# 排除角落控制点区域
	for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		if local_pos.distance_to(handles[corner]) <= threshold:
			return ""
	
	var r := rect
	var inside_x := local_pos.x >= r.position.x - threshold and local_pos.x <= r.position.x + r.size.x + threshold
	var inside_y := local_pos.y >= r.position.y - threshold and local_pos.y <= r.position.y + r.size.y + threshold
	
	if not inside_x or not inside_y:
		return ""
	
	# 上边缘
	if abs(local_pos.y - r.position.y) <= threshold:
		return "top_edge"
	# 下边缘
	if abs(local_pos.y - (r.position.y + r.size.y)) <= threshold:
		return "bottom_edge"
	# 左边缘
	if abs(local_pos.x - r.position.x) <= threshold:
		return "left_edge"
	# 右边缘
	if abs(local_pos.x - (r.position.x + r.size.x)) <= threshold:
		return "right_edge"
	
	return ""


# 鱼缸边界 = 设计分辨率空间
var aquarium_rect: Rect2:
	get:
		return Rect2(0, 0, Global.DESIGN_WIDTH, Global.DESIGN_HEIGHT)


func _ready() -> void:
	Global.decoration_added.connect(_on_decoration_added)
	Global.move_mode_changed.connect(_on_move_mode_changed)
	# 不再设置 Aquarium 节点的缩放，由 main.gd 直接控制背景
	_setup_water_surface()
	_setup_selection_overlay()
	set_process_unhandled_input(true)


func _setup_water_surface() -> void:
	var shader := preload("res://shaders/water_surface.gdshader") as Shader
	if shader == null:
		return
	
	_water_surface_material = ShaderMaterial.new()
	_water_surface_material.shader = shader
	
	_water_surface = ColorRect.new()
	_water_surface.name = "WaterSurface"
	_water_surface.material = _water_surface_material
	_water_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_water_surface)
	
	_update_water_surface()


func _update_water_surface() -> void:
	if _water_surface == null:
		return
	
	var surf_height := Global.DESIGN_HEIGHT * water_surface_height_ratio
	
	_water_surface.size = Vector2(Global.DESIGN_WIDTH, surf_height)
	_water_surface.position = Vector2.ZERO


func set_water_surface_height_ratio(value: float) -> void:
	water_surface_height_ratio = value


# ── Selection Overlay ────────────────────────────────────────────────────

func _setup_selection_overlay() -> void:
	_selection_overlay = Node2D.new()
	_selection_overlay.name = "SelectionOverlay"
	_selection_overlay.z_index = 100
	# 设置脚本让 _selection_overlay 能绘制
	var s = GDScript.new()
	s.source_code = """
extends Node2D

var _aqua = null

func _draw() -> void:
	if _aqua == null or _aqua._move_selected_deco == null:
		return
	var deco = _aqua._move_selected_deco
	var rect = _aqua._get_deco_rect(deco)
	var handles = _aqua._get_handle_positions(deco)
	var hs = _aqua.HANDLE_SIZE
	var hover = _aqua._hovered_edge
	
	# 边框（亮黄色）
	var border_color = Color(1, 1, 0, 0.8)
	draw_rect(rect, border_color, false, 2.0)
	
	# ── 边缘条 ────────────────────────────────────────────────────────
	var edge_color_default := Color(1, 1, 0, 0.3)
	var edge_color_hover := Color(1, 0.6, 0, 0.7)
	
	# 上边缘
	var top_rect = Rect2(rect.position.x + hs, rect.position.y - 1, rect.size.x - hs * 2, 4)
	draw_rect(top_rect, edge_color_hover if hover in ["top_edge", "top_center", "top_left", "top_right"] else edge_color_default, true)
	# 下边缘
	var bot_rect = Rect2(rect.position.x + hs, rect.position.y + rect.size.y - 3, rect.size.x - hs * 2, 4)
	draw_rect(bot_rect, edge_color_hover if hover in ["bottom_edge", "bottom_center", "bottom_left", "bottom_right"] else edge_color_default, true)
	# 左边缘
	var left_rect = Rect2(rect.position.x - 1, rect.position.y + hs, 4, rect.size.y - hs * 2)
	draw_rect(left_rect, edge_color_hover if hover in ["left_edge", "middle_left", "top_left", "bottom_left"] else edge_color_default, true)
	# 右边缘
	var right_rect = Rect2(rect.position.x + rect.size.x - 3, rect.position.y + hs, 4, rect.size.y - hs * 2)
	draw_rect(right_rect, edge_color_hover if hover in ["right_edge", "middle_right", "top_right", "bottom_right"] else edge_color_default, true)
	
	# ── 控制点 ────────────────────────────────────────────────────────
	var handle_default_fill := Color.WHITE
	var handle_hover_fill := Color(1, 0.8, 0.2)
	var handle_border := Color(0.2, 0.2, 0.2, 0.8)
	
	for name in handles:
		var hp = handles[name]
		var hr = Rect2(hp.x - hs/2, hp.y - hs/2, hs, hs)
		var fill = handle_hover_fill if hover == name else handle_default_fill
		draw_rect(hr, fill, true)
		draw_rect(hr, handle_border, false, 1.0)
	
	# ── 层级标签 ──────────────────────────────────────────────────────
	var layer_text := \"层级: %d\" % deco.z_index
	var font := ThemeDB.get_fallback_font()
	var font_size := 18
	var text_size := font.get_string_size(layer_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var label_pos := Vector2(rect.position.x + rect.size.x + 10, rect.position.y + rect.size.y / 2 - text_size.y / 2)
	# 文字
	draw_string(font, label_pos, layer_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 0, 0.9))
	# 小提示：滚动滚轮调整
	var hint_pos := Vector2(label_pos.x, label_pos.y + text_size.y + 2)
	draw_string(font, hint_pos, \"(滚轮调整)\", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 0, 0.5))
"""
	s.reload()
	_selection_overlay.set_script(s)
	_selection_overlay._aqua = self
	add_child(_selection_overlay)


func _on_move_mode_changed(active: bool) -> void:
	if not active:
		clear_move_selection()


func clear_move_selection() -> void:
	_move_selected_deco = null
	_is_dragging_deco = false
	_deco_drag_type = ""
	_hovered_edge = ""
	if _selection_overlay:
		_selection_overlay.queue_redraw()


func _select_decoration(deco: Sprite2D) -> void:
	_move_selected_deco = deco
	_selection_overlay.queue_redraw()


# 拖拽结束后，将装饰物的位置/缩放保存到 Global.decoration_data
func _save_deco_data() -> void:
	if _move_selected_deco == null:
		return
	var deco := _move_selected_deco
	var deco_type = deco.get_meta(&"deco_type", -1)
	if deco_type < 0:
		return
	Global.update_decoration_instance(deco_type, deco.position, deco.scale)


# 检查鼠标是否悬停在选中装饰物的边缘/控制点上
func _update_selection_hover() -> void:
	if _move_selected_deco == null or _is_dragging_deco:
		if _hovered_edge != "":
			_hovered_edge = ""
			_selection_overlay.queue_redraw()
		return
	if not Global.move_mode:
		if _hovered_edge != "":
			_hovered_edge = ""
			_selection_overlay.queue_redraw()
		return
	
	var mouse_global := get_global_mouse_position()
	var area := _move_selected_deco.get_node_or_null("ClickArea") as Area2D
	if area == null:
		return
	var local_click := area.to_local(mouse_global)
	# local_click 在装饰本地空间，需乘以 scale 转换到父级坐标空间
	var click_parent := _move_selected_deco.position + local_click * _move_selected_deco.scale
	
	var new_hover := _hit_test_handle(_move_selected_deco, click_parent)
	if new_hover == "":
		new_hover = _hit_test_edge(_move_selected_deco, click_parent)
	
	if new_hover != _hovered_edge:
		_hovered_edge = new_hover
		_selection_overlay.queue_redraw()


func _process(_delta: float) -> void:
	_update_selection_hover()
	
	if not _is_dragging_deco or _move_selected_deco == null:
		return
	
	var mouse_global := get_global_mouse_position()
	var tex_size := _move_selected_deco.texture.get_size() if _move_selected_deco.texture else Vector2(64, 64)
	
	if _deco_drag_type == "move":
		var delta := mouse_global - _deco_drag_start_mouse_global
		var new_pos := _deco_drag_start_pos + delta / Global.scale_factor
		# 限制在鱼缸范围内
		var margin := 10.0
		new_pos.x = clampf(new_pos.x, margin, aquarium_rect.size.x - margin)
		new_pos.y = clampf(new_pos.y, aquarium_rect.size.y * 0.3, aquarium_rect.size.y - margin)
		_move_selected_deco.position = new_pos
	else:
		# Resize: 根据拖拽的控制点调整 scale
		var current_mouse := to_local(mouse_global)
		var start_mouse := to_local(_deco_drag_start_mouse_global)
		var drag_delta := current_mouse - start_mouse
		var start_scale := _deco_drag_start_scale
		var start_pos := _deco_drag_start_pos
		
		var new_scale := start_scale
		var new_pos := start_pos
		var dx := drag_delta.x
		var dy := drag_delta.y
		
		match _deco_drag_type:
			"top_left":
				new_scale.x = max(0.1, start_scale.x - dx / tex_size.x)
				new_scale.y = max(0.1, start_scale.y - dy / tex_size.y)
				new_pos.x = start_pos.x + dx / 2
				new_pos.y = start_pos.y + dy / 2
			"top_center", "top_edge":
				new_scale.y = max(0.1, start_scale.y - dy / tex_size.y)
				new_pos.y = start_pos.y + dy / 2
			"top_right":
				new_scale.x = max(0.1, start_scale.x + dx / tex_size.x)
				new_scale.y = max(0.1, start_scale.y - dy / tex_size.y)
				new_pos.y = start_pos.y + dy / 2
			"middle_left", "left_edge":
				new_scale.x = max(0.1, start_scale.x - dx / tex_size.x)
				new_pos.x = start_pos.x + dx / 2
			"middle_right", "right_edge":
				new_scale.x = max(0.1, start_scale.x + dx / tex_size.x)
			"bottom_left":
				new_scale.x = max(0.1, start_scale.x - dx / tex_size.x)
				new_scale.y = max(0.1, start_scale.y + dy / tex_size.y)
				new_pos.x = start_pos.x + dx / 2
			"bottom_center", "bottom_edge":
				new_scale.y = max(0.1, start_scale.y + dy / tex_size.y)
			"bottom_right":
				new_scale.x = max(0.1, start_scale.x + dx / tex_size.x)
				new_scale.y = max(0.1, start_scale.y + dy / tex_size.y)
		
		_move_selected_deco.scale = new_scale
		_move_selected_deco.position = new_pos
		
		# 更新 ClickArea 碰撞形状大小
		var area := _move_selected_deco.get_node_or_null("ClickArea") as Area2D
		if area:
			var shape_node := area.get_child(0) as CollisionShape2D
			if shape_node and shape_node.shape is RectangleShape2D:
				shape_node.shape.size = tex_size * new_scale
	
	_selection_overlay.queue_redraw()


func _change_deco_z_index(delta_z: int) -> void:
	"""调整选中装饰物的层级，并更新数据和子节点顺序"""
	if _move_selected_deco == null or _is_dragging_deco:
		return
	var deco := _move_selected_deco
	var new_z: int = max(0, deco.z_index + delta_z)
	if new_z == deco.z_index:
		return
	
	deco.z_index = new_z
	
	# 更新存档数据
	var deco_type = deco.get_meta(&"deco_type", -1)
	if deco_type >= 0:
		Global.update_decoration_instance(deco_type, deco.position, deco.scale, new_z)
		Global.save_dirty = true
	
	# 按 z_index 重排 decoration_container 子节点顺序
	_sort_decoration_children()
	
	_selection_overlay.queue_redraw()


func _sort_decoration_children() -> void:
	"""将 decoration_container 的子节点按 z_index 升序排列（z 越低越靠下）"""
	var children := decoration_container.get_children()
	children.sort_custom(func(a, b): return a.z_index < b.z_index)
	for child in children:
		decoration_container.move_child(child, -1)


var _deco_click_handled_this_frame: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if not Global.move_mode:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 如果装饰物已经处理了点击，不清除选中
		if _deco_click_handled_this_frame:
			_deco_click_handled_this_frame = false
			return
		# 左键点击空白区域 → 取消选中
		if _move_selected_deco != null:
			clear_move_selection()
		return
	# 滚轮调整层级
	if event is InputEventMouseButton and event.pressed:
		if _move_selected_deco == null or _is_dragging_deco:
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_change_deco_z_index(1)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_change_deco_z_index(-1)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			# 释放鼠标 = 结束拖拽
			if _is_dragging_deco:
				_is_dragging_deco = false
				_deco_drag_type = ""
				_save_deco_data()
				Global.save_dirty = true


# ── Decoration input handling (called by _connect_decoration_interaction) ──

func _handle_decoration_input(deco: Sprite2D, event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not Global.move_mode:
		return
	
	_deco_click_handled_this_frame = true
	
	# 检查点击位置是否在控制点上
	var area := deco.get_node_or_null("ClickArea") as Area2D
	if area == null:
		return
	var local_click := area.to_local(get_global_mouse_position())
	# local_click 在装饰本地空间，需乘以 scale 转换到父级（decoration_container）坐标空间
	var click_parent := deco.position + local_click * deco.scale
	var handle := _hit_test_handle(deco, click_parent)
	
	if handle != "":
		# 点击了控制点 → 开始缩放
		_move_selected_deco = deco
		_is_dragging_deco = true
		_deco_drag_type = handle
		_deco_drag_start_mouse_global = get_global_mouse_position()
		_deco_drag_start_pos = deco.position
		_deco_drag_start_scale = deco.scale
		_deco_drag_start_tex_size = deco.texture.get_size() if deco.texture else Vector2(64, 64)
		_selection_overlay.queue_redraw()
	else:
		# 检查是否在边缘上（仅对已选中装饰物有效）
		var edge := ""
		if _move_selected_deco == deco:
			edge = _hit_test_edge(deco, click_parent)
		if edge != "":
			# 点击了边缘 → 开始边缘拉伸
			_move_selected_deco = deco
			_is_dragging_deco = true
			_deco_drag_type = edge
			_deco_drag_start_mouse_global = get_global_mouse_position()
			_deco_drag_start_pos = deco.position
			_deco_drag_start_scale = deco.scale
			_deco_drag_start_tex_size = deco.texture.get_size() if deco.texture else Vector2(64, 64)
			_selection_overlay.queue_redraw()
		elif _move_selected_deco == deco:
			# 已选中且不在边缘 → 开始拖拽移动
			_is_dragging_deco = true
			_deco_drag_type = "move"
			_deco_drag_start_mouse_global = get_global_mouse_position()
			_deco_drag_start_pos = deco.position
			_deco_drag_start_scale = deco.scale
		else:
			# 未选中 → 选中该装饰物
			_select_decoration(deco)


func _on_decoration_added(deco_type: int) -> void:
	var deco := Global.make_decoration_sprite(deco_type)
	if deco == null:
		return
	var margin := 100.0
	var x := randf_range(aquarium_rect.position.x + margin, aquarium_rect.position.x + aquarium_rect.size.x - margin)
	var y := randf_range(aquarium_rect.position.y + aquarium_rect.size.y * 0.5, aquarium_rect.position.y + aquarium_rect.size.y - 20)
	deco.position = Vector2(x, y)
	_connect_decoration_interaction(deco)
	decoration_container.add_child(deco)
	# 更新装饰数据中的实际位置
	Global.update_decoration_instance(deco_type, deco.position, deco.scale)


func _connect_decoration_interaction(deco: Sprite2D) -> void:
	"""为装饰物连接出售/移动模式的点击交互"""
	var area := deco.get_node_or_null("ClickArea") as Area2D
	if area == null:
		return
	
	area.input_event.connect(func(_viewport: Node, event: InputEvent, _shape_idx: int):
		if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			return
		
		# 移动模式优先
		if Global.move_mode:
			_handle_decoration_input(deco, event)
			return
		
		# 出售模式
		if Global.sell_mode:
			Global.sell_decoration_sprite(deco)
			return
	)
	
	area.mouse_entered.connect(func():
		if Global.move_mode and _move_selected_deco != deco:
			deco.modulate = Color(0.8, 1.0, 0.8, 1)
		elif Global.sell_mode:
			deco.modulate = Color(1, 0.6, 0.6, 1)
	)
	
	area.mouse_exited.connect(func():
		if Global.move_mode and _move_selected_deco != deco:
			deco.modulate = Color(1, 1, 1, 1)
		elif not Global.sell_mode:
			deco.modulate = Color(1, 1, 1, 1)
	)
	
	# 模式切换时恢复装饰物颜色（存为变量以便后续断开）
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


func spawn_food() -> void:
	if not Global.can_afford(10):
		return
	if not Global.spend(10):
		return
	
	var pellet_scene := preload("res://scenes/food/food_pellet.tscn")
	var count := randi_range(2, 4)
	for i in count:
		var pellet := pellet_scene.instantiate()
		var margin := 80.0
		var x := randf_range(aquarium_rect.position.x + margin, aquarium_rect.position.x + aquarium_rect.size.x - margin)
		pellet.position = Vector2(x, aquarium_rect.position.y + 20)
		pellet.bottom_y = aquarium_rect.position.y + aquarium_rect.size.y - 10
		food_container.add_child(pellet)
		food_pellets.append(pellet)
		pellet.tree_exited.connect(_on_pellet_removed.bind(pellet))


func _on_pellet_removed(pellet: Node2D) -> void:
	food_pellets.erase(pellet)


func get_nearest_food(fish_pos: Vector2) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for pellet in food_pellets:
		if not is_instance_valid(pellet):
			continue
		var dist := fish_pos.distance_to(pellet.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = pellet
	return nearest
