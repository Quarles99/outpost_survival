extends Node2D
class_name Formation

## Dynamic anchor a team's units leash toward (see
## CombatUnit._apply_formation_pull) - replaces an earlier fixed-spawn-point
## leash, which could deadlock two units each leashed to their own
## far-apart, never-updating spawn point once the battle had drifted from
## where it started (confirmed via headless testing: 2 of 6 battles never
## resolved within 90s under that scheme). First pass: only a single static
## "Line" preset (see FormationCatalog) - dynamic formation/tactic
## *selection* by any kind of higher-level strategist AI, and tactics like
## kiting living on the formation rather than the unit type, are
## deliberately deferred ideas - see
## Outpost_Survival/Ideas/Formation Strategy AI.md.

var facing: float = 1.0
var rank_depths: Array = []
var rank_for_type: Dictionary = {}
var row_spacing: float = 90.0
## Copied from the preset, not read by anything yet - extension point for a
## future formation-level tactics system (e.g. kiting aggressiveness).
var tactics: Dictionary = {}
var play_bounds := Rect2()

## Shared Array reference, same pattern as CombatUnit.enemies -
## CombatTestManager points this at its own team_a/team_b array (only after
## _spawn_team returns a finished roster - assigning it earlier leaves this
## formation watching a stale empty array with no compile-time warning) so
## deaths are reflected for free via the same array CombatTestManager
## already prunes.
var living_units: Array = []


func setup(preset: Dictionary, p_facing: float, p_play_bounds: Rect2 = Rect2()) -> void:
	facing = p_facing
	rank_depths = preset.get("rank_depths", [400.0])
	rank_for_type = preset.get("rank_for_type", {})
	row_spacing = preset.get("row_spacing", 90.0)
	tactics = preset.get("tactics", {})
	play_bounds = p_play_bounds


## Returns local offsets (relative to this Formation's own position)
## parallel to `roster`, grouping by rank (rank_for_type, defaulting unlisted
## types to the last/deepest rank) and centering each rank's own row via
## row_spacing - generalizes the two-rank front/back math this replaced
## (CombatTestManager's old _spawn_rank) over an arbitrary number of ranks.
func assign_slots(roster: Array) -> Array:
	var by_rank: Array = []
	for _i in rank_depths.size():
		by_rank.append([])
	for i in roster.size():
		var unit_type = roster[i]
		var rank: int = rank_for_type.get(unit_type, rank_depths.size() - 1)
		by_rank[rank].append(i)

	var offsets: Array = []
	offsets.resize(roster.size())
	for rank in rank_depths.size():
		var indices: Array = by_rank[rank]
		var row_offset := (indices.size() - 1) / 2.0
		for j in indices.size():
			var roster_index: int = indices[j]
			offsets[roster_index] = Vector2(facing * rank_depths[rank], (j - row_offset) * row_spacing)
	return offsets


## The anchor directly tracks its own team's living centroid every frame -
## no separate "advance toward the enemy" pull. An earlier version blended
## a fixed-speed advance with a drift cap relative to the centroid, and the
## two rules fought each other into a stable equilibrium well short of
## actual contact (confirmed via a headless trace: the anchor visibly
## advanced for a few seconds, then froze in place for the rest of a full
## 90s battle - zero deaths, because leash centers never moved that unit's
## targets stayed correct, but nothing could effectively pursue). Since
## individual units already path toward their own targets (see
## CombatUnit._process), the team's centroid naturally advances as a
## consequence of units engaging - no synthetic push needed on top of that,
## and no risk of two rules disagreeing about where the anchor should be.
func _process(_delta: float) -> void:
	var centroid = _living_centroid()
	if centroid != null:
		global_position = centroid
	if play_bounds.size != Vector2.ZERO:
		global_position = global_position.clamp(play_bounds.position, play_bounds.end)


## Averages (position - slot_offset), not raw position - a real bug caught
## via a headless trace: averaging raw positions conflates two different
## reference points. slot_offset assumes the formation's own position is a
## center both ranks sit relative to, but a raw average of unit positions
## in an asymmetric formation (3 units at depth 380, 3 at depth 520) sits
## at the *weighted* depth (450), not 0 - so a perfectly-formed team's own
## raw centroid was never actually at the point its own slot offsets were
## computed relative to. That mismatch showed up as every unit's leash
## center jumping ~450px off on the very first frame, then compounding:
## the anchor visibly ran away in a straight line for the length of an
## entire 8s trace instead of tracking the team. Subtracting each unit's
## own slot_offset before averaging "undoes" its individual placement
## first, so a perfectly-formed team's centroid lands exactly back on the
## formation's own position, matching what assign_slots() assumed.
##
## Fleeing units are also deliberately excluded from the average (falling
## back to every living unit only if the whole team happens to be fleeing
## at once) - an Archer/Mage legitimately kiting away from a melee threat
## shouldn't drag the rest of the team's leash anchor with it.
func _living_centroid() -> Variant:
	var alive: Array = living_units.filter(func(u): return is_instance_valid(u) and not (u as CombatUnit)._dead)
	if alive.is_empty():
		return null
	var steady: Array = alive.filter(func(u): return not (u as CombatUnit)._fleeing)
	var units: Array = steady if not steady.is_empty() else alive
	var sum := Vector2.ZERO
	for u in units:
		var unit: CombatUnit = u
		sum += unit.global_position - unit.slot_offset
	return sum / units.size()
