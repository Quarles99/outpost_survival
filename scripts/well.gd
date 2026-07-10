extends Node2D
class_name Well

@export var display_name: String = "Well"

@onready var label: Label = $Label


func _ready() -> void:
	label.text = display_name
