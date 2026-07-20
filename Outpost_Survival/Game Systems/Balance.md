# Balance Tuning Reference

Every numeric balance knob in the game, in one condensed place. Edit values in this table directly, then hand it back for implementation - each row names the exact `const`/`@export`/dict entry and file so the edit can be applied precisely. Not player-facing (see `Docs/stats.md` for that) and not a full constant dump - AI-behavior epsilons/hysteresis timers (chase-stall give-up, LOS block give-up, kite retreat weights, etc.) are deliberately excluded as "feel" tuning, not balance.

Edit-and-hand-back workflow: change a **Value** cell, leave everything else alone (don't touch File/Line - if a line number drifts after other edits, re-derive it from the name before relying on it), and note *why* in a throwaway comment if it's not obvious - it'll get folded into the doc-comment when implemented. See [[Balance Changelog]] for the history of what's changed here and when - this table only ever shows the current state.

Drift also runs the other way - a value can get changed directly in code (playtesting, a quick manual tweak) without this doc being updated to match. `tools/check_balance.py` (repo root) automates catching either direction: it parses every single-constant row here (`` `path` `` + `` `CONST_NAME` `` pair) and diffs the Value cell against the actual code. Run it (`python3 tools/check_balance.py`) before trusting this doc's current-state claim, especially after a play session where values might have been tweaked ad hoc. It flags real mismatches plus an UNRESOLVED list for rows it can't parse (dict/array-literal knobs like `DEFAULT_RESOURCES`/`HAPPINESS_BANDS`/`SPEED_MULTIPLIERS`, and the three table-shaped sections: Building Costs & Output, Combat - Unit Stats, Combat - Damage Multipliers) - those still need a manual read.

## Economy - Starting State & Storage

| Knob                                 | Value | File:Line                                            | Notes                                                                                                                                          |
| ------------------------------------ | ----- | ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| Starting cabbage                     | 100   | `autoload/game_state.gd` `DEFAULT_RESOURCES`         | Comfortably covers the very first meal (36.0 for 3 citizens) - see Economy - Food Consumption below                                            |
| Starting wood                        | 50    | `autoload/game_state.gd` `DEFAULT_RESOURCES`         | Covers a Lumber Camp (25 wood) with 25 to spare - Farm/House must be gathered for, see Construction section                                    |
| Starting population / capacity       | 3     | `autoload/game_state.gd:66` `DEFAULT_POPULATION`     |                                                                                                                                                |
| Base storage capacity (per resource) | 1000  | `autoload/game_state.gd:84` `BASE_STORAGE_CAPACITY`  | Raised via a direct code edit (bypassing this doc's usual edit-and-hand-back flow) - reconciled here after the fact, see [[Balance Changelog]] |
| Income rate sample window            | 60.0s | `autoload/game_state.gd:106` `INCOME_WINDOW_SECONDS` | HUD's "X/min" readout                                                                                                                          |

## Economy - Food Consumption

| Knob                      | Value | File:Line                                               | Notes                                                                                                                                     |
| ------------------------- | ----- | ------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Food per citizen per meal | 12    | `autoload/game_state.gd:19` `FOOD_PER_CITIZEN_PER_MEAL` | Charged at both `DayNightCycle.day_started` and `night_started` - same amount both times by design. 24.0/citizen per full day+night cycle |

## Building Costs & Output

| Building         | Cost                           | Output/cycle               | Work interval  | File:Line                                                        |
| ---------------- | ------------------------------ | -------------------------- | -------------- | ---------------------------------------------------------------- |
| Outpost Hall     | Not placeable (fixed start)    | -                          | -              | `scripts/building_catalog.gd:24`                                 |
| Cabbage Farm     | 25 wood                        | 0.5 wood -> 1.1 cabbage    | 6.0s (default) | `scripts/building_catalog.gd:40`                                 |
| Lumber Camp      | 25 wood                        | 2 wood/chop                | 6.0s (chop)    | `scripts/building_catalog.gd:56`, `scripts/lumber_camp.gd:17,24` |
| House            | 50 wood                        | +2 pop capacity            | -              | `scripts/building_catalog.gd:68`                                 |
| House upgrade    | 100 wood + 50 brick            | +2 more pop capacity       | -              | `scripts/house.gd:22`                                            |
| Stone Mine       | 25 wood                        | 0.6 stone                  | 6.0s (default) | `scripts/building_catalog.gd:79`                                 |
| Brickmaker       | 100 wood + 25 stone            | 1 stone -> 0.5 brick       | 6.0s (default) | `scripts/building_catalog.gd:91`                                 |
| Well             | 50 wood + 50 stone             | unlimited water            | -              | `scripts/building_catalog.gd:105`                                 |
| Storage Facility | 500 wood + 100 stone           | +60 capacity/resource      | -              | `scripts/building_catalog.gd:116`                                |
| Grain Farm       | 25 wood                        | 0.5 wood -> 1.0 grain      | 6.0s (default) | `scripts/building_catalog.gd:145`                                |
| Mill             | 50 wood + 25 brick             | 1 grain -> 1 flour         | 6.0s (default) | `scripts/building_catalog.gd:161`                                |
| Bakery           | 50 wood + 25 brick             | 1 flour -> 1 bread         | 6.0s (default) | `scripts/building_catalog.gd:178`                                |
| Hops Farm        | 25 wood                        | 0.5 wood -> 1.0 hops       | 6.0s (default) | `scripts/building_catalog.gd:193`                                |
| Brewery          | 25 wood + 15 stone + 15 brick  | 1.0 hops -> 1.0 beer       | 6.0s (default) | `scripts/building_catalog.gd:217`                                |
| Fruit Orchard    | 200 wood                       | 1.0 wood -> 2.2 fruit      | 12.0s          | `scripts/building_catalog.gd:237`                                |
| Potato Farm      | 25 wood                        | 0.5 wood -> 1.0 potato     | 6.0s (default) | `scripts/building_catalog.gd:253`                                |
| Barracks         | 100 wood + 25 stone            | trains melee_combat        | -              | `scripts/building_catalog.gd:283`                                |
| Archery Range    | 125 wood + 25 bricks           | trains archery             | -              | `scripts/building_catalog.gd:299`                                |
| Mage Tower       | 200 wood + 25 stone + 25 brick | trains spellcasting        | -              | `scripts/building_catalog.gd:313`                                |

Grain Farm/Hops Farm/Fruit Orchard/Potato Farm are `"placeable": false` as of an explicit request to combine the five raw-crop Farm-family buildings into one buildable building - their cost/output numbers above are still real (a retooled Farm produces exactly as this table shows once switched to that recipe), they're just no longer placeable fresh from the Build menu. Only Cabbage Farm is; every other crop is reached by retooling it afterward (free, instant - see stats.md/mechanics.md).

**Not yet implemented** - rows in a prior edit of this table described mechanics that don't exist in code yet, so they've been left out above rather than documented as if real (see this file's own "current state only" rule). Flagging here instead of silently dropping the idea:
- Outpost Hall tiered upgrades (3 tiers, first funded by brick) gating Archery Range (needs Barracks + tier 2) and Mage Tower (needs tier 3).
- Per-skill-level requirements to build/use Grain Farm (30 farming), Hops Farm (40), Fruit Orchard (60 "to use"), Potato Farm (20).
- Brewery's recipe as "1 hops + 1 grain -> 1 beer" (a second input) - `Workshop` (`workshop.gd`) only supports a single `input_resource`/`input_per_tick` pair today, shared by Mill/Bakery/Brewery alike, so a genuine two-input recipe needs a code change there (and to `Character._run_farm_loop`, which drives the buffered converter loop), not a value edit. Brewery's cost above *is* applied; its recipe stays single-input (hops only, 1.0 hops -> 1.0 beer) until that's built.

All three are real feature work, not numeric tuning - say the word if you want any built.

## Construction / Labor

| Knob                             | Value               | File:Line                                               | Notes                                                                                                     |
| -------------------------------- | ------------------- | ------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Labor required per material unit | 0.5                 | `scripts/base.gd:118` `LABOR_PER_MATERIAL_UNIT`          | `labor_required = max(total_cost * this, MIN_LABOR_REQUIRED)` - lowered from 2.0 to speed construction up |
| Minimum labor required (floor)   | 2.0                 | `scripts/base.gd:119` `MIN_LABOR_REQUIRED`               | Lowered from 10.0 to speed construction up                                                                |
| Labor added per work tick        | 2.0                 | `scripts/character.gd:78` `CONSTRUCTION_LABOR_PER_TICK` | Before skill/happiness multiplier                                                                         |
| Construction haul priority       | smallest-need-first | `scripts/character.gd` `_find_construction_haul_job`    | Not a numeric knob - flag if reverting risks re-introducing the starvation soft-lock this fixed           |

## Trees

| Knob              | Value       | File:Line                         | Notes                                                                            |
| ----------------- | ----------- | ---------------------------------- | -------------------------------------------------------------------------------- |
| Sapling grow time | 700 seconds | `scripts/tree.gd:20` `grow_time`  | Raised from 25.0 per an explicit "trees should take much longer to grow" request |
| Wood per tree     | 80          | `scripts/tree.gd:15` `max_wood`   | Raised from 20.0 per an explicit "increase wood per tree significantly" request - 40 chops to deplete at LumberCamp's default 2.0 wood/chop, up from 10 |

## Movement & Work Pace

| Knob                             | Value        | File:Line                                       | Notes                                                                                                                                                           |
| -------------------------------- | ------------ | ----------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Citizen move speed               | 70 px/s      | `scripts/character.gd:18` `MOVE_SPEED`          | Halved this session from 140.0                                                                                                                                  |
| Min/max move duration            | 0.6s / 20.0s | `scripts/character.gd:19-20`                    | Clamps a haul/walk trip's tween duration                                                                                                                        |
| Default work cycle interval      | 6.0s         | `scripts/workstation.gd:78` `work_interval`     | Per-catalog-entry override possible - Fruit Orchard's own explicit override scales alongside this default to stay 2x slower (see Building Costs & Output above) |
| Carry limit (haul size)          | 10           | `scripts/workstation.gd:66` `carry_limit`       | Scaled by hauler's strength skill multiplier                                                                                                                    |
| XP per gather/work tick          | 4.0          | `scripts/character.gd:33` `XP_PER_GATHER`       | Flat, not scaled by output                                                                                                                                      |
| Speed-skill XP per second moving | 2.5          | `scripts/character.gd:96` `SPEED_XP_PER_SECOND` |                                                                                                                                                                 |
| Citizen avoidance radius | 18 px | `scripts/character.gd:39` `AVOIDANCE_RADIUS` | RVO radius vs. other citizens, well under CollisionShape2D's 36px click-hitbox - new (Add collisions to villagers so they can't stack up on the same spot.md), first-pass, not tuned via playtesting |
| Citizen avoidance neighbor distance / time horizon | 150 px / 1.5s | `scripts/character.gd:40-41` `AVOIDANCE_NEIGHBOR_DISTANCE`/`AVOIDANCE_TIME_HORIZON_AGENTS` | Pulled down from NavigationServer's crowd-sim defaults (500px/~20s), same reasoning as CombatUnit's own tuning above |
| Dirt path wear gain / decay per second | 0.5 / 0.05 | `autoload/world_grid.gd:50,55` `WEAR_PER_SECOND`/`WEAR_DECAY_PER_SECOND` | New (Dynamic path building system.md), first-pass, not tuned via playtesting. Decay is 10x slower than gain on purpose - a constantly-crossed route stays worn, a one-off crossing fades in well under a minute |
| Dirt path threshold / max wear | 1.0 / 2.0 | `autoload/world_grid.gd:58,62` `WEAR_PATH_THRESHOLD`/`WEAR_MAX` | A cell becomes a visible worn path at 1.0 wear; clamped at 2.0 so a heavily-trodden tile doesn't take proportionally longer to decay back down once traffic stops |
| Dirt path speed bonus | 1.15x | `autoload/world_grid.gd:65` `PATH_SPEED_MULTIPLIER` | Applied to any citizen currently standing on a worn-path cell while moving |

## Day / Night

| Knob | Value | File:Line | Notes |
|---|---|---|---|
| Day duration | 480.0s (8 min) | `autoload/day_night_cycle.gd:24` `DAY_DURATION` | |
| Night duration | 240.0s (4 min) | `autoload/day_night_cycle.gd:25` `NIGHT_DURATION` | 2:1 day:night ratio |
| Recruit cooldown | 1 day | `autoload/day_night_cycle.gd:32` `recruit_cooldown_days` | `var`, not `const` - meant to be lowered by a future upgrade |
| Day/night tint transition | 8.0s | `scripts/base.gd:96` `DAY_NIGHT_TRANSITION_SECONDS` | |

## Fast Forward

| Knob | Value | File:Line | Notes |
|---|---|---|---|
| Speed multipliers | 1x / 2x / 4x | `scripts/base.gd:60` `SPEED_MULTIPLIERS` | Cycled by HUD Speed button / `+`/`-` |

## Happiness

| Knob                                    | Value                                                                         | File:Line                                          | Notes                              |
| --------------------------------------- | ----------------------------------------------------------------------------- | -------------------------------------------------- | ---------------------------------- |
| Tick interval                           | 5.0s                                                                          | `scripts/base.gd:128` `HAPPINESS_TICK_INTERVAL`     |                                    |
| Ease rate toward target                 | 1                                                                             | `scripts/base.gd:131` `HAPPINESS_EASE_RATE`         |                                    |
| Baseline target                         | 50.0                                                                          | `scripts/base.gd:132` `HAPPINESS_BASELINE`          |                                    |
| Water bonus                             | +5                                                                            | `scripts/base.gd:135` `HAPPINESS_WATER_BONUS`      |                                    |
| Food-stocked bonus                      | +10                                                                           | `scripts/base.gd:138` `HAPPINESS_FOOD_BONUS`       |                                    |
| Starving penalty                        | 20.0                                                                          | `scripts/base.gd:139` `HAPPINESS_STARVING_PENALTY` | Stored as a positive magnitude, applied as `-HAPPINESS_STARVING_PENALTY` at the one call site (`_on_happiness_tick`) - net effect is -20, doc previously showed that net value instead of the actual constant |
| Bonus per food-variety type stocked     | +5.0                                                                          | `scripts/base.gd:140` `HAPPINESS_PER_FOOD_VARIETY` |                                    |
| Unhappy threshold                       | 15                                                                            | `scripts/base.gd:144` `UNHAPPY_THRESHOLD`          | Below this counts toward departure |
| Ticks unhappy before a citizen leaves   | 12                                                                            | `scripts/base.gd:147` `LEAVE_AFTER_UNHAPPY_TICKS`  | At 5.0s/tick = 60s sustained       |
| Happiness bands (production multiplier) | Thriving 80+ ×1.15 / Content 50+ ×1.0 / Unhappy 20+ ×0.85 / Miserable 0+ ×0.6 | `scripts/base.gd:191` `HAPPINESS_BANDS`            |                                    |

## Citizen Recruitment

| Knob                          | Value | File:Line                                           | Notes                                                         |
| ----------------------------- | ----- | --------------------------------------------------- | ------------------------------------------------------------- |
| Cost per food tier            | 50    | `scripts/recruit_catalog.gd:22` `RECRUIT_UNIT_COST` | Tier-T candidate costs this much of every tier 0..T food type |
| Starting skill level (tier 0) | 10    | `scripts/recruit_catalog.gd:51` `STARTING_LEVEL`    |                                                               |
| Level step per food tier      | 10    | `scripts/recruit_catalog.gd:48` `TIER_LEVEL_STEP`   |                                                               |

## Military Buildings (Barracks/Archery Range/Mage Tower)

| Knob                        | Value               | File:Line                                              | Notes                                                           |
| --------------------------- | ------------------- | ------------------------------------------------------ | --------------------------------------------------------------- |
| Base unit cap               | 3                   | `scripts/training_ground.gd:88` `BASE_UNIT_CAP`        | Overrides Workstation's usual 1-worker cap                      |
| Unit cap gained per upgrade | 3                   | `scripts/training_ground.gd:89` `UNIT_CAP_PER_UPGRADE` |                                                                 |
| Upgrade cost                | 25 brick            | `scripts/training_ground.gd:90` `UPGRADE_COST`         | Flat per upgrade, repeatable/uncapped - not yet scaled by level |

## Skill Curve (all job/combat skills)

| Knob                        | Value | File:Line                                          | Notes              |
| --------------------------- | ----- | -------------------------------------------------- | ------------------ |
| Max level                   | 99    | `scripts/skill_curve.gd:10` `MAX_LEVEL`            |                    |
| Output multiplier per level | 0.02  | `scripts/skill_curve.gd:12` `MULTIPLIER_PER_LEVEL` | ~2.96x at level 99 |

## Combat - Unit Stats (`scripts/combat/combat_unit.gd`)

| Type         | Health  | Damage | Armor | Range | Atk interval | Move speed |
| ------------ | ------- | ------ | ----- | ----- | ------------ | ---------- |
| Shieldbearer | 760     | 8      | 4     | 45    | 1.2s         | 120        |
| Marauder     | 340     | 18     | 1     | 45    | 0.8s         | 165        |
| Archer       | 280     | 16     | 0     | 260   | 1.2s         | 170        |
| Mage         | 220     | 14     | 0     | 220   | 1.5s         | 140        |
| Outrider     | 320     | 10     | 0     | 45    | 0.8s         | 200        |
| Trapper      | 400     | 9      | 0     | 60    | 1.1s         | 130        |
| Pikeman      | 400     | 11     | 0     | 65    | 1.1s         | 125        |
| Skirmisher   | 260     | 13     | 0     | 220   | 1.0s         | 180        |

`STATS` at line 182, `ARMOR` at line 710. Health multiplier (`HEALTH_MULTIPLIER`, line 167) = 4.0x applied to every type's base HP - edit type ratios via the base numbers, not this multiplier, unless the goal is genuinely "make every fight take longer/shorter across the board." Pikeman/Skirmisher added per an explicit request ("Choosing what units to use at a barracks") - first-pass numbers, not tuned via playtesting, same as every other type here. Pikeman replaces Trapper as Barracks' melee-counter-specialist choice (longer reach, no debuff - see its hard counter in the Damage Multipliers table below); Skirmisher is Archery Range's alternative to Archer (less range/damage, faster attacks/movement, hard-counters Archer specifically). Outrider/Trapper are unchanged and still fully valid types - see `TrainingGround.UNIT_CHOICES_BY_SKILL` for why they're not currently producible by any building (a deferred Stable, not a removal).

## Combat - Damage Multipliers (`DAMAGE_MULTIPLIERS`, line 674)

Row = defender, column = attacker. 1.0 = neutral, >1.0 = takes bonus damage, <1.0 = resists.

| Defender ↓ / Attacker → | Shieldbearer | Marauder | Archer | Mage | Outrider | Trapper | Pikeman | Skirmisher |
| ----------------------- | ------------ | -------- | ------ | ---- | -------- | ------- | ------- | ---------- |
| Shieldbearer            | 1.0          | 1.0      | 0.4    | 1.5  | 1.0      | 1.0     | 1.0     | 0.4        |
| Marauder                | 1.0          | 1.0      | 0.6    | 1.0  | 1.0      | 1.0     | 1.0     | 0.6        |
| Archer                  | 1.0          | 1.0      | 1.0    | 0.5  | 1.0      | 1.0     | 1.5     | 1.6        |
| Mage                    | 1.0          | 1.0      | 1.0    | 0.5  | 1.0      | 1.0     | 1.5     | 1.2        |
| Outrider                | 1.0          | 1.0      | 1.0    | 1.0  | 1.0      | 1.0     | 1.7     | 1.0        |
| Trapper                 | 1.0          | 1.0      | 1.0    | 1.0  | 1.0      | 1.0     | 1.0     | 1.0        |
| Pikeman                 | 1.0          | 1.0      | 1.0    | 1.0  | 1.0      | 1.0     | 1.0     | 1.0        |
| Skirmisher              | 1.2          | 1.2      | 0.5    | 1.0  | 1.2      | 1.0     | 1.0     | 0.7        |

Pikeman's hard counter vs Outrider (2.0, in Outrider's own row) and Skirmisher's hard counter vs Archer (1.8, in Archer's own row) are the two new asymmetric relationships - everything else either mirrors an existing type's defensive shape (Skirmisher copies Archer's "weak to melee, resists magic" row) or stays neutral (Pikeman's own row is flat 1.0, same "no defensive edge" shape as Outrider/Trapper).

Damage formula: `max(MIN_DAMAGE, (attacker_damage * skill_mult - defender_armor) * this_multiplier)`.

## Combat - Misc

| Knob                               | Value       | File:Line                                                                 | Notes                                                                     |
| ---------------------------------- | ----------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| Min damage floor                   | 1.0         | `scripts/combat/combat_unit.gd:728` `MIN_DAMAGE`                          | A hit can never be reduced past this                                      |
| Combat skill multiplier per level  | 0.005       | `scripts/combat/combat_unit.gd:153` `COMBAT_SKILL_MULTIPLIER_PER_LEVEL`   | Deliberately much smaller than the job-skill curve - "minor" scaling only |
| Mage splash radius                 | 90px        | `scripts/combat/combat_unit.gd:498` `MAGE_SPLASH_RADIUS`                  |                                                                           |
| Mage splash damage share           | 0.5         | `scripts/combat/combat_unit.gd:503` `MAGE_SPLASH_DAMAGE_MULTIPLIER`       | Of the primary hit, per splash victim                                     |
| Trapper slow multiplier / duration | 0.5x / 4.0s | `scripts/combat/combat_unit.gd:498-499` `SLOW_MULTIPLIER`/`SLOW_DURATION` |                                                                           |
| Rout morale threshold              | 45          | `scripts/combat/combat_unit.gd:541` `ROUT_MORALE_THRESHOLD`               | Below this, a unit breaks and flees                                       |
| Morale loss per wound (weight)     | 85.0        | `scripts/combat/combat_unit.gd:550` `MORALE_WOUND_WEIGHT`                 | Scaled by damage as a fraction of max HP                                  |
| Morale loss per nearby ally death  | 35.0        | `scripts/combat/combat_unit.gd:557` `MORALE_ALLY_DEATH_PENALTY`           | Within `MORALE_ALLY_DEATH_RADIUS` (260px)                                 |
| Morale ease rate                   | 8.0         | `scripts/combat/combat_unit.gd:565` `MORALE_EASE_RATE`                    | How fast morale drifts toward its target                                  |
| Escape (rout survive) time         | 5.0s        | `scripts/combat/combat_unit.gd:572` `ROUT_ESCAPE_TIME`                    | A routing unit survives once it flees this long                           |

See [[Balance Changelog]] for the history of changes made through this file's edit-and-hand-back workflow - this table itself always reflects the current implemented state only.
