extends Node2D
class_name StorageFacility

@export var display_name: String = "Storage Facility"

@onready var label: Label = $Label


func _ready() -> void:
	label.text = display_name
