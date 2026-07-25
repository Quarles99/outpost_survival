extends RefCounted
class_name RaidController

## Owns one in-progress orc raid on the live village map - the in-place
## counterpart to CombatTestManager's battle bookkeeping (_spawn_battle/
## _check_empty_teams/_declare_result), scoped down to a single asymmetric
## town-vs-raiders fight instead of a general two-team sandbox. Base owns one
## instance (Base._raid) and drives it from its own _process(), the same
## "owner calls .update(delta) into a plain object" shape StrategistAI
## already uses for CombatTestManager - see that class's own doc comment.
##
## Two phases: orcs spawn and patrol/harass on their own (see OrcRaider) with
## no win/lose condition yet; begin_engagement() (called by
## Base._on_rally_pressed) turns it into a real fight once the player
## rallies a squad, and update() starts checking for a resolution from that
## point on. See Outpost_Survival/Game Systems/Village Raids.md.

var orcs: Array = []
var soldiers: Array = []
var formation_b: Formation = null
var formation_a: Formation = null
var engaged := false
var resolved := false
## "win"/"lose" from the town's perspective, same vocabulary
## Base._apply_battle_result already expects - only meaningful once resolved.
var outcome := ""
var casualty_ids: Array[String] = []


func setup_orcs(p_orcs: Array, p_formation_b: Formation) -> void:
	orcs = p_orcs
	formation_b = p_formation_b
	formation_b.living_units = orcs
	formation_b.original_roster_size = orcs.size()
	for orc in orcs:
		(orc as OrcRaider).died.connect(_on_orc_died)
		(orc as OrcRaider).escaped.connect(_on_orc_escaped)


## Called once, when the player presses Rally with this raid's orcs
## selected. Wires both rosters' `enemies` cross-references (same pattern as
## CombatTestManager._spawn_battle) and flips every live orc out of
## patrol/alert into Mode.ENGAGED - the one point OrcRaider hands off to
## CombatUnit's fully unmodified targeting/attack/morale AI.
##
## Also gives every orc a real formation_b slot_offset here, not at spawn -
## OrcRaider.setup_patrol leaves it at Vector2.ZERO (irrelevant while
## patrolling independently), so without this every orc would share the
## exact same leash center the instant combat's formation-leash pull
## (CombatUnit._apply_formation_pull) starts applying, rather than holding a
## proper battle line the way formation_a's soldiers already do via
## Base._on_rally_pressed's own assign_slots() call.
func begin_engagement(p_soldiers: Array, p_formation_a: Formation) -> void:
	soldiers = p_soldiers
	formation_a = p_formation_a
	formation_a.living_units = soldiers
	formation_a.original_roster_size = soldiers.size()
	for soldier in soldiers:
		(soldier as CombatUnit).enemies = orcs
		(soldier as CombatUnit).died.connect(_on_soldier_died)
		(soldier as CombatUnit).escaped.connect(_on_soldier_escaped)

	var orc_types: Array = orcs.map(func(o): return (o as OrcRaider).unit_type)
	var orc_offsets := formation_b.assign_slots(orc_types)
	for i in orcs.size():
		var orc: OrcRaider = orcs[i]
		orc.slot_offset = orc_offsets[i]
		orc.enemies = soldiers
		orc.mode = OrcRaider.Mode.ENGAGED
	engaged = true


func update(_delta: float) -> void:
	if resolved or not engaged:
		return
	_check_mass_rout(formation_a, "lose")
	if resolved:
		return
	_check_mass_rout(formation_b, "win")
	if resolved:
		return
	if orcs.is_empty():
		_declare("win")
	elif soldiers.is_empty():
		_declare("lose")


## Mirrors CombatTestManager._check_mass_rout exactly (see that function's
## own doc comment for why the result is decided the instant the threshold
## crosses, not once every straggler has physically left) - `outcome_if_routs`
## is from the town's perspective, the same "win"/"lose" vocabulary
## Base._apply_battle_result expects.
func _check_mass_rout(formation: Formation, outcome_if_routs: String) -> void:
	if resolved or not is_instance_valid(formation) or not formation.is_mass_routed():
		return
	formation.force_rout_all()
	_declare(outcome_if_routs)


func _declare(p_outcome: String) -> void:
	if resolved:
		return
	resolved = true
	outcome = p_outcome


func _on_soldier_died(unit: CombatUnit) -> void:
	if unit.citizen_id != "":
		casualty_ids.append(unit.citizen_id)
	soldiers.erase(unit)


func _on_soldier_escaped(unit: CombatUnit) -> void:
	soldiers.erase(unit)


func _on_orc_died(unit: CombatUnit) -> void:
	orcs.erase(unit)


func _on_orc_escaped(unit: CombatUnit) -> void:
	orcs.erase(unit)


## Frees every still-alive orc/soldier avatar and both Formations. Idempotent
## (safe to call once more after an already-torn-down raid) since every free
## is guarded by is_instance_valid - Base._teardown_raid relies on this being
## safe to call unconditionally both at natural resolution and as a load-time
## safety net (see that function's own doc comment).
func teardown() -> void:
	for unit in orcs + soldiers:
		if is_instance_valid(unit):
			(unit as Node).queue_free()
	if is_instance_valid(formation_a):
		formation_a.queue_free()
	if is_instance_valid(formation_b):
		formation_b.queue_free()
	orcs = []
	soldiers = []
