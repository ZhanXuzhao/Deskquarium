class_name FishCard
extends Panel

signal buy_pressed(species: int)

var species: int = -1

@onready var preview: TextureRect = %Preview
@onready var name_label: Label = %NameLabel
@onready var price_label: Label = %PriceLabel
@onready var buy_button: Button = %BuyButton


func setup(type: int) -> void:
	species = type

	buy_button.pressed.connect(_on_buy_button_pressed)
	preview.gui_input.connect(_on_preview_gui_input)

	var tex_path := FishData.get_texture_path(type)
	var tex := load(tex_path) as Texture2D if ResourceLoader.exists(tex_path) else null

	if tex:
		preview.texture = tex
		preview.modulate = Color(1, 1, 1, 1)
	else:
		preview.texture = null
		preview.modulate = Color(0.3, 0.3, 0.3, 1)

	name_label.text = FishData.get_species_name(type)

	var is_unlocked := Global.unlocked_species[type]
	if is_unlocked:
		var cost: int = FishData.get_buy_cost(type)
		price_label.text = "¥%d" % cost
	else:
		var req: Dictionary = FishData.get_unlock_requirement(type)
		price_label.text = "累计¥%d解锁" % req.value
		price_label.modulate = Color(1, 0.5, 0.5, 1)

	refresh()


func _on_buy_button_pressed() -> void:
	buy_pressed.emit(species)


func _on_preview_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		buy_pressed.emit(species)


func refresh() -> void:
	if species < 0:
		return
	var is_unlocked := Global.unlocked_species[species]
	if is_unlocked:
		var cost := FishData.get_buy_cost(species)
		buy_button.disabled = Global.coins < cost or not Global.can_add_fish()
		buy_button.text = "购买"
	else:
		buy_button.disabled = true
		buy_button.text = "???"
