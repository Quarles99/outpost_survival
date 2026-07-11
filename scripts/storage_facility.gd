extends Area2D
class_name StorageFacility

@export var display_name: String = "Storage Facility"

@onready var label: Label = $Label
@onready var worker_spot: Marker2D = $WorkerSpot


func _ready() -> void:
	label.text = display_name


## A placed Storage Facility is a real drop-off/pickup point for haulers,
## not just a storage_capacity bump - Base registers/unregisters this with
## WorldGrid.stockpile_spots on placement/removal, so Character's haul
## loops can route to whichever registered stockpile (this or the Outpost
## Hall) is nearest instead of always the Outpost Hall (see WorldGrid.
## nearest_stockpile). Reuses the WorkerSpot marker rather than a second
## one - a leftover name from when this was also an explicit hauler-
## assignment target; kept as-is since renaming the marker node buys
## nothing now that assignment is fully automatic.
func get_stockpile_spot() -> Vector2:
	return worker_spot.global_position
