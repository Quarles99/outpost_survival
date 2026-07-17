extends Workstation
class_name Brickmaker

## Converts stone into brick (see BuildingCatalog's "brickmaker" entry for
## the actual input_resource/input_per_tick/output_per_tick values) via the
## same Character._run_farm_loop every Farm-class building uses - shares the
## loop by structural typing alone (input_per_tick/input_resource live on
## Workstation itself), not by extending Farm. Deliberately NOT part of the
## Farm-family retool system (BuildingCatalog.farm_family_options()/the
## crop-selection panel): a Brickmaker is a dedicated, single-recipe
## building, not one of several interchangeable recipes sharing one
## worker-assignment slot the way Cabbage Farm/Mill/Bakery/etc. are. No
## `clicked` signal for the same reason - Base._wire_farm_clicks only wires
## the crop panel to `is Farm` nodes, so simply not extending Farm already
## keeps this building out of that system with no extra guarding needed.


func get_skill_id() -> String:
	return "masonry"
