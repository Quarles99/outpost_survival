extends Area2D
class_name OutpostHall

## Base opens the recruit panel on this - Outpost Hall was previously a
## plain Node2D (never clicked, just a stockpile drop-off point), so
## becoming an Area2D with a click handler is new specifically for
## recruitment (see Base._on_outpost_hall_clicked).
signal clicked

@export var display_name: String = "Outpost Hall"
## Same purpose/wiring as Workstation.description/House.description - shown
## in the mouseover tooltip (see Base._wire_building_tooltip). The Outpost
## Hall is never instantiated via BuildingCatalog/_apply_option_properties
## (it's the one fixed starting building, placed directly in Base.tscn -
## see CLAUDE.md), so this default has to match BuildingCatalog's
## "outpost_hall" entry text by hand rather than being copied in at
## placement time the way a freshly-built structure's would be.
@export var description: String = "The settlement's founding hall - the recruitment point and central stockpile."

## See Workstation.XRAY_MATERIAL's doc comment - same shared material, same
## reasoning.
const XRAY_MATERIAL := preload("res://shaders/xray_reveal_material.tres")

@onready var label: Label = $Label
@onready var stockpile_spot: Marker2D = $StockpileSpot
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	## No number to show and the name is dropped per an explicit request
	## (see Workstation._update_label's own doc comment) - nothing left to
	## float above the Outpost Hall.
	label.text = ""
	input_event.connect(_on_input_event)
	sprite.material = XRAY_MATERIAL


func get_stockpile_spot() -> Vector2:
	return stockpile_spot.global_position


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		clicked.emit()
