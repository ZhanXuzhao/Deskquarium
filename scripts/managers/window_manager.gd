class_name WindowManager
extends Node2D

# ── Signals ──
signal tiny_mode_changed(active: bool)
signal wallpaper_mode_changed(active: bool)
signal redraw_requested()
signal before_ui_hidden()
signal after_ui_shown()
signal aquarium_scale_needed()


# ── References (set by main.gd) ──
var ui_container: Node2D
var ui_layer: CanvasLayer


# ── Public state ──
var wallpaper_mode: bool = false
var tiny_mode: bool = false


# ── Private state ──
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

const TINY_WIDTH := 400
const TINY_HEIGHT := 200


# ═══════════════════════════════════════════════════════
#  Public API
# ═══════════════════════════════════════════════════════

func enter_tiny() -> void:
	_prev_window_mode = DisplayServer.window_get_mode()
	_prev_borderless = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
	_prev_window_pos = DisplayServer.window_get_position()
	_prev_window_size = DisplayServer.window_get_size()
	_prev_always_on_top = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP)
	
	# 退出壁纸模式（如果已激活）
	if wallpaper_mode:
		_exit_wallpaper_mode_internal()
	
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	# 优先使用存档中的尺寸和位置
	if Global.tiny_window_size != Vector2i.ZERO:
		DisplayServer.window_set_size(Global.tiny_window_size)
		DisplayServer.window_set_position(Global.tiny_window_pos)
	else:
		DisplayServer.window_set_size(Vector2i(TINY_WIDTH, TINY_HEIGHT))
		var screen_center := DisplayServer.screen_get_size() / 2.0
		DisplayServer.window_set_position(Vector2i(int(screen_center.x - TINY_WIDTH / 2.0), int(screen_center.y - TINY_HEIGHT / 2.0)))
	
	_hide_all_ui()
	aquarium_scale_needed.emit()
	
	tiny_mode = true
	tiny_mode_changed.emit(true)


func exit_tiny() -> void:
	# 记录当前 Tiny 窗口尺寸/位置
	Global.tiny_window_size = DisplayServer.window_get_size()
	Global.tiny_window_pos = DisplayServer.window_get_position()

	_drag_active = false
	_resize_active = false
	Input.set_custom_mouse_cursor(null)
	_tiny_near_left = false
	_tiny_near_right = false
	_tiny_near_top = false
	_tiny_near_bottom = false
	redraw_requested.emit()
	_close_exit_popup()
	_show_all_ui()
	
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, _prev_borderless)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, _prev_always_on_top)
	DisplayServer.window_set_mode(_prev_window_mode)
	if _prev_window_pos != Vector2i.ZERO:
		DisplayServer.window_set_position(_prev_window_pos)
	if _prev_window_size != Vector2i.ZERO:
		DisplayServer.window_set_size(_prev_window_size)
	
	tiny_mode = false
	tiny_mode_changed.emit(false)


func enter_wallpaper() -> void:
	_prev_window_mode = DisplayServer.window_get_mode()
	_prev_borderless = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
	_prev_window_pos = DisplayServer.window_get_position()
	_prev_window_size = DisplayServer.window_get_size()
	
	# 退出 tiny 模式（如果已激活）
	if tiny_mode:
		_exit_tiny_mode_internal()
	
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	
	_hide_all_ui()
	
	if DisplayServer.get_name() == "Windows":
		_set_window_as_wallpaper()
	
	wallpaper_mode = true
	wallpaper_mode_changed.emit(true)


func exit_wallpaper() -> void:
	_close_exit_popup()
	_show_all_ui()
	
	if DisplayServer.get_name() == "Windows":
		_restore_window_parent()
	
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, _prev_borderless)
	DisplayServer.window_set_mode(_prev_window_mode)
	if _prev_window_pos != Vector2i.ZERO:
		DisplayServer.window_set_position(_prev_window_pos)
	if _prev_window_size != Vector2i.ZERO:
		DisplayServer.window_set_size(_prev_window_size)
	
	wallpaper_mode = false
	wallpaper_mode_changed.emit(false)


func toggle_tiny(btn: Button) -> void:
	if not tiny_mode:
		enter_tiny()
		btn.modulate = Color(0.8, 0.6, 1.0)
	else:
		exit_tiny()
		btn.modulate = Color(1, 1, 1, 1)


func toggle_wallpaper(btn: Button) -> void:
	if not wallpaper_mode:
		enter_wallpaper()
		btn.modulate = Color(0.6, 1.0, 0.8)
	else:
		exit_wallpaper()
		btn.modulate = Color(1, 1, 1, 1)


# ═══════════════════════════════════════════════════════
#  Input handling (called by main.gd)
# ═══════════════════════════════════════════════════════

func handle_input(event: InputEvent) -> bool:
	"""处理窗口模式输入。返回 true 表示事件已处理。"""
	if not (tiny_mode or wallpaper_mode):
		return false
	
	if not (event is InputEventMouseButton):
		return false
	
	var view_size := get_viewport_rect().size
	var mouse_pos := get_viewport().get_mouse_position()
	
	# 壁纸模式
	if wallpaper_mode:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _tiny_exit_popup and is_instance_valid(_tiny_exit_popup) and _tiny_exit_popup.visible:
				var popup_rect := Rect2(_tiny_exit_popup.position, _tiny_exit_popup.size)
				if popup_rect.has_point(mouse_pos):
					return true  # 让按钮处理
				else:
					_close_exit_popup()
			if event.double_click:
				exit_wallpaper()
				get_viewport().set_input_as_handled()
				return true
			get_viewport().set_input_as_handled()
			return true
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_show_exit_popup("壁纸")
			get_viewport().set_input_as_handled()
			return true
	
	# Tiny 模式：拖拽/缩放 + 右键弹窗
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and tiny_mode and event.double_click:
		exit_tiny()
		get_viewport().set_input_as_handled()
		return true
	
	if event.button_index == MOUSE_BUTTON_LEFT:
		if _tiny_exit_popup and is_instance_valid(_tiny_exit_popup) and _tiny_exit_popup.visible:
			var popup_rect := Rect2(_tiny_exit_popup.position, _tiny_exit_popup.size)
			if popup_rect.has_point(mouse_pos):
				return true
			else:
				_close_exit_popup()
		
		if event.pressed:
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
				_resize_active = true
				_resize_start_mouse = DisplayServer.mouse_get_position()
				_resize_start_size = DisplayServer.window_get_size()
				_resize_start_pos = DisplayServer.window_get_position()
			else:
				_drag_active = true
				_drag_start_mouse = DisplayServer.mouse_get_position()
				_drag_start_window = DisplayServer.window_get_position()
			
			get_viewport().set_input_as_handled()
			return true
		else:
			_drag_active = false
			_resize_active = false
			_resize_edges = 0
			Input.set_custom_mouse_cursor(null)
	
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_show_exit_popup("Tiny")
		get_viewport().set_input_as_handled()
		return true
	
	return false


func handle_cancel() -> bool:
	"""处理 ESC 键。返回 true 表示已消费。"""
	if not (tiny_mode or wallpaper_mode):
		return false
	if _tiny_exit_popup and is_instance_valid(_tiny_exit_popup) and _tiny_exit_popup.visible:
		_close_exit_popup()
		return true
	return true  # 在窗口模式下消费 ESC


# ═══════════════════════════════════════════════════════
#  Process (called by main.gd)
# ═══════════════════════════════════════════════════════

func handle_process(_delta: float) -> void:
	if tiny_mode:
		_update_tiny_window()
		_update_resize_cursor()


# ═══════════════════════════════════════════════════════
#  Edge highlight drawing data (called by main.gd's _draw)
# ═══════════════════════════════════════════════════════

func get_edge_highlights() -> Array[Dictionary]:
	if not tiny_mode:
		return []
	var view_size := get_viewport_rect().size
	var result: Array[Dictionary] = []
	if _tiny_near_left:
		result.append({"rect": Rect2(0, 0, EDGE_HIGHLIGHT_THICKNESS, view_size.y), "color": EDGE_HIGHLIGHT_COLOR})
	if _tiny_near_right:
		result.append({"rect": Rect2(view_size.x - EDGE_HIGHLIGHT_THICKNESS, 0, EDGE_HIGHLIGHT_THICKNESS, view_size.y), "color": EDGE_HIGHLIGHT_COLOR})
	if _tiny_near_top:
		result.append({"rect": Rect2(0, 0, view_size.x, EDGE_HIGHLIGHT_THICKNESS), "color": EDGE_HIGHLIGHT_COLOR})
	if _tiny_near_bottom:
		result.append({"rect": Rect2(0, view_size.y - EDGE_HIGHLIGHT_THICKNESS, view_size.x, EDGE_HIGHLIGHT_THICKNESS), "color": EDGE_HIGHLIGHT_COLOR})
	return result


# ═══════════════════════════════════════════════════════
#  Private helpers
# ═══════════════════════════════════════════════════════

func _hide_all_ui() -> void:
	before_ui_hidden.emit()
	if is_instance_valid(ui_container):
		ui_container.visible = false


func _show_all_ui() -> void:
	if not is_instance_valid(ui_container):
		return
	ui_container.visible = true
	after_ui_shown.emit()


func _exit_tiny_mode_internal() -> void:
	"""不发射信号退出 tiny（切换到壁纸时使用）"""
	Global.tiny_window_size = DisplayServer.window_get_size()
	Global.tiny_window_pos = DisplayServer.window_get_position()
	_drag_active = false
	_resize_active = false
	Input.set_custom_mouse_cursor(null)
	_tiny_near_left = false
	_tiny_near_right = false
	_tiny_near_top = false
	_tiny_near_bottom = false
	redraw_requested.emit()
	_close_exit_popup()
	tiny_mode = false


func _exit_wallpaper_mode_internal() -> void:
	"""不发射信号退出壁纸（切换到 tiny 时使用）"""
	_close_exit_popup()
	if DisplayServer.get_name() == "Windows":
		_restore_window_parent()
	wallpaper_mode = false


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
	
	var mouse_inside := mouse_pos.x >= 0 and mouse_pos.x < view_size.x and mouse_pos.y >= 0 and mouse_pos.y < view_size.y
	
	var near_left := mouse_inside and mouse_pos.x <= RESIZE_HANDLE_SIZE
	var near_right := mouse_inside and mouse_pos.x >= view_size.x - RESIZE_HANDLE_SIZE
	var near_top := mouse_inside and mouse_pos.y <= RESIZE_HANDLE_SIZE
	var near_bottom := mouse_inside and mouse_pos.y >= view_size.y - RESIZE_HANDLE_SIZE
	
	if near_left != _tiny_near_left or near_right != _tiny_near_right or near_top != _tiny_near_top or near_bottom != _tiny_near_bottom:
		_tiny_near_left = near_left
		_tiny_near_right = near_right
		_tiny_near_top = near_top
		_tiny_near_bottom = near_bottom
		redraw_requested.emit()
	
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


func _show_exit_popup(mode_name: String) -> void:
	if _tiny_exit_popup and _tiny_exit_popup.visible:
		return
	_close_exit_popup()
	
	if not is_instance_valid(ui_layer):
		return
	
	var popup := Panel.new()
	popup.name = "TinyExitPopup"
	popup.size = Vector2(200, 130)
	var view_size := get_viewport_rect().size
	popup.position = Vector2(view_size.x / 2 - 100, view_size.y / 2 - 65)
	ui_layer.add_child(popup)
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
	if mode_name == "壁纸":
		exit_btn.pressed.connect(_on_wallpaper_exit_pressed)
	else:
		exit_btn.pressed.connect(_on_tiny_exit_pressed)
	
	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.position = Vector2(20, 85)
	cancel_btn.size = Vector2(160, 28)
	popup.add_child(cancel_btn)
	cancel_btn.pressed.connect(_close_exit_popup)


func _close_exit_popup() -> void:
	if _tiny_exit_popup and is_instance_valid(_tiny_exit_popup):
		_tiny_exit_popup.queue_free()
	_tiny_exit_popup = null


func _on_tiny_exit_pressed() -> void:
	exit_tiny()


func _on_wallpaper_exit_pressed() -> void:
	exit_wallpaper()


func _set_window_as_wallpaper() -> void:
	"""通过 PowerShell 调用 Win32 API，将窗口设为桌面壁纸层子窗口"""
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
[W]::SendMessageTimeout($progman,0x052C,[IntPtr]::Zero,[IntPtr]::Zero,2,1000,[ref][IntPtr]::Zero)
$workerW=[IntPtr]::Zero
$wallpaperW=[IntPtr]::Zero
while($true){
    $workerW=[W]::FindWindowEx([IntPtr]::Zero,$workerW,"WorkerW",$null)
    if($workerW -eq [IntPtr]::Zero){break}
    $defView=[W]::FindWindowEx($workerW,[IntPtr]::Zero,"SHELLDLL_DefView",$null)
    if($defView -ne [IntPtr]::Zero){
        $wallpaperW=[W]::GetWindow($workerW,3)
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


func _restore_window_parent() -> void:
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
