extends RefCounted
class_name SkillTitles

## Eleven job skills earn a title now - the original eight trades plus the
## three combat skills trained at a TrainingGround (Barracks/Archery Range/
## Mage Tower - see training_ground.gd) - speed/strength still train
## passively just by existing (see character.gd's doc comments on them)
## rather than representing a trade, so there's no natural "job noun" to
## pair a tier word with (compare SKILL_LABELS in skill_panel.gd, which does
## show all skills for the raw stats sheet). Being in TITLE_SKILLS is also
## what makes Base._job_posts()/_run_job_assignment treat a TrainingGround
## as a normal assignable post, same as any other job.
const TITLE_SKILLS := ["farming", "lumberjacking", "mining", "masonry", "milling", "baking", "brewing", "construction", "melee_combat", "archery", "spellcasting"]

const JOB_NOUNS := {
	"farming": "Farmer",
	"lumberjacking": "Lumberjack",
	"mining": "Miner",
	"masonry": "Mason",
	"milling": "Miller",
	"baking": "Baker",
	"brewing": "Brewer",
	"construction": "Builder",
	"melee_combat": "Soldier",
	"archery": "Archer",
	"spellcasting": "Mage",
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


## Every job skill, ranked by this citizen's own level in it, descending -
## used by Base._run_job_assignment as each citizen's ordered list of which
## post to try proposing to first. Ties (including the common "level 1 in
## everything" case for a brand-new citizen) are broken by TITLE_SKILLS'
## fixed order via a total-order comparator rather than relying on
## Array.sort_custom being stable (it isn't guaranteed to be in Godot) -
## deterministic regardless of engine sort implementation.
##
## Deliberately NOT grouping citizens by a single precomputed "best skill"
## before matching (an earlier design of this function did, and had a real
## bug): every fresh citizen ties at level 1 across all six skills, so a
## fixed tie-break would put literally everyone's "best skill" at
## TITLE_SKILLS[0] ("farming") - if the player's first building happens to
## be a Lumber Camp rather than a Farm, nobody would ever be eligible to
## work it, no matter how idle they are, since none of them would have
## "lumberjacking" as their nominal favorite. Returning a full ranked list
## instead lets the matching algorithm fall through to a citizen's 2nd,
## 3rd, etc. choice when their 1st has no room (or doesn't exist yet).
static func skill_preference_order(data: CharacterData) -> Array:
	var order := TITLE_SKILLS.duplicate()
	order.sort_custom(func(a: String, b: String) -> bool:
		var level_a: int = data.get_skill_level(a) if data else 1
		var level_b: int = data.get_skill_level(b) if data else 1
		if level_a != level_b:
			return level_a > level_b
		return TITLE_SKILLS.find(a) < TITLE_SKILLS.find(b)
	)
	return order
