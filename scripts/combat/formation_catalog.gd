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
## Trapper explicitly joins Shieldbearer/Marauder at rank 0 (front) in every
## preset below except Guard - its whole job is intercepting fast divers
## before they reach the back line, so starting it back with the ranged
## units would defeat the purpose. Outrider is deliberately left unlisted
## everywhere (defaulting to the back rank alongside Archer/Mage) - it
## starts safe and dives in aggressively per its own TYPE_PREFERENCE rather
## than starting already committed to a front-line brawl.
const OPTIONS := [
	{
		"id": "line",
		"display_name": "Line",
		"rank_depths": [380.0, 520.0],
		"rank_for_type": {CombatUnit.UnitType.SHIELDBEARER: 0, CombatUnit.UnitType.MARAUDER: 0, CombatUnit.UnitType.TRAPPER: 0},
		"row_spacing": 90.0,
		"tactics": {},
	},
	# Counters an Archer-heavy enemy: both melee types resist Archer damage
	# (0.4x/0.6x, see DAMAGE_MULTIPLIERS) but only while actually fighting,
	# not while walking into range - the priority is closing distance fast
	# as one tight group rather than the usual wide front/back split, so the
	# whole line arrives together instead of the back rank trailing. Also
	# barely kites (tiny melee_avoid_radius) - against a ranged-heavy enemy
	# there's rarely a nearby enemy Shieldbearer/Marauder worth evading
	# anyway, and standing firm keeps the advance cohesive.
	{
		"id": "rush",
		"display_name": "Rush",
		"rank_depths": [380.0, 420.0],
		"rank_for_type": {CombatUnit.UnitType.SHIELDBEARER: 0, CombatUnit.UnitType.MARAUDER: 0, CombatUnit.UnitType.TRAPPER: 0},
		"row_spacing": 70.0,
		"tactics": {"melee_avoid_radius": 60.0},
	},
	# Counters a Shieldbearer/Marauder-heavy enemy: ranged units are the
	# ones actually weak/strong here (Archer weak to melee at 1.5x, but
	# Shieldbearer/Marauder resist Archer at 0.4x/0.6x - the archer's own
	# safety, not its damage output, is what's at stake), so hold them much
	# further back (wide rank gap) and kite more aggressively (larger
	# melee_avoid_radius) to stay out of melee reach longer. 200, not the
	# naive "as large as possible" - a real bug caught by observed play:
	# melee_avoid_radius above either ranged type's own attack_range
	# (Archer 260, Mage 220) leaves no "safe firing zone" where a unit is
	# far enough from a threat to stand its ground but still close enough
	# to shoot, so it never stops retreating long enough to actually
	# skirmish. 200 stays under both, so there's real room to fire before
	# evasion kicks in.
	{
		"id": "skirmish",
		"display_name": "Skirmish",
		"rank_depths": [380.0, 650.0],
		"rank_for_type": {CombatUnit.UnitType.SHIELDBEARER: 0, CombatUnit.UnitType.MARAUDER: 0, CombatUnit.UnitType.TRAPPER: 0},
		"row_spacing": 110.0,
		"tactics": {"melee_avoid_radius": 200.0},
	},
	# Counters a Mage-heavy enemy: inverts the usual melee-front/ranged-back
	# split, since Archers resist Magic (0.5x, DAMAGE_MULTIPLIERS[ARCHER][
	# MAGE]) while Shieldbearer is weak to it (1.7x - heavy armor conducts
	# magic, its single biggest weakness) - Archers/Mages hold the front,
	# the opposite of every other preset here. Marauder joins them at rank 0
	# too, unlike Shieldbearer: its light armor doesn't conduct magic at all
	# (1.0x, neutral, see DAMAGE_MULTIPLIERS), so it has nothing to fear
	# from the same threat Shieldbearer needs to hide from - only
	# Shieldbearer defaults to the back rank here. Lower melee_avoid_radius
	# since the front line is now expected to hold its ground like a tank,
	# not kite.
	{
		"id": "guard",
		"display_name": "Guard",
		"rank_depths": [380.0, 520.0],
		"rank_for_type": {CombatUnit.UnitType.ARCHER: 0, CombatUnit.UnitType.MAGE: 0, CombatUnit.UnitType.MARAUDER: 0},
		"row_spacing": 90.0,
		"tactics": {"melee_avoid_radius": 80.0},
	},
	# Counters a Shieldbearer- or Trapper-dominant enemy: unlike Guard above,
	# there's no reason for *our own* Shieldbearer to retreat here - neither
	# threat is a magic attacker, so our tank has nothing to hide from. The
	# actual goal (bring ranged units into contact with a magic-vulnerable
	# enemy Shieldbearer sooner, or simply hold ground instead of kiting from
	# a Trapper's slow) only needs ranged units brought closer, not the tank
	# sent back - Shieldbearer/Marauder/Trapper still hold the actual front
	# rank, unlike Guard's inverted layout, but Archer/Mage's own rank moves
	# up to 420 (tight, like Rush) instead of Line's 520. Added after a real
	# bug: StrategistAI originally reused Guard for this trigger too, which in
	# the "balanced" mirror matchup (both sides see the other as Shieldbearer-
	# dominant, so both switch to the same preset) sent both teams'
	# Shieldbearers to the back rank while their own Archers took the front
	# completely unprotected - reported as "Shieldbearers stuck behind the
	# archers."
	#
	# Originally a single combined rank (everyone at depth 380, empty
	# rank_for_type since with one rank every type already defaults there) -
	# reported as a second bug: Shieldbearers "running way out of position."
	# Traced to the single rank cramming an entire roster (all 6 units in the
	# "balanced" matchup) into one row at row_spacing 90 - a 450px-wide line
	# versus every other preset's ~180px (3 units per rank), so a unit at the
	# extreme end of that line had a formation slot nowhere near where the
	# actual fighting was happening. It also had a second, less visible
	# problem: with only one rank, Outrider (meant to default to the back
	# rank in every preset, unlisted here on purpose - see this file's own
	# top-level comment) had nowhere else to go and got pulled to the front
	# too. Splitting back into two properly-separated ranks (melee at 380,
	# ranged pulled up to 420 instead of Line's 520) fixes both at once: rank
	# width stays bounded to whatever's actually in each rank, and Outrider
	# reclaims its usual unlisted-defaults-to-the-back-rank behavior, same as
	# every other preset.
	{
		"id": "press",
		"display_name": "Press",
		"rank_depths": [380.0, 420.0],
		"rank_for_type": {CombatUnit.UnitType.SHIELDBEARER: 0, CombatUnit.UnitType.MARAUDER: 0, CombatUnit.UnitType.TRAPPER: 0},
		"row_spacing": 90.0,
		"tactics": {"melee_avoid_radius": 80.0},
	},
]


static func get_option(id: String) -> Dictionary:
	for option in OPTIONS:
		if option["id"] == id:
			return option
	return {}
