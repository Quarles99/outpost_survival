extends Area2D
class_name OutpostHall

## Base opens the recruit panel on this - Outpost Hall was previously a
## plain Node2D (never clicked, just a stockpile drop-off point), so
## becoming an Area2D with a click handler is new specifically for
## recruitment (see Base._on_outpost_hall_clicked).
signal clicked

@export var display_name: String = "Outpost Hall"

@onready var label: Label = $Label
@onready var stockpile_spot: Marker2D = $StockpileSpot


func _ready() -> void:
	label.text = display_name
	input_event.connect(_on_input_event)


func get_stockpile_spot() -> Vector2:
	return stockpile_spot.global_position


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		clicked.emit()
