# Balance Tuning Reference

Every numeric balance knob in the game, in one condensed place. Edit values in this table directly, then hand it back for implementation - each row names the exact `const`/`@export`/dict entry and file so the edit can be applied precisely. Not player-facing (see `Docs/stats.md` for that) and not a full constant dump - AI-behavior epsilons/hysteresis timers (chase-stall give-up, LOS block give-up, kite retreat weights, etc.) are deliberately excluded as "feel" tuning, not balance.

Edit-and-hand-back workflow: change a **Value** cell, leave everything else alone (don't touch File/Line - if a line number drifts after other edits, re-derive it from the name before relying on it), and note *why* in a throwaway comment if it's not obvious - it'll get folded into the doc-comment when implemented. See [[Balance Changelog]] for the history of what's changed here and when - this table only ever shows the current state.

## Economy - Starting State & Storage

| Knob | Value | File:Line | Notes |
|---|---|---|---|
| Starting cabbage | 30.0 | `autoload/game_state.gd` `DEFAULT_RESOURCES` | The very first meal (54.0 for 3 citizens) now exceeds this outright - see Economy - Food Consumption below |
| Starting wood | 10.0 | `autoload/game_state.gd` `DEFAULT_RESOURCES` | Covers Lumber Camp only - Farm/House must be gathered for, see Construction section |
| Starting population / capacity | 3 | `autoload/game_state.gd:86` `DEFAULT_POPULATION` | |
| Base storage capacity (per resource) | 120.0 | `autoload/game_state.gd:99` `BASE_STORAGE_CAPACITY` | |
| Income rate sample window | 60.0s | `autoload/game_state.gd:121` `INCOME_WINDOW_SECONDS` | HUD's "X/min" readout |

## Economy - Food Consumption

| Knob                      | Value | File:Line                                               | Notes                                                                                                                                     |
| ------------------------- | ----- | ------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Food per citizen per meal | 10    | `autoload/game_state.gd:26` `FOOD_PER_CITIZEN_PER_MEAL` | Charged at both `DayNightCycle.day_started` and `night_started` - same amount both times by design. 36.0/citizen per full day+night cycle |

## Building Costs & Output

| Building          | Cost                          | Output/cycle                | Work interval  | File:Line                                                        |
| ----------------- | ------------------------------ | ---------------------------- | -------------- | ---------------------------------------------------------------- |
| Outpost Hall       | Not placeable (fixed start)    | -                             | -              | `scripts/building_catalog.gd:24`                                 |
| Cabbage Farm       | 10 wood                        | 1.0 cabbage                  | 3.0s (default) | `scripts/building_catalog.gd:34`                                 |
| Lumber Camp        | 10 wood                        | 2 wood/chop                  | 2.0s (chop)    | `scripts/building_catalog.gd:47`, `scripts/lumber_camp.gd:17,20` |
| House              | 20 wood                        | +2 pop capacity              | -              | `scripts/building_catalog.gd:59`                                 |
| House upgrade      | 20 wood + 10 brick             | +2 more pop capacity         | -              | `scripts/house.gd:22`                                            |
| Stone Mine         | 10 wood                        | 0.5 stone                    | 3.0s (default) | `scripts/building_catalog.gd:69`                                 |
| Brickmaker         | 10 wood + 10 stone             | 1 stone -> 0.5 brick         | 3.0s (default) | `scripts/building_catalog.gd:81`                                 |
| Well               | 5 wood + 10 stone              | unlimited water              | -              | `scripts/building_catalog.gd:93`                                 |
| Storage Facility   | 25 wood + 25 stone             | +60 capacity/resource        | -              | `scripts/building_catalog.gd:103`                                |
| Grain Farm         | 10 wood                        | 1.0 grain                    | 3.0s (default) | `scripts/building_catalog.gd:123`                                |
| Mill               | 10 wood + 10 brick             | 1 grain -> 1 flour           | 3.0s (default) | `scripts/building_catalog.gd:138`                                |
| Bakery             | 10 wood + 5 stone              | 1 flour -> 1 bread           | 3.0s (default) | `scripts/building_catalog.gd:151`                                |
| Hops Farm          | 10 wood                        | 1.0 hops                     | 3.0s (default) | `scripts/building_catalog.gd:164`                                |
| Brewery            | 10 wood + 5 stone + 5 brick    | 1 hops + 1 grain -> 1 beer   | 3.0s (default) | `scripts/building_catalog.gd:176`                                |
| Fruit Orchard      | 20 wood                        | 2.0 fruit                    | 6.0s           | `scripts/building_catalog.gd:189`                                |
| Potato Farm        | 10 wood                        | 1.0 potato                   | 3.0s (default) | `scripts/building_catalog.gd:202`                                |
| Barracks           | 20 wood + 10 stone             | trains melee_combat          | -              | `scripts/building_catalog.gd:229`                                |
| Archery Range      | 10 wood + 5 stone              | trains archery               | -              | `scripts/building_catalog.gd:241`                                |
| Mage Tower         | 10 wood + 10 stone + 5 brick   | trains spellcasting          | -              | `scripts/building_catalog.gd:253`                                |

**Not yet implemented** - two rows in a prior edit of this table described mechanics that don't exist in code yet, so they've been left out above rather than documented as if real (see this file's own "current state only" rule). Flagging here instead of silently dropping the idea:
- Outpost Hall tiered upgrades (3 tiers, first funded by brick) gating Archery Range (needs Barracks + tier 2) and Mage Tower (needs tier 3).
- Per-skill-level requirements to build/use Grain Farm (30 farming), Hops Farm (40), Fruit Orchard (60 "to use"), Potato Farm (20).

Both are real feature work (a prerequisite/tech-tree system), not numeric tuning - say the word if you want either built.

## Construction / Labor

| Knob | Value | File:Line | Notes |
|---|---|---|---|
| Labor required per material unit | 2.0 | `scripts/base.gd:87` `LABOR_PER_MATERIAL_UNIT` | `labor_required = max(total_cost * this, MIN_LABOR_REQUIRED)` |
| Minimum labor required (floor) | 10.0 | `scripts/base.gd:88` `MIN_LABOR_REQUIRED` | |
| Labor added per work tick | 1.0 | `scripts/character.gd:51` `CONSTRUCTION_LABOR_PER_TICK` | Before skill/happiness multiplier |
| Construction haul priority | smallest-need-first | `scripts/character.gd` `_find_construction_haul_job` | Not a numeric knob - flag if reverting risks re-introducing the starvation soft-lock this fixed |

## Movement & Work Pace

| Knob                             | Value        | File:Line                                       | Notes                                                         |
| -------------------------------- | ------------ | ----------------------------------------------- | ------------------------------------------------------------- |
| Citizen move speed               | 70.0 px/s    | `scripts/character.gd:18` `MOVE_SPEED`          | Halved this session from 140.0                                |
| Min/max move duration            | 0.6s / 20.0s | `scripts/character.gd:19-20`                    | Clamps a haul/walk trip's tween duration                      |
| Default work cycle interval      | 3.0s         | `scripts/workstation.gd:51` `work_interval`     | Per-catalog-entry override possible (see Fruit Orchard above) |
| Carry limit (haul size)          | 8            | `scripts/workstation.gd:44` `carry_limit`       | Scaled by hauler's strength skill multiplier                  |
| XP per gather/work tick          | 4.0          | `scripts/character.gd:25` `XP_PER_GATHER`       | Flat, not scaled by output                                    |
| Speed-skill XP per second moving | 2.5          | `scripts/character.gd:69` `SPEED_XP_PER_SECOND` |                                                               |

## Day / Night

| Knob | Value | File:Line | Notes |
|---|---|---|---|
| Day duration | 480.0s (8 min) | `autoload/day_night_cycle.gd:24` `DAY_DURATION` | |
| Night duration | 240.0s (4 min) | `autoload/day_night_cycle.gd:25` `NIGHT_DURATION` | 2:1 day:night ratio |
| Recruit cooldown | 1 day | `autoload/day_night_cycle.gd:32` `recruit_cooldown_days` | `var`, not `const` - meant to be lowered by a future upgrade |
| Day/night tint transition | 8.0s | `scripts/base.gd:69` `DAY_NIGHT_TRANSITION_SECONDS` | |

## Fast Forward

| Knob | Value | File:Line | Notes |
|---|---|---|---|
| Speed multipliers | 1x / 2x / 4x | `scripts/base.gd:32` `SPEED_MULTIPLIERS` | Cycled by HUD Speed button / `+`/`-` |

## Happiness

| Knob                                    | Value                                                                         | File:Line                                          | Notes                              |
| --------------------------------------- | ----------------------------------------------------------------------------- | -------------------------------------------------- | ---------------------------------- |
| Tick interval                           | 5.0s                                                                          | `scripts/base.gd:97` `HAPPINESS_TICK_INTERVAL`     |                                    |
| Ease rate toward target                 | 1                                                                             | `scripts/base.gd:98` `HAPPINESS_EASE_RATE`         |                                    |
| Baseline target                         | 50.0                                                                          | `scripts/base.gd:99` `HAPPINESS_BASELINE`          |                                    |
| Water bonus                             | +5                                                                            | `scripts/base.gd:100` `HAPPINESS_WATER_BONUS`      |                                    |
| Food-stocked bonus                      | +10                                                                           | `scripts/base.gd:101` `HAPPINESS_FOOD_BONUS`       |                                    |
| Starving penalty                        | -20.0                                                                         | `scripts/base.gd:102` `HAPPINESS_STARVING_PENALTY` |                                    |
| Bonus per food-variety type stocked     | +5.0                                                                          | `scripts/base.gd:103` `HAPPINESS_PER_FOOD_VARIETY` |                                    |
| Unhappy threshold                       | 15                                                                            | `scripts/base.gd:105` `UNHAPPY_THRESHOLD`          | Below this counts toward departure |
| Ticks unhappy before a citizen leaves   | 12                                                                            | `scripts/base.gd:108` `LEAVE_AFTER_UNHAPPY_TICKS`  | At 5.0s/tick = 60s sustained       |
| Happiness bands (production multiplier) | Thriving 80+ ×1.15 / Content 50+ ×1.0 / Unhappy 20+ ×0.85 / Miserable 0+ ×0.6 | `scripts/base.gd:119` `HAPPINESS_BANDS`            |                                    |

## Citizen Recruitment

| Knob                          | Value | File:Line                                           | Notes                                                         |
| ----------------------------- | ----- | --------------------------------------------------- | ------------------------------------------------------------- |
| Cost per food tier            | 20    | `scripts/recruit_catalog.gd:20` `RECRUIT_UNIT_COST` | Tier-T candidate costs this much of every tier 0..T food type |
| Starting skill level (tier 0) | 10    | `scripts/recruit_catalog.gd:47` `STARTING_LEVEL`    |                                                               |
| Level step per food tier      | 10    | `scripts/recruit_catalog.gd:48` `TIER_LEVEL_STEP`   |                                                               |

## Military Buildings (Barracks/Archery Range/Mage Tower)

| Knob | Value | File:Line | Notes |
|---|---|---|---|
| Base unit cap | 3 | `scripts/training_ground.gd:55` `BASE_UNIT_CAP` | Overrides Workstation's usual 1-worker cap |
| Unit cap gained per upgrade | 3 | `scripts/training_ground.gd:56` `UNIT_CAP_PER_UPGRADE` | |
| Upgrade cost | 10 brick | `scripts/training_ground.gd:57` `UPGRADE_COST` | Flat per upgrade, repeatable/uncapped - not yet scaled by level |

## Skill Curve (all job/combat skills)

| Knob | Value | File:Line | Notes |
|---|---|---|---|
| Max level | 99 | `scripts/skill_curve.gd:10` `MAX_LEVEL` | |
| Output multiplier per level | 0.02 | `scripts/skill_curve.gd:12` `MULTIPLIER_PER_LEVEL` | ~2.96x at level 99 |

## Combat - Unit Stats (`scripts/combat/combat_unit.gd`)

| Type         | Health  | Damage | Armor | Range | Atk interval | Move speed |
| ------------ | ------- | ------ | ----- | ----- | ------------ | ---------- |
| Shieldbearer | 760     | 8      | 4     | 45    | 1.2s         | 120        |
| Marauder     | 340     | 18     | 1     | 45    | 0.8s         | 165        |
| Archer       | 280     | 16     | 0     | 260   | 1.2s         | 170        |
| Mage         | 220     | 14     | 0     | 220   | 1.5s         | 140        |
| Outrider     | 320     | 10     | 0     | 45    | 0.8s         | 200        |
| Trapper      | 400     | 9      | 0     | 60    | 1.1s         | 130        |

`STATS` at line 96, `ARMOR` at line 553. Health multiplier (`HEALTH_MULTIPLIER`, line 81) = 4.0x applied to every type's base HP - edit type ratios via the base numbers, not this multiplier, unless the goal is genuinely "make every fight take longer/shorter across the board."

## Combat - Damage Multipliers (`DAMAGE_MULTIPLIERS`, line 519)

Row = defender, column = attacker. 1.0 = neutral, >1.0 = takes bonus damage, <1.0 = resists.

| Defender ↓ / Attacker → | Shieldbearer | Marauder | Archer | Mage | Outrider | Trapper |
|---|---|---|---|---|---|---|
| Shieldbearer | 1.0 | 1.0 | 0.4 | 1.7 | 1.0 | 1.0 |
| Marauder | 1.0 | 1.0 | 0.6 | 1.0 | 1.0 | 1.0 |
| Archer | 1.5 | 1.5 | 1.0 | 0.5 | 1.0 | 1.0 |
| Mage | 1.5 | 1.5 | 1.5 | 0.5 | 1.0 | 1.0 |
| Outrider | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |
| Trapper | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |

Damage formula: `max(MIN_DAMAGE, (attacker_damage * skill_mult - defender_armor) * this_multiplier)`.

## Combat - Misc

| Knob                               | Value       | File:Line                                                                 | Notes                                                                     |
| ---------------------------------- | ----------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| Min damage floor                   | 1.0         | `scripts/combat/combat_unit.gd:569` `MIN_DAMAGE`                          | A hit can never be reduced past this                                      |
| Combat skill multiplier per level  | 0.005       | `scripts/combat/combat_unit.gd:67` `COMBAT_SKILL_MULTIPLIER_PER_LEVEL`    | Deliberately much smaller than the job-skill curve - "minor" scaling only |
| Mage splash radius                 | 90px        | `scripts/combat/combat_unit.gd:364` `MAGE_SPLASH_RADIUS`                  |                                                                           |
| Mage splash damage share           | 0.5         | `scripts/combat/combat_unit.gd:369` `MAGE_SPLASH_DAMAGE_MULTIPLIER`       | Of the primary hit, per splash victim                                     |
| Trapper slow multiplier / duration | 0.5x / 4.0s | `scripts/combat/combat_unit.gd:498-499` `SLOW_MULTIPLIER`/`SLOW_DURATION` |                                                                           |
| Rout morale threshold              | 45          | `scripts/combat/combat_unit.gd:407` `ROUT_MORALE_THRESHOLD`               | Below this, a unit breaks and flees                                       |
| Morale loss per wound (weight)     | 85.0        | `scripts/combat/combat_unit.gd:416` `MORALE_WOUND_WEIGHT`                 | Scaled by damage as a fraction of max HP                                  |
| Morale loss per nearby ally death  | 35.0        | `scripts/combat/combat_unit.gd:423` `MORALE_ALLY_DEATH_PENALTY`           | Within `MORALE_ALLY_DEATH_RADIUS` (260px)                                 |
| Morale ease rate                   | 8.0         | `scripts/combat/combat_unit.gd:431` `MORALE_EASE_RATE`                    | How fast morale drifts toward its target                                  |
| Escape (rout survive) time         | 5.0s        | `scripts/combat/combat_unit.gd:438` `ROUT_ESCAPE_TIME`                    | A routing unit survives once it flees this long                           |

See [[Balance Changelog]] for the history of changes made through this file's edit-and-hand-back workflow - this table itself always reflects the current implemented state only.
