extends RefCounted
class_name FormationCatalog

## Static catalog of named Formation presets, mirroring BuildingCatalog/
## RecruitCatalog's convention. One preset for now ("line", matching the
## two-rank layout CombatTestManager used to hardcode before Formation
## existed) - a future "Wedge"/"Turtle" preset is just another entry here,
## no code changes needed elsewhere. See Outpost_Survival/Ideas/Formation
## Strategy AI.md for the deferred idea of choosing between presets at all
## (player-driven or AI-driven) - right now CombatTestManager always uses
## "line".
const OPTIONS := [
	{
		"id": "line",
		"display_name": "Line",
		"rank_depths": [380.0, 520.0],
		"rank_for_type": {CombatUnit.UnitType.SWORDSMAN: 0},
		"row_spacing": 90.0,
		"tactics": {},
	},
]


static func get_option(id: String) -> Dictionary:
	for option in OPTIONS:
		if option["id"] == id:
			return option
	return {}
