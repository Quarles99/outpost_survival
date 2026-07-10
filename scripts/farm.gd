extends Workstation
class_name Farm

## Despite the name, Farm is a generic single-input/single-output converter,
## not just crop-growing: the original wood->food Farm and every Alternative
## Crop Types building (GrainFarm, Mill, Bakery, HopsFarm, Brewery,
## FruitOrchard, PotatoFarm - see BuildingCatalog) are all just Farm
## instances configured differently, sharing Character._run_farm_loop rather
## than each needing their own subclass/loop. A building with no real input
## (Fruit/Potato - "consistent", not gated on deliveries) sets
## input_per_tick to 0, which makes the loop's "do I need to restock"
## check always false without any special-casing.
@export var input_per_tick: float = 0.5
@export var input_resource: String = "wood"
## Skill this building trains - "farming" for raw crops, but "milling"/
## "baking"/"brewing" etc. for refinement buildings, since those are
## meaningfully different trades even though they share this class.
@export var skill_id: String = "farming"


func get_skill_id() -> String:
	return skill_id


func get_input_resource() -> String:
	return input_resource
