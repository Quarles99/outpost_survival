extends Node2D
class_name OutpostHall

@export var display_name: String = "Outpost Hall"

@onready var label: Label = $Label
@onready var stockpile_spot: Marker2D = $StockpileSpot


func _ready() -> void:
	label.text = display_name


func get_stockpile_spot() -> Vector2:
	return stockpile_spot.global_position
