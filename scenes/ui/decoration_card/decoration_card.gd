class_name DecorationCard
extends Panel

signal buy_pressed(deco_type: int)

var deco_type: int = -1

@onready var preview: TextureRect = %Preview
@onready var name_label: Label = %NameLabel
@onready var price_label: Label = %PriceLabel
@onready var buy_button: Button = %BuyButton


func setup(type: int) -> void:
	deco_type = type
	
	buy_button.pressed.connect(_on_buy_button_pressed)
	preview.gui_input.connect(_on_preview_gui_input)

	var tex_path := DecorationData.get_texture_path(type)
	var tex := load(tex_path) as Texture2D if ResourceLoader.exists(tex_path) else null

	if tex:
		preview.texture = tex
		preview.modulate = Color(1, 1, 1, 1)
	else:
		preview.texture = null
		preview.modulate = Color(0.3, 0.3, 0.3, 1)

	name_label.text = DecorationData.get_display_name(type)

	var cost := DecorationData.get_cost(type)
	price_label.text = "¥%d" % cost

	refresh()


func _on_buy_button_pressed() -> void:
	buy_pressed.emit(deco_type)


func _on_preview_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		buy_pressed.emit(deco_type)


func refresh() -> void:
	if deco_type < 0:
		return
	var cost := DecorationData.get_cost(deco_type)
	buy_button.disabled = Global.coins < cost
