extends RefCounted
class_name RecruitCatalog

## Food tiers a recruit's cost/starting level scale with, ordered lowest to
## highest - deliberately its own list rather than reusing
## GameState.FOOD_RESOURCES (which is just a stable iteration order today,
## not a priority list - see its own doc comment). Mirrors the same
## cabbage -> potato -> fruit -> bread -> beer progression the hunger
## system's docs describe: cheap/direct crops first, harder-won refined
## goods (bread's 3-stage grain->flour->bread chain, beer's 2-stage
## hops->beer chain) last.
const FOOD_TIERS := ["cabbage", "potato", "fruit", "bread", "beer"]

## Cost in units of a single food type. A tier-T candidate costs this many
## units of EVERY food type at tier <= T (see _cost_for_tier), not just its
## own tier's food - "the higher level citizens should cost their
## particular food tier as well as an equal amount of all food from lower
## tiers", so a Grandmaster-tier recruit still keeps cabbage/potato/fruit
## relevant instead of obsoleting them the moment Bread/Ale come online.
## Raised 15.0 -> 20.0 via Outpost_Survival/Balance.md's edit-and-hand-back
## workflow.
const RECRUIT_UNIT_COST := 20.0

const NAMES := [
	"Brom", "Ysolde", "Garrick", "Merida", "Torvald", "Elowen",
	"Caspian", "Rowena", "Duncan", "Wilhelmina", "Osric", "Freya",
]

## skill_id -> display label, for showing "Lv 5 Farming" etc. on cards.
## Covers every skill a Farm-family Workstation can currently train (see
## farm.gd) plus lumberjacking/mining/masonry - deliberately not "labor",
## the dead generic Workstation default.
const SPECIALIZATIONS := {
	"farming": "Farming",
	"lumberjacking": "Lumberjacking",
	"mining": "Mining",
	"masonry": "Masonry",
	"milling": "Milling",
	"baking": "Baking",
	"brewing": "Brewing",
	"construction": "Construction",
}

## Starting level for a tier-0 (cabbage) candidate - a meaningful head
## start over a fresh level-1 worker ("different starting skills" per the
## design doc) without being able to out-level what a citizen earns
## through play. Each tier above that adds TIER_LEVEL_STEP more, so a
## tier-4 (beer/Ale) candidate starts at STARTING_LEVEL + 4*TIER_LEVEL_STEP.
## Both raised 5 -> 10 via Outpost_Survival/Balance.md's edit-and-hand-back
## workflow.
const STARTING_LEVEL := 10
const TIER_LEVEL_STEP := 10


## `count` candidates - distinct names AND distinct food tiers where
## possible (so the offered choice reads as an actual spread of cheap/
## common vs. expensive/rare, not 3 draws that might repeat the same
## tier) - each with a random specialization, a starting_xp amount ready
## to drop straight into a fresh CharacterData.skill_xp, and a `cost`
## Dictionary reflecting its tier (see _cost_for_tier).
static func generate_candidates(count: int = 3) -> Array[Dictionary]:
	var names := NAMES.duplicate()
	names.shuffle()
	var tiers := FOOD_TIERS.duplicate()
	tiers.shuffle()
	var skill_ids := SPECIALIZATIONS.keys()

	var out: Array[Dictionary] = []
	for i in count:
		var skill_id: String = skill_ids.pick_random()
		var tier_index := FOOD_TIERS.find(tiers[i % tiers.size()])
		var level := STARTING_LEVEL + tier_index * TIER_LEVEL_STEP
		out.append({
			"name": names[i % names.size()],
			"skill_id": skill_id,
			"skill_label": SPECIALIZATIONS[skill_id],
			"starting_xp": SkillCurve.xp_for_level(level),
			"level": level,
			"tier_food": FOOD_TIERS[tier_index],
			"cost": _cost_for_tier(tier_index),
		})
	return out


## Tier-T cost: RECRUIT_UNIT_COST of every food type at tier 0..T (its own
## tier's food plus an equal amount of every cheaper tier's food) - see
## RECRUIT_UNIT_COST's doc comment for why.
static func _cost_for_tier(tier_index: int) -> Dictionary:
	var cost := {}
	for i in tier_index + 1:
		cost[FOOD_TIERS[i]] = RECRUIT_UNIT_COST
	return cost


## A single fixed-skill candidate for a combat-training building's own
## additional recruit (see TrainingGround.clicked/can_recruit and
## Base._on_training_ground_clicked) - always tier-0 cost/level, unlike
## generate_candidates' random tier spread, since there's no "which food
## tier" choice for this recruit - just "do you want this building's
## specific combat skill or not." skill_id/skill_label come from the calling
## building (melee_combat/"Soldier", archery/"Archer", spellcasting/"Mage" -
## see SkillTitles.JOB_NOUNS, not duplicated into SPECIALIZATIONS above
## since combat skills aren't part of the normal Outpost Hall pool).
static func generate_combat_candidate(skill_id: String, skill_label: String) -> Dictionary:
	var names := NAMES.duplicate()
	names.shuffle()
	return {
		"name": names[0],
		"skill_id": skill_id,
		"skill_label": skill_label,
		"starting_xp": SkillCurve.xp_for_level(STARTING_LEVEL),
		"level": STARTING_LEVEL,
		"cost": _cost_for_tier(0),
	}
