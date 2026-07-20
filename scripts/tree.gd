extends Node2D
class_name WorldTree

signal depleted(tree: WorldTree)

const SAPLING_SCALE := 0.35
## See Workstation.XRAY_MATERIAL's doc comment - same shared material, same
## reasoning.
const XRAY_MATERIAL := preload("res://shaders/xray_reveal_material.tres")

## Raised 20.0 -> 80.0 via Outpost_Survival/Game Systems/Balance.md's
## edit-and-hand-back workflow, per an explicit "increase how much wood is
## in each tree significantly" request - a mature tree now takes 40 chops
## to fully deplete at LumberCamp.wood_per_chop's default 2.0, up from 10.
@export var max_wood: float = 80.0
## Raised 25.0 -> 100.0 per an explicit request ("trees should take much
## longer to grow"), then 100.0 -> 700.0 via Outpost_Survival/Game
## Systems/Balance.md's edit-and-hand-back workflow - a replanted sapling
## now takes noticeably longer to mature back into a harvestable tree.
@export var grow_time: float = 700.0

var grid_cell: Vector2i
var is_mature: bool = true
var claimed: bool = false
var wood_remaining: float

@onready var sprite: Sprite2D = $Sprite2D

## The scene's authored scale (e.g. 0.5 to size a 400x400 source PNG down to
## the grid) - captured before _ready() overwrites sprite.scale for the
## sapling/mature states, so every other scale in this script (sapling,
## punch, fall) can stay a fraction of "full size" instead of hardcoding
## Vector2.ONE and silently assuming the art is authored at 1:1 scale.
var _full_scale: Vector2

var _punch_tween: Tween


func _ready() -> void:
	_full_scale = sprite.scale
	sprite.material = XRAY_MATERIAL
	if is_mature:
		wood_remaining = max_wood
		sprite.scale = _full_scale
	else:
		wood_remaining = 0.0
		sprite.scale = _full_scale * SAPLING_SCALE
		var tween := create_tween()
		tween.tween_property(sprite, "scale", _full_scale, grow_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
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
	sprite.scale = _full_scale
	_punch_tween = create_tween()
	_punch_tween.tween_property(sprite, "scale", _full_scale * 1.08, 0.08)
	_punch_tween.tween_property(sprite, "scale", _full_scale, 0.12)


func _fall_and_remove() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "scale", sprite.scale * 0.15, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)
