# Stats Reference

Every concrete number currently in the game. Grouped by system; see [mechanics.md](mechanics.md) for how these numbers are used.

## Starting State

| | Value |
|---|---|
| Starting cabbage | 30 |
| Starting wood | 10 (a Lumber Camp outright, nothing more - Cabbage Farm and House must be earned via gathering, see mechanics.md#building--placement) |
| Starting stone / grain / flour / bread / hops / beer / fruit / potato / brick | 0 each |
| Starting population | 3 (Aldric, Brenna, Cass) |
| Starting population capacity | 3 |
| Starting water access | None (no Well built) |
| Starting citizen skill levels | All skills level 1 (0 xp) |
| Initial scattered trees | 12, mature, scattered within 5 tiles of the starting Lumber Camp |

## Resource Storage

| | Value |
|---|---|
| Baseline storage capacity (per resource, with no Storage Facility) | 120 |
| Storage Facility bonus | +60 (stacks per facility built) |
| Overflow behavior | Excess above capacity is lost, not refunded |
| Food-equivalent resources (drawn down for hunger, split evenly across whichever are in stock) | cabbage, potato, fruit, bread, beer ("Ale") |

## Food Bar (`HUD`)

| | Value |
|---|---|
| Location | Bottom-right corner, HUD |
| Fill | Aggregate food total (`GameState.get_total_food()`) against `storage_capacity` |
| Overlay | Red, inside the top of the fill - always shows the exact cost of the next meal (`FOOD_PER_CITIZEN_PER_MEAL * population_count`), not a rate projection |

## Resource Consumption

| | Value |
|---|---|
| Food (or food-equivalent) eaten per citizen per meal | 12.0 |
| Meal timing | Twice per day/night cycle - at dawn (`DayNightCycle.day_started`) and dusk (`night_started`), same amount both times |
| Applies to | every citizen, regardless of work assignment |
| Floor | resources can't go below 0 |

## Buildings

| Building | Footprint | Cost | Grants | Notes |
|---|---|---|---|---|
| Outpost Hall | 2×2 | Not placeable (fixed starting building) | — | A stockpile drop-off/pickup point - haulers use whichever registered stockpile (any Outpost Hall or Storage Facility) is nearest. |
| Cabbage Farm | 2×2 | 10 wood | — | The only Farm-family building placeable from the Build menu - converts wood → cabbage by default, then retool (see below) into any other Farm-family recipe. See production table below. |
| Lumber Camp | 1×1 | 10 wood | — | Produces wood by chopping trees. See production table below. |
| House | 2×2 | 50 wood | +2 population capacity | Passive — no worker slot. Click once placed to open a panel with a description and, if not yet upgraded, an Upgrade button previewing its cost (50 brick + 100 wood, for +2 more population capacity) before spending - denied if already upgraded or unaffordable. Deliberately no raw stone in the upgrade cost - an upgraded ("stone") house is built from worked brick, not the raw ore. |
| Stone Mine | 1×1 | 10 wood | — | Produces stone, no input needed. See production table below. |
| Well | 1×1 | 10 stone + 5 wood | +1 to water-well count (unlocks water access) | Passive — no worker slot. |
| Storage Facility | 2×4 | 25 wood + 25 stone | +60 storage capacity (all resources) | Also a stockpile drop-off/pickup point, same as the Outpost Hall, and assignable as a hauler post (see Assigning Citizens). Not upgradeable in place yet; build another for more capacity. |
| Brickmaker | 1×1 | 10 wood + 10 stone | — | Converts stone → brick. Not part of the Farm-family retool group (see below) - a dedicated, single-recipe building. See production table below. |
| Grain Farm | 2×2 | Not placeable directly (retool a Farm-family building into this recipe, free and instant) | — | Converts wood → grain. Crop-chain building; see table below. |
| Mill | 2×2 | 10 wood + 10 brick | — | Converts grain → flour. |
| Bakery | 2×2 | 10 wood + 5 stone | — | Converts flour → bread (edible). |
| Hops Farm | 2×2 | Not placeable directly (retool a Farm-family building into this recipe, free and instant) | — | Converts wood → hops. |
| Brewery | 2×2 | 10 wood + 5 stone + 5 brick | — | Converts hops → beer (luxury good, not edible). |
| Fruit Orchard | 2×2 | Not placeable directly (retool a Farm-family building into this recipe, free and instant) | — | Converts wood → fruit (edible) - slower but reliable. |
| Potato Farm | 2×2 | Not placeable directly (retool a Farm-family building into this recipe, free and instant) | — | Converts wood → potato (edible). |
| Barracks | 2×2 | 20 wood + 10 stone | — | Trains `melee_combat`. No input/output - pure time-worked xp (see Skills & Leveling). Max 1 built at once - see Combat-Building Recruit below. |
| Archery Range | 2×2 | 10 wood + 5 stone | — | Trains `archery`. Same no-input/output shape as Barracks. Max 1 built at once. |
| Mage Tower | 2×2 | 10 wood + 10 stone + 5 brick | — | Trains `spellcasting`. Same no-input/output shape as Barracks. Max 1 built at once. |

All 5 raw-crop Farm-family recipes (Cabbage/Grain/Hops/Fruit/Potato) share one retool group: click any placed one to switch it into any other, for free, at any time - see [mechanics.md](mechanics.md#building--placement). Only Cabbage Farm is placeable from the Build menu, per an explicit request to combine the five into one buildable building rather than five separate ones - Grain/Hops/Fruit/Potato are reached exclusively by retooling an existing Farm-family building afterward, never placed fresh. Mill/Bakery/Brewery are a separate, still-independently-placeable trio (Workshop-class, not Farm-class - see below), and Brickmaker and the three combat-training buildings (Barracks/Archery Range/Mage Tower, sharing `TrainingGround.tscn`) are deliberately excluded from the retool group entirely.

## Workstation Production

| | Farm | Lumber Camp | Stone Mine | Brickmaker |
|---|---|---|---|---|
| Output resource | cabbage | wood | stone | brick |
| Output per work cycle | 1.0 × skill multiplier | 2.0 × skill multiplier (per chop) | 0.5 × skill multiplier | 0.5 × skill multiplier |
| Input resource | wood | — | — | stone |
| Input cost per work cycle | 0.5 wood flat (not scaled by skill) | — | — | 1.0 stone flat (not scaled by skill) |
| Work cycle interval | 6.0 s | 3.0 s (per chop) | 6.0 s | 6.0 s (default) |
| Carry limit (output buffer cap / haul size) | 8.0 | 8.0 | 8.0 | 8.0 |
| Search radius (tree-finding, Lumber Camp only) | — | 4.5 tiles | — | — |
| Target forest size maintained (Lumber Camp only) | — | 16 trees within search radius | — | — |
| Skill trained | `farming` | `lumberjacking` | `mining` | `masonry` |
| Max workers assigned at once | 1 | 1 | 1 | 1 |

Brickmaker shares `Character._run_farm_loop` with the Farm class (input_per_tick/input_resource live on `Workstation` itself, not `Farm`, specifically so a non-Farm-family converter like this can reuse the loop) but does **not** get the Water Farming Bonus below - that bonus is gated to `post is Farm` specifically, since an irrigation well boosting brick-making wouldn't make sense.

## Worker Caps (`Workstation`)

| | Value |
|---|---|
| Max workers per Workstation (Farm-family, Lumber Camp, Stone Mine) | 1 |
| Max workers per military building (Barracks/Archery Range/Mage Tower) | 3, +3 per upgrade - see Military Building Unit Cap below |

Each post's status label shows live occupancy as `"<name>\n<active_workers>/<max_workers>"` (e.g. `"Lumber Camp 1/1"`), refreshed on every automatic assignment/unassignment. The Outpost Hall and Storage Facilities are never job posts - haulers are never explicitly "assigned" to either (see Automatic Job Assignment below), so they carry no worker count.

## Automatic Job Assignment (`Base`, `SkillTitles`)

| | Value |
|---|---|
| Job skills eligible for auto-assignment | farming, lumberjacking, mining, masonry, milling, baking, brewing, construction (`SkillTitles.TITLE_SKILLS`) |
| Matching algorithm | Citizen-proposing deferred acceptance (generalized Gale-Shapley), recomputed from scratch on every trigger |
| Triggers | Game boot/load, citizen recruited/departed, job post built/disabled/re-enabled |
| Swap condition | Strictly higher level in the contested skill only - ties never swap |
| Post disable toggle | Right-click any placed job post - evicts its current worker immediately, excluded from matching (0 capacity) until re-enabled |

The **Farm** class is a generic single-input/single-output converter (exported `input_per_tick`, `input_resource`, `skill_id`, `sprite_tint`) — the row above is its default configuration (wood → cabbage, "farming"). The full Alternative Crop Types chain is built from the same class, sharing one scene (`CropStation.tscn`) and distinguished only by catalog configuration:

| Building | Input → Output | Input/tick | Output/tick | Work interval | Skill trained |
|---|---|---|---|---|---|
| Grain Farm | wood → grain | 0.5 | 1.0 | 6.0 s (default) | `farming` |
| Mill | grain → flour | 1.0 | 1.0 | 6.0 s (default) | `milling` |
| Bakery | flour → bread | 1.0 | 1.0 | 6.0 s (default) | `baking` |
| Hops Farm | wood → hops | 0.5 | 1.0 | 6.0 s (default) | `farming` |
| Brewery | hops → beer | 1.0 | 1.0 | 6.0 s (default) | `brewing` |
| Fruit Orchard | wood → fruit | 1.0 | 2.0 | 12.0 s (slower) | `farming` |
| Potato Farm | wood → potato | 0.5 | 1.0 | 6.0 s (default) | `farming` |

Output/tick scales by the worker's skill multiplier the same way the base Farm's does; input/tick does not - a higher-level worker gets more output from the same input, not just more of both at a fixed ratio. Every Farm-family recipe now requires a wood input (Fruit Orchard and Potato Farm used to be input-free "consistent" crops - no longer, per an explicit request that all farms require wood).

A Farm-class post's haul trip triggers when its input buffer can't cover the next work cycle's input cost, or its output buffer is full (whichever comes first). A Lumber Camp or Stone Mine's haul trip triggers when its output buffer hits the carry limit.

## Trees (`WorldTree`)

| | Value |
|---|---|
| Wood per mature tree | 20.0 |
| Sapling → maturity grow time | 25 seconds |
| Sapling starting visual scale | 0.35× of full size |
| Wood harvested per chop | 2.0 × chopper's skill multiplier |

## Skill Curve (`SkillCurve`)

RuneScape-style exponential 1–99 curve: `xp_for_level(L) = floor(1/4 * sum[n=1..L-1] floor(n + 300 * 2^(n/7)) * multiplier_for_level(n))`. The `* multiplier_for_level(n)` factor is what makes xp *required* scale at the same rate xp *granted* does (see below) - without it, a worker's growing output multiplier would grant more xp per action every level while the requirement stayed fixed, snowballing level-up speed on top of the output bonus itself.

| | Value |
|---|---|
| Max level | 99 |
| Output multiplier per level above 1 | +2% |
| Multiplier at level 99 | ~2.96× a level-1 worker |
| XP granted per resource-production action (farming/lumberjacking/mining/masonry/milling/baking/brewing) | `amount produced this tick × 4.0` - a level-1 Cabbage Farm worker still grants exactly 4.0/tick (unchanged from the old flat rate), but a higher-level (higher-output) worker now grants proportionally more |
| XP granted per action (construction labor, training drill, strength per haul trip) | 4.0 flat, regardless of level or amount - these don't represent a real resource amount to scale against |

## Skill Titles (`SkillTitles`)

Eleven skills count: the eight job skills (farming, lumberjacking, mining, masonry, milling, baking, brewing, construction) plus the three combat skills (melee_combat, archery, spellcasting) - speed/strength are excluded, since they train passively and don't represent a trade. Job nouns for the three combat skills: melee_combat → Soldier, archery → Archer, spellcasting → Mage (e.g. "Master Archer").

| Level | Tier |
|---|---|
| 1 | Apprentice |
| 25 | Journeyman |
| 50 | Master |
| 75 | Grandmaster |
| 99 | Legendary |

Title = tier word (by whichever job skill is trained highest) + that skill's job noun (Farmer, Lumberjack, Miner, Mason, Miller, Baker, Brewer, Builder) - e.g. "Master Lumberjack". A tie at the same max level goes to whichever skill matches the citizen's current assignment, if any.

## Construction (`Base`, `ConstructionSite`, `Character`)

| | Value |
|---|---|
| Skill trained | `construction` |
| Materials delivery | Any idle/hauling citizen, same mechanism as output pickup/input delivery - see Gathering & Hauling |
| Labor required | `max(total units in the option's cost * 0.5, 2.0)` (`Base.LABOR_PER_MATERIAL_UNIT`/`MIN_LABOR_REQUIRED`) - e.g. a 25-wood Lumber Camp needs 12.5 labor, a 500-wood+100-stone Storage Facility needs 300 |
| Labor added per work cycle | 2.0 (`Character.CONSTRUCTION_LABOR_PER_TICK`) × the worker's construction skill multiplier × the settlement's happiness output multiplier × a multi-builder effectiveness factor (see below) |
| Work cycle interval | 6.0 s (`Workstation.work_interval` default, unchanged for a construction site) |
| Max workers per site | 3 (`ConstructionSite.MAX_BUILDERS`) - each worker's own labor-per-cycle is scaled by `1 / active_workers^0.5` (`Character.CONSTRUCTION_MULTI_BUILDER_EXPONENT`), so more builders finish a site faster but with diminishing returns rather than linearly (2 workers ≈1.41x a single worker's speed, 3 ≈1.73x, not 2x/3x) |
| What happens on completion | Site is freed; the real building is instantiated in its place and granted its capacity/water/storage bonus then, not at placement time; a fresh job-assignment pass runs immediately |
| What's spent, and when | The option's full cost, deducted resource-by-resource as each haul trip actually delivers it - nothing is spent at placement-confirm time |

## Movement & Work Timing (`Character`)

| | Value |
|---|---|
| Move speed | 70 px/s (before the speed skill's multiplier) |
| Min move duration (even for very short trips) | 0.6 s |
| Max move duration (even for very long trips) | 20.0 s |
| Pause at stockpile per haul trip | 0.3 s |
| Idle retry delay (no work found / target too empty) | 2.5 s |
| Minimum buffer amount worth an idle-hauler trip | 1.0 |

## Water Farming Bonus (`Character`)

| | Value |
|---|---|
| Farm-family output bonus with a Well built | 1.25× (output only, input cost unaffected) |

## Speed & Strength (`Character`)

| | Value |
|---|---|
| Speed xp per second spent moving | 2.5 |
| Strength xp per haul trip that moved anything | 4.0 (same flat amount as XP_PER_GATHER) |
| Effect of speed | Multiplies move speed (70 px/s base), same +2%/level curve as any other skill |
| Effect of strength | Multiplies a workstation's base carry_limit for that character's own haul trips |
| Trained by | Existing/moving (speed) and completing a haul trip (strength) - regardless of work assignment, unlike every other skill |

## Fast Forward (`Base`)

| | Value |
|---|---|
| Speed multipliers | 1x, 2x, 4x (cycles on click/key, wraps back to 1x) |
| Mechanism | `Engine.time_scale` - speeds up everything uniformly (movement, work, hunger, happiness, the day/night clock), not just one system |
| Controls | HUD "Speed" button (click to cycle), or `+`/`-` keys |
| Resets to 1x | On leaving Base (menu, battle deployment, quit) - a transient display preference, not saved game state |

## Camera (`RtsCamera`)

| | Value |
|---|---|
| Zoom range | 0.5× (zoomed out) – 2.0× (zoomed in) |
| Zoom step per scroll click | 0.1 |
| Zoom tween duration | 0.15 s |
| Edge-scroll trigger margin | 24 px from screen edge |
| Edge-scroll speed | 900 px/s (world space, scaled by zoom) |
| Extra pan room beyond map bounds | 320 world units |

## Income Rate (`GameState`)

| | Value |
|---|---|
| History sample interval | 1 s |
| Rolling window | Exactly 60 s once that much history exists (interpolated between samples straddling the boundary); shorter and exact just after boot |
| Displayed for | Wood, Stone (dedicated rows), and every food-family resource (aggregate + each of the collapsible breakdown's rows) |

## Happiness (`Base`, `CharacterData`)

| | Value |
|---|---|
| Happiness range | 0–100 |
| Starting happiness | 50 |
| Happiness re-target tick interval | 5 s |
| Ease rate (max change per tick) | 1.0 toward target |
| Baseline target (before bonuses/penalties) | 50 |
| Water access bonus/penalty | ±5 |
| Food-in-stock bonus | +10 |
| Starving (no food at all) penalty | −20 |
| Bonus per distinct food-equivalent resource in stock | +5 (see food-equivalent list above) |
| Unhappy threshold | below 15 |
| Consecutive unhappy ticks before a citizen leaves | 12 (12 × 5 s = 60 s) |

### Happiness Bands (production multiplier)

| Band | Settlement happiness | Output multiplier |
|---|---|---|
| Thriving | ≥ 80 | 1.15× |
| Content | ≥ 50 | 1.0× |
| Unhappy | ≥ 20 | 0.85× |
| Miserable | < 20 | 0.6× |

## Citizen Recruitment (`RecruitCatalog`)

| | Value |
|---|---|
| Candidates offered per visit | 3, distinct food tiers where possible |
| Food tiers (lowest to highest) | cabbage, potato, fruit, bread, beer ("Ale") |
| Cost per food type in a candidate's cost | 20 |
| Cost formula | 20 of the candidate's own tier's food, plus 20 of every cheaper tier's food (e.g. a bread-tier (index 3) candidate costs 20 cabbage + 20 potato + 20 fruit + 20 bread) |
| Starting level | 10 at tier 0 (cabbage), +10 per tier above that (10/20/30/40/50) |
| Possible specializations | farming, lumberjacking, mining, masonry, milling, baking, brewing, construction |
| Gated on | open population capacity, affording that candidate's own (tier-scaled) cost, and the once-per-day recruit cooldown (see Day & Night below) |

## Combat-Building Recruit (`TrainingGround`, `Base`)

| | Value |
|---|---|
| Buildings | Barracks (melee_combat/"Soldier"), Archery Range (archery/"Archer"), Mage Tower (spellcasting/"Mage") |
| Max built at once | 1 each (`BuildingCatalog`'s `"max_count"`) |
| Candidates offered | 1, always that building's own combat skill |
| Cost | Tier-0 (cabbage only), same 20/food-type rate as a normal recruit |
| Starting level | 10 (same as a tier-0 normal recruit) |
| Cooldown | Once per day, independent per building - does not consume or compete with the Outpost Hall's own cooldown |

## Military Building Unit Cap (`TrainingGround`, `Base`)

Barracks/Archery Range/Mage Tower each override `Workstation`'s normal 1-worker cap with their own, upgradeable one - clicking a built one now opens a panel offering both Recruit (see above) and Upgrade rather than jumping straight to a recruit candidate.

| | Value |
|---|---|
| Base unit cap (unupgraded) | 3 |
| Unit cap gained per upgrade | 3 |
| Upgrade cost | 10 brick, flat per upgrade (not yet scaled by level) |
| Max upgrade level | None - repeatable indefinitely |
| Effect | Raises that specific building's `max_workers`, so up to that many citizens can train there / deploy from it at once |

## Choosing a Unit Type (`TrainingGround`, `Base`)

Each Barracks/Archery Range is locked to producing one specific combat unit type at a time, chosen from that building's panel (a "Train: \<Unit\>" option alongside Recruit/Upgrade) - free and instant to change, any time, as many times as you like. It only decides which concrete unit a citizen trained there becomes on deployment (see Combat sandbox docs) - not their trained skill, XP, or anything else about them.

| Building | Choices | Default |
|---|---|---|
| Barracks (melee_combat) | Shieldbearer, Marauder, Pikeman | Shieldbearer |
| Archery Range (archery) | Archer, Skirmisher | Archer |
| Mage Tower (spellcasting) | Mage only - no choice offered | Mage |

Pikeman and Skirmisher are new unit types - see the combat sandbox's own balance reference for their stats. Outrider and Trapper (the previous two melee options) aren't currently producible by any building - they're being held for a future Stable building, not removed from the game.

## Day & Night (`DayNightCycle`)

| | Value |
|---|---|
| Day length | 480s (8 minutes) |
| Night length | 240s (4 minutes) |
| Day:Night ratio | 2:1 |
| Full cycle length | 720s (12 minutes) |
| Day counter | Increments at dawn (start of the day phase); starts at 1 |
| Recruit cooldown | 1 full day-number increment by default (`recruit_cooldown_days`) - a var, not a const, so a future upgrade can lower it; nothing does yet |
| World tint transition (dawn/dusk) | 8s tween between day/night colors |
| Persistence | Day number, phase, elapsed time within the phase, and last-recruit day all survive save/load and a battle deployment round trip |
| Food consumption | A flat meal (see Resource Consumption above) is charged at both `day_started` and `night_started` |

## Map Size (`IsoGround`, `Base.tscn`)

| | Value |
|---|---|
| Playable grid | 28×28 tiles (784 total) |
| Grid coordinate range | x: -12..15, y: -12..15 |

## Display (`project.godot`)

| | Value |
|---|---|
| Base viewport size | 1280×720 |
| Stretch mode | `canvas_items` (scales 2D scene + UI together) |
| Stretch aspect | `expand` (extra window space reveals more world/UI margin, never stretches or letterboxes) |
| Resizable | Yes |

## Save Slots (`SaveManager`)

| | Value |
|---|---|
| Number of slots | 3 |
| Save location | `user://saves/slot_N.json` |
| Legacy migration | A pre-slot-system `user://savegame.json`, if found, is moved into slot 1 on first boot |

## Grid Projection (`IsoUtils`)

| | Value |
|---|---|
| Tile width | 128 px |
| Tile height | 64 px |
| Projection | 2:1 dimetric ("AoE2-style"), not true isometric |
