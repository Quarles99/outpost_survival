extends RefCounted
class_name SkillTitles

## Only the six job skills earn a title - speed/strength train passively
## just by existing (see character.gd's doc comments on them) rather than
## representing a trade, so there's no natural "job noun" to pair a tier
## word with (compare SKILL_LABELS in skill_panel.gd, which does show all
## eight for the raw stats sheet).
const TITLE_SKILLS := ["farming", "lumberjacking", "mining", "milling", "baking", "brewing"]

const JOB_NOUNS := {
	"farming": "Farmer",
	"lumberjacking": "Lumberjack",
	"mining": "Miner",
	"milling": "Miller",
	"baking": "Baker",
	"brewing": "Brewer",
}

## [min_level, tier name] pairs, ascending - level 99 (SkillCurve.MAX_LEVEL)
## is deliberately its own top tier rather than folded into Grandmaster, so
## "Legendary" stays a genuine, rare payoff for the full many-hundred-hour
## grind rather than something reached well before the cap.
const TIER_THRESHOLDS := [
	[1, "Apprentice"],
	[25, "Journeyman"],
	[50, "Master"],
	[75, "Grandmaster"],
	[99, "Legendary"],
]


## The one active title: tier word (by whichever job skill this citizen has
## trained highest) + that skill's job noun, e.g. "Master Lumberjack". Ties
## at the same max level go to `current_skill_id` if it's one of the tied
## skills - the same as CLAUDE.md's Farm/LumberCamp duck-typing spirit,
## "the skill matching what they're doing right now" is the only tiebreak
## that means anything to the player watching them work. A fresh citizen
## with nothing trained yet (every skill at level 1) still gets "Apprentice
## <first skill>" - a deliberate baseline flavor title, not a special case
## to hide the title system entirely - so no title-less citizens exist.
static func get_title(data: CharacterData, current_skill_id: String) -> String:
	var best_level := -1
	var best_skill: String = TITLE_SKILLS[0]
	for skill_id in TITLE_SKILLS:
		var level: int = data.get_skill_level(skill_id) if data else 1
		if level > best_level or (level == best_level and skill_id == current_skill_id):
			best_level = level
			best_skill = skill_id
	return "%s %s" % [_tier_for_level(best_level), JOB_NOUNS[best_skill]]


static func _tier_for_level(level: int) -> String:
	var tier: String = TIER_THRESHOLDS[0][1]
	for entry in TIER_THRESHOLDS:
		if level >= entry[0]:
			tier = entry[1]
	return tier
