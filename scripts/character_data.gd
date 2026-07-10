extends Resource
class_name CharacterData

## Stable save/load identity, distinct from character_name - recruited
## citizens are drawn from a small procedural name pool (see RecruitCatalog)
## so two live citizens can end up sharing a display name. Empty for the 3
## hand-authored .tres characters until Base._ready() backfills one.
@export var id: String = ""
@export var character_name: String = ""
## skill_id (e.g. "farming", "lumberjacking") -> cumulative xp earned in it.
## Untracked skills default to 0 xp / level 1 rather than needing an entry.
@export var skill_xp: Dictionary = {}

## 0-100. Eases toward a target Base.gd recomputes periodically from
## settlement conditions (water access, food stock, food variety) rather
## than jumping instantly - see Base._on_happiness_tick.
@export var happiness: float = 50.0
## Consecutive happiness ticks spent below Base.UNHAPPY_THRESHOLD. Resets to
## 0 the moment happiness recovers; hitting Base.LEAVE_AFTER_UNHAPPY_TICKS
## means this citizen leaves for good. Persisted (not just runtime state) so
## a quicksave/quickload can't be used to reset a citizen's countdown.
@export var unhappy_streak: int = 0


func get_skill_xp(skill_id: String) -> float:
	return skill_xp.get(skill_id, 0.0)


func get_skill_level(skill_id: String) -> int:
	return SkillCurve.level_for_xp(get_skill_xp(skill_id))


func get_skill_multiplier(skill_id: String) -> float:
	return SkillCurve.multiplier_for_level(get_skill_level(skill_id))


func add_skill_xp(skill_id: String, amount: float) -> void:
	skill_xp[skill_id] = get_skill_xp(skill_id) + amount
