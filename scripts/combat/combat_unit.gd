extends Node2D
class_name CombatUnit

## Standalone combat-sandbox actor (see scenes/combat/CombatTest.tscn) - not
## wired into Character/the job-assignment system yet. Per Outpost_Survival/
## Ideas/Combat Units.md, the real design is citizens training a combat
## skill at a job post the same as any other trade; this class exists to
## prototype targeting/damage/kiting feel in isolation before that
## integration happens, so its stats/logic are expected to migrate into a
## Character work loop later rather than stay a separate class forever.

signal died(unit: CombatUnit)

enum UnitType { SWORDSMAN, ARCHER, MAGE, OUTRIDER, TRAPPER }
enum Team { A, B }

const TYPE_NAMES := {
	UnitType.SWORDSMAN: "Swordsman",
	UnitType.ARCHER: "Archer",
	UnitType.MAGE: "Mage",
	UnitType.OUTRIDER: "Outrider",
	UnitType.TRAPPER: "Trapper",
}

## First-pass stats, not tuned via playtesting - see Ideas/Combat Units.md
## for the qualitative traits these are meant to express (tough melee
## blocker, high-damage kiting archer, fragile-but-punishing kiting mage).
## melee_avoid_radius is only read for units with avoids_melee = true - a
## nearby enemy Swordsman inside that radius makes the unit retreat instead
## of attacking that tick (see _process). Outrider and Trapper both have
## avoids_melee = false despite being fragile-ish - both are melee-range
## themselves (can't attack at all without being in melee anyway, so
## fleeing would just mean never landing a hit - the exact "no safe firing
## zone" trap the Skirmish preset's melee_avoid_radius bug fell into for
## ranged units) and their whole design is built around aggressively
## closing distance, not evading.
const STATS := {
	UnitType.SWORDSMAN: {
		"health": 120.0, "damage": 12.0, "attack_range": 45.0,
		"attack_interval": 1.0, "move_speed": 150.0, "ranged": false,
		"avoids_melee": false, "melee_avoid_radius": 0.0,
	},
	UnitType.ARCHER: {
		"health": 70.0, "damage": 16.0, "attack_range": 260.0,
		"attack_interval": 1.2, "move_speed": 170.0, "ranged": true,
		"avoids_melee": true, "melee_avoid_radius": 150.0,
	},
	UnitType.MAGE: {
		"health": 55.0, "damage": 14.0, "attack_range": 220.0,
		"attack_interval": 1.5, "move_speed": 140.0, "ranged": true,
		"avoids_melee": true, "melee_avoid_radius": 170.0,
	},
	## Pure-mobility counter to kiting Archers/Mages: fast enough (200) to
	## outrun both outright (170/140) with no bonus damage or resistances
	## at all - the whole answer to "my melee can't catch archers" is
	## literally catching them, nothing else. Fragile (80 HP, no defensive
	## edge) so it loses a straight fight to a Swordsman if it's forced
	## into one.
	UnitType.OUTRIDER: {
		"health": 80.0, "damage": 10.0, "attack_range": 45.0,
		"attack_interval": 0.8, "move_speed": 200.0, "ranged": false,
		"avoids_melee": false, "melee_avoid_radius": 0.0,
	},
	## Counter to fast movers (Outrider specifically, but the slow applies
	## to anything it hits) - see SLOW_MULTIPLIER/SLOW_DURATION and _attack().
	## No bonus damage or resistances either; its counter-play is entirely
	## the debuff, not the damage triangle.
	UnitType.TRAPPER: {
		"health": 100.0, "damage": 9.0, "attack_range": 60.0,
		"attack_interval": 1.1, "move_speed": 130.0, "ranged": false,
		"avoids_melee": false, "melee_avoid_radius": 0.0,
	},
}

## Role behavior: target selection is a weighted score, not a strict ordered
## list (target_priority, removed) - the old approach couldn't express
## "prefer whoever's wounded" or "defend my ward" without special-casing,
## both of which the role system below needs. See _score_target().
##
## attacker type -> defender type -> preference bonus. Replaces the old
## ordered target_priority lists with equivalent (or richer) weighted
## preferences - e.g. Archer's old [Mage, Archer, Swordsman] tiers become
## descending bonuses here, plus new entries for Outrider/Trapper that
## didn't exist when target_priority was ordered-list-only. Swordsman stays
## empty (no type preference at all) - it holds the line and fights
## whoever's in front of it, not a specific type.
const TYPE_PREFERENCE := {
	UnitType.SWORDSMAN: {},
	UnitType.ARCHER: {
		UnitType.MAGE: 100.0, UnitType.OUTRIDER: 80.0, UnitType.ARCHER: 60.0,
		UnitType.TRAPPER: 50.0, UnitType.SWORDSMAN: 20.0,
	},
	UnitType.MAGE: {
		UnitType.SWORDSMAN: 100.0, UnitType.OUTRIDER: 50.0, UnitType.ARCHER: 40.0,
		UnitType.TRAPPER: 40.0, UnitType.MAGE: 20.0,
	},
	UnitType.OUTRIDER: {
		UnitType.ARCHER: 100.0, UnitType.MAGE: 60.0, UnitType.TRAPPER: 30.0,
		UnitType.SWORDSMAN: 10.0, UnitType.OUTRIDER: 20.0,
	},
	UnitType.TRAPPER: {
		UnitType.OUTRIDER: 90.0, UnitType.ARCHER: 40.0, UnitType.MAGE: 40.0,
		UnitType.SWORDSMAN: 20.0, UnitType.TRAPPER: 20.0,
	},
}

## Bonus per point of "how wounded" a candidate target is (0 at full health,
## WOUNDED_WEIGHT at 0 health) - "consistent DPS to squishy targets" reads
## as focus-firing already-wounded enemies to secure kills rather than
## spreading damage, applies to every role (not just Archer) since it's
## generally good behavior. Deliberately smaller than a typical
## TYPE_PREFERENCE gap so it nudges rather than overrides type preference.
const WOUNDED_WEIGHT := 40.0
## Added when a candidate is near this unit's `ward` (see _update_ward()) -
## deliberately the largest single term, so a Trapper reliably peels onto
## whatever's actually threatening its ward rather than a preferred-type
## enemy standing safely elsewhere. Falls off smoothly to 0 at
## WARD_THREAT_RADIUS rather than a hard cutoff.
const WARD_THREAT_WEIGHT := 120.0
const WARD_THREAT_RADIUS := 220.0
## Small tiebreaker so "no other reason to prefer A over B" falls back to
## nearest, without letting distance alone override a real type/wounded/
## ward preference for a far-but-juicier target.
const DISTANCE_WEIGHT := 0.05

## How often a Trapper reconsiders which ally it's guarding (see
## _update_ward()) - dynamic/periodic rather than assigned once, so it
## follows whichever ally is actually in danger as the battle shifts,
## rather than committing to one ward for the whole fight regardless of
## where the real threat moves.
const WARD_REEVAL_INTERVAL := 3.0
## Where a Trapper leashes to when it has a ward - just behind/beside them,
## not exactly overlapping.
const WARD_OFFSET := Vector2(0.0, 40.0)
## See _ward_score() - deliberately larger than any possible danger-score
## gap (bounded by the map's own diagonal, ~2800px) so spreading coverage
## across every available ward always wins over concentrating it,
## regardless of relative danger.
const WARD_COVERAGE_PENALTY := 5000.0

## Per-role multiplier on FORMATION_LEASH_RANGE. Swordsman "holds the line"
## - a noticeably tighter leash than the baseline so it won't wander far
## chasing a kill. Outrider is the opposite: its whole job is intentionally
## breaking formation cohesion to run down a specific enemy Archer, so it
## gets a much looser leash instead of being exempted from one entirely -
## still can't literally run to the map edge chasing something forever
## (see Combat System.md's "runs to the edge" history), just has far more
## room than everyone else before being reeled back.
const LEASH_MULTIPLIER := {
	UnitType.SWORDSMAN: 0.6,
	UnitType.ARCHER: 1.0,
	UnitType.MAGE: 1.0,
	UnitType.OUTRIDER: 2.0,
	UnitType.TRAPPER: 1.0,
}

## Applied by a Trapper's attack (see _attack()) to whatever it hits -
## overwrites rather than stacks on repeated hits (no duration-refresh or
## multiplicative-stacking logic), the simplest version that still directly
## negates a fast mover's whole advantage. First-pass numbers.
const SLOW_MULTIPLIER := 0.5
const SLOW_DURATION := 2.0

## defender type -> attacker type -> incoming damage multiplier. Encodes
## every resistance/weakness pair from Ideas/Combat Units.md directly
## (Swordsman resistant to Archer/weak to Mage, Archer resistant to
## Mage/weak to Swordsman, Mage weak to both and its own "strong vs melee"
## trait is just the Swordsman row's weakness restated from the attacker's
## side) rather than deriving it at runtime from separate resistance lists.
## Outrider/Trapper are both flat 1.0 in every direction, including against
## each other - both were explicitly designed to win through mobility/
## crowd-control instead of the damage triangle, not to be a 4th/5th
## faction in it.
const DAMAGE_MULTIPLIERS := {
	UnitType.SWORDSMAN: {UnitType.SWORDSMAN: 1.0, UnitType.ARCHER: 0.5, UnitType.MAGE: 1.5, UnitType.OUTRIDER: 1.0, UnitType.TRAPPER: 1.0},
	UnitType.ARCHER: {UnitType.SWORDSMAN: 1.5, UnitType.ARCHER: 1.0, UnitType.MAGE: 0.5, UnitType.OUTRIDER: 1.0, UnitType.TRAPPER: 1.0},
	UnitType.MAGE: {UnitType.SWORDSMAN: 1.5, UnitType.ARCHER: 1.5, UnitType.MAGE: 0.5, UnitType.OUTRIDER: 1.0, UnitType.TRAPPER: 1.0},
	UnitType.OUTRIDER: {UnitType.SWORDSMAN: 1.0, UnitType.ARCHER: 1.0, UnitType.MAGE: 1.0, UnitType.OUTRIDER: 1.0, UnitType.TRAPPER: 1.0},
	UnitType.TRAPPER: {UnitType.SWORDSMAN: 1.0, UnitType.ARCHER: 1.0, UnitType.MAGE: 1.0, UnitType.OUTRIDER: 1.0, UnitType.TRAPPER: 1.0},
}

const TEAM_COLORS := {
	Team.A: Color(0.35, 0.55, 1.0),
	Team.B: Color(1.0, 0.4, 0.35),
}

## Rough "how much army is this worth" cost, derived from STATS rather than
## a separate hardcoded number so it can't drift out of sync with the stats
## it's describing - health * damage-per-second. A first-pass heuristic for
## hand-authoring asymmetric-but-comparable test rosters (see
## CombatTestManager's matchups), not a perfectly balanced economy - it
## deliberately ignores matchup-dependent value (DAMAGE_MULTIPLIERS), attack
## range, or move speed, since those are exactly the factors a composition
## counter-pick is supposed to exploit, not average away.
static func point_cost(unit_type: UnitType) -> float:
	var stats: Dictionary = STATS[unit_type]
	return float(stats["health"]) * float(stats["damage"]) / float(stats["attack_interval"])

## Collision radius fed to NavigationAgent2D's avoidance (RVO) simulation -
## same for every type, first pass, roughly matching the character token's
## visual footprint.
const UNIT_RADIUS := 22.0

## Distance from this unit's Formation slot at which the return-to-formation
## pull (see _apply_formation_pull) fully dominates combat intent - not a
## hard wall, a saturation point for a smooth gradient. Loose enough to
## cover a normal frontal engagement (teams start 760px apart at the front
## rank, see FormationCatalog's "line" preset - two units pulled back at 550
## each can still close a 760px gap with room to spare) but tight enough
## that a unit chasing something faster than itself all the way across the
## map gets reeled back in well before it, rather than dragging the fight to
## the map edge.
const FORMATION_LEASH_RANGE := 550.0

var unit_type: UnitType
var team: Team
## Live roster of the opposing team - a shared Array reference owned by
## CombatTestManager, which removes a unit from it (via the died signal)
## rather than this class querying the scene tree/groups itself.
var enemies: Array = []

var max_health: float
var health: float
var _attack_cooldown := 0.0
var _target: CombatUnit = null
var _dead := false
## The delta passed to the _process() call that most recently called
## nav_agent.set_velocity() - avoidance computes asynchronously, so
## _on_velocity_computed() needs a delta from whenever it eventually fires,
## not necessarily the current frame's.
var _delta := 0.0
## True whenever this unit is in range of _target with nothing to evade -
## see _process()'s "stand and fight" branch. Read by _on_velocity_computed()
## to hold ground instead of applying avoidance's suggested nudge.
var _holding_position := false
## True whenever this unit is actively kiting away from a melee threat -
## read by Formation._living_centroid() so a legitimately-retreating Archer/
## Mage doesn't drag its whole team's leash anchor backward with it (a real
## bug: including fleeing units in the centroid created a feedback loop
## where kiting dragged the anchor back, which pulled every other unit's
## leash back too, compounding into the whole team retreating).
var _fleeing := false
## 1.0 = no slow. Set by take_damage_from_trapper-equivalent logic in
## _attack() when hit by a Trapper (see SLOW_MULTIPLIER/SLOW_DURATION);
## counts down and resets to 1.0 in _process(). Applied everywhere
## STATS.move_speed would otherwise be read directly (combat_velocity,
## the formation-pull's own return velocity, and nav_agent.max_speed) so a
## slowed unit is actually slower in every context, not just some of them.
var _speed_multiplier := 1.0
var _speed_debuff_timer := 0.0
## Hard clamp applied after every avoidance-driven move - RVO avoidance
## isn't aware of the navmesh's own bounds (it only reasons about nearby
## agents, not terrain), so heavy crowding at the initial engagement can
## genuinely push a unit's "safe velocity" outward for several frames in a
## row with nothing to stop it walking clean off the map. Set by
## CombatTestManager to its own NAV_BOUNDS, inset by this unit's radius.
var play_bounds := Rect2()
## This unit's team formation and its assigned slot offset within it (both
## set by CombatTestManager in setup()) - see _apply_formation_pull(). The
## slot is relative to the Formation's own (dynamic) position, not a fixed
## world point.
var formation: Formation = null
var slot_offset := Vector2.ZERO
## Only meaningfully used by Trapper (see _update_ward()) - the ally this
## unit is currently protecting. When set, _apply_formation_pull() leashes
## to the ward's live position instead of the static formation slot.
var ward: CombatUnit = null
var _ward_reeval_timer := 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var name_label: Label = $NameLabel
@onready var health_bar_bg: ColorRect = $HealthBarBg
@onready var health_bar_fill: ColorRect = $HealthBarFill
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D


func setup(p_unit_type: UnitType, p_team: Team, p_enemies: Array, p_play_bounds: Rect2 = Rect2(), p_formation: Formation = null, p_slot_offset: Vector2 = Vector2.ZERO) -> void:
	unit_type = p_unit_type
	team = p_team
	enemies = p_enemies
	play_bounds = p_play_bounds
	formation = p_formation
	slot_offset = p_slot_offset
	var stats: Dictionary = STATS[unit_type]
	max_health = stats["health"]
	health = max_health
	name_label.text = TYPE_NAMES[unit_type]
	name_label.add_theme_color_override("font_color", TEAM_COLORS[team])
	sprite.modulate = TEAM_COLORS[team]
	_update_health_bar()

	nav_agent.radius = UNIT_RADIUS
	nav_agent.max_speed = stats["move_speed"]
	nav_agent.avoidance_enabled = true
	# Defaults (neighbor_distance 500, time_horizon_agents ~20s) are tuned
	# for large crowds reacting to far-off traffic; with only ~12 units
	# total, that made every unit factor in nearly the whole battle as
	# "nearby," producing wide preemptive detours instead of tight,
	# local dodges - a real contributor to combat reading as sluggish.
	nav_agent.neighbor_distance = 200.0
	nav_agent.time_horizon_agents = 2.0
	nav_agent.velocity_computed.connect(_on_velocity_computed)


func _process(delta: float) -> void:
	if _dead:
		return
	_delta = delta
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)

	if _speed_debuff_timer > 0.0:
		_speed_debuff_timer -= delta
		if _speed_debuff_timer <= 0.0:
			_speed_multiplier = 1.0

	if unit_type == UnitType.TRAPPER:
		_ward_reeval_timer -= delta
		if _ward_reeval_timer <= 0.0 or not is_instance_valid(ward) or ward._dead:
			_ward_reeval_timer = WARD_REEVAL_INTERVAL
			_update_ward()

	if not is_instance_valid(_target) or (_target as CombatUnit)._dead:
		_retarget()
	if not is_instance_valid(_target):
		_holding_position = false
		_fleeing = false
		nav_agent.set_velocity(Vector2.ZERO)
		return

	var stats: Dictionary = STATS[unit_type]
	var effective_speed: float = float(stats["move_speed"]) * _speed_multiplier
	nav_agent.max_speed = effective_speed
	var to_target: Vector2 = _target.global_position - global_position
	var dist := to_target.length()
	var threat: CombatUnit = _nearest_melee_threat() if stats["avoids_melee"] else null

	# combat_velocity is this unit's raw combat intent - actual routing
	# around other units (including a threat this unit is fleeing, or an
	# ally standing in the way while approaching) is NavigationAgent2D's
	# avoidance (RVO) simulation's job, not this branch's. That split is
	# what fixed archers/mages getting stuck: fleeing is a full-speed,
	# straight-line retreat (no more hand-rolled "curve toward the target"
	# blend diluting the escape speed below the pursuer's own speed - see
	# git history for that earlier, insufficient fix), and the routing
	# around whatever's actually in the way happens for free via avoidance.
	var combat_velocity := Vector2.ZERO
	_holding_position = false
	_fleeing = false
	if threat:
		_fleeing = true
		combat_velocity = (global_position - threat.global_position).normalized() * effective_speed
	elif dist > float(stats["attack_range"]):
		nav_agent.target_position = _target.global_position
		var next_pos := nav_agent.get_next_path_position()
		var dir := next_pos - global_position
		if dir.length_squared() > 0.0001:
			combat_velocity = dir.normalized() * effective_speed
	else:
		# In range and no threat to evade - hold the line and finish this
		# target rather than drift. A zero *preferred* velocity alone isn't
		# enough: RVO still treats separation from crowded neighbors as a
		# hard constraint, not just this unit's own preference, so a
		# unit standing still mid-fight could still get physically jostled
		# by everyone else's avoidance around it. _holding_position tells
		# _on_velocity_computed() to ignore whatever avoidance computes and
		# not move this frame - engaged units still register their
		# (stationary) presence via set_velocity() below, so they remain a
		# proper obstacle for everyone else's avoidance, they just can't be
		# pushed around by it themselves anymore.
		_face(to_target)
		_holding_position = true

	if _holding_position:
		nav_agent.set_velocity(Vector2.ZERO)
	else:
		var desired_velocity := _apply_formation_pull(combat_velocity, effective_speed)
		if desired_velocity.length_squared() > 0.0001:
			_face(desired_velocity.normalized())
		nav_agent.set_velocity(desired_velocity)

	# Attacking is independent of the movement branch above - a kiting or
	# avoidance-deflected unit still fires if its target happens to be in
	# range that tick (hit-and-run), rather than every retreat costing it
	# the whole tick's damage.
	if dist <= float(stats["attack_range"]) and _attack_cooldown <= 0.0:
		_attack(_target)
		_attack_cooldown = float(stats["attack_interval"])


## NavigationAgent2D avoidance computes off-thread - set_velocity() doesn't
## move the unit itself, this signal (fired once the safe/collision-adjusted
## velocity is ready, using whichever _process's delta was current at the
## time) is what actually does.
func _on_velocity_computed(safe_velocity: Vector2) -> void:
	if _holding_position:
		return
	global_position += safe_velocity * _delta
	if play_bounds.size != Vector2.ZERO:
		global_position = global_position.clamp(play_bounds.position, play_bounds.end)


## Blends combat_velocity with a pull back toward this unit's leash center,
## weighted by how far it's already drifted - a smooth gradient, not a hard
## clamp (an earlier version hard-clamped position to a fixed radius around
## the unit's own static spawn point, which caused real deadlocks: two units
## each leashed to their own far-apart, never-updating point could end up
## with no reachable overlap once the battle drifted from where it started -
## see Formation, whose whole job is being a leash center that moves with
## the battle instead). At dist_from_slot >= this role's own leash range the
## pull fully dominates (weight 1.0); below that it's a proportional mix, so
## a unit chasing something can still drift meaningfully off its slot
## without a sudden snap back the instant it crosses some threshold.
##
## The leash center itself is role-dependent: a Trapper with a live ward
## leashes to the ward's own current position (WARD_OFFSET beside it)
## instead of a fixed formation slot, so it actually follows its charge
## around rather than sitting in a static spot. Everyone else (and a
## ward-less Trapper) uses the usual formation-slot center.
func _apply_formation_pull(combat_velocity: Vector2, speed: float) -> Vector2:
	if not is_instance_valid(formation):
		return combat_velocity
	var leash_center: Vector2
	if is_instance_valid(ward):
		leash_center = ward.global_position + WARD_OFFSET
	else:
		leash_center = formation.global_position + slot_offset
	if play_bounds.size != Vector2.ZERO:
		leash_center = leash_center.clamp(play_bounds.position, play_bounds.end)
	var offset := global_position - leash_center
	var dist_from_slot := offset.length()
	if dist_from_slot < 0.001:
		return combat_velocity
	var leash_range := FORMATION_LEASH_RANGE * float(LEASH_MULTIPLIER.get(unit_type, 1.0))
	var pull_weight := clampf(dist_from_slot / leash_range, 0.0, 1.0)
	if pull_weight <= 0.0:
		return combat_velocity
	var return_velocity := (-offset / dist_from_slot) * speed
	return combat_velocity.lerp(return_velocity, pull_weight)


func _face(dir: Vector2) -> void:
	if absf(dir.x) > 0.01:
		sprite.flip_h = dir.x < 0.0


## Deliberately never reassigns `enemies` itself - it's the exact same Array
## object CombatTestManager holds as team_a/team_b and prunes on death, so
## every unit on a side sees deaths on the other side for free. Filtering
## into a new Array here (as an earlier version of this function did) would
## silently detach this unit's view from that shared array, leaving stale
## freed-object references behind for _nearest_melee_threat() to crash on
## later - caught via the headless battle-simulation verification run.
##
## Only called when the current _target dies/goes invalid, not re-run every
## frame - "consistent DPS to squishy targets" means committing to a kill,
## not constantly re-scoring and flip-flopping toward marginally-better
## targets mid-fight, which would spread damage around instead of securing
## kills.
func _retarget() -> void:
	var live := _live_enemies()
	if live.is_empty():
		_target = null
		return
	var best: CombatUnit = live[0]
	var best_score := _score_target(best)
	for c in live:
		var score := _score_target(c)
		if score > best_score:
			best = c
			best_score = score
	_target = best


## Weighted target score: type preference (TYPE_PREFERENCE) + how wounded
## the candidate already is (WOUNDED_WEIGHT) + how close it is to this
## unit's ward, if any (WARD_THREAT_WEIGHT) - distance to the candidate
## itself only ever factors in as a small tiebreaker (DISTANCE_WEIGHT). See
## each const's own comment for why it's weighted the way it is.
func _score_target(candidate: CombatUnit) -> float:
	var score: float = TYPE_PREFERENCE[unit_type].get(candidate.unit_type, 0.0)
	var hp_frac := candidate.health / candidate.max_health if candidate.max_health > 0.0 else 0.0
	score += (1.0 - hp_frac) * WOUNDED_WEIGHT
	if is_instance_valid(ward):
		var dist_to_ward := candidate.global_position.distance_to(ward.global_position)
		score += WARD_THREAT_WEIGHT * clampf(1.0 - dist_to_ward / WARD_THREAT_RADIUS, 0.0, 1.0)
	score -= global_position.distance_to(candidate.global_position) * DISTANCE_WEIGHT
	return score


## Trapper-only (see _process()) - picks whichever living Archer/Mage ally
## is currently in the most danger (nearest enemy closest to them), falling
## back to nearest ally if no enemies are alive to threaten anyone. Reads
## formation.living_units rather than a separate "allies" reference - it's
## already the exact same array CombatTestManager points a team's Formation
## at, so there's nothing new to keep in sync.
##
## Each Trapper decides independently, with no central assignment step, so
## danger alone isn't enough: every Trapper would agree on the single
## most-threatened archer and all pile onto it, leaving every other archer
## completely unguarded (confirmed via a headless trace before this fix -
## all 3 Trappers in one test converged on the same ward). _ward_score()
## folds in how many *other* living Trappers already guard a candidate as a
## strong penalty, so coverage spreads across every available ward first;
## only once everyone already has at least one guard does it become worth
## doubling up on whichever is most endangered.
func _update_ward() -> void:
	if not is_instance_valid(formation):
		ward = null
		return
	var candidates: Array = formation.living_units.filter(func(u):
		var c: CombatUnit = u
		return is_instance_valid(c) and not c._dead and c != self and (c.unit_type == UnitType.ARCHER or c.unit_type == UnitType.MAGE)
	)
	if candidates.is_empty():
		ward = null
		return
	var live_enemies := _live_enemies()
	var best: CombatUnit = candidates[0]
	var best_score := _ward_score(best, live_enemies)
	for c in candidates:
		var score := _ward_score(c, live_enemies)
		if score > best_score:
			best = c
			best_score = score
	ward = best


## WARD_COVERAGE_PENALTY is deliberately far larger than any possible
## _danger_to() gap (bounded by the map's own diagonal, ~2800px) - "already
## guarded by one more Trapper than some alternative" always outweighs any
## danger difference, guaranteeing an unguarded ward beats a guarded one
## regardless of relative threat, not just usually.
func _ward_score(candidate: CombatUnit, live_enemies: Array) -> float:
	var guard_count := 0
	for u in formation.living_units:
		var other: CombatUnit = u
		if other == self or not is_instance_valid(other) or other._dead:
			continue
		if other.unit_type == UnitType.TRAPPER and other.ward == candidate:
			guard_count += 1
	return _danger_to(candidate, live_enemies) - guard_count * WARD_COVERAGE_PENALTY


## Higher = more in danger (nearest enemy is closer). -INF with no living
## enemies at all, so any real ally beats "no candidate yet" in the caller's
## first-iteration comparison without needing a special case there.
func _danger_to(ally: CombatUnit, live_enemies: Array) -> float:
	if live_enemies.is_empty():
		return -INF
	var nearest := INF
	for e in live_enemies:
		nearest = minf(nearest, ally.global_position.distance_to((e as CombatUnit).global_position))
	return -nearest


func _live_enemies() -> Array:
	return enemies.filter(func(e): return is_instance_valid(e) and not (e as CombatUnit)._dead)


func _nearest(candidates: Array) -> CombatUnit:
	var best: CombatUnit = candidates[0]
	var best_dist := global_position.distance_squared_to(best.global_position)
	for c in candidates:
		var d := global_position.distance_squared_to((c as CombatUnit).global_position)
		if d < best_dist:
			best = c
			best_dist = d
	return best


## Only Swordsmen count as a "melee threat" to kite - matches Ideas/Combat
## Units.md, where only the Swordsman is a melee unit.
func _nearest_melee_threat() -> CombatUnit:
	var melee_enemies: Array = _live_enemies().filter(func(e): return (e as CombatUnit).unit_type == UnitType.SWORDSMAN)
	if melee_enemies.is_empty():
		return null
	var nearest := _nearest(melee_enemies)
	# The per-type default from STATS, unless this unit's current Formation
	# overrides it (e.g. "Skirmish" wants far more evasive ranged units,
	# "Guard" wants its front-line Archers holding ground like a tank
	# instead) - the tactics-as-a-formation-property extension point noted
	# in Ideas/Formation Strategy AI.md, now actually read.
	var radius: float = STATS[unit_type]["melee_avoid_radius"]
	if is_instance_valid(formation):
		radius = formation.tactics.get("melee_avoid_radius", radius)
	return nearest if global_position.distance_to(nearest.global_position) < radius else null


func _attack(target: CombatUnit) -> void:
	var mult: float = DAMAGE_MULTIPLIERS[target.unit_type][unit_type]
	var dmg: float = STATS[unit_type]["damage"] * mult
	target.take_damage(dmg)
	_punch()
	if STATS[unit_type]["ranged"]:
		_spawn_tracer(target.global_position)
	if unit_type == UnitType.TRAPPER:
		target.apply_slow(SLOW_MULTIPLIER, SLOW_DURATION)


func take_damage(amount: float) -> void:
	if _dead:
		return
	health = maxf(health - amount, 0.0)
	_update_health_bar()
	_spawn_floating_text("-%d" % int(round(amount)), Color(1.0, 0.35, 0.35))
	if health <= 0.0:
		_die()


## Called by a Trapper's _attack() on whatever it hits - overwrites any
## existing slow rather than stacking (see SLOW_MULTIPLIER/SLOW_DURATION's
## own comment for why). _process() ticks _speed_debuff_timer down and
## resets _speed_multiplier to 1.0 once it expires.
func apply_slow(multiplier: float, duration: float) -> void:
	if _dead:
		return
	_speed_multiplier = multiplier
	_speed_debuff_timer = duration
	_spawn_floating_text("Slowed!", Color(0.55, 0.85, 1.0))


func _die() -> void:
	_dead = true
	died.emit(self)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(self, "scale", Vector2(0.6, 0.6), 0.4)
	tween.tween_callback(queue_free)


func _punch() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _update_health_bar() -> void:
	var frac := clampf(health / max_health, 0.0, 1.0) if max_health > 0.0 else 0.0
	health_bar_fill.scale.x = frac
	health_bar_fill.color = Color(0.3, 1.0, 0.3).lerp(Color(1.0, 0.2, 0.2), 1.0 - frac)


func _spawn_floating_text(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.z_index = 100
	label.position = global_position + Vector2(-10.0, -110.0)
	get_parent().add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 24.0, 0.6)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)


func _spawn_tracer(target_pos: Vector2) -> void:
	var line := Line2D.new()
	line.add_point(global_position + Vector2(0.0, -50.0))
	line.add_point(target_pos + Vector2(0.0, -50.0))
	line.width = 2.0
	line.default_color = Color(1.0, 1.0, 0.6, 0.9)
	line.z_index = 50
	get_parent().add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.2)
	tween.tween_callback(line.queue_free)
