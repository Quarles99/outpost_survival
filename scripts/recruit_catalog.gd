extends RefCounted
class_name RecruitCatalog

const RECRUIT_COST := {"food": 15.0}

const NAMES := [
	"Brom", "Ysolde", "Garrick", "Merida", "Torvald", "Elowen",
	"Caspian", "Rowena", "Duncan", "Wilhelmina", "Osric", "Freya",
]

## skill_id -> display label, for showing "Lv 5 Farming" etc. on cards.
## Every Farm-family building trains "farming" regardless of recipe (see
## Farm.get_skill_id()) - milling/baking/brewing used to be separate
## specializations here but were reverted to plain "farming" along with
## that - plus lumberjacking/mining, the other two trainable trades.
## Deliberately not "labor", the dead generic Workstation default.
const SPECIALIZATIONS := {
	"farming": "Farming",
	"lumberjacking": "Lumberjacking",
	"mining": "Mining",
}

## Starting level in a candidate's specialization - a meaningful head start
## over a fresh level-1 worker ("different starting skills" per the design
## doc) without being able to out-level what a citizen earns through play.
const STARTING_LEVEL := 5


## `count` candidates (distinct names where possible), each with a random
## specialization and a starting_xp amount ready to drop straight into a
## fresh CharacterData.skill_xp.
static func generate_candidates(count: int = 3) -> Array[Dictionary]:
	var names := NAMES.duplicate()
	names.shuffle()
	var skill_ids := SPECIALIZATIONS.keys()
	var starting_xp := SkillCurve.xp_for_level(STARTING_LEVEL)

	var out: Array[Dictionary] = []
	for i in count:
		var skill_id: String = skill_ids.pick_random()
		out.append({
			"name": names[i % names.size()],
			"skill_id": skill_id,
			"skill_label": SPECIALIZATIONS[skill_id],
			"starting_xp": starting_xp,
		})
	return out
