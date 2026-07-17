extends RefCounted
class_name StrategistAI

## One instance per team, owned by CombatTestManager. Every RE_EVAL_INTERVAL
## seconds, tallies the enemy's living HP by unit type to find the dominant
## threat, and - if the switch cooldown has elapsed and the counter-pick
## actually differs from the team's current Formation preset - applies it.
## Rule-based counter-picking rather than a general scoring/utility AI: an
## explicit choice (see Outpost_Survival/Ideas/Formation Strategy AI.md) to
## keep this explainable/debuggable over a first pass - COUNTER_PRESET below
## is the entire "why" of every decision this makes, no hidden scoring.
## Full information: reads enemy_units directly rather than any kind of
## scouting/vision model, since this is a test sandbox for the AI's
## decision-making, not a fog-of-war simulation.

## First-pass, not tuned via playtesting. RE_EVAL_INTERVAL controls how
## often the AI reassesses at all; SWITCH_COOLDOWN separately gates actually
## switching once it decides to, so a composition estimate flickering near
## a decision boundary can't cause rapid back-and-forth thrashing.
const RE_EVAL_INTERVAL := 4.0
const SWITCH_COOLDOWN := 6.0

## Dominant-enemy-type -> the FormationCatalog preset that counters it - see
## that file's own comments for the DAMAGE_MULTIPLIERS-derived reasoning.
## Marauder inherits the old Swordsman-dominant mapping ("skirmish" - a
## genuine high-DPS melee threat that demands evasion, more true of
## Marauder than it ever was of the generic Swordsman it replaced).
## Shieldbearer gets its own: low damage and slow, so it isn't really a
## "kite it" threat the way Marauder is - what actually matters is its
## pronounced weakness to magic (1.7x, heaviest armor conducts it best),
## so "press" (Archer/Mage brought forward alongside the existing front
## line) puts our own ranged damage in early, frequent contact with the
## one thing it's specifically bad against. Deliberately "press," not
## "guard" - a real bug caught in the "balanced" mirror matchup: guard
## sends *our own* Shieldbearer to the back rank too (it exists to hide a
## magic-vulnerable tank from an enemy Mage threat, which isn't what's
## happening here), and since a mirror matchup has both sides seeing each
## other as Shieldbearer-dominant, both StrategistAIs picked the same
## preset and sent both teams' tanks to the back at once while their
## Archers took the front unprotected. "press" keeps Shieldbearer/Marauder
## in the front rank where they belong and just adds ranged units
## alongside them, with nothing sent backward.
## Outrider/Trapper aren't in the damage triangle at all (both flat 1.0
## everywhere), so their entries are reasoned from behavior instead: an
## Outrider-dominant enemy is fast but fragile and doesn't kite, so "rush"
## (close distance fast, minimize exposure to whatever else they're
## bringing) beats it in a straight fight; a Trapper-dominant enemy's whole
## threat is negating mobility-dependent play via the slow debuff, so
## "press" (low melee_avoid_radius, front line already holds ground rather
## than relying on kiting) sidesteps that threat instead of walking into
## it - same reasoning as the old "guard" mapping, but without that
## preset's unrelated (and here counterproductive) tank retreat.
## None of these are deeply tested/tuned yet.
const COUNTER_PRESET := {
	CombatUnit.UnitType.SHIELDBEARER: "press",
	CombatUnit.UnitType.MARAUDER: "skirmish",
	CombatUnit.UnitType.ARCHER: "rush",
	CombatUnit.UnitType.MAGE: "guard",
	CombatUnit.UnitType.OUTRIDER: "rush",
	CombatUnit.UnitType.TRAPPER: "press",
}
## Used when the enemy has no living units left to react to, or (not
## currently reachable, since "dominant by HP" always picks some type when
## any enemy is alive) a genuinely even split - kept as an explicit fallback
## rather than leaving the formation on whatever it last happened to be.
const DEFAULT_PRESET := "line"

var formation: Formation
var enemy_units: Array
var _time_since_eval := 0.0
var _time_since_switch := 0.0


func _init(p_formation: Formation, p_enemy_units: Array) -> void:
	formation = p_formation
	enemy_units = p_enemy_units
	_time_since_switch = SWITCH_COOLDOWN # allow an immediate first decision


func update(delta: float) -> void:
	_time_since_eval += delta
	_time_since_switch += delta
	if _time_since_eval < RE_EVAL_INTERVAL:
		return
	_time_since_eval = 0.0

	var desired := _decide()
	if desired == formation.preset_id or _time_since_switch < SWITCH_COOLDOWN:
		return
	var preset := FormationCatalog.get_option(desired)
	if preset.is_empty():
		return
	formation.apply_preset(preset)
	_time_since_switch = 0.0


## Dominant type = highest total remaining HP among living enemies of that
## type, not raw count - a type that's mostly dead shouldn't still be
## treated as the main threat just because a couple of husks are left.
func _decide() -> String:
	var hp_by_type := {}
	for u in enemy_units:
		var unit: CombatUnit = u
		if not is_instance_valid(unit) or unit._dead:
			continue
		hp_by_type[unit.unit_type] = hp_by_type.get(unit.unit_type, 0.0) + unit.health
	if hp_by_type.is_empty():
		return formation.preset_id if formation.preset_id != "" else DEFAULT_PRESET

	var dominant_type = null
	var dominant_hp := -1.0
	for unit_type in hp_by_type:
		if hp_by_type[unit_type] > dominant_hp:
			dominant_hp = hp_by_type[unit_type]
			dominant_type = unit_type
	return COUNTER_PRESET.get(dominant_type, DEFAULT_PRESET)
