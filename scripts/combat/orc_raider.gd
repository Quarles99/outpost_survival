extends CombatUnit
class_name OrcRaider

## A CombatUnit that starts out patrolling/harassing the live village map
## instead of immediately fighting - see Outpost_Survival/Actionable Ideas/
## Completed/Implement orc enemies present on the village map..md and
## Outpost_Survival/Game Systems/Village Raids.md for the full design.
## Spawned/owned by Base (_on_night_started_raid) and RaidController, not
## CombatTestManager - this class never appears in the standalone
## CombatTest.tscn sandbox.
##
## Mode.ENGAGED is the exact point this becomes a normal CombatUnit: once
## RaidController.begin_engagement() flips mode, _process() below starts
## calling super._process() every frame instead of the patrol/alert branch,
## handing off to the fully unmodified inherited targeting/attack/morale/
## formation-leash AI. CombatUnit._target is typed CombatUnit, so an orc can
## never "attack" a Character through that inherited machinery - the
## patrol/alert branch below deliberately never touches _target/_retarget()/
## _attack(), only Character.flee_home_from_raid().
enum Mode { PATROL, ALERTED, ENGAGED }

## --- Raid scaling (see Village Raids.md - explicitly flagged as needing
## playtesting/tuning, not derived from any existing balance number) -------
## No raid spawns until this day's night (day_number is still the *current*
## day when DayNightCycle.night_started fires - see that signal's own doc
## comment - so RAID_START_DAY=2 means the very first night, "Night 1", is
## always quiet).
const RAID_START_DAY := 2
const RAID_BASE_SIZE := 2
const RAID_MAX_SIZE := 7
## +1 orc every this many raids (not every night - RAID_START_DAY already
## gates which nights raid at all).
const RAID_SIZE_GROWTH_INTERVAL := 2
const RAID_BASE_SKILL_MAX := 3
const RAID_SKILL_GROWTH_PER_RAID := 1
const RAID_SKILL_CAP := 40
## Cycled to build a roster of any size - a beatable melee/ranged/tank mix
## from the very first (2-unit) raid rather than a random grab-bag.
const RAID_COMPOSITION_CYCLE: Array[CombatUnit.UnitType] = [
	CombatUnit.UnitType.MARAUDER, CombatUnit.UnitType.ARCHER, CombatUnit.UnitType.SHIELDBEARER,
	CombatUnit.UnitType.MARAUDER, CombatUnit.UnitType.SHIELDBEARER, CombatUnit.UnitType.ARCHER,
	CombatUnit.UnitType.MARAUDER,
]


## 1-indexed: RAID_START_DAY's night is raid 1, the next raid night is 2, etc.
static func _raid_number(day: int) -> int:
	return day - RAID_START_DAY + 1


static func roster_for_night(day: int) -> Array[CombatUnit.UnitType]:
	var raid_number := _raid_number(day)
	var size := clampi(RAID_BASE_SIZE + (raid_number - 1) / RAID_SIZE_GROWTH_INTERVAL, RAID_BASE_SIZE, RAID_MAX_SIZE)
	var roster: Array[CombatUnit.UnitType] = []
	for i in size:
		roster.append(RAID_COMPOSITION_CYCLE[i % RAID_COMPOSITION_CYCLE.size()])
	return roster


static func skill_level_for_night(day: int) -> int:
	var raid_number := _raid_number(day)
	var max_level := clampi(RAID_BASE_SKILL_MAX + (raid_number - 1) * RAID_SKILL_GROWTH_PER_RAID, RAID_BASE_SKILL_MAX, RAID_SKILL_CAP)
	return randi_range(1, max_level)


## How far from its own spawn point an orc wanders while patrolling.
const PATROL_RADIUS := 320.0
const PATROL_ARRIVE_DIST := 24.0
## Fraction of the type's own STATS move_speed used while patrolling - a
## leisurely stroll, not a battle-ready approach speed.
const PATROL_SPEED_FRACTION := 0.45

## How often an orc scans for a nearby villager to notice.
const NOTICE_INTERVAL := 1.5
const NOTICE_RADIUS := 220.0
## Rolled once per notice tick per orc - not guaranteed the instant a
## villager wanders close, so a patrol doesn't read as omniscient.
const ATTACK_CHANCE := 0.35
const ALERT_ARRIVE_DIST := 40.0
## Once an orc gives up on a caught villager (or the villager escapes it),
## briefly skip re-noticing so it doesn't instantly re-alert on the same
## target/spot.
const POST_ALERT_COOLDOWN := NOTICE_INTERVAL * 2.0

var mode: Mode = Mode.PATROL
var _patrol_center: Vector2
## Shared reference to Base.characters - never mutated here, only scanned.
var _citizens_ref: Array = []
var _alert_target: Character = null
var _notice_cooldown := 0.0


## Called right after the inherited CombatUnit.setup() - that call still
## does all sprite/stat/nav_agent init unchanged, this just adds the
## patrol-specific state setup() has no concept of.
func setup_patrol(p_patrol_center: Vector2, p_citizens: Array) -> void:
	_patrol_center = p_patrol_center
	_citizens_ref = p_citizens
	nav_agent.target_position = p_patrol_center


func _process(delta: float) -> void:
	if mode == Mode.ENGAGED:
		super._process(delta)
		return
	if _dead:
		return
	## Must run even outside Mode.ENGAGED, same as CombatUnit's own _process
	## does for itself - otherwise patrol/alert movement would only ever
	## cache a velocity (via the inherited _on_velocity_computed) and never
	## apply it, since this override never calls super._process() in these
	## two modes. See _integrate_velocity's own doc comment.
	_integrate_velocity(delta)
	_notice_cooldown -= delta
	match mode:
		Mode.PATROL:
			_process_patrol()
		Mode.ALERTED:
			_process_alert()


func _process_patrol() -> void:
	if global_position.distance_to(nav_agent.target_position) < PATROL_ARRIVE_DIST:
		_pick_new_patrol_target()
	var stats: Dictionary = STATS[unit_type]
	_step_toward(nav_agent.target_position, float(stats["move_speed"]) * PATROL_SPEED_FRACTION * _skill_multiplier)
	if _notice_cooldown <= 0.0:
		_notice_cooldown = NOTICE_INTERVAL
		_maybe_notice_citizen()


func _pick_new_patrol_target() -> void:
	var offset := Vector2.from_angle(randf() * TAU) * randf_range(60.0, PATROL_RADIUS)
	nav_agent.target_position = _patrol_center + offset


## Nearest live, visible citizen within NOTICE_RADIUS - a hidden (already-
## rallied-as-a-soldier) Character is invisible/input_pickable=false (see
## Base._on_rally_pressed) but stays in the characters array, so `visible`
## is what actually excludes them here, not array membership.
func _maybe_notice_citizen() -> void:
	var nearest: Character = null
	var nearest_dist := NOTICE_RADIUS
	for c in _citizens_ref:
		var citizen: Character = c
		if not is_instance_valid(citizen) or not citizen.visible:
			continue
		var dist := global_position.distance_to(citizen.global_position)
		if dist <= nearest_dist:
			nearest = citizen
			nearest_dist = dist
	if nearest == null:
		return
	if randf() < ATTACK_CHANCE:
		mode = Mode.ALERTED
		_alert_target = nearest


func _process_alert() -> void:
	if not is_instance_valid(_alert_target) or not _alert_target.visible:
		_end_alert()
		return
	var target_pos: Vector2 = _alert_target.global_position
	if global_position.distance_to(target_pos) <= ALERT_ARRIVE_DIST:
		_alert_target.flee_home_from_raid()
		_end_alert()
		return
	var stats: Dictionary = STATS[unit_type]
	_step_toward(target_pos, float(stats["move_speed"]) * _skill_multiplier)


func _end_alert() -> void:
	_alert_target = null
	mode = Mode.PATROL
	_notice_cooldown = POST_ALERT_COOLDOWN


## Same nav_agent-driven step Character._move_to's loop body uses, just run
## once per frame here instead of inside an awaited coroutine - CombatUnit's
## own _process is already frame-driven throughout, not coroutine-driven, so
## this matches that style rather than Character's.
func _step_toward(target_pos: Vector2, speed: float) -> void:
	nav_agent.target_position = target_pos
	nav_agent.max_speed = speed
	if nav_agent.is_navigation_finished():
		nav_agent.set_velocity(Vector2.ZERO)
		return
	var next_pos: Vector2 = nav_agent.get_next_path_position()
	var direction := global_position.direction_to(next_pos)
	_face(direction)
	nav_agent.set_velocity(direction * speed)
