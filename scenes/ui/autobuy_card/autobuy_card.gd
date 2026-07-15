class_name AutoBuyCard
extends Panel

signal target_changed(species: int, new_target: int)

var species: int = -1

@onready var preview: TextureRect = %Preview
@onready var name_label: Label = %NameLabel
@onready var target_label: Label = %TargetLabel
@onready var dec_btn: Button = %DecButton
@onready var inc_btn: Button = %IncButton


func setup(type: int) -> void:
	species = type

	dec_btn.pressed.connect(_on_dec_pressed)
	inc_btn.pressed.connect(_on_inc_pressed)

	var tex_path := FishData.get_texture_path(type)
	var tex := load(tex_path) as Texture2D if ResourceLoader.exists(tex_path) else null

	if tex:
		preview.texture = tex
		preview.modulate = Color(1, 1, 1, 1)
	else:
		preview.texture = null
		preview.modulate = Color(0.3, 0.3, 0.3, 1)

	name_label.text = FishData.get_species_name(type)
	refresh()


func refresh() -> void:
	if species < 0:
		return
	var unlocked := Global.unlocked_species[species]
	var targets: Dictionary = Global.auto_buy_targets
	var current: int = targets.get(species, 0)

	target_label.text = "%d" % current

	# 未解锁的鱼显示灰色，不能调整
	if not unlocked:
		modulate = Color(0.5, 0.5, 0.5, 0.6)
		dec_btn.disabled = true
		inc_btn.disabled = true
		target_label.modulate = Color(1, 1, 1, 0.4)
	else:
		modulate = Color(1, 1, 1, 1)
		dec_btn.disabled = current <= 0
		inc_btn.disabled = false
		target_label.modulate = Color(1, 1, 0.6, 1)


func _on_dec_pressed() -> void:
	var targets: Dictionary = Global.auto_buy_targets
	var cur: int = targets.get(species, 0)
	if cur > 0:
		targets[species] = cur - 1
		Global.auto_buy_targets = targets
		target_changed.emit(species, cur - 1)
		refresh()


func _on_inc_pressed() -> void:
	var targets: Dictionary = Global.auto_buy_targets
	var cur: int = targets.get(species, 0)
	targets[species] = cur + 1
	Global.auto_buy_targets = targets
	target_changed.emit(species, cur + 1)
	refresh()
