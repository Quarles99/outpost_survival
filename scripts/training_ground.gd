extends Workstation
class_name TrainingGround

## Shared class for Barracks/Archery Range/Mage Tower - the "convert a
## citizen into a soldier" building from Outpost_Survival/Ideas/Combat
## Units.md's deferred integration item. Exactly the same relationship to
## Workshop (Mill/Bakery/Brewery) that class has to Farm: one class, three
## catalog entries distinguished only by skill_id (here "melee_combat"/
## "archery"/"spellcasting" instead of "milling"/"baking"/"brewing"), no
## input/output at all - training a citizen isn't a resource conversion,
## it's pure time-worked, so Character._run_training_loop (not
## _run_farm_loop) drives it. See CombatUnit.SKILL_ID/COMBAT_SKILL_MULTIPLIER_
## PER_LEVEL for the (still sandbox-only) other end of this skill id - real
## citizen levels trained here aren't fed into CombatUnit yet, that's a
## separate not-yet-built piece (see combat_unit.gd's own doc comment).
##
## `clicked` (added per an explicit request, "combat buildings offering an
## additional recruit per day of their combat style") mirrors Farm/
## OutpostHall/House's own clicked-signal pattern - Base opens a single-
## candidate recruit panel on this pre-trained in skill_id, gated by
## can_recruit() below. Deliberately still no Farm-family crop-selection
## wiring (that part of the original reasoning stands) - clicked here means
## "recruit," not "retool."
signal clicked

@export var skill_id: String = "melee_combat"

## Per-building once-per-day recruit cooldown, independent of DayNightCycle's
## own last_recruit_day (the Outpost Hall's cooldown) - per an explicit
## request that a built combat building grant an *additional* recruit per
## day, not compete with the settlement's normal one. Only sound because
## each combat building type is capped at one at a time (see
## BuildingCatalog's "max_count": 1 on barracks/archery_range/mage_tower) -
## without that cap, stacking several of the same building would each
## independently grant their own extra recruit, unbounded. Same 0-sentinel
## pattern as DayNightCycle.last_recruit_day (see its own doc comment) -
## day_number starts at 1 and only increases, so 0 can never be reached by
## real play, making "always recruitable before this building's first
## recruitment" fall out for free rather than needing a separate bool.
## Persisted across save/load - see Base._serialize_placed_buildings/
## _restore_placed_buildings, same conditional-field pattern House.upgraded/
## Workstation.disabled already use.
var last_recruit_day: int = 0

## Per-upgrade unit-cap growth - "military buildings should have a unit cap
## associated with the upgrade level, starting at 3 and increasing by 3 each
## time." A freshly-built military building trains BASE_UNIT_CAP citizens at
## once (overriding Workstation.max_workers' own default of 1 - see _ready);
## each purchased upgrade raises that by UNIT_CAP_PER_UPGRADE, uncapped (no
## max upgrade_level yet). Paid in brick only ("the first upgrade being from
## stone bricks") at a flat cost per upgrade - not scaled to get pricier at
## higher levels, since only the first upgrade's cost was specified; a
## natural next tuning knob if the flat rate turns out too cheap late-game
## (see Outpost_Survival/Balance.md).
const BASE_UNIT_CAP := 3
const UNIT_CAP_PER_UPGRADE := 3
const UPGRADE_COST := {"brick": 10.0}

## How many times this specific building has been upgraded - unlike House's
## one-shot `upgraded` bool, this counts up indefinitely. Persisted the same
## conditional way as last_recruit_day (see Base._serialize_placed_buildings/
## _restore_placed_buildings) - only written/restored when > 0, so an
## un-upgraded building's save entry is unchanged from before this field
## existed.
var upgrade_level: int = 0


func get_skill_id() -> String:
	return skill_id


func can_recruit() -> bool:
	if last_recruit_day == 0:
		return true
	return DayNightCycle.day_number - last_recruit_day >= DayNightCycle.recruit_cooldown_days


## Mirrors DayNightCycle.days_until_next_recruit() - Base's training-ground
## panel shows this on the Recruit option while it's on cooldown, same as
## the Outpost Hall's own flash-message wording.
func days_until_next_recruit() -> int:
	if can_recruit():
		return 0
	return DayNightCycle.recruit_cooldown_days - (DayNightCycle.day_number - last_recruit_day)


func mark_recruited() -> void:
	last_recruit_day = DayNightCycle.day_number


func get_unit_cap() -> int:
	return BASE_UNIT_CAP + upgrade_level * UNIT_CAP_PER_UPGRADE


## Live purchase path - increments by exactly one level and recomputes
## max_workers/the label immediately (see Base._on_training_ground_option_
## chosen for the spend/afford check that guards calling this).
func mark_upgraded() -> void:
	upgrade_level += 1
	max_workers = get_unit_cap()
	_update_label()


## Load-path counterpart to mark_upgraded() - jumps straight to a saved
## upgrade_level in one step rather than incrementing once per call, since a
## save can represent any number of prior upgrades.
func restore_upgrade_level(level: int) -> void:
	upgrade_level = level
	max_workers = get_unit_cap()
	_update_label()


func _ready() -> void:
	## Overrides Workstation.max_workers' exported default of 1 - see
	## get_unit_cap()'s doc comment. Set before super._ready() so the very
	## first _update_label() call (inside it) already reads the correct cap.
	max_workers = get_unit_cap()
	super._ready()
	input_event.connect(_on_input_event)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		clicked.emit()
