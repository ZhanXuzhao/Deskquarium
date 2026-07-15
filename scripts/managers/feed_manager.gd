class_name FeedManager
extends Node2D

# ── Signals ──
signal feed_mode_changed(active: bool)


# ── References (set by main.gd) ──
var fish_container: Node2D
var food_container: Node2D
var aquarium: Node2D
var ui_container: Node2D
var aquarium_bounds_getter: Callable  # () -> Rect2


# ── Public state ──
var feed_mode: bool = false


# ── Private state ──
var _feed_holding: bool = false
var _feed_hold_time: float = 0.0
const FEED_INTERVAL: float = 1.0 / 3.0

var _pellet_scene = preload("res://scenes/food/food_pellet.tscn")
var _pellet_script = preload("res://scripts/food/food_pellet.gd")
var _food_cursor_tex = preload("res://assets/ui/ui_food.svg")


# ═══════════════════════════════════════════════════════
#  Public API
# ═══════════════════════════════════════════════════════

func is_active() -> bool:
	return feed_mode


func exit_feed_mode() -> void:
	feed_mode = false
	_feed_holding = false
	_feed_hold_time = 0.0
	Input.set_custom_mouse_cursor(null)
	if is_instance_valid(ui_container):
		var feed_btn := ui_container.get_node_or_null("Btn_feed") as Button
		if feed_btn:
			feed_btn.modulate = Color(1, 1, 1, 1)
	feed_mode_changed.emit(false)


func toggle(btn: Button) -> void:
	if not feed_mode:
		_enter_feed_mode()
		btn.modulate = Color(1.0, 0.8, 0.4)
	else:
		exit_feed_mode()
		btn.modulate = Color(1, 1, 1, 1)


# ═══════════════════════════════════════════════════════
#  Process & Input (called by main.gd)
# ═══════════════════════════════════════════════════════

func process_feed(_delta: float) -> void:
	if feed_mode and _feed_holding:
		_feed_hold_time += _delta
		while _feed_hold_time >= FEED_INTERVAL:
			_feed_hold_time -= FEED_INTERVAL
			_place_food_at_mouse()


func handle_input(event: InputEvent) -> bool:
	"""处理投喂模式左键点击。返回 true 表示事件已处理。"""
	if not feed_mode:
		return false
	if not (event is InputEventMouseButton):
		return false
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_feed_holding = true
			_feed_hold_time = 0.0
			_place_food_at_mouse()
		else:
			_feed_holding = false
		get_viewport().set_input_as_handled()
		return true
	return false


# ═══════════════════════════════════════════════════════
#  Feed methods
# ═══════════════════════════════════════════════════════

func do_feed() -> void:
	"""一次投放 10 颗鱼食（按钮投喂，目前未使用）"""
	if fish_container.get_child_count() == 0:
		return
	if not Global.spend(10):
		return
	var bounds := aquarium_bounds_getter.call()
	for i in 10:
		var pellet := _pellet_scene.instantiate()
		pellet.set_script(_pellet_script)
		
		var margin := 80
		var x := randf_range(bounds.position.x + margin, bounds.position.x + bounds.size.x - margin)
		pellet.position = Vector2(x, bounds.position.y + 10)
		pellet.bottom_y = bounds.position.y + bounds.size.y - 10
		food_container.add_child(pellet)
		
		for fish in fish_container.get_children():
			if fish.has_method("set_food_target"):
				fish.set_food_target(pellet)


# ═══════════════════════════════════════════════════════
#  Private
# ═══════════════════════════════════════════════════════

func _enter_feed_mode() -> void:
	feed_mode = true
	var cursor_tex := _food_cursor_tex as Texture2D
	if cursor_tex:
		var img := cursor_tex.get_image()
		if img:
			img.resize(32, 32, Image.INTERPOLATE_LANCZOS)
			var scaled_tex := ImageTexture.create_from_image(img)
			Input.set_custom_mouse_cursor(scaled_tex, Input.CURSOR_ARROW, Vector2(16, 16))
	feed_mode_changed.emit(true)


func _place_food_at_mouse() -> void:
	if fish_container.get_child_count() == 0:
		return
	if not Global.spend(10):
		return
	
	var mouse_pos := get_global_mouse_position()
	var local_pos := aquarium.to_local(mouse_pos)
	var bounds := aquarium_bounds_getter.call()
	
	var margin := 20.0
	var clamped_x := clampf(local_pos.x, margin, bounds.size.x - margin)
	var clamped_y := clampf(local_pos.y, margin, bounds.size.y - margin)
	
	var pellet := _pellet_scene.instantiate()
	pellet.set_script(_pellet_script)
	pellet.position = Vector2(clamped_x, clamped_y)
	pellet.bottom_y = bounds.position.y + bounds.size.y - 10
	food_container.add_child(pellet)
	
	for fish in fish_container.get_children():
		if fish.has_method("set_food_target"):
			fish.set_food_target(pellet)
