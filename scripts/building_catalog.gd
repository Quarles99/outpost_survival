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
		"scene": preload("res://scenes/building/OutpostHall.tscn"),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 20.0},
		"placeable": false,
	},
	## Cost raised 6.0 -> 10.0 via Outpost_Survival/Balance.md's edit-and-
	## hand-back workflow.
	{
		"id": "farm",
		"display_name": "Cabbage Farm",
		"scene": preload("res://scenes/workstation/Farm.tscn"),
		"resource_type": "cabbage",
		"output_per_tick": 1.0,
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 10.0},
	},
	## Cost raised 5.0 -> 10.0 via Outpost_Survival/Balance.md's edit-and-
	## hand-back workflow - see GameState.DEFAULT_RESOURCES's matching wood
	## raise (5.0 -> 10.0), kept in exact lockstep since starting wood is
	## tuned to afford this building alone and nothing else.
	{
		"id": "woodpile",
		"display_name": "Lumber Camp",
		"scene": preload("res://scenes/workstation/LumberCamp.tscn"),
		"resource_type": "wood",
		"grid_size": Vector2i(1, 1),
		"cost": {"wood": 10.0},
	},
	## Cost raised 10.0 -> 20.0 via Outpost_Survival/Balance.md's edit-and-
	## hand-back workflow - pushes the first House further out (more wood to
	## gather before it's even placeable), on top of the Lumber Camp cost
	## raise above also delaying when gathering can even start.
	{
		"id": "house",
		"display_name": "House",
		"scene": preload("res://scenes/building/House.tscn"),
		"grid_size": Vector2i(2, 2),
		"population_capacity": 2,
		"cost": {"wood": 20.0},
	},
	## Cost raised 8.0 -> 10.0 via Outpost_Survival/Balance.md's edit-and-
	## hand-back workflow.
	{
		"id": "stone_mine",
		"display_name": "Stone Mine",
		"scene": preload("res://scenes/workstation/StoneMine.tscn"),
		"resource_type": "stone",
		"output_per_tick": 0.5,
		"grid_size": Vector2i(1, 1),
		"cost": {"wood": 10.0},
	},
	## Cost raised 8.0+6.0 -> 10.0+10.0 and output halved 1.0 -> 0.5 brick
	## (input stays 1.0 stone) via Outpost_Survival/Balance.md's edit-and-
	## hand-back workflow.
	{
		"id": "brickmaker",
		"display_name": "Brickmaker",
		"scene": preload("res://scenes/workstation/Brickmaker.tscn"),
		"resource_type": "brick",
		"input_resource": "stone",
		"input_per_tick": 1.0,
		"output_per_tick": 0.5,
		"sprite_tint": Color(0.6, 0.32, 0.22),
		"grid_size": Vector2i(1, 1),
		"cost": {"wood": 10.0, "stone": 10.0},
	},
	## Wood cost raised 4.0 -> 5.0 via Outpost_Survival/Balance.md's edit-
	## and-hand-back workflow.
	{
		"id": "well",
		"display_name": "Well",
		"scene": preload("res://scenes/building/Well.tscn"),
		"grid_size": Vector2i(1, 1),
		"water_wells": 1,
		"cost": {"stone": 10.0, "wood": 5.0},
	},
	## Cost raised 15.0+10.0 -> 25.0+25.0 via Outpost_Survival/Balance.md's
	## edit-and-hand-back workflow.
	{
		"id": "storage_facility",
		"display_name": "Storage Facility",
		"scene": preload("res://scenes/building/StorageFacility.tscn"),
		"grid_size": Vector2i(2, 4),
		"storage_capacity": 60.0,
		"cost": {"wood": 25.0, "stone": 25.0},
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
	## Cost raised 6.0 -> 10.0 via Outpost_Survival/Balance.md's edit-and-
	## hand-back workflow.
	{
		"id": "grain_farm",
		"display_name": "Grain Farm",
		"scene": preload("res://scenes/workstation/CropStation.tscn"),
		"resource_type": "grain",
		"input_resource": "wood",
		"input_per_tick": 0.5,
		"output_per_tick": 1.0,
		"sprite_tint": Color(0.85, 0.75, 0.35),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 10.0},
	},
	## Cost raised 8.0+6.0 -> 10.0+10.0 via Outpost_Survival/Balance.md's
	## edit-and-hand-back workflow (recipe amounts unchanged: 1.0 grain ->
	## 1.0 flour).
	{
		"id": "mill",
		"display_name": "Mill",
		"scene": preload("res://scenes/workstation/Workshop.tscn"),
		"resource_type": "flour",
		"input_resource": "grain",
		"input_per_tick": 1.0,
		"output_per_tick": 1.0,
		"skill_id": "milling",
		"sprite_tint": Color(0.8, 0.78, 0.72),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 10.0, "brick": 10.0},
	},
	## Cost raised 8.0+4.0 -> 10.0+5.0 via Outpost_Survival/Balance.md's
	## edit-and-hand-back workflow.
	{
		"id": "bakery",
		"display_name": "Bakery",
		"scene": preload("res://scenes/workstation/Workshop.tscn"),
		"resource_type": "bread",
		"input_resource": "flour",
		"input_per_tick": 1.0,
		"output_per_tick": 1.0,
		"skill_id": "baking",
		"sprite_tint": Color(0.82, 0.55, 0.3),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 10.0, "stone": 5.0},
	},
	## Cost raised 6.0 -> 10.0 via Outpost_Survival/Balance.md's edit-and-
	## hand-back workflow.
	{
		"id": "hops_farm",
		"display_name": "Hops Farm",
		"scene": preload("res://scenes/workstation/CropStation.tscn"),
		"resource_type": "hops",
		"input_resource": "wood",
		"input_per_tick": 0.5,
		"output_per_tick": 1.0,
		"sprite_tint": Color(0.5, 0.75, 0.4),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 10.0},
	},
	## Stone/brick cost adjusted 4.0/6.0 -> 5.0/5.0 via Outpost_Survival/
	## Balance.md's edit-and-hand-back workflow.
	{
		"id": "brewery",
		"display_name": "Brewery",
		"scene": preload("res://scenes/workstation/Workshop.tscn"),
		"resource_type": "beer",
		"input_resource": "hops",
		"input_per_tick": 1.0,
		"output_per_tick": 1.0,
		"skill_id": "brewing",
		"sprite_tint": Color(0.75, 0.55, 0.2),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 10.0, "stone": 5.0, "brick": 5.0},
	},
	## Cost raised 8.0 -> 20.0 and output raised 0.6 -> 2.0 via
	## Outpost_Survival/Balance.md's edit-and-hand-back workflow.
	{
		"id": "fruit_orchard",
		"display_name": "Fruit Orchard",
		"scene": preload("res://scenes/workstation/CropStation.tscn"),
		"resource_type": "fruit",
		"input_resource": "",
		"input_per_tick": 0.0,
		"output_per_tick": 2.0,
		"work_interval": 6.0,
		"sprite_tint": Color(0.85, 0.45, 0.5),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 20.0},
	},
	## Cost raised 6.0 -> 10.0 via Outpost_Survival/Balance.md's edit-and-
	## hand-back workflow.
	{
		"id": "potato_farm",
		"display_name": "Potato Farm",
		"scene": preload("res://scenes/workstation/CropStation.tscn"),
		"resource_type": "potato",
		"input_resource": "",
		"input_per_tick": 0.0,
		"output_per_tick": 1.0,
		"sprite_tint": Color(0.65, 0.5, 0.35),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 10.0},
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
	## Cost raised 10.0+6.0 -> 20.0+10.0 via Outpost_Survival/Balance.md's
	## edit-and-hand-back workflow.
	{
		"id": "barracks",
		"display_name": "Barracks",
		"scene": preload("res://scenes/workstation/TrainingGround.tscn"),
		"resource_type": "melee_combat",
		"skill_id": "melee_combat",
		"sprite_tint": Color(0.55, 0.22, 0.2),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 20.0, "stone": 10.0},
		"max_count": 1,
	},
	## Cost raised 8.0+4.0 -> 10.0+5.0 via Outpost_Survival/Balance.md's
	## edit-and-hand-back workflow.
	{
		"id": "archery_range",
		"display_name": "Archery Range",
		"scene": preload("res://scenes/workstation/TrainingGround.tscn"),
		"resource_type": "archery",
		"skill_id": "archery",
		"sprite_tint": Color(0.35, 0.45, 0.25),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 10.0, "stone": 5.0},
		"max_count": 1,
	},
	## Cost raised 6.0+8.0+4.0 -> 10.0+10.0+5.0 via Outpost_Survival/
	## Balance.md's edit-and-hand-back workflow.
	{
		"id": "mage_tower",
		"display_name": "Mage Tower",
		"scene": preload("res://scenes/workstation/TrainingGround.tscn"),
		"resource_type": "spellcasting",
		"skill_id": "spellcasting",
		"sprite_tint": Color(0.35, 0.25, 0.5),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 10.0, "stone": 10.0, "brick": 5.0},
		"max_count": 1,
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
