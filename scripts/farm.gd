extends Workstation
class_name Farm

## Base opens the crop-selection panel on this, letting the player retool
## an already-placed Farm-family building into any other Farm-class recipe
## (see BuildingCatalog.farm_family_options() and Base._on_farm_clicked) -
## same clicked-signal pattern as OutpostHall's recruit-panel trigger.
signal clicked

## Despite the name, Farm is a generic single-input/single-output converter,
## not just crop-growing: the original wood->food Farm and every Alternative
## Crop Types building (GrainFarm, Mill, Bakery, HopsFarm, Brewery,
## FruitOrchard, PotatoFarm - see BuildingCatalog) are all just Farm
## instances configured differently, sharing Character._run_farm_loop rather
## than each needing their own subclass/loop. A building with no real input
## (Fruit/Potato - "consistent", not gated on deliveries) sets
## input_per_tick to 0, which makes the loop's "do I need to restock"
## check always false without any special-casing. input_per_tick/
## input_resource themselves now live on Workstation (moved up so Brickmaker
## - a dedicated, non-Farm-family converter, see brickmaker.gd - can share
## the same loop) - Farm no longer needs its own copies of either.
## Skill this building trains - "farming" for raw crops, but "milling"/
## "baking"/"brewing" for refinement buildings (Mill/Bakery/Brewery), since
## those are a meaningfully different trade despite sharing this class.
## Briefly unified to always be "farming" and then reverted - milling/
## baking/brewing aren't farming.
@export var skill_id: String = "farming"


func get_skill_id() -> String:
	return skill_id


func _ready() -> void:
	super._ready()
	input_event.connect(_on_input_event)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		clicked.emit()
