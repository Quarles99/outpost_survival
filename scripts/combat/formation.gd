extends Node2D
class_name Formation

## Dynamic anchor a team's units leash toward (see
## CombatUnit._apply_formation_pull) - replaces an earlier fixed-spawn-point
## leash, which could deadlock two units each leashed to their own
## far-apart, never-updating spawn point once the battle had drifted from
## where it started (confirmed via headless testing: 2 of 6 battles never
## resolved within 90s under that scheme). Also the thing a StrategistAI
## (scripts/combat/strategist_ai.gd) reconfigures via apply_preset() to
## switch a team's whole formation+tactics mid-battle - see
## Outpost_Survival/Ideas/Formation Strategy AI.md for the design.

var facing: float = 1.0
var rank_depths: Array = []
var rank_for_type: Dictionary = {}
var row_spacing: float = 90.0
## Read by CombatUnit._nearest_melee_threat() to override that type's
## default melee_avoid_radius - e.g. "Skirmish" wants far more evasive
## ranged units, "Guard" wants its front-line Archers holding ground
## instead. See FormationCatalog.
var tactics: Dictionary = {}
## Which FormationCatalog entry this is currently configured as - lets
## StrategistAI (and the UI) tell what's active without keeping a second
## copy of that state themselves.
var preset_id: String = ""
var play_bounds := Rect2()

## Shared Array reference, same pattern as CombatUnit.enemies -
## CombatTestManager points this at its own team_a/team_b array (only after
## _spawn_team returns a finished roster - assigning it earlier leaves this
## formation watching a stale empty array with no compile-time warning) so
## deaths are reflected for free via the same array CombatTestManager
## already prunes.
var living_units: Array = []

## Set once by CombatTestManager right after spawning - living_units
## shrinks as units die/escape, so this is the only place the team's
## original headcount survives, needed as the denominator below.
var original_roster_size := 0
## One-shot latch - once true, is_mass_routed() stops recomputing (a
## unit that later dies/escapes shouldn't somehow "un-rout" the team by
## shrinking living_units further and diluting the fraction back down).
var _mass_routed := false

## Fraction of a team lost (dead or already individually routing - see
## CombatUnit.ROUT_MORALE_THRESHOLD for that trigger) needed to break the
## rest of the army at once, per an explicit request: "if enough troops
## route it should trigger a full scale retreat and defeat." First-pass,
## not tuned via playtesting.
const MASS_ROUT_THRESHOLD := 0.5


## Checked by CombatTestManager every frame; true once MASS_ROUT_THRESHOLD
## has been crossed (see force_rout_all(), which CombatTestManager calls
## immediately after this returns true for the first time).
func is_mass_routed() -> bool:
	if _mass_routed or original_roster_size <= 0:
		return _mass_routed
	var routing_count := 0
	for u in living_units:
		var unit: CombatUnit = u
		if is_instance_valid(unit) and not unit._dead and unit._routing:
			routing_count += 1
	var dead_count := original_roster_size - living_units.size()
	var lost_fraction := float(dead_count + routing_count) / float(original_roster_size)
	if lost_fraction >= MASS_ROUT_THRESHOLD:
		_mass_routed = true
	return _mass_routed


## Breaks every still-fighting unit on this team at once - see
## CombatUnit.force_rout(). Idempotent (force_rout() itself guards against
## a unit that's already routing), so safe even if called more than once.
func force_rout_all() -> void:
	for u in living_units:
		var unit: CombatUnit = u
		if is_instance_valid(unit) and not unit._dead:
			unit.force_rout()


## Slowest current move speed among this team's still-approaching units -
## per an explicit request to keep the formation cohesive by having
## everyone advance at the slowest member's pace until they're actually
## given "the command to engage." There's no literal player command in
## this AI-driven sandbox, so that's mapped onto the natural equivalent:
## a unit stops being bound by the group's pace the moment it commits to
## any other behavior of its own (holding position to fight, fleeing a
## threat, an Outrider kiting a blocker, a Mage holding back, or routing) -
## engaging *is* effectively the command that releases it. Read by
## CombatUnit._process()'s approach branch (see CombatUnit.
## _uncapped_move_speed(), called here on every living, still-approaching
## teammate) - only applies while actually approaching a target, never to
## the emergency-speed behaviors above, which all need their full speed
## regardless of formation pace. Returns INF (no cap) if nothing
## currently qualifies as "still approaching" - a unit querying this
## always counts itself (it's in living_units and, by construction, in
## the approach branch when it calls this), so this never returns
## something faster than the caller's own speed.
func slowest_approach_speed() -> float:
	var slowest := INF
	for u in living_units:
		var unit: CombatUnit = u
		if not is_instance_valid(unit) or unit._dead:
			continue
		if unit._holding_position or unit._fleeing or unit._kiting_blocker or unit._holding_back or unit._routing:
			continue
		slowest = minf(slowest, unit._uncapped_move_speed())
	return slowest


func setup(preset: Dictionary, p_facing: float, p_play_bounds: Rect2 = Rect2()) -> void:
	facing = p_facing
	play_bounds = p_play_bounds
	_apply_layout(preset)


## Switches to a different preset mid-battle (StrategistAI's whole job) and
## reassigns every currently-living unit's slot_offset to match. Existing
## units aren't teleported to their new slot - each starts a
## CombatUnit.begin_slot_transition() glide from its current offset to the
## new one (see that function's own doc comment for why: an instant snap
## used to make the leash pull respond with a full-speed reversal the same
## frame a preset switched, which read as a frontline fighter bolting out
## of position for no reason even when the preset choice itself - e.g.
## Guard retreating a magic-vulnerable Shieldbearer from a Mage threat -
## was deliberate).
func apply_preset(preset: Dictionary) -> void:
	_apply_layout(preset)
	var alive: Array = living_units.filter(func(u): return is_instance_valid(u) and not (u as CombatUnit)._dead)
	var types: Array = alive.map(func(u): return (u as CombatUnit).unit_type)
	var offsets := assign_slots(types)
	for i in alive.size():
		(alive[i] as CombatUnit).begin_slot_transition(offsets[i])


func _apply_layout(preset: Dictionary) -> void:
	rank_depths = preset.get("rank_depths", [400.0])
	rank_for_type = preset.get("rank_for_type", {})
	row_spacing = preset.get("row_spacing", 90.0)
	tactics = preset.get("tactics", {})
	preset_id = preset.get("id", "")


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


## The anchor tracks its own team's living centroid every frame, rate-
## limited to ANCHOR_MAX_SPEED - no separate "advance toward the enemy"
## pull. An earlier version blended a fixed-speed advance with a drift cap
## relative to the centroid, and the two rules fought each other into a
## stable equilibrium well short of actual contact (confirmed via a
## headless trace: the anchor visibly advanced for a few seconds, then
## froze in place for the rest of a full 90s battle - zero deaths, because
## leash centers never moved that unit's targets stayed correct, but
## nothing could effectively pursue). Since individual units already path
## toward their own targets (see CombatUnit._process), the team's centroid
## naturally advances as a consequence of units engaging - no synthetic
## push needed on top of that. The rate limit added here is a different
## thing entirely, not a second competing rule: there's still exactly one
## target (the centroid) and the anchor always moves toward it, it just
## can't teleport there instantly - so this can't reproduce the old
## freeze (that came from two *different* target directions disagreeing).
##
## Reported directly as "melee units drifting apart from the formation and
## leading each other on wild goose chases," root-caused via headless
## instrumentation: _living_centroid()'s "steady" set (units not actively
## fleeing/kiting/leashing home/routing) legitimately shrinks to just 1-2
## members in Outrider-heavy rosters (Outrider spends much of a battle
## kiting blockers), and *which* one or two units happen to qualify as
## "steady" churns from frame to frame as different units briefly enter
## and exit those states - each such membership change swaps the average
## between two potentially very-far-apart positions instantly. Confirmed
## via a direct trace of the raw (pre-rate-limit) centroid in
## support_vs_outrider/archer_core_vs_melee_rush (both Outrider-heavy):
## anchor "speed" (position delta / frame delta) spiked as high as
## 37,898-73,436 units/second - a physical impossibility for any actual
## unit (the fastest type, Outrider, tops out around 300) - confirming
## these were snap discontinuities in the average, not real motion. Since
## every unit's own leash center is `formation.global_position +
## slot_offset` (or a ward's position for a guarding Trapper), each such
## teleport instantly relocated *every* unit's "home" - which is what
## visibly reads as the whole squad lurching after (or away from)
## wherever the anchor happened to jump to that frame. A hard snap to a
## noisy signal is the actual bug; ANCHOR_MAX_SPEED turns it into a
## bounded pursuit of that same signal instead, well above any speed the
## anchor needs for genuine tracking (bounded by member units' own speeds)
## but low enough that a single frame's discontinuity can't relocate
## everyone's leash center across the map. Verified headless: the same
## trace against the post-fix code showed zero >2000 units/sec spikes.
const ANCHOR_MAX_SPEED := 800.0

func _process(delta: float) -> void:
	var centroid = _living_centroid()
	if centroid != null:
		global_position = global_position.move_toward(centroid, ANCHOR_MAX_SPEED * delta)
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
## Units temporarily displaced from their formation slot for a legitimate
## tactical reason are also excluded from the average (falling back to
## every living unit only if the whole team happens to qualify at once) -
## an Archer/Mage fleeing a melee threat (_fleeing), an Outrider
## maneuvering around a blocker (_kiting_blocker), a Mage holding back
## from an Archer threat (_holding_back), a unit routing off the map
## entirely (_routing), or a unit its own leash is actively reeling back in
## (_leashing_home) shouldn't drag the rest of the team's leash anchor
## along with it.
##
## _leashing_home closes a real feedback loop reported directly as "melee
## units drifting apart from the formation and leading each other on wild
## goose chases": the other four flags only cover *special evasive*
## states, but an ordinary unit just approaching a target that happens to
## be far away (a kiting Outrider, a fleeing Archer) was never excluded -
## so as it drifted, this very centroid (which its own leash center is
## computed from, via CombatUnit._apply_formation_pull()) drifted right
## along with it, keeping that unit's own dist_from_slot artificially
## small and defeating FORMATION_LEASH_RANGE's entire point of reeling a
## unit back before it drags the fight away. Worse, once the anchor
## moved, *every other* unit's own leash center moved with it too, pulling
## them off their own slots toward the runaway unit's direction - the
## "leading each other" part. See CombatUnit._leashing_home's own doc
## comment for the full mechanism.
func _living_centroid() -> Variant:
	var alive: Array = living_units.filter(func(u): return is_instance_valid(u) and not (u as CombatUnit)._dead)
	if alive.is_empty():
		return null
	var steady: Array = alive.filter(func(u):
		var unit: CombatUnit = u
		return not (unit._fleeing or unit._kiting_blocker or unit._holding_back or unit._routing or unit._leashing_home)
	)
	var units: Array = steady if not steady.is_empty() else alive
	var sum := Vector2.ZERO
	for u in units:
		var unit: CombatUnit = u
		sum += unit.global_position - unit.slot_offset
	return sum / units.size()
