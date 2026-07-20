extends RefCounted
class_name BuildingCatalog

const OPTIONS := [
	## Never actually placeable (see "placeable": false below) - the Outpost
	## Hall is the one fixed starting building, never re-buildable by the
	## player (see CLAUDE.md's "Minimal starting buildings"). grid_size/cost
	## still need to live here regardless, though: Base._ready() reads
	## grid_size to reserve the starting building's footprint
	## (_reserve_existing_footprint), and cost/scene are the same fields
	## every other catalog entry needs, kept for consistency even though
	## cost is never actually charged for it. Bug found and fixed via the
	## Balance.md tuning doc: placeable_options() used to filter on
	## grid_size alone, which every buildable option also has, so this
	## entry was silently showing up in the real Build menu as a purchasable
	## 20-wood option - placing it would have worked as an extra stockpile
	## (Base._materialize_building registers any get_stockpile_spot()
	## building generically) but never as a recruitment point (only the
	## original $OutpostHall node gets its `clicked` signal wired to
	## _on_outpost_hall_clicked, in Base._ready() - a constructed one
	## wouldn't), a confusing half-working duplicate nothing was ever meant
	## to allow.
	{
		"id": "outpost_hall",
		"display_name": "Outpost Hall",
		"description": "The settlement's founding hall - the recruitment point and central stockpile.",
		"scene": preload("res://scenes/building/OutpostHall.tscn"),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 20.0},
		"placeable": false,
	},
	## Cost raised 10.0 -> 25.0, output raised 1.0 -> 1.1 cabbage via
	## Outpost_Survival/Game Systems/Balance.md's edit-and-hand-back
	## workflow. input_resource/input_per_tick added per an earlier explicit
	## request ("all farms require wood as an input") - matches Grain
	## Farm/Hops Farm's existing 0.5-wood-per-output ratio, so every
	## Farm-family recipe (interchangeable via the free retool panel, see
	## BuildingCatalog.farm_family_options) shares the same input cost shape
	## rather than some needing wood and others not.
	{
		"id": "farm",
		"display_name": "Cabbage Farm",
		"description": "Grows cabbage from wood. Retool it into any other crop for free once placed.",
		"scene": preload("res://scenes/workstation/Farm.tscn"),
		"resource_type": "cabbage",
		"input_resource": "wood",
		"input_per_tick": 0.5,
		"output_per_tick": 1.1,
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 25.0},
	},
	## Cost raised 10.0 -> 50.0, then lowered 50.0 -> 25.0, via
	## Outpost_Survival/Game Systems/Balance.md's edit-and-hand-back
	## workflow. No longer in lockstep with GameState.DEFAULT_RESOURCES's
	## starting wood (50.0) - starting wood now covers this outright with
	## 25.0 left over, rather than exactly nothing else.
	{
		"id": "woodpile",
		"display_name": "Lumber Camp",
		"description": "Chops nearby trees for wood, replanting saplings as it clears them.",
		"scene": preload("res://scenes/workstation/LumberCamp.tscn"),
		"resource_type": "wood",
		"grid_size": Vector2i(1, 1),
		"cost": {"wood": 25.0},
	},
	## Cost raised 20.0 -> 50.0 via Outpost_Survival/Game Systems/Balance.md's
	## edit-and-hand-back workflow - pushes the first House further out (more
	## wood to gather before it's even placeable), on top of the Lumber Camp
	## cost raise above also delaying when gathering can even start.
	{
		"id": "house",
		"display_name": "House",
		"description": "Raises population capacity. Can be upgraded once for even more capacity.",
		"scene": preload("res://scenes/building/House.tscn"),
		"grid_size": Vector2i(2, 2),
		"population_capacity": 2,
		"cost": {"wood": 50.0},
	},
	## Cost raised 10.0 -> 25.0, output raised 0.5 -> 0.6 stone via
	## Outpost_Survival/Game Systems/Balance.md's edit-and-hand-back
	## workflow.
	{
		"id": "stone_mine",
		"display_name": "Stone Mine",
		"description": "Quarries raw stone from the ground - no input needed.",
		"scene": preload("res://scenes/workstation/StoneMine.tscn"),
		"resource_type": "stone",
		"output_per_tick": 0.6,
		"grid_size": Vector2i(1, 1),
		"cost": {"wood": 25.0},
	},
	## Cost raised 10.0+10.0 -> 100.0+25.0 via Outpost_Survival/Game
	## Systems/Balance.md's edit-and-hand-back workflow (output/input recipe
	## unchanged: 1.0 stone -> 0.5 brick).
	{
		"id": "brickmaker",
		"display_name": "Brickmaker",
		"description": "Fires raw stone into brick, used by upgrades and advanced buildings.",
		"scene": preload("res://scenes/workstation/Brickmaker.tscn"),
		"resource_type": "brick",
		"input_resource": "stone",
		"input_per_tick": 1.0,
		"output_per_tick": 0.5,
		"sprite_tint": Color(0.6, 0.32, 0.22),
		"grid_size": Vector2i(1, 1),
		"cost": {"wood": 100.0, "stone": 25.0},
	},
	## Cost raised 5.0+10.0 -> 50.0+50.0 via Outpost_Survival/Game
	## Systems/Balance.md's edit-and-hand-back workflow.
	{
		"id": "well",
		"display_name": "Well",
		"description": "Grants unlimited water access, boosting nearby farm output.",
		"scene": preload("res://scenes/building/Well.tscn"),
		"grid_size": Vector2i(1, 1),
		"water_wells": 1,
		"cost": {"stone": 50.0, "wood": 50.0},
	},
	## Cost raised 25.0+25.0 -> 500.0+100.0, storage bonus lowered
	## 1000.0 -> 60.0 via Outpost_Survival/Game Systems/Balance.md's
	## edit-and-hand-back workflow.
	{
		"id": "storage_facility",
		"display_name": "Storage Facility",
		"description": "Raises the stockpile cap for every resource.",
		"scene": preload("res://scenes/building/StorageFacility.tscn"),
		"grid_size": Vector2i(2, 4),
		"storage_capacity": 60.0,
		"cost": {"wood": 500.0, "stone": 100.0},
	},
	## --- Alternative Crop Types ---------------------------------------------
	## Grain Farm/Hops Farm/Fruit Orchard/Potato Farm share CropStation.tscn
	## (farm.gd's generic converter loop) and are part of the Farm-family
	## retool group (see FARM_FAMILY_SCENE_PATHS below). Mill/Bakery/Brewery
	## use Workshop.tscn instead (workshop.gd, same converter loop by
	## structural typing, not by extending Farm) and are deliberately NOT
	## part of that retool group - "specialist workshops," not one of
	## several interchangeable crop recipes. All 7 are still distinguished
	## purely by these catalog fields, applied at placement via
	## Base.BUILDING_PROPERTIES/_apply_option_properties.
	## Cost raised 10.0 -> 25.0 via Outpost_Survival/Game Systems/Balance.md's
	## edit-and-hand-back workflow. "placeable": false added per an earlier
	## explicit request ("combine all farms into one farm building that can
	## be changed to whatever crop is desired") - same mechanism Outpost Hall
	## already uses to stay out of placeable_options() while remaining a
	## real OPTIONS entry. farm_family_options() (the retool panel) filters
	## by scene path only, ignoring "placeable" entirely, so this recipe is
	## still fully choosable via retool - only the standalone Build-menu
	## button for it is gone. The base "farm"/Cabbage Farm entry above is
	## the one and only Farm-family building left in the Build menu; every
	## other crop is reached by retooling it after placement.
	{
		"id": "grain_farm",
		"display_name": "Grain Farm",
		"description": "Grows grain from wood - feeds a Mill for flour.",
		"scene": preload("res://scenes/workstation/CropStation.tscn"),
		"resource_type": "grain",
		"input_resource": "wood",
		"input_per_tick": 0.5,
		"output_per_tick": 1.0,
		"sprite_tint": Color(0.85, 0.75, 0.35),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 25.0},
		"placeable": false,
	},
	## Cost raised 10.0+10.0 -> 50.0+25.0 via Outpost_Survival/Game
	## Systems/Balance.md's edit-and-hand-back workflow (recipe amounts
	## unchanged: 1.0 grain -> 1.0 flour).
	{
		"id": "mill",
		"display_name": "Mill",
		"description": "Grinds grain into flour - feeds a Bakery for bread.",
		"scene": preload("res://scenes/workstation/Workshop.tscn"),
		"resource_type": "flour",
		"input_resource": "grain",
		"input_per_tick": 1.0,
		"output_per_tick": 1.0,
		"skill_id": "milling",
		"sprite_tint": Color(0.8, 0.78, 0.72),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 50.0, "brick": 25.0},
	},
	## Cost changed 10.0 wood+5.0 stone -> 50.0 wood+25.0 brick via
	## Outpost_Survival/Game Systems/Balance.md's edit-and-hand-back
	## workflow - a resource-type swap (stone -> brick), not just an amount
	## raise.
	{
		"id": "bakery",
		"display_name": "Bakery",
		"description": "Bakes flour into bread, a food source.",
		"scene": preload("res://scenes/workstation/Workshop.tscn"),
		"resource_type": "bread",
		"input_resource": "flour",
		"input_per_tick": 1.0,
		"output_per_tick": 1.0,
		"skill_id": "baking",
		"sprite_tint": Color(0.82, 0.55, 0.3),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 50.0, "brick": 25.0},
	},
	## Cost raised 10.0 -> 25.0 via Outpost_Survival/Game Systems/Balance.md's
	## edit-and-hand-back workflow.
	{
		"id": "hops_farm",
		"display_name": "Hops Farm",
		"description": "Grows hops from wood - feeds a Brewery for beer.",
		"scene": preload("res://scenes/workstation/CropStation.tscn"),
		"resource_type": "hops",
		"input_resource": "wood",
		"input_per_tick": 0.5,
		"output_per_tick": 1.0,
		"sprite_tint": Color(0.5, 0.75, 0.4),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 25.0},
		"placeable": false,
	},
	## Cost raised 10.0+5.0+5.0 -> 25.0+15.0+15.0 via Outpost_Survival/Game
	## Systems/Balance.md's edit-and-hand-back workflow. That same pass also
	## describes the recipe as "1 hops + 1 grain -> 1 beer" (a second input)
	## - NOT applied here: Workshop (workshop.gd) only supports a single
	## input_resource/input_per_tick pair, so a genuine two-input recipe
	## needs an actual code change to Workshop/Character._run_farm_loop, not
	## a value edit. Recipe stays single-input (hops only) until that's
	## built - flagged rather than silently implemented as a reinterpreted
	## single input, per this file's own "flag real feature work instead of
	## guessing" precedent (see the "Not yet implemented" note below the
	## Building Costs & Output table).
	{
		"id": "brewery",
		"display_name": "Brewery",
		"description": "Brews hops into beer, a food source.",
		"scene": preload("res://scenes/workstation/Workshop.tscn"),
		"resource_type": "beer",
		"input_resource": "hops",
		"input_per_tick": 1.0,
		"output_per_tick": 1.0,
		"skill_id": "brewing",
		"sprite_tint": Color(0.75, 0.55, 0.2),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 25.0, "stone": 15.0, "brick": 15.0},
	},
	## Cost raised 20.0 -> 200.0 and output raised 2.0 -> 2.2 via
	## Outpost_Survival/Game Systems/Balance.md's edit-and-hand-back
	## workflow. work_interval kept at exactly 2x Workstation.work_interval's
	## own default (currently 6.0, so 12.0 here) - per an earlier explicit
	## request to preserve the same relative speed relationships between
	## buildings when the standard default itself changes, not a fixed
	## absolute number.
	{
		"id": "fruit_orchard",
		"display_name": "Fruit Orchard",
		"description": "Grows fruit from wood - a high-yield food source, slower to work.",
		"scene": preload("res://scenes/workstation/CropStation.tscn"),
		"resource_type": "fruit",
		"input_resource": "wood",
		"input_per_tick": 1.0,
		"output_per_tick": 2.2,
		"work_interval": 12.0,
		"sprite_tint": Color(0.85, 0.45, 0.5),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 200.0},
		"placeable": false,
	},
	## Cost raised 10.0 -> 25.0 via Outpost_Survival/Game Systems/Balance.md's
	## edit-and-hand-back workflow.
	{
		"id": "potato_farm",
		"display_name": "Potato Farm",
		"description": "Grows potatoes from wood - a food source.",
		"scene": preload("res://scenes/workstation/CropStation.tscn"),
		"resource_type": "potato",
		"input_resource": "wood",
		"input_per_tick": 0.5,
		"output_per_tick": 1.0,
		"sprite_tint": Color(0.65, 0.5, 0.35),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 25.0},
		"placeable": false,
	},
	## --- Combat training -----------------------------------------------------
	## Barracks/Archery Range/Mage Tower all share TrainingGround.tscn
	## (training_ground.gd - no input/output, no Farm-family retool wiring,
	## same relationship to Workshop that Mill/Bakery/Brewery have), each
	## training one of the three combat skills a citizen needs before
	## CombatUnit reads their level (see Outpost_Survival/Ideas/Combat
	## Units.md's deferred integration item - that read isn't wired up yet,
	## this is only the town-side half). Each also now grants its own
	## additional once-per-day recruit of its own combat skill when clicked
	## (see TrainingGround.clicked/can_recruit/mark_recruited and
	## Base._on_training_ground_clicked) - "max_count": 1 caps each of the
	## three to one at a time (checked by Base._update_ghost/_count_existing),
	## per an explicit request ("for now"), since each instance independently
	## grants its own extra recruit and stacking several would stack that
	## bonus unbounded.
	## Cost raised 20.0+10.0 -> 100.0+25.0 via Outpost_Survival/Game
	## Systems/Balance.md's edit-and-hand-back workflow.
	{
		"id": "barracks",
		"display_name": "Barracks",
		"description": "Trains melee combat skill and recruits/produces melee units.",
		"scene": preload("res://scenes/workstation/TrainingGround.tscn"),
		"resource_type": "melee_combat",
		"skill_id": "melee_combat",
		"sprite_tint": Color(0.55, 0.22, 0.2),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 100.0, "stone": 25.0},
		"max_count": 1,
		"chosen_unit_type": CombatUnit.UnitType.SHIELDBEARER,
	},
	## Cost changed 10.0 wood+5.0 stone -> 125.0 wood+25.0 brick via
	## Outpost_Survival/Game Systems/Balance.md's edit-and-hand-back
	## workflow - a resource-type swap (stone -> brick) as well as an amount
	## raise.
	{
		"id": "archery_range",
		"display_name": "Archery Range",
		"description": "Trains archery skill and recruits/produces ranged units.",
		"scene": preload("res://scenes/workstation/TrainingGround.tscn"),
		"resource_type": "archery",
		"skill_id": "archery",
		"sprite_tint": Color(0.35, 0.45, 0.25),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 125.0, "brick": 25.0},
		"max_count": 1,
		"chosen_unit_type": CombatUnit.UnitType.ARCHER,
	},
	## Cost raised 10.0+10.0+5.0 -> 200.0+25.0+25.0 via Outpost_Survival/Game
	## Systems/Balance.md's edit-and-hand-back workflow.
	{
		"id": "mage_tower",
		"display_name": "Mage Tower",
		"description": "Trains spellcasting skill and recruits/produces mages.",
		"scene": preload("res://scenes/workstation/TrainingGround.tscn"),
		"resource_type": "spellcasting",
		"skill_id": "spellcasting",
		"sprite_tint": Color(0.35, 0.25, 0.5),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 200.0, "stone": 25.0, "brick": 25.0},
		"max_count": 1,
		"chosen_unit_type": CombatUnit.UnitType.MAGE,
	},
]


## Options that can be freely placed on the ground via the building-placement
## ghost cursor (identified by having a grid footprint).
static func placeable_options() -> Array:
	return OPTIONS.filter(func(option: Dictionary) -> bool: return option.has("grid_size") and option.get("placeable", true))


## Options sharing a Farm-class scene (the original wood->food Farm plus
## the raw-crop Alternative Crop Types buildings - Grain Farm, Hops Farm,
## Fruit Orchard, Potato Farm - see farm.gd) - identified structurally by
## which scene they instantiate rather than a hardcoded id list, so a
## future Farm-family addition doesn't need to remember to register here
## separately. Offered by Base's crop-selection panel when an already-
## placed Farm-family building is clicked, letting the player retool it
## into any other recipe in this list. Mill/Bakery/Brewery deliberately
## excluded - they use Workshop.tscn instead (see workshop.gd), not part of
## this retool group despite sharing the same converter work loop.
const FARM_FAMILY_SCENE_PATHS := [
	"res://scenes/workstation/Farm.tscn",
	"res://scenes/workstation/CropStation.tscn",
]


static func farm_family_options() -> Array:
	return OPTIONS.filter(func(option: Dictionary) -> bool: return option["scene"].resource_path in FARM_FAMILY_SCENE_PATHS)


static func get_option(id: String) -> Dictionary:
	for option in OPTIONS:
		if option["id"] == id:
			return option
	return {}
