extends Node2D
class_name WorldRock

## A mineable boulder - WorldTree's sibling for stone, planted by
## Base._scatter_initial_mineable_rocks and harvested the same way a
## demolish-marked tree is (see Character._run_demolish_harvest). Simpler than
## WorldTree: no growth/sapling/replant concept at all - a boulder doesn't
## grow back once mined out, unlike a tree a Lumber Camp deliberately
## replants, so there's no is_mature/grow_time/matured signal to mirror.

signal depleted(rock: WorldRock)

## See Workstation.XRAY_MATERIAL's doc comment - same shared material, same
## reasoning.
const XRAY_MATERIAL := preload("res://shaders/xray_reveal_material.tres")

## First-pass value, half of WorldTree.max_wood's 80 - stone reads as
## somewhat scarcer/more valuable per node than wood. Tunable via
## Outpost_Survival/Game Systems/Balance.md's edit-and-hand-back workflow.
@export var max_stone: float = 40.0

var grid_cell: Vector2i
var claimed: bool = false
var stone_remaining: float

@onready var sprite: Sprite2D = $Sprite2D

var _full_scale: Vector2
var _punch_tween: Tween


func _ready() -> void:
	_full_scale = sprite.scale
	sprite.material = XRAY_MATERIAL
	stone_remaining = max_stone


func harvest(amount: float) -> float:
	if stone_remaining <= 0.0:
		return 0.0
	var taken := minf(amount, stone_remaining)
	stone_remaining -= taken
	_hit_punch()
	if stone_remaining <= 0.0:
		depleted.emit(self)
		_fall_and_remove()
	return taken


func _hit_punch() -> void:
	if _punch_tween:
		_punch_tween.kill()
	sprite.scale = _full_scale
	_punch_tween = create_tween()
	_punch_tween.tween_property(sprite, "scale", _full_scale * 1.08, 0.08)
	_punch_tween.tween_property(sprite, "scale", _full_scale, 0.12)


func _fall_and_remove() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "scale", sprite.scale * 0.15, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)
