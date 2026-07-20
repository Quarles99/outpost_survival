extends Node2D
class_name Well

@export var display_name: String = "Well"

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
