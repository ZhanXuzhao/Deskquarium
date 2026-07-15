class_name DecorationPlacer
extends Node2D

# ── Signals ──
signal placement_started(deco_type: int)
signal placement_confirmed(deco_type: int, position: Vector2)
signal placement_cancelled(deco_type: int)


# ── References (set by main.gd) ──
var aquarium: Node2D
var decoration_container: Node2D
var aquarium_ref: Aquarium  # Aquarium 节点引用（用于移动模式交互）
var aquarium_bounds_getter: Callable  # () -> Rect2


# ── Public state ──
var placement_deco_type: int = -1


# ── Private state ──
var _placement_preview: Sprite2D = null


# ═══════════════════════════════════════════════════════
#  Public API
# ═══════════════════════════════════════════════════════

func is_active() -> bool:
	return Global.decoration_placement_active


func start_placement(deco_type: int) -> void:
	"""进入放置模式：鼠标跟随预览，点击放置"""
	Global.decoration_placement_active = true
	placement_deco_type = deco_type
	
	_placement_preview = Sprite2D.new()
	_placement_preview.name = "PlacementPreview"
	var tex_path := DecorationData.get_texture_path(deco_type)
	if ResourceLoader.exists(tex_path):
		_placement_preview.texture = load(tex_path)
	_placement_preview.scale = Vector2(0.5, 0.5)
	_placement_preview.modulate = Color(1, 1, 1, 0.6)
	_placement_preview.z_index = 10
	decoration_container.add_child(_placement_preview)
	
	update_preview()
	placement_started.emit(deco_type)


func cancel_placement() -> void:
	"""取消放置，退还金币"""
	if placement_deco_type >= 0:
		var cost := DecorationData.get_cost(placement_deco_type)
		Global.coins += cost
	placement_cancelled.emit(placement_deco_type)
	_exit_placement_mode()


func confirm_placement() -> void:
	"""确认放置装饰物"""
	if _placement_preview == null:
		return
	
	var pos := _placement_preview.position
	var preview_scale := _placement_preview.scale
	var new_z := 10
	_place_decoration(placement_deco_type, pos, preview_scale, new_z)
	Global.owned_decorations.append({"type": placement_deco_type, "x": pos.x, "y": pos.y, "scale_x": preview_scale.x, "scale_y": preview_scale.y, "z_index": new_z})
	Global.decoration_placed.emit(placement_deco_type, pos)
	placement_confirmed.emit(placement_deco_type, pos)
	Global.save_dirty = true
	_exit_placement_mode()


func update_preview() -> void:
	"""更新预览跟随鼠标位置"""
	if _placement_preview == null:
		return
	var mouse_pos := get_global_mouse_position()
	var local_pos := aquarium.to_local(mouse_pos)
	var bounds: Rect2 = aquarium_bounds_getter.call()
	var margin := 20.0
	var clamped_x := clampf(local_pos.x, margin, bounds.size.x - margin)
	var clamped_y := clampf(local_pos.y, bounds.size.y * 0.3, bounds.size.y - margin)
	_placement_preview.position = Vector2(clamped_x, clamped_y)


func restore_from_save() -> void:
	"""从存档恢复已拥有的装饰物"""
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
			if pos == Vector2.ZERO and dict.get("x", 0) == 0 and dict.get("y", 0) == 0:
				var bounds: Rect2 = aquarium_bounds_getter.call()
				var margin := 100.0
				pos.x = randf_range(margin, bounds.size.x - margin)
				pos.y = randf_range(bounds.size.y * 0.4, bounds.size.y - 20.0)
			_place_decoration(deco_type, pos, deco_scale, z_idx)
		else:
			var deco_type: int = d
			var bounds: Rect2 = aquarium_bounds_getter.call()
			var margin := 100.0
			var x := randf_range(margin, bounds.size.x - margin)
			var y := randf_range(bounds.size.y * 0.4, bounds.size.y - 20.0)
			_place_decoration(deco_type, Vector2(x, y))
	
	if aquarium_ref and aquarium_ref.has_method("_sort_decoration_children"):
		aquarium_ref._sort_decoration_children()


# ═══════════════════════════════════════════════════════
#  Private
# ═══════════════════════════════════════════════════════

func _exit_placement_mode() -> void:
	"""退出放置模式，清理预览"""
	Global.decoration_placement_active = false
	placement_deco_type = -1
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
	"""为装饰物连接出售/移动模式的点击和悬停交互"""
	var area := deco.get_node_or_null("ClickArea") as Area2D
	if area == null:
		return
	
	area.input_event.connect(func(_viewport: Node, event: InputEvent, _shape_idx: int):
		if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			return
		if Global.move_mode and aquarium_ref:
			aquarium_ref._handle_decoration_input(deco, event)
			return
		if not Global.sell_mode:
			return
		Global.sell_decoration_sprite(deco)
	)
	
	area.mouse_entered.connect(func():
		if Global.move_mode and aquarium_ref and aquarium_ref._move_selected_deco != deco:
			deco.modulate = Color(0.8, 1.0, 0.8, 1)
		elif Global.sell_mode:
			deco.modulate = Color(1, 0.6, 0.6, 1)
	)
	
	area.mouse_exited.connect(func():
		if Global.move_mode:
			if aquarium_ref and aquarium_ref._move_selected_deco != deco:
				deco.modulate = Color(1, 1, 1, 1)
		elif not Global.sell_mode:
			deco.modulate = Color(1, 1, 1, 1)
	)
	
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
	
	deco.tree_exited.connect(func():
		if Global.sell_mode_changed.is_connected(sell_lambda):
			Global.sell_mode_changed.disconnect(sell_lambda)
		if Global.move_mode_changed.is_connected(move_lambda):
			Global.move_mode_changed.disconnect(move_lambda)
	)
