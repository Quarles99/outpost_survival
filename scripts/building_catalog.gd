extends RefCounted
class_name BuildingCatalog

const OPTIONS := [
	{
		"id": "outpost_hall",
		"display_name": "Outpost Hall",
		"scene": preload("res://scenes/building/OutpostHall.tscn"),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 20.0},
	},
	{
		"id": "farm",
		"display_name": "Farm",
		"scene": preload("res://scenes/workstation/Farm.tscn"),
		"resource_type": "food",
		"output_per_tick": 1.0,
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 6.0},
	},
	{
		"id": "woodpile",
		"display_name": "Lumber Camp",
		"scene": preload("res://scenes/workstation/LumberCamp.tscn"),
		"resource_type": "wood",
		"grid_size": Vector2i(1, 1),
		"cost": {"wood": 5.0},
	},
	{
		"id": "house",
		"display_name": "House",
		"scene": preload("res://scenes/building/House.tscn"),
		"grid_size": Vector2i(2, 2),
		"population_capacity": 2,
		"cost": {"wood": 10.0},
	},
	{
		"id": "stone_mine",
		"display_name": "Stone Mine",
		"scene": preload("res://scenes/workstation/StoneMine.tscn"),
		"resource_type": "stone",
		"output_per_tick": 0.5,
		"grid_size": Vector2i(1, 1),
		"cost": {"wood": 8.0},
	},
	{
		"id": "well",
		"display_name": "Well",
		"scene": preload("res://scenes/building/Well.tscn"),
		"grid_size": Vector2i(1, 1),
		"water_wells": 1,
		"cost": {"stone": 10.0, "wood": 4.0},
	},
	{
		"id": "storage_facility",
		"display_name": "Storage Facility",
		"scene": preload("res://scenes/building/StorageFacility.tscn"),
		"grid_size": Vector2i(2, 4),
		"storage_capacity": 30.0,
		"cost": {"wood": 15.0, "stone": 10.0},
	},
	## --- Alternative Crop Types ---------------------------------------------
	## All share CropStation.tscn (farm.gd's now-generic converter loop - see
	## its docs) and are distinguished purely by these catalog fields, applied
	## at placement via Base.BUILDING_PROPERTIES/_apply_option_properties.
	{
		"id": "grain_farm",
		"display_name": "Grain Farm",
		"scene": preload("res://scenes/workstation/CropStation.tscn"),
		"resource_type": "grain",
		"input_resource": "wood",
		"input_per_tick": 0.5,
		"output_per_tick": 1.0,
		"skill_id": "farming",
		"sprite_tint": Color(0.85, 0.75, 0.35),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 6.0},
	},
	{
		"id": "mill",
		"display_name": "Mill",
		"scene": preload("res://scenes/workstation/CropStation.tscn"),
		"resource_type": "flour",
		"input_resource": "grain",
		"input_per_tick": 1.0,
		"output_per_tick": 1.0,
		"skill_id": "milling",
		"sprite_tint": Color(0.8, 0.78, 0.72),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 8.0},
	},
	{
		"id": "bakery",
		"display_name": "Bakery",
		"scene": preload("res://scenes/workstation/CropStation.tscn"),
		"resource_type": "bread",
		"input_resource": "flour",
		"input_per_tick": 1.0,
		"output_per_tick": 1.0,
		"skill_id": "baking",
		"sprite_tint": Color(0.82, 0.55, 0.3),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 8.0, "stone": 4.0},
	},
	{
		"id": "hops_farm",
		"display_name": "Hops Farm",
		"scene": preload("res://scenes/workstation/CropStation.tscn"),
		"resource_type": "hops",
		"input_resource": "wood",
		"input_per_tick": 0.5,
		"output_per_tick": 1.0,
		"skill_id": "farming",
		"sprite_tint": Color(0.5, 0.75, 0.4),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 6.0},
	},
	{
		"id": "brewery",
		"display_name": "Brewery",
		"scene": preload("res://scenes/workstation/CropStation.tscn"),
		"resource_type": "beer",
		"input_resource": "hops",
		"input_per_tick": 1.0,
		"output_per_tick": 1.0,
		"skill_id": "brewing",
		"sprite_tint": Color(0.75, 0.55, 0.2),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 10.0, "stone": 4.0},
	},
	{
		"id": "fruit_orchard",
		"display_name": "Fruit Orchard",
		"scene": preload("res://scenes/workstation/CropStation.tscn"),
		"resource_type": "fruit",
		"input_resource": "",
		"input_per_tick": 0.0,
		"output_per_tick": 0.6,
		"work_interval": 3.0,
		"skill_id": "farming",
		"sprite_tint": Color(0.85, 0.45, 0.5),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 8.0},
	},
	{
		"id": "potato_farm",
		"display_name": "Potato Farm",
		"scene": preload("res://scenes/workstation/CropStation.tscn"),
		"resource_type": "potato",
		"input_resource": "",
		"input_per_tick": 0.0,
		"output_per_tick": 1.0,
		"skill_id": "farming",
		"sprite_tint": Color(0.65, 0.5, 0.35),
		"grid_size": Vector2i(2, 2),
		"cost": {"wood": 6.0},
	},
]


## Options that can be freely placed on the ground via the building-placement
## ghost cursor (identified by having a grid footprint).
static func placeable_options() -> Array:
	return OPTIONS.filter(func(option: Dictionary) -> bool: return option.has("grid_size"))


static func get_option(id: String) -> Dictionary:
	for option in OPTIONS:
		if option["id"] == id:
			return option
	return {}
