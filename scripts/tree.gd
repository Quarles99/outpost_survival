extends Node2D
class_name WorldTree

signal depleted(tree: WorldTree)

const SAPLING_SCALE := 0.35

@export var max_wood: float = 20.0
@export var grow_time: float = 25.0

var grid_cell: Vector2i
var is_mature: bool = true
var claimed: bool = false
var wood_remaining: float

@onready var sprite: Sprite2D = $Sprite2D

var _punch_tween: Tween


func _ready() -> void:
	if is_mature:
		wood_remaining = max_wood
		sprite.scale = Vector2.ONE
	else:
		wood_remaining = 0.0
		sprite.scale = Vector2.ONE * SAPLING_SCALE
		var tween := create_tween()
		tween.tween_property(sprite, "scale", Vector2.ONE, grow_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_callback(_on_matured)


func _on_matured() -> void:
	is_mature = true
	wood_remaining = max_wood


func harvest(amount: float) -> float:
	if not is_mature or wood_remaining <= 0.0:
		return 0.0
	var taken := minf(amount, wood_remaining)
	wood_remaining -= taken
	_hit_punch()
	if wood_remaining <= 0.0:
		depleted.emit(self)
		_fall_and_remove()
	return taken


func _hit_punch() -> void:
	if _punch_tween:
		_punch_tween.kill()
	sprite.scale = Vector2.ONE
	_punch_tween = create_tween()
	_punch_tween.tween_property(sprite, "scale", Vector2.ONE * 1.08, 0.08)
	_punch_tween.tween_property(sprite, "scale", Vector2.ONE, 0.12)


func _fall_and_remove() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "scale", sprite.scale * 0.15, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)
