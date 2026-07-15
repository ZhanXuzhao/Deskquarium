extends Area2D

class_name FoodPellet

var sink_speed: float = 30.0
var lifetime: float = 300.0
var elapsed: float = 0.0
var bottom_y: float = INF
var consumed: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	if sprite and sprite.texture == null:
		sprite.texture = load("res://assets/food_pellet.svg")
	
	if collision_shape and collision_shape.shape == null:
		var shape := CircleShape2D.new()
		shape.radius = 8
		collision_shape.shape = shape
	
	sprite.modulate = Color(1, 1, 1, 0.9)
	
	var fade_in := create_tween()
	fade_in.tween_property(sprite, "modulate:a", 1.0, 0.2)
	
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	elapsed += delta
	
	if position.y < bottom_y:
		position.y += sink_speed * delta
		if position.y >= bottom_y:
			position.y = bottom_y

	if elapsed > lifetime and position.y >= bottom_y:
		_despawn()


func _on_body_entered(_body: Node2D) -> void:
	pass


func consume() -> void:
	if consumed:
		return
	consumed = true
	collision_shape.set_deferred("disabled", true)
	
	var tween := create_tween()
	var orig_pos := position
	# 震动（幅度3px，每步0.2s，持续约1秒）
	for i in range(2):
		tween.tween_property(self, "position:x", orig_pos.x + 3.0, 0.2)
		tween.tween_property(self, "position:x", orig_pos.x - 3.0, 0.2)
	tween.tween_property(self, "position:x", orig_pos.x, 0.04)
	# 淡出消失
	tween.tween_property(sprite, "modulate:a", 0.0, 0.16)
	tween.tween_callback(queue_free)


func _despawn() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
