extends Node2D
class_name House

@export var display_name: String = "House"
@export var population_capacity: int = 2

@onready var label: Label = $Label


func _ready() -> void:
	label.text = display_name
