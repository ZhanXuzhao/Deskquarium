extends Node2D

class_name Aquarium

@onready var fish_container: Node2D = $FishContainer
@onready var food_container: Node2D = $FoodContainer
@onready var decoration_container: Node2D = $DecorationContainer
@onready var click_area: Area2D = $ClickArea

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


# 鱼缸边界 = 设计分辨率空间
var aquarium_rect: Rect2:
	get:
		return Rect2(0, 0, Global.DESIGN_WIDTH, Global.DESIGN_HEIGHT)


func _ready() -> void:
	Global.fish_added.connect(_on_fish_added)
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
	
	# 边框
	draw_rect(rect, Color(1, 1, 0, 0.8), false, 2.0)
	
	# 控制点
	var hs = _aqua.HANDLE_SIZE
	for name in handles:
		var hp = handles[name]
		var hr = Rect2(hp.x - hs/2, hp.y - hs/2, hs, hs)
		draw_rect(hr, Color.WHITE, true)
		draw_rect(hr, Color(0.2, 0.2, 0.2, 0.8), false, 1.0)
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
	if _selection_overlay:
		_selection_overlay.queue_redraw()


func _select_decoration(deco: Sprite2D) -> void:
	_move_selected_deco = deco
	_selection_overlay.queue_redraw()


func _process(_delta: float) -> void:
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
			"top_center":
				new_scale.y = max(0.1, start_scale.y - dy / tex_size.y)
				new_pos.y = start_pos.y + dy / 2
			"top_right":
				new_scale.x = max(0.1, start_scale.x + dx / tex_size.x)
				new_scale.y = max(0.1, start_scale.y - dy / tex_size.y)
				new_pos.y = start_pos.y + dy / 2
			"middle_left":
				new_scale.x = max(0.1, start_scale.x - dx / tex_size.x)
				new_pos.x = start_pos.x + dx / 2
			"middle_right":
				new_scale.x = max(0.1, start_scale.x + dx / tex_size.x)
			"bottom_left":
				new_scale.x = max(0.1, start_scale.x - dx / tex_size.x)
				new_scale.y = max(0.1, start_scale.y + dy / tex_size.y)
				new_pos.x = start_pos.x + dx / 2
			"bottom_center":
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
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			# 释放鼠标 = 结束拖拽
			if _is_dragging_deco:
				_is_dragging_deco = false
				_deco_drag_type = ""
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
	# 转换到父级（decoration_container）坐标空间
	var click_parent := deco.position + local_click
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
		# 点击了装饰物主体 → 开始移动或选中
		if _move_selected_deco == deco:
			# 已选中 → 开始拖拽移动
			_is_dragging_deco = true
			_deco_drag_type = "move"
			_deco_drag_start_mouse_global = get_global_mouse_position()
			_deco_drag_start_pos = deco.position
			_deco_drag_start_scale = deco.scale
		else:
			# 未选中 → 选中该装饰物
			_select_decoration(deco)


func _on_fish_added(fish: Node2D) -> void:
	fish_container.add_child(fish)
	if fish.has_method("set_aquarium_bounds"):
		fish.set_aquarium_bounds(aquarium_rect)


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
	
	# 模式切换时恢复装饰物颜色
	Global.sell_mode_changed.connect(func(active: bool):
		if not is_instance_valid(deco):
			return
		if not active and not Global.move_mode:
			deco.modulate = Color(1, 1, 1, 1)
	)
	
	Global.move_mode_changed.connect(func(active: bool):
		if not is_instance_valid(deco):
			return
		if not active:
			deco.modulate = Color(1, 1, 1, 1)
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
