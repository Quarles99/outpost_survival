extends RefCounted
class_name FormationCatalog

## Static catalog of named Formation presets, mirroring BuildingCatalog/
## RecruitCatalog's convention. Each of the three counter-strategies below
## (rush/skirmish/guard) is derived directly from CombatUnit.DAMAGE_
## MULTIPLIERS rather than picked arbitrarily - see each entry's own
## comment - so StrategistAI's counter-picking logic has a real basis, not
## just cosmetic variety. "line" (the original two-rank layout) is the
## balanced default for a roughly-even or unclear matchup.
##
## Trapper explicitly joins Swordsman at rank 0 (front) in every preset
## below except Guard - its whole job is intercepting fast divers before
## they reach the back line, so starting it back with the ranged units
## would defeat the purpose. Outrider is deliberately left unlisted
## everywhere (defaulting to the back rank alongside Archer/Mage) - it
## starts safe and dives in aggressively per its own target_priority
## rather than starting already committed to a front-line brawl.
const OPTIONS := [
	{
		"id": "line",
		"display_name": "Line",
		"rank_depths": [380.0, 520.0],
		"rank_for_type": {CombatUnit.UnitType.SWORDSMAN: 0, CombatUnit.UnitType.TRAPPER: 0},
		"row_spacing": 90.0,
		"tactics": {},
	},
	# Counters an Archer-heavy enemy: a Swordsman resists Archer damage
	# (0.5x, see DAMAGE_MULTIPLIERS[SWORDSMAN][ARCHER]) but only while
	# actually fighting, not while walking into range - the priority is
	# closing distance fast as one tight group rather than the usual wide
	# front/back split, so the whole line arrives together instead of the
	# back rank trailing. Also barely kites (tiny melee_avoid_radius) -
	# against a ranged-heavy enemy there's rarely a nearby enemy Swordsman
	# worth evading anyway, and standing firm keeps the advance cohesive.
	{
		"id": "rush",
		"display_name": "Rush",
		"rank_depths": [380.0, 420.0],
		"rank_for_type": {CombatUnit.UnitType.SWORDSMAN: 0, CombatUnit.UnitType.TRAPPER: 0},
		"row_spacing": 70.0,
		"tactics": {"melee_avoid_radius": 60.0},
	},
	# Counters a Swordsman-heavy enemy: ranged units are the ones actually
	# weak/strong here (Archer weak to Swordsman at 1.5x, but Swordsman
	# resists Archer at 0.5x - the archer's own safety, not its damage
	# output, is what's at stake), so hold them much further back
	# (wide rank gap) and kite more aggressively (larger melee_avoid_radius)
	# to stay out of melee reach longer. 200, not the naive "as large as
	# possible" - a real bug caught by observed play: melee_avoid_radius
	# above either ranged type's own attack_range (Archer 260, Mage 220)
	# leaves no "safe firing zone" where a unit is far enough from a
	# Swordsman to stand its ground but still close enough to shoot, so it
	# never stops retreating long enough to actually skirmish. 200 stays
	# under both, so there's real room to fire before evasion kicks in.
	{
		"id": "skirmish",
		"display_name": "Skirmish",
		"rank_depths": [380.0, 650.0],
		"rank_for_type": {CombatUnit.UnitType.SWORDSMAN: 0, CombatUnit.UnitType.TRAPPER: 0},
		"row_spacing": 110.0,
		"tactics": {"melee_avoid_radius": 200.0},
	},
	# Counters a Mage-heavy enemy: inverts the usual melee-front/ranged-back
	# split, since Archers resist Magic (0.5x, DAMAGE_MULTIPLIERS[ARCHER][
	# MAGE]) while Swordsmen are weak to it (1.5x) - Archers (and Mages,
	# which per the current multiplier table also resist Magic) hold the
	# front and Swordsmen wait behind, the opposite of every other preset
	# here. Lower melee_avoid_radius since the front line is now expected
	# to hold its ground like a tank, not kite.
	{
		"id": "guard",
		"display_name": "Guard",
		"rank_depths": [380.0, 520.0],
		"rank_for_type": {CombatUnit.UnitType.ARCHER: 0, CombatUnit.UnitType.MAGE: 0},
		"row_spacing": 90.0,
		"tactics": {"melee_avoid_radius": 80.0},
	},
]


static func get_option(id: String) -> Dictionary:
	for option in OPTIONS:
		if option["id"] == id:
			return option
	return {}
