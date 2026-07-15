class_name SideMenu
extends Node2D

signal shop_pressed()
signal feed_pressed(btn: Button)
signal sell_toggled(btn: Button)
signal move_toggled(btn: Button)
signal upgrade_pressed()
signal autobuy_pressed()
signal wallpaper_toggled(btn: Button)
signal tiny_toggled(btn: Button)

const BTN_WIDTH := 70
const BTN_HEIGHT := 65
const SPACING := 12
const PANEL_WIDTH := 85

@onready var vbox: VBoxContainer = $VBox
@onready var btn_shop: Button = $VBox/Btn_shop
@onready var btn_feed: Button = $VBox/Btn_feed
@onready var btn_sell: Button = $VBox/Btn_sell
@onready var btn_move: Button = $VBox/Btn_move
@onready var btn_upgrade: Button = $VBox/Btn_upgrade
@onready var btn_autobuy: Button = $VBox/Btn_autobuy
@onready var btn_wallpaper: Button = $VBox/Btn_wallpaper
@onready var btn_tiny: Button = $VBox/Btn_tiny


func _ready() -> void:
	btn_shop.pressed.connect(func(): shop_pressed.emit())
	btn_feed.pressed.connect(func(): feed_pressed.emit(btn_feed))
	btn_sell.pressed.connect(func(): sell_toggled.emit(btn_sell))
	btn_move.pressed.connect(func(): move_toggled.emit(btn_move))
	btn_upgrade.pressed.connect(func(): upgrade_pressed.emit())
	btn_autobuy.pressed.connect(func(): autobuy_pressed.emit())
	btn_wallpaper.pressed.connect(func(): wallpaper_toggled.emit(btn_wallpaper))
	btn_tiny.pressed.connect(func(): tiny_toggled.emit(btn_tiny))


func update_position(view_size: Vector2) -> void:
	# VBoxContainer 自动计算总高度（按钮高度 * 数量 + 间隔）
	var total_height := vbox.get_minimum_size().y
	var start_y := maxf(0.0, (view_size.y - total_height) / 2.0)
	var vbox_x := view_size.x - PANEL_WIDTH + (PANEL_WIDTH - BTN_WIDTH) / 2.0
	
	vbox.position = Vector2(vbox_x, start_y)
	vbox.size = Vector2(BTN_WIDTH, total_height)
