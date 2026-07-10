extends Node2D
class_name IsoGround

const GRASS := preload("res://art/iso_ground_tile.svg")
const WORN := preload("res://art/iso_ground_tile_worn.svg")

@export var width: int = 9
@export var depth: int = 8
@export var start_x: int = -4
@export var start_y: int = 0


func _ready() -> void:
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()

	for i in width:
		var gx := start_x + i
		for j in depth:
			var gy := start_y + j
			var tile := Sprite2D.new()
			var spatial_hash := absi(gx * 3 + gy * 7)
			tile.texture = WORN if spatial_hash % 13 == 0 else GRASS
			tile.position = IsoUtils.grid_to_screen(Vector2(gx, gy))
			add_child(tile)
