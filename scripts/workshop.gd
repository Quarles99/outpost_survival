extends Workstation
class_name Workshop

## Shared class for Mill/Bakery/Brewery - specialist refinement buildings
## that were originally just differently-configured Farm instances (like
## every other Alternative Crop Types building) but got carved out into
## their own identity per an explicit request: a mill/bakery/brewery isn't
## a farm, it shouldn't share Farm's class, retool panel, or art. Still a
## generic single-input/single-output converter under the hood, same as
## Farm (input_per_tick/input_resource live on Workstation itself - see its
## own doc comment - specifically so a converter class doesn't have to be
## Farm to share Character._run_farm_loop), and skill_id stays a per-
## catalog-entry export (Mill trains "milling", Bakery "baking", Brewery
## "brewing") rather than being hardcoded per building the way Brickmaker's
## single fixed "masonry" is - three distinct trades still need one class
## with a configurable skill, not three near-identical classes.
##
## Deliberately no `clicked` signal / crop-selection wiring, same reasoning
## as Brickmaker: not extending Farm and having no `clicked` signal is what
## keeps a building out of the Farm-family retool panel with zero extra
## guarding needed (Base._wire_farm_clicks only wires that panel to `is
## Farm` nodes) - a Mill can no longer be freely retooled into a Cabbage
## Farm or vice versa, matching "specialist workshop, not one of several
## interchangeable crop recipes."
@export var skill_id: String = "labor"


func get_skill_id() -> String:
	return skill_id
