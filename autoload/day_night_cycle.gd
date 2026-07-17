extends Node

## Global day/night clock - foundation for the systems described in
## Outpost_Survival/Ideas/Day-Night Cycle.md (food consumption, work
## schedules/sleep, and more "down the road" per that note - none of those
## are wired up yet, only the clock itself, its visual tint, and the recruit
## cooldown below are). Anything that needs to react to the cycle should
## listen to day_started/night_started rather than polling is_day every
## frame.

## Emitted the instant a new day begins (dawn) - `day` is the new day_number.
signal day_started(day: int)
## Emitted the instant night falls - `day` is still the day that's ending
## (day_number hasn't incremented yet), so this reads as "Night <day>"
## following "Day <day>", not "Night <day+1>".
signal night_started(day: int)

## 8 minutes of day, 4 minutes of night - a 2:1 ratio, per an explicit
## request. Both in seconds, scaled by Engine.time_scale like any other
## Node._process delta (CombatTestManager cranking that up during a battle
## also speeds up the clock in the background while Base is unloaded - a
## minor, accepted side effect of a battle only ever lasting a couple of
## real minutes, not worth special-casing).
const DAY_DURATION := 480.0
const NIGHT_DURATION := 240.0

## How many full day_number increments must pass between a settlement's
## recruitments. A var, not a const, specifically so a future upgrade (a
## building/tech that speeds up recruiting) can lower it at runtime -
## nothing does yet, this is just the hook per an explicit request ("with
## potential upgrades or ways of increasing that down the line").
var recruit_cooldown_days := 1

var day_number := 1
var is_day := true
## Seconds elapsed within the *current* phase (day or night), not since the
## start of the full day+night cycle - resets to 0 every time day_started/
## night_started fires.
var phase_elapsed := 0.0

## Which day_number a citizen was most recently recruited on. 0 means
## "never recruited yet" - see can_recruit()'s doc comment for why that
## sentinel, rather than day_number itself, is what makes the very first
## recruitment always immediately available.
var last_recruit_day := 0


func _process(delta: float) -> void:
	phase_elapsed += delta
	var duration := DAY_DURATION if is_day else NIGHT_DURATION
	## `while`, not `if` - correct even across an implausibly large delta
	## spike (a stalled frame, a debugger pause) rather than only ever
	## advancing one phase per _process call.
	while phase_elapsed >= duration:
		phase_elapsed -= duration
		is_day = not is_day
		if is_day:
			day_number += 1
			day_started.emit(day_number)
		else:
			night_started.emit(day_number)
		duration = DAY_DURATION if is_day else NIGHT_DURATION


## 0.0 (phase just started) to 1.0 (about to flip) - exposed for a future
## HUD progress readout; nothing consumes it yet.
func phase_progress() -> float:
	var duration := DAY_DURATION if is_day else NIGHT_DURATION
	return clampf(phase_elapsed / duration, 0.0, 1.0)


## True once `recruit_cooldown_days` full days have passed since
## last_recruit_day - always true before the first-ever recruitment
## (last_recruit_day's 0 sentinel can never be reached by day_number, which
## starts at 1 and only increases), so a fresh settlement can recruit
## immediately rather than waiting out a cooldown against a recruitment
## that never happened.
func can_recruit() -> bool:
	if last_recruit_day == 0:
		return true
	return day_number - last_recruit_day >= recruit_cooldown_days


func mark_recruited() -> void:
	last_recruit_day = day_number


## How many more day_number increments until can_recruit() is true again -
## 0 if it already is. Used for the HUD's cooldown message.
func days_until_next_recruit() -> int:
	if can_recruit():
		return 0
	return recruit_cooldown_days - (day_number - last_recruit_day)


## Called by Base._ready() alongside GameState.reset_to_defaults() - see
## that call site's doc comment for why this is safe to call unconditionally
## even right before a save load overwrites every one of these fields.
func reset_to_defaults() -> void:
	day_number = 1
	is_day = true
	phase_elapsed = 0.0
	last_recruit_day = 0
