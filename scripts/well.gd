extends Area2D
class_name Well

## Promoted from Node2D to Area2D (with a new CollisionShape2D in
## Well.tscn, matching the 1x1 RectangleShape2D convention every other
## single-tile building uses) specifically so it can participate in the
## mouseover tooltip system (Base._wire_building_tooltip needs
## mouse_entered/mouse_exited, which only Area2D provides) - Well was
## previously the one building type with no click/hover handling of any
## kind. Doesn't add an input_event handler or a `clicked` signal though;
## left-click still does nothing here, only hover.
@export var display_name: String = "Well"
## Same purpose/wiring as Workstation.description - shown in the mouseover
## tooltip. Set from BuildingCatalog's "well" entry via the existing
## _apply_option_properties machinery, same as display_name.
@export var description: String = ""

## See Workstation.XRAY_MATERIAL's doc comment - same shared material, same
## reasoning.
const XRAY_MATERIAL := preload("res://shaders/xray_reveal_material.tres")

@onready var label: Label = $Label
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	## No number to show and the name is dropped per an explicit request
	## (see Workstation._update_label's own doc comment) - nothing left to
	## float above a Well.
	label.text = ""
	sprite.material = XRAY_MATERIAL
