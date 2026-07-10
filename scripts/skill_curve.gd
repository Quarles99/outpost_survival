extends RefCounted
class_name SkillCurve

## Classic RuneScape-style 1-99 curve: cumulative xp needed for level L is
## floor(1/4 * sum_{n=1}^{L-1} floor(n + 300 * 2^(n/7))). Grows exponentially
## (logarithmic in the other direction: level as a function of xp flattens
## hard at the top) so early levels come quickly but level 99 is a
## many-hundred-hour aspirational grind, matching the design doc's
## "long grind to max out a skill" intent.
const MAX_LEVEL := 99
## +2%/level above 1, so a maxed (lvl 99) worker outputs ~2.96x a lvl 1 worker.
const MULTIPLIER_PER_LEVEL := 0.02

static var _xp_table: Array[float] = []


static func _ensure_table() -> void:
	if not _xp_table.is_empty():
		return
	_xp_table.append(0.0)
	var points := 0.0
	for level in range(1, MAX_LEVEL):
		points += floor(level + 300.0 * pow(2.0, level / 7.0))
		_xp_table.append(floor(points / 4.0))


## Total cumulative xp required to have reached `level`.
static func xp_for_level(level: int) -> float:
	_ensure_table()
	return _xp_table[clampi(level, 1, MAX_LEVEL) - 1]


static func level_for_xp(xp: float) -> int:
	_ensure_table()
	var level := 1
	for i in range(1, _xp_table.size()):
		if xp >= _xp_table[i]:
			level = i + 1
		else:
			break
	return level


static func multiplier_for_level(level: int) -> float:
	return 1.0 + (level - 1) * MULTIPLIER_PER_LEVEL


## 0-1 progress of `xp` between the current level and the next, for xp-bar UI.
static func xp_progress(xp: float, level: int) -> float:
	var cur := xp_for_level(level)
	var next := cur if level >= MAX_LEVEL else xp_for_level(level + 1)
	if next <= cur:
		return 1.0
	return clampf((xp - cur) / (next - cur), 0.0, 1.0)
