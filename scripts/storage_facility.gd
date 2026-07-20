extends Area2D
class_name StorageFacility

@export var display_name: String = "Storage Facility"
## Same purpose/wiring as Workstation.description - shown in the mouseover
## tooltip (see Base._wire_building_tooltip). StorageFacility doesn't
## extend Workstation, so (like House) it needs its own copy of this
## field; set from BuildingCatalog's "storage_facility" entry via the
## existing _apply_option_properties machinery, same as display_name.
@export var description: String = ""

## See Workstation.XRAY_MATERIAL's doc comment - same shared material, same
## reasoning.
const XRAY_MATERIAL := preload("res://shaders/xray_reveal_material.tres")

@onready var label: Label = $Label
@onready var worker_spot: Marker2D = $WorkerSpot


func _ready() -> void:
	## No number to show and the name is dropped per an explicit request
	## (see Workstation._update_label's own doc comment) - nothing left to
	## float above a Storage Facility.
	label.text = ""
	## Unlike every other occluder class, this one has several Sprite2D
	## children (the scattered goods piles, Pile1-Pile4 - see
	## StorageFacility.tscn) rather than one $Sprite2D, so material
	## assignment has to walk children instead of a single onready ref.
	for child in get_children():
		if child is Sprite2D:
			child.material = XRAY_MATERIAL


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
