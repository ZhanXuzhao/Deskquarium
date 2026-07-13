extends Control

class_name HUD

@onready var coin_label: Label = $CoinLabel
@onready var total_earned_label: Label = %TotalEarnedLabel
@onready var fish_count_label: Label = %FishCountLabel


func _ready() -> void:
	Global.coins_changed.connect(_on_coins_changed)
	Global.total_earned_changed.connect(_on_total_earned_changed)
	Global.game_loaded.connect(_on_game_loaded)
	_update_coins(Global.coins)
	_update_total_earned(Global.total_earned)


func _on_coins_changed(amount: int) -> void:
	_update_coins(amount)


func _on_total_earned_changed(amount: int) -> void:
	_update_total_earned(amount)


func _on_game_loaded() -> void:
	_update_coins(Global.coins)
	_update_total_earned(Global.total_earned)


func _update_coins(amount: int) -> void:
	coin_label.text = "金币: %d" % amount


func _update_total_earned(amount: int) -> void:
	total_earned_label.text = "累计: %d" % amount


func update_fish_count(count: int, max_count: int) -> void:
	fish_count_label.text = "鱼: %d/%d" % [count, max_count]


func _on_feed_button_pressed() -> void:
	Global.feed_mode = true


func _on_sell_button_pressed() -> void:
	Global.sell_mode = not Global.sell_mode
